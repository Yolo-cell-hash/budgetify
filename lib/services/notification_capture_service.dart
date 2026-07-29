import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_model.dart';
import 'app_events.dart';
import 'database_service.dart';
import 'notification_parser_service.dart';
import 'notification_service.dart';
import 'sms_parser_service.dart';
import 'sms_service.dart' show checkBudgetThresholds;
import 'transaction_reconciler.dart';
import 'widget_service.dart';

/// Where the notification-capture feature stands, for the settings tile.
enum NotifCaptureStatus {
  /// The in-app toggle is off (the default; nothing is captured or stored).
  off,

  /// Toggle on, but the system-level notification access is not granted —
  /// the listener is not bound, so nothing arrives. The tile shows a call
  /// to action.
  awaitingAccess,

  /// Toggle on and access granted; the listener is live.
  on,
}

/// Dart side of payment-app notification capture. The Kotlin listener
/// (TxnNotificationListener.kt) appends filtered events to a JSON-lines
/// queue file; this service drains that file into the normal transaction
/// pipeline — parser, mute check, payee aliases, rules, reconciler,
/// insert, alerts — mirroring the SMS paths step for step.
///
/// The drain runs from four triggers, all funnelled through [drain]:
///  1. app launch ([attach], called from main's deferred init),
///  2. app resume (lifecycle observer),
///  3. a "queueChanged" nudge from Kotlin while an engine is alive
///     (real-time capture when the app is running),
///  4. the hourly WorkManager scan (catch-up when the app stays closed).
/// The background isolate has no method channel — the drain deliberately
/// reads the queue file directly so trigger 4 needs nothing but dart:io.
///
/// Correctness never depends on the consumed-watermark: replayed events
/// re-parse to the same fingerprint and are dropped by the exists check /
/// the insert's ConflictAlgorithm.ignore, so a lost watermark means wasted
/// work, not duplicates.
class NotificationCaptureService with WidgetsBindingObserver {
  static final NotificationCaptureService _instance =
      NotificationCaptureService._internal();
  factory NotificationCaptureService() => _instance;
  NotificationCaptureService._internal();

  /// The Kotlin listener reads this exact key from Flutter's prefs file —
  /// with the toggle off it stores nothing, even if system access is
  /// granted. Renaming it breaks that contract.
  static const String enabledKey = 'notif_capture_enabled';

  static const String _watermarkKey = 'notif_capture_consumed_upto';
  static const String _queueFileName = 'notif_capture_queue.jsonl';

  /// Events younger than this when drained still fire a "₹X debited" alert;
  /// older ones insert silently, so a catch-up drain after hours offline
  /// never floods the shade with stale alerts (the SMS catch-up scan's
  /// summary-notification rule, tightened for single events).
  static const Duration freshAlertWindow = Duration(minutes: 3);

  static const MethodChannel _channel =
      MethodChannel('budgetify/notif_capture');

  final DatabaseService _db = DatabaseService();

  /// Settings tile state; updated on attach/resume/toggle.
  final ValueNotifier<NotifCaptureStatus> status =
      ValueNotifier(NotifCaptureStatus.off);

  bool _attached = false;
  bool _draining = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Idempotent hookup: channel handler (live nudges), lifecycle observer
  /// (resume drains) and one initial drain. Called after the first frame
  /// from main's deferred init; every step tolerates the platform side
  /// being absent (tests, fresh engines).
  Future<void> attach() async {
    if (_attached) return;
    _attached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'queueChanged') {
        await drain();
      }
      return null;
    });
    WidgetsBinding.instance.addObserver(this);
    await refreshStatus();
    await drain();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Also re-checks access: the user may be returning from the system
      // notification-access screen right now.
      refreshStatus();
      drain();
    }
  }

  // ── Settings surface ─────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(enabledKey) ?? false;
  }

  /// Flip the in-app toggle. Enabling also stamps the ever-enabled flag
  /// that switches the SMS-side reconciler on. Returns the new status.
  Future<NotifCaptureStatus> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, value);
    if (value) {
      await TransactionReconciler.markEverEnabled();
    }
    await refreshStatus();
    if (value && status.value == NotifCaptureStatus.on) {
      await drain();
    }
    return status.value;
  }

  /// Whether the system has granted notification access. False whenever the
  /// platform can't answer (no engine, non-Android) — never throws.
  Future<bool> isAccessGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessGranted') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Deep-link to the system notification-access screen (scoped to this app
  /// on API 30+). The result is observed on resume, not awaited.
  Future<void> openAccessSettings() async {
    try {
      await _channel.invokeMethod('openAccessSettings');
    } catch (_) {
      // Nothing to do — the tile keeps showing the call to action.
    }
  }

  Future<NotifCaptureStatus> refreshStatus() async {
    if (!await isEnabled()) {
      status.value = NotifCaptureStatus.off;
    } else if (await isAccessGranted()) {
      status.value = NotifCaptureStatus.on;
    } else {
      status.value = NotifCaptureStatus.awaitingAccess;
    }
    return status.value;
  }

  // ── The drain ────────────────────────────────────────────────────────────

  /// Read the queue file and run every new event through the standard
  /// pipeline. Returns how many transactions were inserted. Safe to call
  /// from any isolate and at any time; concurrent calls collapse into one.
  Future<int> drain() async {
    if (_draining) return 0;
    _draining = true;
    try {
      return await _drainOnce();
    } catch (e) {
      debugPrint('notification drain failed: $e');
      return 0;
    } finally {
      _draining = false;
    }
  }

  Future<int> _drainOnce() async {
    if (!await isEnabled()) return 0;

    final file = await _queueFile();
    if (file == null || !await file.exists()) return 0;

    final prefs = await SharedPreferences.getInstance();
    final consumedUpto = prefs.getInt(_watermarkKey) ?? 0;

    final List<String> lines;
    try {
      lines = await file.readAsLines();
    } catch (_) {
      return 0; // Racing a Kotlin trim-rename; the next drain gets it.
    }

    var inserted = <TransactionModel>[];
    var newWatermark = consumedUpto;
    final now = DateTime.now();

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      Map<String, dynamic> event;
      try {
        event = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        continue; // A torn/foreign line is skipped, never fatal.
      }

      final posted = event['posted'] as int? ?? 0;
      if (posted <= consumedUpto) continue; // Already processed.
      if (posted > newWatermark) newWatermark = posted;

      final txn = await _processEvent(event);
      if (txn != null) {
        // Alert only for events fresh enough to still be "just happened".
        final postedAt = DateTime.fromMillisecondsSinceEpoch(posted);
        inserted.add(txn);
        if (now.difference(postedAt) <= freshAlertWindow) {
          await NotificationService().showTransactionNotification(txn);
        }
      }
    }

    if (newWatermark > consumedUpto) {
      await prefs.setInt(_watermarkKey, newWatermark);
    }

    if (inserted.isNotEmpty) {
      // Mirror the SMS paths' aftermath: budgets, widget, live screens.
      if (inserted.any((t) => t.type == TransactionType.debit)) {
        await checkBudgetThresholds(_db, NotificationService());
      }
      try {
        await WidgetService.update();
      } catch (_) {
        // Widget refresh is cosmetic; never fail the drain over it.
      }
      notifyAppDataChanged();
    }
    return inserted.length;
  }

  /// One event through the pipeline. Returns the inserted transaction, or
  /// null when it was rejected, a duplicate, or absorbed by the reconciler.
  /// The step order deliberately mirrors SmsService._processMessage.
  Future<TransactionModel?> _processEvent(Map<String, dynamic> event) async {
    var txn = NotificationParserService.parse(
      packageName: event['pkg'] as String? ?? '',
      title: event['title'] as String? ?? '',
      text: event['text'] as String? ?? '',
      bigText: event['big'] as String? ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(
        event['posted'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (txn == null) return null;

    // The user marked this shape "not a transaction" — drop it.
    if (await _db.isMessageMuted(txn.sender, txn.message)) return null;

    // Same enrichment order as SMS: alias → keyword classify → direction
    // override → fingerprint (the override must precede the fingerprint,
    // which includes the type).
    txn = await _db.applyPayeeAlias(txn);
    txn = SmsParserService.classifyFromMerchantName(txn);
    txn = await _db.applyTypeOverride(txn);
    txn = txn.withFingerprint();

    // Replay of an event we already stored (watermark loss, re-posted
    // notification) → the fingerprint already exists.
    if (await _db.transactionExists(
      txn.message,
      txn.detectedAt,
      fingerprint: txn.fingerprint,
    )) {
      return null;
    }

    // The same payment may already be here as its SMS twin, the user's own
    // manual entry, or a tombstone of a copy they deleted. SMS/manual wins;
    // deletions stay deleted.
    if (await TransactionReconciler().shouldDropIncomingNotifTxn(txn)) {
      return null;
    }

    final rule = await _db.findMatchingRule(txn.merchantName, txn.type);
    if (rule != null) {
      txn = txn.copyWith(
        category: rule.category,
        notes: rule.notes,
        isClassified: true,
      );
    }

    final id = await _db.insertTransaction(txn);
    if (id <= 0) return null; // Lost an insert race; the other copy won.
    return txn.copyWith(id: id);
  }

  Future<File?> _queueFile() async {
    try {
      // path_provider's application-support directory is Android's
      // filesDir — the same directory the Kotlin listener writes to.
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_queueFileName');
    } catch (_) {
      return null; // Non-Android / test environment.
    }
  }
}
