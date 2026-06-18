import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/transaction_rule_model.dart';
import '../models/holding.dart';
import '../models/sip.dart';
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
      version: 15,
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
        last_notified_threshold INTEGER NOT NULL DEFAULT 0,
        notified_period TEXT
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

    // Manual net-worth / investment holdings
    await db.execute(_createHoldingsTable);

    // Monthly net-worth snapshots (powers the Wrapped net-worth-change stat)
    await db.execute(_createNetWorthSnapshotsTable);

    // Automated recurring investments (SIPs / RDs) + their instalment ledger.
    await db.execute(_createSipsTable);
    await db.execute(_createSipPaymentsTable);
    await db.execute(
      'CREATE INDEX idx_sip_payments_sip ON sip_payments(sip_id)',
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

  static const String _createHoldingsTable = '''
      CREATE TABLE IF NOT EXISTS holdings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        updated_at INTEGER NOT NULL
      )
    ''';

  static const String _createNetWorthSnapshotsTable = '''
      CREATE TABLE IF NOT EXISTS net_worth_snapshots(
        period TEXT PRIMARY KEY,
        net_worth REAL NOT NULL,
        assets REAL NOT NULL,
        liabilities REAL NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''';

  static const String _createSipsTable = '''
      CREATE TABLE IF NOT EXISTS sips(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL,
        amount_is_fixed INTEGER NOT NULL DEFAULT 1,
        day_of_month INTEGER NOT NULL,
        start_date INTEGER,
        end_date INTEGER,
        auto_detect INTEGER NOT NULL DEFAULT 1,
        holding_id INTEGER,
        prior_installments INTEGER NOT NULL DEFAULT 0,
        last_reminder_period TEXT,
        created_at INTEGER NOT NULL
      )
    ''';

  // One row per resolved monthly instalment. The UNIQUE(sip_id, period_key)
  // makes reconciliation idempotent — re-running a scan never double-records
  // the same month.
  static const String _createSipPaymentsTable = '''
      CREATE TABLE IF NOT EXISTS sip_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sip_id INTEGER NOT NULL,
        period_key TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL,
        transaction_id INTEGER,
        resolved_at INTEGER NOT NULL,
        UNIQUE(sip_id, period_key)
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

    if (oldVersion < 12) {
      // Per-period alert tracking: lets per-category (and the overall) budget
      // alerts reset cleanly each month instead of staying silenced after the
      // first period that crossed a high threshold.
      try {
        await db.execute(
          'ALTER TABLE budgets ADD COLUMN notified_period TEXT',
        );
      } catch (e) {
        // Column may already exist
      }
      // Anchor any already-notified budgets to the current period so the
      // upgrade itself doesn't replay an alert the user already saw.
      final now = DateTime.now();
      final periodKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await db.update(
        'budgets',
        {'notified_period': periodKey},
        where: 'last_notified_threshold > 0',
      );
    }

    if (oldVersion < 13) {
      // Manual net-worth / investment holdings table.
      await db.execute(_createHoldingsTable);
    }

    if (oldVersion < 14) {
      // Monthly net-worth snapshots for the Wrapped net-worth-change stat.
      await db.execute(_createNetWorthSnapshotsTable);
    }

    if (oldVersion < 15) {
      // Automated recurring investments (SIPs / RDs) + instalment ledger.
      await db.execute(_createSipsTable);
      await db.execute(_createSipPaymentsTable);
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sip_payments_sip ON sip_payments(sip_id)',
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

  /// Count unclassified transactions detected within [start]..[end]
  /// (used by the weekly "tag your transactions" reminder).
  Future<int> countUnclassifiedInPeriod(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions '
      'WHERE is_classified = 0 AND detected_at >= ? AND detected_at <= ?',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// How many transactions currently carry [category].
  Future<int> countTransactionsWithCategory(String category) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE category = ?',
      [category],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// Clear [category] from every transaction that carries it (used when a
  /// tag is deleted). Rows return to the unclassified queue.
  Future<int> untagCategory(String category) async {
    final db = await database;
    return db.update(
      'transactions',
      {'category': null, 'is_classified': 0},
      where: 'category = ?',
      whereArgs: [category],
    );
  }

  /// Get transactions with combined, independent filters.
  ///
  /// [type] (debit/credit/null=all), [category], and [classified]
  /// (true=classified only, false=unclassified only, null=all) all combine —
  /// e.g. unclassified debits, or classified credits.
  Future<List<TransactionModel>> getFilteredTransactions({
    TransactionType? type,
    String? category,
    bool? classified,
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

    if (classified != null) {
      whereClauses.add('is_classified = ?');
      whereArgs.add(classified ? 1 : 0);
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

  /// All per-category budgets (the overall budget — category IS NULL — is
  /// excluded). Ordered by amount so the larger envelopes surface first.
  Future<List<Budget>> getCategoryBudgets() async {
    final db = await database;
    final result = await db.query(
      'budgets',
      where: 'category IS NOT NULL',
      orderBy: 'amount DESC',
    );
    return result.map((map) => Budget.fromMap(map)).toList();
  }

  /// SQL fragment excluding non-expense categories (Self Transfer,
  /// Investments) from spending aggregates. Untagged debits (NULL category)
  /// are kept. Returns the clause and the args to append.
  static (String, List<Object>) _nonExpenseExclusion() {
    final cats = ExpenseCategories.nonExpense.toList();
    final placeholders = List.filled(cats.length, '?').join(', ');
    return ('(category IS NULL OR category NOT IN ($placeholders))', cats);
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
    } else {
      // Whole-period spend excludes self-transfers and investments
      final (clause, exArgs) = _nonExpenseExclusion();
      where += ' AND $clause';
      args.addAll(exArgs);
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
    String? category,
  }) async {
    final db = await database;
    // A specific category is requested verbatim (it's already a real expense
    // tag); the whole-day view instead excludes the non-expense categories.
    String where = 'type = ? AND detected_at >= ? AND detected_at <= ?';
    final List<Object> args = [
      TransactionType.debit.index,
      startDate.millisecondsSinceEpoch,
      endDate.millisecondsSinceEpoch,
    ];
    if (category != null) {
      where += ' AND category = ?';
      args.add(category);
    } else {
      final (clause, exArgs) = _nonExpenseExclusion();
      where += ' AND $clause';
      args.addAll(exArgs);
    }
    final result = await db.query(
      'transactions',
      columns: ['detected_at', 'amount'],
      where: where,
      whereArgs: args,
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
    int threshold, {
    String? period,
  }) async {
    final db = await database;
    await db.update(
      'budgets',
      {
        'last_notified_threshold': threshold,
        if (period != null) 'notified_period': period,
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
    final (clause, exArgs) = _nonExpenseExclusion();
    final result = await db.rawQuery(
      '''
      SELECT category, SUM(amount) as total FROM transactions
      WHERE type = ? AND detected_at >= ? AND detected_at <= ?
        AND category IS NOT NULL AND $clause
      GROUP BY category ORDER BY total DESC
    ''',
      [
        TransactionType.debit.index,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
        ...exArgs,
      ],
    );

    return {
      for (var row in result)
        row['category'] as String: (row['total'] as num).toDouble(),
    };
  }

  /// Count of expense transactions per category within [startDate]..[endDate]
  /// (debits only, classified, non-expense categories excluded). Drives the
  /// "your most-tagged spend has no budget" suggestion. Ordered most-frequent
  /// first.
  Future<Map<String, int>> getCategoryTransactionCounts({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final (clause, exArgs) = _nonExpenseExclusion();
    final result = await db.rawQuery(
      '''
      SELECT category, COUNT(*) as cnt FROM transactions
      WHERE type = ? AND detected_at >= ? AND detected_at <= ?
        AND category IS NOT NULL AND $clause
      GROUP BY category ORDER BY cnt DESC
    ''',
      [
        TransactionType.debit.index,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
        ...exArgs,
      ],
    );
    return {
      for (final row in result)
        row['category'] as String: (row['cnt'] as int),
    };
  }

  /// Merchant-level spend within a single [category] for a period. Each entry
  /// has `merchant` (String), `total` (double) and `count` (int), ordered by
  /// spend descending. Powers the merchant breakdown on the category budget
  /// insights page.
  Future<List<Map<String, dynamic>>> getMerchantBreakdownForCategory({
    required String category,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(NULLIF(TRIM(merchant_name), ''), 'Other') as merchant,
             SUM(amount) as total, COUNT(*) as cnt
      FROM transactions
      WHERE type = ? AND category = ? AND detected_at >= ? AND detected_at <= ?
      GROUP BY merchant ORDER BY total DESC
    ''',
      [
        TransactionType.debit.index,
        category,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
    );
    return [
      for (final row in result)
        {
          'merchant': row['merchant'] as String,
          'total': (row['total'] as num).toDouble(),
          'count': row['cnt'] as int,
        },
    ];
  }

  /// WHERE fragment matching one merchant, including the catch-all "Other"
  /// bucket (transactions with no extracted merchant name).
  static (String, List<Object>) _merchantClause(String merchant) {
    if (merchant == 'Other') {
      return ("(merchant_name IS NULL OR TRIM(merchant_name) = '')", const []);
    }
    return ('merchant_name = ?', [merchant]);
  }

  /// Top merchants by spend across all expense categories for a period.
  /// Debits only; non-expense categories (Self Transfer / Investments) are
  /// excluded. Each entry has `merchant`, `total` (double) and `count` (int),
  /// ordered by spend descending. [limit] 0 = no limit.
  Future<List<Map<String, dynamic>>> getMerchantBreakdown({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 0,
  }) async {
    final db = await database;
    final (clause, exArgs) = _nonExpenseExclusion();
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(NULLIF(TRIM(merchant_name), ''), 'Other') as merchant,
             SUM(amount) as total, COUNT(*) as cnt
      FROM transactions
      WHERE type = ? AND detected_at >= ? AND detected_at <= ? AND $clause
      GROUP BY merchant ORDER BY total DESC${limit > 0 ? ' LIMIT $limit' : ''}
    ''',
      [
        TransactionType.debit.index,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
        ...exArgs,
      ],
    );
    return [
      for (final row in result)
        {
          'merchant': row['merchant'] as String,
          'total': (row['total'] as num).toDouble(),
          'count': row['cnt'] as int,
        },
    ];
  }

  /// Per-month spend at a single [merchant] for the last [months] months,
  /// oldest first. Each entry has `month` (DateTime), `total` (double) and
  /// `count` (int). Powers the merchant trend chart.
  Future<List<Map<String, dynamic>>> getMerchantMonthlyTrend(
    String merchant, {
    int months = 6,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final (mClause, mArgs) = _merchantClause(merchant);
    final out = <Map<String, dynamic>>[];
    for (int i = months - 1; i >= 0; i--) {
      final mStart = DateTime(now.year, now.month - i, 1);
      final mEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);
      final r = await db.rawQuery(
        'SELECT SUM(amount) as total, COUNT(*) as cnt FROM transactions '
        'WHERE type = ? AND detected_at >= ? AND detected_at <= ? AND $mClause',
        [
          TransactionType.debit.index,
          mStart.millisecondsSinceEpoch,
          mEnd.millisecondsSinceEpoch,
          ...mArgs,
        ],
      );
      out.add({
        'month': mStart,
        'total': (r.first['total'] as num?)?.toDouble() ?? 0.0,
        'count': (r.first['cnt'] as int?) ?? 0,
      });
    }
    return out;
  }

  /// All debit transactions for [merchant] within a date range, newest first.
  Future<List<TransactionModel>> getMerchantTransactions(
    String merchant, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final (mClause, mArgs) = _merchantClause(merchant);
    final maps = await db.query(
      'transactions',
      where: 'type = ? AND detected_at >= ? AND detected_at <= ? AND $mClause',
      whereArgs: [
        TransactionType.debit.index,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
        ...mArgs,
      ],
      orderBy: 'detected_at DESC',
    );
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
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

      final (clause, exArgs) = _nonExpenseExclusion();
      final result = await db.rawQuery(
        '''
        SELECT SUM(amount) as total FROM transactions
        WHERE type = ? AND detected_at >= ? AND detected_at <= ? AND $clause
      ''',
        [
          TransactionType.debit.index,
          monthStart.millisecondsSinceEpoch,
          monthEnd.millisecondsSinceEpoch,
          ...exArgs,
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

  /// Apply every active rule to currently-unclassified transactions.
  ///
  /// This is what makes "auto tag all past transactions" work after a
  /// restore: once the rules are back, any past (or freshly re-scanned)
  /// transaction whose merchant matches a rule gets tagged automatically.
  /// Returns the number of transactions newly classified.
  Future<int> applyRulesToUntagged() async {
    final rules = await getActiveRules();
    if (rules.isEmpty) return 0;

    final db = await database;
    final rows = await db.query('transactions', where: 'is_classified = 0');
    var applied = 0;

    for (final row in rows) {
      final txn = TransactionModel.fromMap(row);
      for (final rule in rules) {
        if (rule.matches(txn.merchantName, txn.type)) {
          await db.update(
            'transactions',
            {
              'category': rule.category,
              'notes': rule.notes,
              'is_classified': 1,
            },
            where: 'id = ?',
            whereArgs: [txn.id],
          );
          applied++;
          break;
        }
      }
    }
    return applied;
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
  // ==================== HOLDINGS (NET WORTH) OPERATIONS ====================

  Future<int> insertHolding(Holding holding) async {
    final db = await database;
    return db.insert('holdings', holding.toMap());
  }

  Future<int> updateHolding(Holding holding) async {
    final db = await database;
    return db.update(
      'holdings',
      holding.toMap(),
      where: 'id = ?',
      whereArgs: [holding.id],
    );
  }

  Future<int> deleteHolding(int id) async {
    final db = await database;
    return db.delete('holdings', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Holding>> getHoldings() async {
    final db = await database;
    final maps = await db.query('holdings', orderBy: 'amount DESC');
    return maps.map((m) => Holding.fromMap(m)).toList();
  }

  /// Upsert the current month's net-worth snapshot from current holdings, so
  /// the monthly Wrapped can show a net-worth change once two months exist.
  Future<void> recordNetWorthSnapshotForCurrentMonth() async {
    final db = await database;
    final summary = NetWorthSummary(await getHoldings());
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    await db.insert(
      'net_worth_snapshots',
      {
        'period': period,
        'net_worth': summary.netWorth,
        'assets': summary.assets,
        'liabilities': summary.liabilities,
        'updated_at': now.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Net worth recorded for [period] ("YYYY-MM"), or null if none.
  Future<double?> getNetWorthSnapshot(String period) async {
    final db = await database;
    final r = await db.query(
      'net_worth_snapshots',
      columns: ['net_worth'],
      where: 'period = ?',
      whereArgs: [period],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (r.first['net_worth'] as num).toDouble();
  }

  /// All-time total the user has tagged as 'Investments' across detected
  /// transactions. Surfaced in the net-worth view so SMS-detected investing
  /// is visible alongside manual holdings.
  Future<double> getInvestmentsTagTotal() async {
    final db = await database;
    final r = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions "
      "WHERE type = ? AND category = 'Investments'",
      [TransactionType.debit.index],
    );
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// A single holding by id, or null. Used when a SIP instalment needs to
  /// top up its backing holding.
  Future<Holding?> getHolding(int id) async {
    final db = await database;
    final r = await db.query('holdings', where: 'id = ?', whereArgs: [id], limit: 1);
    if (r.isEmpty) return null;
    return Holding.fromMap(r.first);
  }

  // ==================== SIP / RD OPERATIONS ====================

  Future<int> insertSip(Sip sip) async {
    final db = await database;
    return db.insert('sips', sip.toMap());
  }

  Future<int> updateSip(Sip sip) async {
    final db = await database;
    return db.update('sips', sip.toMap(), where: 'id = ?', whereArgs: [sip.id]);
  }

  /// Delete a SIP and its instalment ledger. The backing holding is left in
  /// place — the money invested so far is real and stays in net worth.
  Future<void> deleteSip(int id) async {
    final db = await database;
    await db.delete('sip_payments', where: 'sip_id = ?', whereArgs: [id]);
    await db.delete('sips', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Sip>> getSips() async {
    final db = await database;
    final maps = await db.query('sips', orderBy: 'created_at DESC');
    return maps.map((m) => Sip.fromMap(m)).toList();
  }

  Future<Sip?> getSip(int id) async {
    final db = await database;
    final r = await db.query('sips', where: 'id = ?', whereArgs: [id], limit: 1);
    if (r.isEmpty) return null;
    return Sip.fromMap(r.first);
  }

  /// All instalments recorded for a SIP, newest first.
  Future<List<SipPayment>> getSipPayments(int sipId) async {
    final db = await database;
    final maps = await db.query(
      'sip_payments',
      where: 'sip_id = ?',
      whereArgs: [sipId],
      orderBy: 'period_key DESC',
    );
    return maps.map((m) => SipPayment.fromMap(m)).toList();
  }

  /// The instalment recorded for a given month, or null if none yet.
  Future<SipPayment?> getSipPaymentForPeriod(int sipId, String periodKey) async {
    final db = await database;
    final r = await db.query(
      'sip_payments',
      where: 'sip_id = ? AND period_key = ?',
      whereArgs: [sipId, periodKey],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return SipPayment.fromMap(r.first);
  }

  /// Number of *paid* instalments (detected or confirmed; skips excluded).
  Future<int> getPaidSipPaymentCount(int sipId) async {
    final db = await database;
    final r = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM sip_payments "
      "WHERE sip_id = ? AND status != 'skipped'",
      [sipId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// Total money credited so far via a SIP (paid instalments only).
  Future<double> getSipInvestedTotal(int sipId) async {
    final db = await database;
    final r = await db.rawQuery(
      "SELECT SUM(amount) AS t FROM sip_payments "
      "WHERE sip_id = ? AND status != 'skipped'",
      [sipId],
    );
    return (r.first['t'] as num?)?.toDouble() ?? 0.0;
  }

  /// Insert or replace the instalment for a (sip, period) — idempotent.
  Future<void> upsertSipPayment(SipPayment payment) async {
    final db = await database;
    await db.insert(
      'sip_payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Find an Investments-tagged debit that plausibly *is* this month's
  /// instalment: tagged 'Investments', within [windowStart]..[windowEnd], not
  /// already linked to another instalment, and (when [amount] is given)
  /// matching it within ₹1. Returns the one closest to the [due] date.
  Future<TransactionModel?> findInvestmentTransactionForSip({
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime due,
    double? amount,
  }) async {
    final db = await database;
    final where = StringBuffer(
      "type = ? AND category = 'Investments' "
      "AND detected_at >= ? AND detected_at <= ? "
      "AND id NOT IN (SELECT transaction_id FROM sip_payments "
      "WHERE transaction_id IS NOT NULL)",
    );
    final args = <Object>[
      TransactionType.debit.index,
      windowStart.millisecondsSinceEpoch,
      windowEnd.millisecondsSinceEpoch,
    ];
    if (amount != null) {
      where.write(' AND amount >= ? AND amount <= ?');
      args..add(amount - 1)..add(amount + 1);
    }
    final maps = await db.query(
      'transactions',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'ABS(detected_at - ${due.millisecondsSinceEpoch}) ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    return {
      'transactions': await db.query('transactions'),
      'budgets': await db.query('budgets'),
      'transaction_rules': await db.query('transaction_rules'),
      'holdings': await db.query('holdings'),
      'sips': await db.query('sips'),
      'sip_payments': await db.query('sip_payments'),
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
    var txnCount = 0, budgetCount = 0, ruleCount = 0, holdingCount = 0;
    var sipCount = 0;
    // Maps a backed-up row id to its restored local id, so SIPs can be
    // re-pointed at their backing holding and instalments at their SIP even
    // though autoincrement ids differ on a fresh device.
    final holdingIdMap = <int, int>{};
    final sipIdMap = <int, int>{};

    for (final raw in (data['transactions'] as List? ?? const [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      row.remove('id');

      // Find an existing row for this transaction (the initial post-reinstall
      // SMS scan may have already re-created it, untagged).
      List<Map<String, Object?>> existing = const [];
      if (row['fingerprint'] != null) {
        existing = await db.query(
          'transactions',
          where: 'fingerprint = ?',
          whereArgs: [row['fingerprint']],
          limit: 1,
        );
      }
      if (existing.isEmpty) {
        existing = await db.query(
          'transactions',
          where: 'message = ? AND detected_at = ?',
          whereArgs: [row['message'], row['detected_at']],
          limit: 1,
        );
      }

      if (existing.isNotEmpty) {
        // The backup is authoritative for tags: re-apply the backed-up
        // category/notes onto the row the rescan created untagged, so tags
        // survive a reinstall. Only overwrite when the backup actually had
        // a category (don't wipe a local tag with a blank one).
        if (row['category'] != null) {
          await db.update(
            'transactions',
            {
              'category': row['category'],
              'is_classified': row['is_classified'] ?? 1,
              'notes': row['notes'],
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
          txnCount++;
        }
        continue;
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

    for (final raw in (data['holdings'] as List? ?? const [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      final oldId = row['id'] as int?;
      row.remove('id');
      final exists = await db.query(
        'holdings',
        where: 'name = ? AND kind = ? AND category = ?',
        whereArgs: [row['name'], row['kind'], row['category']],
        limit: 1,
      );
      final int localId;
      if (exists.isNotEmpty) {
        localId = exists.first['id'] as int;
      } else {
        localId = await db.insert('holdings', row);
        holdingCount++;
      }
      if (oldId != null) holdingIdMap[oldId] = localId;
    }

    // SIP plans: re-point the backing holding, dedupe by (name, category, day).
    for (final raw in (data['sips'] as List? ?? const [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      final oldId = row['id'] as int?;
      row.remove('id');
      final oldHoldingId = row['holding_id'] as int?;
      row['holding_id'] =
          oldHoldingId == null ? null : holdingIdMap[oldHoldingId];
      final exists = await db.query(
        'sips',
        where: 'name = ? AND category = ? AND day_of_month = ?',
        whereArgs: [row['name'], row['category'], row['day_of_month']],
        limit: 1,
      );
      final int localId;
      if (exists.isNotEmpty) {
        localId = exists.first['id'] as int;
      } else {
        localId = await db.insert('sips', row);
        sipCount++;
      }
      if (oldId != null) sipIdMap[oldId] = localId;
    }

    // SIP instalment ledger: re-point to the restored SIP. The transaction_id
    // link is dropped (transaction ids aren't stable across restores) — the
    // instalment's amount is what matters for progress/totals.
    for (final raw in (data['sip_payments'] as List? ?? const [])) {
      final row = Map<String, dynamic>.from(raw as Map);
      row.remove('id');
      final newSipId = sipIdMap[row['sip_id'] as int?];
      if (newSipId == null) continue; // orphaned instalment — skip
      row['sip_id'] = newSipId;
      row['transaction_id'] = null;
      final exists = await db.query(
        'sip_payments',
        where: 'sip_id = ? AND period_key = ?',
        whereArgs: [newSipId, row['period_key']],
        limit: 1,
      );
      if (exists.isNotEmpty) continue;
      await db.insert('sip_payments', row);
    }

    return {
      'transactions': txnCount,
      'budgets': budgetCount,
      'rules': ruleCount,
      'holdings': holdingCount,
      'sips': sipCount,
    };
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
