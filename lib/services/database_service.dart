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
      version: 11,
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
        is_manual INTEGER NOT NULL DEFAULT 0,
        fingerprint TEXT
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
    await db.execute(
      'CREATE UNIQUE INDEX idx_transactions_fingerprint ON transactions(fingerprint)',
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
        notified_100 INTEGER NOT NULL DEFAULT 0,
        last_notified_threshold INTEGER NOT NULL DEFAULT 0
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

    // Tombstones for user-deleted SMS transactions, so rescans of the
    // inbox don't resurrect them
    await db.execute(_createDeletedTransactionsTable);
    await db.execute(
      'CREATE INDEX idx_deleted_fingerprint ON deleted_transactions(fingerprint)',
    );
  }

  static const String _createDeletedTransactionsTable = '''
      CREATE TABLE IF NOT EXISTS deleted_transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fingerprint TEXT,
        message TEXT,
        detected_at INTEGER,
        deleted_at INTEGER NOT NULL
      )
    ''';

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

    if (oldVersion < 9) {
      // Add last_notified_threshold column to budgets
      try {
        await db.execute(
          'ALTER TABLE budgets ADD COLUMN last_notified_threshold INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        // Column may already exist
      }

      // Migrate old boolean flags to new threshold integer
      // Compute the highest threshold from existing flags
      await db.rawUpdate('''
        UPDATE budgets SET last_notified_threshold = CASE
          WHEN notified_100 = 1 THEN 100
          WHEN notified_90 = 1 THEN 90
          WHEN notified_50 = 1 THEN 50
          ELSE 0
        END
      ''');
    }

    if (oldVersion < 10) {
      // Add fingerprint column for deduplication
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN fingerprint TEXT',
        );
      } catch (e) {
        // Column may already exist
      }

      // Backfill fingerprints for all existing transactions
      await _backfillFingerprintsInternal(db);

      // Remove duplicates (keep the row with the lowest id)
      await _deduplicateTransactionsInternal(db);

      // Now create the unique index
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_fingerprint ON transactions(fingerprint)',
      );
    }

    if (oldVersion < 11) {
      // Tombstones so deleted SMS transactions stay deleted across rescans
      await db.execute(_createDeletedTransactionsTable);
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_deleted_fingerprint ON deleted_transactions(fingerprint)',
      );
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

  /// Backfill fingerprints for all existing transactions during migration.
  Future<void> _backfillFingerprintsInternal(Database db) async {
    final rows = await db.query('transactions');
    for (final row in rows) {
      final amount = row['amount'] as double;
      final type = TransactionType.values[row['type'] as int];
      final sender = row['sender'] as String;
      final message = row['message'] as String;
      final detectedAt = DateTime.fromMillisecondsSinceEpoch(
        row['detected_at'] as int,
      );

      final fingerprint = TransactionModel.computeFingerprint(
        amount: amount,
        type: type,
        sender: sender,
        message: message,
        detectedAt: detectedAt,
      );

      await db.update(
        'transactions',
        {'fingerprint': fingerprint},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  /// Remove duplicate transactions during migration.
  /// For each group of rows sharing the same fingerprint, keep only the one
  /// with the smallest id (the original) and delete the rest.
  Future<void> _deduplicateTransactionsInternal(Database db) async {
    await db.execute('''
      DELETE FROM transactions
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM transactions
        WHERE fingerprint IS NOT NULL
        GROUP BY fingerprint
      ) AND fingerprint IS NOT NULL
    ''');
  }

  // ==================== TRANSACTION OPERATIONS ====================

  /// Insert a new transaction.
  /// Computes fingerprint if not set, and silently ignores duplicates.
  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    final txn = transaction.withFingerprint();
    return await db.insert(
      'transactions',
      txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Check if a transaction already exists by fingerprint (primary) or
  /// by exact message + timestamp (fallback for un-fingerprinted rows).
  Future<bool> transactionExists(String message, DateTime detectedAt,
      {String? fingerprint}) async {
    final db = await database;

    // Primary check: fingerprint match
    if (fingerprint != null) {
      final fpResult = await db.query(
        'transactions',
        where: 'fingerprint = ?',
        whereArgs: [fingerprint],
        limit: 1,
      );
      if (fpResult.isNotEmpty) return true;
    }

    // Fallback: exact message + timestamp match
    final result = await db.query(
      'transactions',
      where: 'message = ? AND detected_at = ?',
      whereArgs: [message, detectedAt.millisecondsSinceEpoch],
      limit: 1,
    );
    if (result.isNotEmpty) return true;

    // Tombstone check: the user explicitly deleted this transaction, so a
    // rescan of the SMS inbox must not bring it back
    if (fingerprint != null) {
      final tombstone = await db.query(
        'deleted_transactions',
        where: 'fingerprint = ?',
        whereArgs: [fingerprint],
        limit: 1,
      );
      if (tombstone.isNotEmpty) return true;
    }
    final msgTombstone = await db.query(
      'deleted_transactions',
      where: 'message = ? AND detected_at = ?',
      whereArgs: [message, detectedAt.millisecondsSinceEpoch],
      limit: 1,
    );
    return msgTombstone.isNotEmpty;
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

  /// Delete a transaction.
  ///
  /// SMS-derived transactions get a tombstone first so the same SMS is not
  /// re-imported by the next inbox scan. Manual transactions don't need
  /// one — nothing re-creates them.
  Future<int> deleteTransaction(int id) async {
    final db = await database;

    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty && (rows.first['is_manual'] as int? ?? 0) == 0) {
      final row = rows.first;
      await db.insert('deleted_transactions', {
        'fingerprint': row['fingerprint'],
        'message': row['message'],
        'detected_at': row['detected_at'],
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

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

  /// Update the last notified budget threshold for a budget.
  /// [threshold] is the percentage value (e.g. 50, 75, 90, 100, 120, 150, 200, ...).
  Future<void> updateLastNotifiedThreshold(
    int budgetId,
    int threshold,
  ) async {
    final db = await database;
    await db.update(
      'budgets',
      {
        'last_notified_threshold': threshold,
        // Keep old flags in sync for backward compat
        'notified_50': threshold >= 50 ? 1 : 0,
        'notified_90': threshold >= 90 ? 1 : 0,
        'notified_100': threshold >= 100 ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [budgetId],
    );
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

  /// Export every table as raw row maps, for encrypted backup.
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    return {
      'transactions': await db.query('transactions'),
      'budgets': await db.query('budgets'),
      'transaction_rules': await db.query('transaction_rules'),
    };
  }

  /// Import backup data, merging with existing rows.
  ///
  /// Transactions dedupe via the unique fingerprint index (or message +
  /// timestamp for rows without a fingerprint); budgets and rules are only
  /// inserted when no identical row already exists, so restoring the same
  /// backup twice is a no-op.
  Future<Map<String, int>> importBackupData(Map<String, dynamic> data) async {
    final db = await database;
    var txnCount = 0, budgetCount = 0, ruleCount = 0;

    for (final raw in (data['transactions'] as List? ?? const [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      row.remove('id');
      if (row['fingerprint'] == null) {
        final exists = await db.query(
          'transactions',
          where: 'message = ? AND detected_at = ?',
          whereArgs: [row['message'], row['detected_at']],
          limit: 1,
        );
        if (exists.isNotEmpty) continue;
      }
      final id = await db.insert(
        'transactions',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (id > 0) txnCount++;
    }

    for (final raw in (data['budgets'] as List? ?? const [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      row.remove('id');
      final exists = await db.query(
        'budgets',
        where: 'name = ? AND amount = ? AND period = ? AND start_date = ?',
        whereArgs: [row['name'], row['amount'], row['period'], row['start_date']],
        limit: 1,
      );
      if (exists.isNotEmpty) continue;
      await db.insert('budgets', row);
      budgetCount++;
    }

    for (final raw in (data['transaction_rules'] as List? ?? const [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      row.remove('id');
      final exists = await db.query(
        'transaction_rules',
        where: 'sender_name = ? AND transaction_type = ? AND category = ?',
        whereArgs: [row['sender_name'], row['transaction_type'], row['category']],
        limit: 1,
      );
      if (exists.isNotEmpty) continue;
      await db.insert('transaction_rules', row);
      ruleCount++;
    }

    return {
      'transactions': txnCount,
      'budgets': budgetCount,
      'rules': ruleCount,
    };
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
