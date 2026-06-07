import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'sms_parser_service.dart';
import 'notification_service.dart';

/// Top-level function for handling SMS in background
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  final dbService = DatabaseService();

  var transaction = SmsParserService.parseTransaction(
    message.address ?? 'Unknown',
    message.body ?? '',
    DateTime.now(),
  );

  if (transaction != null) {
    // Compute fingerprint for deduplication
    transaction = transaction.withFingerprint();

    final exists = await dbService.transactionExists(
      transaction.message,
      transaction.detectedAt,
      fingerprint: transaction.fingerprint,
    );

    if (!exists) {
      // Try to auto-classify using rules (merchant name + type based)
      final rule = await dbService.findMatchingRule(
        transaction.merchantName,
        transaction.type,
      );
      if (rule != null) {
        transaction = transaction.copyWith(
          category: rule.category,
          notes: rule.notes,
          isClassified: true,
        );
      }

      await dbService.insertTransaction(transaction);

      await NotificationService().showTransactionNotification(transaction);

      // Check budget thresholds for debit transactions
      if (transaction.type == TransactionType.debit) {
        await checkBudgetThresholds(dbService, NotificationService());
      }
    }
  }
}

/// Defined thresholds for budget notifications.
/// Returns the sorted list of thresholds up to [maxPercent].
List<int> _getThresholds(double currentPercent) {
  // Fixed thresholds below 200%
  final List<int> thresholds = [50, 75, 90, 100, 120, 150, 200];

  // Dynamic thresholds beyond 200% in 50% increments
  int next = 250;
  while (next <= currentPercent + 50) {
    thresholds.add(next);
    next += 50;
  }

  return thresholds;
}

/// Determine the highest threshold that has been crossed.
/// Returns 0 if no threshold has been crossed yet.
int _computeCurrentThreshold(double percent) {
  final thresholds = _getThresholds(percent);
  int currentThreshold = 0;
  for (final t in thresholds) {
    if (percent >= t) {
      currentThreshold = t;
    }
  }
  return currentThreshold;
}

/// Check and notify budget thresholds.
/// This is public so HomeScreen can also call it when the app is open.
Future<void> checkBudgetThresholds(
  DatabaseService db,
  NotificationService ns,
) async {
  final budget = await db.getActiveBudget();
  if (budget == null) return;

  final spent = await db.getSpendingForPeriod(
    startDate: budget.currentPeriodStart,
    endDate: budget.currentPeriodEnd,
  );

  final percent = budget.amount > 0 ? (spent / budget.amount) * 100 : 0.0;
  final currentThreshold = _computeCurrentThreshold(percent);

  // Only notify if a new (higher) threshold has been crossed
  if (currentThreshold > 0 &&
      currentThreshold > budget.lastNotifiedThreshold) {
    await ns.showBudgetNotification(
      threshold: currentThreshold,
      spent: spent,
      budget: budget.amount,
    );
    await db.updateLastNotifiedThreshold(budget.id!, currentThreshold);
  }
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
    var transaction = SmsParserService.parseTransaction(
      message.address ?? 'Unknown',
      message.body ?? '',
      DateTime.now(),
    );

    if (transaction != null) {
      // Compute fingerprint for deduplication
      transaction = transaction.withFingerprint();

      // Check for duplicates
      final exists = await _dbService.transactionExists(
        transaction.message,
        transaction.detectedAt,
        fingerprint: transaction.fingerprint,
      );

      if (!exists) {
        // Try to auto-classify using rules (merchant name + type based)
        var txnToSave = transaction;
        final rule = await _dbService.findMatchingRule(
          transaction.merchantName,
          transaction.type,
        );
        if (rule != null) {
          txnToSave = transaction.copyWith(
            category: rule.category,
            notes: rule.notes,
            isClassified: true,
          );
        }

        // Save to database
        final id = await _dbService.insertTransaction(txnToSave);
        final savedTransaction = txnToSave.copyWith(id: id);

        // Notify callback
        onTransactionDetected(savedTransaction);

        // Show notification
        await NotificationService().showTransactionNotification(
          savedTransaction,
        );

        // Check budget thresholds for debit transactions
        if (savedTransaction.type == TransactionType.debit) {
          await checkBudgetThresholds(_dbService, NotificationService());
        }
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

        var transaction = SmsParserService.parseTransaction(
          message.address ?? 'Unknown',
          message.body ?? '',
          message.date != null
              ? DateTime.fromMillisecondsSinceEpoch(message.date!)
              : DateTime.now(),
        );

        if (transaction != null) {
          // Compute fingerprint for deduplication
          transaction = transaction.withFingerprint();

          // Check if already in database
          final exists = await _dbService.transactionExists(
            transaction.message,
            transaction.detectedAt,
            fingerprint: transaction.fingerprint,
          );

          if (!exists) {
            // Try to auto-classify using rules (merchant name + type based)
            var txnToSave = transaction;
            final rule = await _dbService.findMatchingRule(
              transaction.merchantName,
              transaction.type,
            );
            if (rule != null) {
              txnToSave = transaction.copyWith(
                category: rule.category,
                notes: rule.notes,
                isClassified: true,
              );
            }

            final id = await _dbService.insertTransaction(txnToSave);
            // Only add if actually inserted (id > 0 means success)
            if (id > 0) {
              transactions.add(txnToSave.copyWith(id: id));
              count++;
            }
          }
        }
      }

      // After scanning, check budget thresholds
      if (transactions.any((t) => t.type == TransactionType.debit)) {
        await checkBudgetThresholds(_dbService, NotificationService());
      }
    } catch (e) {
      // Silently handle errors - logging would be better in production
    }

    return transactions;
  }
}
