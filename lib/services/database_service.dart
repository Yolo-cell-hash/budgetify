import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/transaction_rule_model.dart';
import 'sms_parser_service.dart';

/// Database service for persisting transactions and budgets
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  /// Get the database instance, initializing if needed
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'budget_tracker.db');

    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables (fresh install)
  Future<void> _onCreate(Database db, int version) async {
    // Transactions table
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type INTEGER NOT NULL,
        sender TEXT NOT NULL,
        message TEXT NOT NULL,
        detected_at INTEGER NOT NULL,
        is_classified INTEGER NOT NULL DEFAULT 0,
        category TEXT,
        notes TEXT,
        account_info TEXT,
        merchant_name TEXT,
        is_manual INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX idx_transactions_detected_at ON transactions(detected_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_category ON transactions(category)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_merchant ON transactions(merchant_name)',
    );

    // Budgets table
    await db.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        period TEXT NOT NULL DEFAULT 'monthly',
        category TEXT,
        start_date TEXT NOT NULL,
        notified_50 INTEGER NOT NULL DEFAULT 0,
        notified_90 INTEGER NOT NULL DEFAULT 0,
        notified_100 INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Transaction rules table for auto-classification (merchant + type based)
    await db.execute('''
      CREATE TABLE transaction_rules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_name TEXT NOT NULL,
        transaction_type INTEGER NOT NULL,
        category TEXT NOT NULL,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_rules_sender ON transaction_rules(sender_name)',
    );
    await db.execute(
      'CREATE INDEX idx_rules_type ON transaction_rules(transaction_type)',
    );
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          period TEXT NOT NULL DEFAULT 'monthly',
          category TEXT,
          start_date TEXT NOT NULL,
          notified_50 INTEGER NOT NULL DEFAULT 0,
          notified_90 INTEGER NOT NULL DEFAULT 0,
          notified_100 INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }

    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN is_manual INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        // Column may already exist
      }
    }

    if (oldVersion < 5) {
      // Clean up old bank accounts table if it exists
      try {
        await db.execute('DROP TABLE IF EXISTS bank_accounts');
      } catch (e) {
        // Ignore errors
      }
    }

    if (oldVersion < 6) {
      // Original transaction rules table (will be migrated in v7)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transaction_rules(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender_pattern TEXT NOT NULL,
          message_keywords TEXT,
          category TEXT NOT NULL,
          notes TEXT,
          apply_to_future INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 7) {
      // Migrate to new sender-based + transaction-type-aware schema
      // Drop old rules table and create new one
      await db.execute('DROP TABLE IF EXISTS transaction_rules');
      await db.execute('''
        CREATE TABLE transaction_rules(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sender_name TEXT NOT NULL,
          transaction_type INTEGER NOT NULL,
          category TEXT NOT NULL,
          notes TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rules_sender ON transaction_rules(sender_name)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rules_type ON transaction_rules(transaction_type)',
      );
    }

    if (oldVersion < 8) {
      // Add merchant_name column to transactions
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN merchant_name TEXT',
        );
      } catch (e) {
        // Column may already exist
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_merchant ON transactions(merchant_name)',
      );

      // Clear stale rules that were based on bank sender addresses
      // (they cause the buggy "Apply to All" behavior)
      await db.execute('DELETE FROM transaction_rules');

      // Backfill merchant names for all existing transactions
      await _backfillMerchantNamesInternal(db);
    }
  }

  /// Internal backfill that works during migration (uses raw db handle)
  Future<void> _backfillMerchantNamesInternal(Database db) async {
    final rows = await db.query('transactions');
    for (final row in rows) {
      final message = row['message'] as String;
      final accountInfo = row['account_info'] as String?;
      final merchantName = SmsParserService.extractMerchantStatic(
        message,
        accountInfo,
      );
      if (merchantName != null) {
        await db.update(
          'transactions',
          {'merchant_name': merchantName},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  // ==================== TRANSACTION OPERATIONS ====================

  /// Insert a new transaction
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Check if a transaction with the same message already exists (avoid duplicates)
  Future<bool> transactionExists(String message, DateTime detectedAt) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'message = ? AND detected_at = ?',
      whereArgs: [message, detectedAt.millisecondsSinceEpoch],
    );
    return result.isNotEmpty;
  }

  /// Update a transaction
  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  /// Delete a transaction
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Get all transactions, ordered by date descending
  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'detected_at DESC');
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  /// Get transactions filtered by type
  Future<List<TransactionModel>> getTransactionsByType(
    TransactionType type,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: [type.index],
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  /// Get unclassified transactions
  Future<List<TransactionModel>> getUnclassifiedTransactions() async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'is_classified = 0',
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  /// Get transactions by category
  Future<List<TransactionModel>> getTransactionsByCategory(
    String category,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  /// Get transactions with combined filters
  Future<List<TransactionModel>> getFilteredTransactions({
    TransactionType? type,
    String? category,
    bool? unclassifiedOnly,
  }) async {
    final db = await database;

    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (type != null) {
      whereClauses.add('type = ?');
      whereArgs.add(type.index);
    }

    if (category != null) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    if (unclassifiedOnly == true) {
      whereClauses.add('is_classified = 0');
    }

    final maps = await db.query(
      'transactions',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  /// Get transactions within a date range
  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'detected_at >= ? AND detected_at <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'detected_at DESC',
    );
    return maps.map((map) => TransactionModel.fromMap(map)).toList();
  }

  /// Get total amount by transaction type
  Future<double> getTotalByType(TransactionType type) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ?',
      [type.index],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get transaction count
  Future<int> getTransactionCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM transactions',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get distinct categories used in transactions
  Future<List<String>> getUsedCategories() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM transactions WHERE category IS NOT NULL ORDER BY category',
    );
    return result.map((r) => r['category'] as String).toList();
  }

  // ==================== BUDGET OPERATIONS ====================

  Future<int> insertBudget(Budget budget) async {
    final db = await database;
    return await db.insert('budgets', budget.toMap());
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    return await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Budget>> getAllBudgets() async {
    final db = await database;
    final result = await db.query('budgets');
    return result.map((map) => Budget.fromMap(map)).toList();
  }

  Future<Budget?> getActiveBudget({String? category}) async {
    final db = await database;
    final result = await db.query(
      'budgets',
      where: category == null ? 'category IS NULL' : 'category = ?',
      whereArgs: category == null ? null : [category],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Budget.fromMap(result.first);
  }

  Future<double> getSpendingForPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
  }) async {
    final db = await database;
    String where = 'type = ? AND detected_at >= ? AND detected_at <= ?';
    List<dynamic> args = [
      TransactionType.debit.index,
      startDate.millisecondsSinceEpoch,
      endDate.millisecondsSinceEpoch,
    ];
    if (category != null) {
      where += ' AND category = ?';
      args.add(category);
    }
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE $where',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<DateTime, double>> getDailySpending({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      columns: ['detected_at', 'amount'],
      where: 'type = ? AND detected_at >= ? AND detected_at <= ?',
      whereArgs: [
        TransactionType.debit.index,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'detected_at ASC',
    );
    final Map<DateTime, double> daily = {};
    for (final row in result) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        row['detected_at'] as int,
      );
      final dayKey = DateTime(date.year, date.month, date.day);
      daily[dayKey] = (daily[dayKey] ?? 0) + (row['amount'] as num).toDouble();
    }
    return daily;
  }

  Future<void> updateBudgetNotificationFlags(
    int budgetId, {
    bool? n50,
    bool? n90,
    bool? n100,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (n50 != null) updates['notified_50'] = n50 ? 1 : 0;
    if (n90 != null) updates['notified_90'] = n90 ? 1 : 0;
    if (n100 != null) updates['notified_100'] = n100 ? 1 : 0;
    if (updates.isNotEmpty) {
      await db.update(
        'budgets',
        updates,
        where: 'id = ?',
        whereArgs: [budgetId],
      );
    }
  }

  // ==================== ANALYTICS QUERIES ====================

  /// Get spending breakdown by category for a period
  Future<Map<String, double>> getSpendingByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT category, SUM(amount) as total FROM transactions
      WHERE type = ? AND detected_at >= ? AND detected_at <= ? AND category IS NOT NULL
      GROUP BY category ORDER BY total DESC
    ''',
      [
        TransactionType.debit.index,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
    );

    return {
      for (var row in result)
        row['category'] as String: (row['total'] as num).toDouble(),
    };
  }

  /// Get monthly spending totals for last N months
  Future<List<Map<String, dynamic>>> getMonthlySpending({
    int months = 6,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final List<Map<String, dynamic>> monthlyData = [];

    for (int i = 0; i < months; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);

      final result = await db.rawQuery(
        '''
        SELECT SUM(amount) as total FROM transactions
        WHERE type = ? AND detected_at >= ? AND detected_at <= ?
      ''',
        [
          TransactionType.debit.index,
          monthStart.millisecondsSinceEpoch,
          monthEnd.millisecondsSinceEpoch,
        ],
      );

      monthlyData.add({
        'month': monthStart,
        'total': (result.first['total'] as num?)?.toDouble() ?? 0.0,
      });
    }

    return monthlyData.reversed.toList();
  }

  /// Get cash transactions (category = 'Cash' or 'Cash Conversion')
  Future<List<TransactionModel>> getCashTransactions() async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: "category IN (?, ?)",
      whereArgs: ['Cash', 'Cash Conversion'],
      orderBy: 'detected_at DESC',
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  /// Get transactions for a specific month
  Future<List<TransactionModel>> getTransactionsByMonth(DateTime month) async {
    final db = await database;
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final result = await db.query(
      'transactions',
      where: 'detected_at >= ? AND detected_at <= ? AND type = ?',
      whereArgs: [
        startOfMonth.millisecondsSinceEpoch,
        endOfMonth.millisecondsSinceEpoch,
        TransactionType.debit.index,
      ],
      orderBy: 'detected_at DESC',
      limit: 50,
    );
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  // ==================== TRANSACTION RULES OPERATIONS ====================

  /// Insert a new transaction rule
  Future<int> insertTransactionRule(TransactionRule rule) async {
    final db = await database;
    return await db.insert('transaction_rules', rule.toMap());
  }

  /// Get all transaction rules
  Future<List<TransactionRule>> getAllTransactionRules() async {
    final db = await database;
    final result = await db.query(
      'transaction_rules',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => TransactionRule.fromMap(map)).toList();
  }

  /// Get active rules
  Future<List<TransactionRule>> getActiveRules() async {
    final db = await database;
    final result = await db.query(
      'transaction_rules',
      where: 'is_active = 1',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => TransactionRule.fromMap(map)).toList();
  }

  /// Find a matching rule for a transaction (merchant name + type based)
  Future<TransactionRule?> findMatchingRule(
    String? merchantName,
    TransactionType transactionType,
  ) async {
    if (merchantName == null || merchantName.isEmpty) return null;

    final rules = await getActiveRules();
    for (final rule in rules) {
      if (rule.matches(merchantName, transactionType)) {
        return rule;
      }
    }
    return null;
  }

  /// Check if a rule already exists for this merchant + type combination
  Future<TransactionRule?> findExistingRule(
    String merchantName,
    TransactionType transactionType,
  ) async {
    final rules = await getAllTransactionRules();
    final normalizedMerchant = merchantName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    for (final rule in rules) {
      final normalizedRule = rule.senderName.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      if (normalizedRule == normalizedMerchant &&
          rule.transactionType == transactionType) {
        return rule;
      }
    }
    return null;
  }

  /// Update an existing rule
  Future<int> updateTransactionRule(TransactionRule rule) async {
    final db = await database;
    return await db.update(
      'transaction_rules',
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  /// Delete a transaction rule
  Future<int> deleteTransactionRule(int id) async {
    final db = await database;
    return await db.delete(
      'transaction_rules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Backfill merchant names for all existing transactions.
  /// Re-parses each SMS body to extract the merchant/payee name.
  /// Called during "Apply to All" / "Apply to Existing" to ensure
  /// all historical transactions have merchant names before bulk matching.
  Future<void> backfillMerchantNames() async {
    final db = await database;
    // Only backfill transactions that don't have a merchant name yet
    final rows = await db.query(
      'transactions',
      where: 'merchant_name IS NULL',
    );

    for (final row in rows) {
      final message = row['message'] as String;
      final accountInfo = row['account_info'] as String?;
      final merchantName = SmsParserService.extractMerchantStatic(
        message,
        accountInfo,
      );
      if (merchantName != null) {
        await db.update(
          'transactions',
          {'merchant_name': merchantName},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  /// Bulk update transactions by merchant name and type.
  /// Only updates transactions that match BOTH merchant name and transaction type.
  /// This is the corrected version that matches on extracted merchant/payee,
  /// not on the bank SMS sender address.
  Future<int> bulkUpdateByMerchant({
    required String merchantName,
    required TransactionType transactionType,
    required String category,
    String? notes,
  }) async {
    final transactions = await getAllTransactions();
    int updatedCount = 0;

    // Normalize the merchant name for matching
    final normalizedPattern = merchantName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    for (final txn in transactions) {
      // Must match transaction type exactly
      if (txn.type != transactionType) continue;

      // Must have a merchant name to match against
      if (txn.merchantName == null || txn.merchantName!.isEmpty) continue;

      // Check merchant match (normalized)
      final normalizedMerchant = txn.merchantName!.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      if (!normalizedMerchant.contains(normalizedPattern) &&
          !normalizedPattern.contains(normalizedMerchant)) {
        continue;
      }

      // Skip if already classified with this category
      if (txn.category == category && txn.isClassified) continue;

      // Update this transaction
      final updated = txn.copyWith(
        category: category,
        notes: notes,
        isClassified: true,
      );
      await updateTransaction(updated);
      updatedCount++;
    }

    return updatedCount;
  }

  /// @deprecated Use [bulkUpdateByMerchant] instead.
  /// Kept for backward compatibility but now redirects to merchant-based matching.
  Future<int> bulkUpdateBySenderAndType({
    required String senderName,
    required TransactionType transactionType,
    required String category,
    String? notes,
  }) async {
    return bulkUpdateByMerchant(
      merchantName: senderName,
      transactionType: transactionType,
      category: category,
      notes: notes,
    );
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
