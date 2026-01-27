import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/bank_account_model.dart';
import '../models/budget_model.dart';

/// Database service for persisting transactions and bank accounts
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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables (fresh install)
  Future<void> _onCreate(Database db, int version) async {
    // Bank accounts table
    await db.execute('''
      CREATE TABLE bank_accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        bank_code TEXT NOT NULL,
        initial_balance REAL NOT NULL,
        current_balance REAL NOT NULL,
        created_at INTEGER NOT NULL,
        color INTEGER
      )
    ''');

    // Transactions table with bank account link
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
        bank_account_id INTEGER,
        FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(id)
      )
    ''');

    // Create indexes
    await db.execute(
      'CREATE INDEX idx_transactions_detected_at ON transactions(detected_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_bank_account ON transactions(bank_account_id)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_category ON transactions(category)',
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
  }

  /// Upgrade database from version 1 to 2
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add bank_accounts table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bank_accounts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          bank_code TEXT NOT NULL,
          initial_balance REAL NOT NULL,
          current_balance REAL NOT NULL,
          created_at INTEGER NOT NULL,
          color INTEGER
        )
      ''');

      // Add bank_account_id column to transactions
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN bank_account_id INTEGER',
      );

      // Create new indexes
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_bank_account ON transactions(bank_account_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)',
      );
    }

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
  }

  // ==================== BANK ACCOUNT OPERATIONS ====================

  /// Insert a new bank account
  Future<int> insertBankAccount(BankAccount account) async {
    final db = await database;
    return await db.insert(
      'bank_accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a bank account
  Future<int> updateBankAccount(BankAccount account) async {
    final db = await database;
    return await db.update(
      'bank_accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  /// Delete a bank account
  Future<int> deleteBankAccount(int id) async {
    final db = await database;
    // Also unlink transactions from this account
    await db.update(
      'transactions',
      {'bank_account_id': null},
      where: 'bank_account_id = ?',
      whereArgs: [id],
    );
    return await db.delete('bank_accounts', where: 'id = ?', whereArgs: [id]);
  }

  /// Get all bank accounts
  Future<List<BankAccount>> getAllBankAccounts() async {
    final db = await database;
    final maps = await db.query('bank_accounts', orderBy: 'name ASC');
    return maps.map((map) => BankAccount.fromMap(map)).toList();
  }

  /// Get bank account by ID
  Future<BankAccount?> getBankAccountById(int id) async {
    final db = await database;
    final maps = await db.query(
      'bank_accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return BankAccount.fromMap(maps.first);
  }

  /// Get bank account by bank code
  Future<BankAccount?> getBankAccountByCode(String bankCode) async {
    final db = await database;
    final maps = await db.query(
      'bank_accounts',
      where: 'bank_code = ?',
      whereArgs: [bankCode],
    );
    if (maps.isEmpty) return null;
    return BankAccount.fromMap(maps.first);
  }

  /// Update bank account balance
  Future<void> updateBankBalance(int accountId, double newBalance) async {
    final db = await database;
    await db.update(
      'bank_accounts',
      {'current_balance': newBalance},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  /// Check if any bank accounts exist
  Future<bool> hasBankAccounts() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bank_accounts',
    );
    return ((result.first['count'] as int?) ?? 0) > 0;
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

  /// Get transactions by bank account
  Future<List<TransactionModel>> getTransactionsByBankAccount(
    int bankAccountId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'bank_account_id = ?',
      whereArgs: [bankAccountId],
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
    int? bankAccountId,
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

    if (bankAccountId != null) {
      whereClauses.add('bank_account_id = ?');
      whereArgs.add(bankAccountId);
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

  /// Get total by type for a specific bank account
  Future<double> getTotalByTypeForAccount(
    TransactionType type,
    int bankAccountId,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND bank_account_id = ?',
      [type.index, bankAccountId],
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
    if (updates.isNotEmpty)
      await db.update(
        'budgets',
        updates,
        where: 'id = ?',
        whereArgs: [budgetId],
      );
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
