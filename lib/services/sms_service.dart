import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import 'database_service.dart';
import 'sms_parser_service.dart';
import 'notification_service.dart';
import 'transaction_reconciler.dart';

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
    // The user marked this message shape "not a transaction" — drop it.
    if (await dbService.isMessageMuted(
      message.address ?? 'Unknown',
      message.body ?? '',
    )) {
      return;
    }

    // Swap in the user-taught payee name before rule matching, so category
    // rules see the corrected name. A recognised merchant behind the
    // corrected name classifies immediately, without user input.
    transaction = await dbService.applyPayeeAlias(transaction);
    transaction = SmsParserService.classifyFromMerchantName(transaction);

    // A user-taught direction for this message shape wins over the parse.
    // Must precede the fingerprint: the fingerprint includes the type.
    transaction = await dbService.applyTypeOverride(transaction);

    // Compute fingerprint for deduplication
    transaction = transaction.withFingerprint();

    final exists = await dbService.transactionExists(
      transaction.message,
      transaction.detectedAt,
      fingerprint: transaction.fingerprint,
    );

    if (!exists) {
      // A payment-app alert may have captured this same payment moments ago —
      // fold the SMS into that row instead of inserting a twin. Inert (one
      // memoised prefs read) until notification capture is first enabled.
      if (await TransactionReconciler().absorbIntoNotifTwin(transaction)) {
        return;
      }

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

/// Check and notify budget thresholds for the overall budget *and* every
/// per-category budget. Public so HomeScreen can also call it when the app
/// is open.
Future<void> checkBudgetThresholds(
  DatabaseService db,
  NotificationService ns,
) async {
  final budgets = await db.getAllBudgets();
  for (final budget in budgets) {
    await _checkOneBudget(db, ns, budget);
  }
}

/// Evaluate a single budget and fire an escalating alert when a new threshold
/// is crossed within the current period. Alert state resets when the period
/// rolls over, so each month starts from a clean slate.
Future<void> _checkOneBudget(
  DatabaseService db,
  NotificationService ns,
  Budget budget,
) async {
  if (budget.id == null || budget.amount <= 0) return;

  final spent = await db.getSpendingForPeriod(
    startDate: budget.currentPeriodStart,
    endDate: budget.currentPeriodEnd,
    category: budget.category, // null → overall (non-expense excluded)
  );

  final percent = (spent / budget.amount) * 100;
  final currentThreshold = _computeCurrentThreshold(percent);

  // High-water mark is only valid within the period it was recorded for.
  final periodKey = budget.currentPeriodKey;
  final samePeriod = budget.notifiedPeriod == periodKey;
  final effectiveLastNotified = samePeriod ? budget.lastNotifiedThreshold : 0;

  if (currentThreshold > 0 && currentThreshold > effectiveLastNotified) {
    await ns.showBudgetNotification(
      threshold: currentThreshold,
      spent: spent,
      budget: budget.amount,
      category: budget.category,
      notificationId: budget.isCategoryBudget ? 4000 + budget.id! : null,
    );
    await db.updateLastNotifiedThreshold(
      budget.id!,
      currentThreshold,
      period: periodKey,
    );
  } else if (!samePeriod && budget.lastNotifiedThreshold != 0) {
    // New period, nothing crossed yet — clear the stale marker once so the
    // first crossing this period still alerts.
    await db.updateLastNotifiedThreshold(budget.id!, 0, period: periodKey);
  }
}

/// Service for handling SMS reading and processing
class SmsService {
  static final SmsService _instance = SmsService._internal();
  Telephony _telephony = Telephony.instance;
  final DatabaseService _dbService = DatabaseService();
  bool _isListening = false;

  /// Swaps in a [Telephony] built against a fake platform. The real plugin
  /// asserts it is running on Android, so the inbox-window tests — which check
  /// that every query carries a date bound — cannot otherwise run off-device.
  @visibleForTesting
  set telephony(Telephony value) => _telephony = value;

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
      // The user marked this message shape "not a transaction" — drop it.
      if (await _dbService.isMessageMuted(
        message.address ?? 'Unknown',
        message.body ?? '',
      )) {
        return;
      }

      // Swap in the user-taught payee name before rule matching; a
      // recognised merchant behind the corrected name classifies instantly.
      transaction = await _dbService.applyPayeeAlias(transaction);
      transaction = SmsParserService.classifyFromMerchantName(transaction);

      // A user-taught direction for this message shape wins over the parse.
      // Must precede the fingerprint: the fingerprint includes the type.
      transaction = await _dbService.applyTypeOverride(transaction);

      // Compute fingerprint for deduplication
      transaction = transaction.withFingerprint();

      // Check for duplicates
      final exists = await _dbService.transactionExists(
        transaction.message,
        transaction.detectedAt,
        fingerprint: transaction.fingerprint,
      );

      if (!exists) {
        // A payment-app alert may have captured this same payment moments
        // ago — fold the SMS into that row instead of inserting a twin (the
        // notification already alerted). Live screens refresh via the
        // reconciler's data-changed signal. Inert until capture is enabled.
        if (await TransactionReconciler().absorbIntoNotifTwin(transaction)) {
          return;
        }

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

  // ------------------------------------------------------------------
  // Inbox scanning
  //
  // Every scan is bounded by a date window that is pushed down into the
  // content-provider query. That bound is the whole ballgame: the telephony
  // plugin answers `getInboxSms` by walking the entire cursor and building one
  // HashMap per row *on the Android main thread*, and the result then crosses
  // the method channel to be decoded on the main isolate. An unbounded query
  // therefore stalls the UI thread for as long as it takes to read every SMS
  // the phone has ever received. On a cold start — app DB and the system SMS
  // provider both off the page cache — that ran into seconds of frozen UI on a
  // mid-range device with a few thousand messages, long enough for the platform
  // to kill the process. A warm relaunch hid it, which is why the app "only
  // crashed the first time". See [_watermarkKey] for how repeat scans stay cheap.
  // ------------------------------------------------------------------

  /// Epoch millis of the newest inbox message a completed scan has examined.
  /// Later scans resume from here rather than from the start of the inbox.
  static const String _watermarkKey = 'sms_scan_watermark';

  /// How much already-examined inbox a routine scan re-reads.
  ///
  /// A message's DATE is when the carrier stamped it, not when it arrived, so a
  /// delayed SMS can surface *below* the watermark after the fact. A couple of
  /// days of overlap catches those; re-examined messages cost one dedup lookup
  /// and are then dropped, so the overlap is cheap to keep generous.
  static const Duration _watermarkOverlap = Duration(days: 2);

  /// How far back a first-ever scan reaches, and the slice it walks in. The
  /// slice is what keeps each individual provider query — and so each block of
  /// the Android main thread — short.
  static const Duration _historyWindow = Duration(days: 365);
  static const Duration _historySlice = Duration(days: 30);

  /// Ceiling on messages examined per window. A pathological inbox or a bad
  /// watermark can never re-create the unbounded read; the scan just stops
  /// early and the next one resumes from where it left off.
  static const int _maxMessagesPerWindow = 400;

  Future<DateTime?> _readWatermark() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_watermarkKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _writeWatermark(DateTime seen) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_watermarkKey) ?? 0;
    if (seen.millisecondsSinceEpoch > current) {
      await prefs.setInt(_watermarkKey, seen.millisecondsSinceEpoch);
    }
  }

  /// Forget how far the inbox has been scanned so the next scan re-imports from
  /// scratch. Call after a restore or a data wipe, where the database no longer
  /// matches what the watermark claims was imported.
  Future<void> resetScanWatermark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_watermarkKey);
  }

  /// Bounds the provider query to `(since, until]`.
  SmsFilter _dateFilter({required DateTime since, required DateTime until}) =>
      SmsFilter.where(SmsColumn.DATE)
          .greaterThan('${since.millisecondsSinceEpoch}')
          .and(SmsColumn.DATE)
          .lessThanOrEqualTo('${until.millisecondsSinceEpoch}');

  /// Scan the inbox for transactions not yet imported.
  ///
  /// Walks forward from the watermark (or, on a first run, from
  /// [_historyWindow] ago) in [_historySlice]-sized windows until it reaches
  /// the present. Windows are walked oldest-first so the watermark only ever
  /// advances over messages that were actually examined — a scan cut short by
  /// [_maxMessagesPerWindow] resumes exactly where it stopped instead of
  /// skipping the gap.
  ///
  /// [maxCount] caps insertions *per window*. The real bound on work is
  /// [_maxMessagesPerWindow]; capping the scan as a whole would, in
  /// oldest-first order, fill the first run with year-old transactions and
  /// leave this week's behind until the next few launches.
  Future<List<TransactionModel>> scanExistingSms({int maxCount = 100}) async {
    final hasPermissions = await hasPermission();
    if (!hasPermissions) return [];

    final transactions = <TransactionModel>[];

    try {
      final now = DateTime.now();
      final watermark = await _readWatermark();
      var cursor = watermark != null
          ? watermark.subtract(_watermarkOverlap)
          : now.subtract(_historyWindow);

      // Carriers do stamp messages in the future, and device clocks jump. Either
      // can park the watermark ahead of now, which would leave the loop below
      // with nothing to do — silently, and on every launch from then on. Keep
      // the start far enough back that a scan always covers the recent past.
      final latestStart = now.subtract(_watermarkOverlap);
      if (cursor.isAfter(latestStart)) cursor = latestStart;

      while (cursor.isBefore(now)) {
        var sliceEnd = cursor.add(_historySlice);
        if (sliceEnd.isAfter(now)) sliceEnd = now;

        final result = await _scanWindow(
          since: cursor,
          until: sliceEnd,
          maxCount: maxCount,
        );
        transactions.addAll(result.inserted);

        if (result.newest != null) await _writeWatermark(result.newest!);

        // The window hit a ceiling, so messages older than the ones examined
        // are still unread. Stop here: the watermark sits at the newest message
        // actually examined, and the next scan continues from there rather than
        // jumping past the backlog.
        if (result.truncated) break;

        cursor = sliceEnd;

        // Let the UI pump a frame between slices. Without this a multi-slice
        // catch-up would monopolise the isolate exactly like the old
        // whole-inbox read did.
        await Future<void>.delayed(Duration.zero);
      }

      // A scan that reached the present has, by definition, seen everything up
      // to now — record that even when the last slice held no messages, so an
      // idle inbox doesn't re-read the overlap window forever.
      if (!cursor.isBefore(now)) await _writeWatermark(now);

      // After scanning, check budget thresholds
      if (transactions.any((t) => t.type == TransactionType.debit)) {
        await checkBudgetThresholds(_dbService, NotificationService());
      }
    } catch (e) {
      // Surface to the caller so the UI can degrade gracefully (show a calm
      // message and still refresh from the DB). Background callers
      // (performBackgroundScan / performForegroundScan) already swallow this,
      // so this only affects the user-initiated foreground scan.
      debugPrint('scanExistingSms failed: $e');
      rethrow;
    }

    return transactions;
  }

  /// One bounded pass over `(since, until]`.
  ///
  /// Reports the newest message date it examined so the caller can advance the
  /// watermark even when nothing parsed — most SMS aren't transactions, and a
  /// watermark that only moved on a successful parse would re-read the same
  /// messages on every launch.
  Future<_WindowResult> _scanWindow({
    required DateTime since,
    required DateTime until,
    required int maxCount,
  }) async {
    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      filter: _dateFilter(since: since, until: until),
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)],
    );

    final inserted = <TransactionModel>[];
    DateTime? newest;
    var examined = 0;
    var truncated = false;

    for (final message in messages) {
      // `maxCount` caps insertions; this caps the work done to find them. Only
      // the former used to exist, so a scan that found nothing new — the common
      // case, every single app open — still walked the entire inbox.
      if (examined >= _maxMessagesPerWindow || inserted.length >= maxCount) {
        truncated = true;
        break;
      }
      examined++;

      final sentAt = message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date!)
          : null;
      if (sentAt != null && (newest == null || sentAt.isAfter(newest))) {
        newest = sentAt;
      }

      var transaction = SmsParserService.parseTransaction(
        message.address ?? 'Unknown',
        message.body ?? '',
        sentAt ?? DateTime.now(),
      );
      if (transaction == null) continue;

      // The user marked this message shape "not a transaction" — skip.
      if (await _dbService.isMessageMuted(
        message.address ?? 'Unknown',
        message.body ?? '',
      )) {
        continue;
      }

      // Swap in the user-taught payee name before rule matching; a recognised
      // merchant behind the corrected name classifies instantly.
      transaction = await _dbService.applyPayeeAlias(transaction);
      transaction = SmsParserService.classifyFromMerchantName(transaction);

      // A user-taught direction for this message shape wins over the parse.
      // Must precede the fingerprint (it includes the type).
      transaction = await _dbService.applyTypeOverride(transaction);

      // Compute fingerprint for deduplication
      transaction = transaction.withFingerprint();

      // Check if already in database
      final exists = await _dbService.transactionExists(
        transaction.message,
        transaction.detectedAt,
        fingerprint: transaction.fingerprint,
      );
      if (exists) continue;

      // Same payment may already sit here as its payment-app-notification
      // twin — upgrade that row in place and move on (not counted as an
      // insert: nothing new appeared). Inert until capture is enabled.
      if (await TransactionReconciler().absorbIntoNotifTwin(transaction)) {
        continue;
      }

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
      if (id > 0) inserted.add(txnToSave.copyWith(id: id));
    }

    return _WindowResult(
      inserted: inserted,
      newest: newest,
      truncated: truncated,
    );
  }
}

/// Outcome of a single bounded inbox window.
class _WindowResult {
  final List<TransactionModel> inserted;

  /// Newest message date examined, or null if the window held no messages.
  final DateTime? newest;

  /// Whether a cap stopped the pass with messages still unread in the window.
  final bool truncated;

  const _WindowResult({
    required this.inserted,
    required this.newest,
    required this.truncated,
  });
}
