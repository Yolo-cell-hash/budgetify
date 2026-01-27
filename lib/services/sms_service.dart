import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_model.dart';
import '../models/bank_account_model.dart';
import 'database_service.dart';
import 'sms_parser_service.dart';
import 'notification_service.dart';

/// Top-level function for handling SMS in background
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  final dbService = DatabaseService();

  final transaction = SmsParserService.parseTransaction(
    message.address ?? 'Unknown',
    message.body ?? '',
    DateTime.now(),
  );

  if (transaction != null) {
    final exists = await dbService.transactionExists(
      transaction.message,
      transaction.detectedAt,
    );

    if (!exists) {
      final bankCode = BankCodes.detectBankCode(message.address ?? '');
      BankAccount? bankAccount;

      if (bankCode != null) {
        bankAccount = await dbService.getBankAccountByCode(bankCode);
      }

      final linkedTransaction = transaction.copyWith(
        bankAccountId: bankAccount?.id,
      );

      await dbService.insertTransaction(linkedTransaction);

      if (bankAccount != null && bankAccount.id != null) {
        await _updateBankBalance(dbService, bankAccount, transaction);
      }

      await NotificationService().showTransactionNotification(
        linkedTransaction,
      );

      // Check budget thresholds for debit transactions
      if (transaction.type == TransactionType.debit) {
        await _checkBudgetThresholds(dbService, NotificationService());
      }
    }
  }
}

/// Check and notify budget thresholds
Future<void> _checkBudgetThresholds(
  DatabaseService db,
  NotificationService ns,
) async {
  final budget = await db.getActiveBudget();
  if (budget == null) return;

  final spent = await db.getSpendingForPeriod(
    startDate: budget.currentPeriodStart,
    endDate: budget.currentPeriodEnd,
  );

  final pct = budget.amount > 0 ? (spent / budget.amount) * 100 : 0;

  if (pct >= 100 && !budget.notified100) {
    await ns.showBudgetNotification(
      threshold: 100,
      spent: spent,
      budget: budget.amount,
    );
    await db.updateBudgetNotificationFlags(budget.id!, n100: true);
  } else if (pct >= 90 && !budget.notified90) {
    await ns.showBudgetNotification(
      threshold: 90,
      spent: spent,
      budget: budget.amount,
    );
    await db.updateBudgetNotificationFlags(budget.id!, n90: true);
  } else if (pct >= 50 && !budget.notified50) {
    await ns.showBudgetNotification(
      threshold: 50,
      spent: spent,
      budget: budget.amount,
    );
    await db.updateBudgetNotificationFlags(budget.id!, n50: true);
  }
}

/// Update bank account balance based on transaction type
Future<void> _updateBankBalance(
  DatabaseService dbService,
  BankAccount account,
  TransactionModel transaction,
) async {
  double newBalance = account.currentBalance;

  if (transaction.type == TransactionType.credit) {
    newBalance += transaction.amount;
  } else {
    newBalance -= transaction.amount;
  }

  await dbService.updateBankBalance(account.id!, newBalance);
}

/// Service for handling SMS reading and processing
class SmsService {
  static final SmsService _instance = SmsService._internal();
  final Telephony _telephony = Telephony.instance;
  final DatabaseService _dbService = DatabaseService();
  bool _isListening = false;

  factory SmsService() => _instance;

  SmsService._internal();

  /// Check if SMS permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Request SMS permission
  Future<PermissionStatus> requestPermission() async {
    // Request SMS permission
    final smsStatus = await Permission.sms.request();

    // Also request notification permission for Android 13+
    await Permission.notification.request();

    return smsStatus;
  }

  /// Check if permission is permanently denied
  Future<bool> isPermissionPermanentlyDenied() async {
    return await Permission.sms.isPermanentlyDenied;
  }

  /// Open app settings for manual permission grant
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Start listening for incoming SMS
  Future<void> startListening({
    required Function(TransactionModel) onTransactionDetected,
  }) async {
    if (_isListening) return;

    final hasPermissions = await hasPermission();
    if (!hasPermissions) {
      throw Exception('SMS permission not granted');
    }

    _isListening = true;

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await _processMessage(message, onTransactionDetected);
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
  }

  /// Process an incoming SMS message
  Future<void> _processMessage(
    SmsMessage message,
    Function(TransactionModel) onTransactionDetected,
  ) async {
    final transaction = SmsParserService.parseTransaction(
      message.address ?? 'Unknown',
      message.body ?? '',
      DateTime.now(),
    );

    if (transaction != null) {
      // Check for duplicates
      final exists = await _dbService.transactionExists(
        transaction.message,
        transaction.detectedAt,
      );

      if (!exists) {
        // Detect bank code from sender and link to account
        final bankCode = BankCodes.detectBankCode(message.address ?? '');
        BankAccount? bankAccount;

        if (bankCode != null) {
          bankAccount = await _dbService.getBankAccountByCode(bankCode);
        }

        // Create transaction with bank account link
        final linkedTransaction = transaction.copyWith(
          bankAccountId: bankAccount?.id,
        );

        // Save to database
        final id = await _dbService.insertTransaction(linkedTransaction);
        final savedTransaction = linkedTransaction.copyWith(id: id);

        // Update bank balance
        if (bankAccount != null && bankAccount.id != null) {
          double newBalance = bankAccount.currentBalance;
          if (transaction.type == TransactionType.credit) {
            newBalance += transaction.amount;
          } else {
            newBalance -= transaction.amount;
          }
          await _dbService.updateBankBalance(bankAccount.id!, newBalance);
        }

        // Notify callback
        onTransactionDetected(savedTransaction);

        // Show notification
        await NotificationService().showTransactionNotification(
          savedTransaction,
        );
      }
    }
  }

  /// Stop listening for SMS
  void stopListening() {
    _isListening = false;
    // Note: telephony package doesn't have a direct stop method
    // Listening stops when the app is disposed
  }

  /// Get existing SMS from inbox (for initial scan)
  /// This also links transactions to bank accounts and updates balances
  Future<List<TransactionModel>> scanExistingSms({int maxCount = 100}) async {
    final hasPermissions = await hasPermission();
    if (!hasPermissions) return [];

    final List<TransactionModel> transactions = [];

    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      int count = 0;
      for (final message in messages) {
        if (count >= maxCount) break;

        final transaction = SmsParserService.parseTransaction(
          message.address ?? 'Unknown',
          message.body ?? '',
          message.date != null
              ? DateTime.fromMillisecondsSinceEpoch(message.date!)
              : DateTime.now(),
        );

        if (transaction != null) {
          // Check if already in database
          final exists = await _dbService.transactionExists(
            transaction.message,
            transaction.detectedAt,
          );

          if (!exists) {
            // Detect bank code and link
            final bankCode = BankCodes.detectBankCode(message.address ?? '');
            BankAccount? bankAccount;

            if (bankCode != null) {
              bankAccount = await _dbService.getBankAccountByCode(bankCode);
            }

            // Create linked transaction
            final linkedTransaction = transaction.copyWith(
              bankAccountId: bankAccount?.id,
            );

            final id = await _dbService.insertTransaction(linkedTransaction);
            transactions.add(linkedTransaction.copyWith(id: id));

            // Update bank balance
            if (bankAccount != null && bankAccount.id != null) {
              // Refetch to get current balance (may have been updated by previous transactions)
              final currentAccount = await _dbService.getBankAccountById(
                bankAccount.id!,
              );
              if (currentAccount != null) {
                double newBalance = currentAccount.currentBalance;
                if (transaction.type == TransactionType.credit) {
                  newBalance += transaction.amount;
                } else {
                  newBalance -= transaction.amount;
                }
                await _dbService.updateBankBalance(bankAccount.id!, newBalance);
              }
            }

            count++;
          }
        }
      }
    } catch (e) {
      // Silently handle errors - logging would be better in production
    }

    return transactions;
  }

  /// Link existing unlinked transactions to bank accounts
  /// Useful for when user adds a bank account after transactions exist
  Future<int> linkExistingTransactions() async {
    final allTransactions = await _dbService.getAllTransactions();
    int linkedCount = 0;

    for (final transaction in allTransactions) {
      if (transaction.bankAccountId == null) {
        // Try to detect bank code from sender
        final bankCode = BankCodes.detectBankCode(transaction.sender);

        if (bankCode != null) {
          final bankAccount = await _dbService.getBankAccountByCode(bankCode);

          if (bankAccount != null && bankAccount.id != null) {
            // Update transaction with bank account link
            final linkedTransaction = transaction.copyWith(
              bankAccountId: bankAccount.id,
            );
            await _dbService.updateTransaction(linkedTransaction);

            // Update balance
            double newBalance = bankAccount.currentBalance;
            if (transaction.type == TransactionType.credit) {
              newBalance += transaction.amount;
            } else {
              newBalance -= transaction.amount;
            }
            await _dbService.updateBankBalance(bankAccount.id!, newBalance);

            linkedCount++;
          }
        }
      }
    }

    return linkedCount;
  }
}
