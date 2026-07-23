import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'notification_capture_service.dart';
import 'notification_service.dart';
import 'sip_service.dart';
import 'recurring_service.dart';
import 'sms_service.dart';
import 'widget_service.dart';
import 'gamification_service.dart';
import '../models/streak_reward.dart';

/// Background service for scheduled SMS scanning.
///
/// Uses an interval-based WorkManager periodic task (default: hourly).
/// The schedule is re-asserted on every app launch so it survives app
/// updates, force-stops, and OEM battery-manager kills — the previous
/// design only registered the task when the user touched settings, and
/// scanned just once every 12 hours pinned to a hardcoded clock time.
class BackgroundService {
  static const String scanTaskName = 'sms_scan_task';
  static const String scanTaskUniqueName = 'budget_tracker_sms_scan';

  // Weekly "tag your transactions" reminder
  static const String weeklyReminderTaskName = 'weekly_unclassified_reminder';
  static const String weeklyReminderUniqueName =
      'budget_tracker_weekly_reminder';

  // Daily SIP/RD "Investment Alert" prompts: noon (~12 PM) and evening (~8 PM).
  // The evening one only fires if the noon prompt went unanswered.
  static const String sipNoonTaskName = 'sip_noon_check';
  static const String sipNoonUniqueName = 'budget_tracker_sip_noon';
  static const String sipEveningTaskName = 'sip_evening_check';
  static const String sipEveningUniqueName = 'budget_tracker_sip_evening';

  // Daily recurring-bill "Bill reminder" prompts: noon and evening, mirroring
  // the SIP slots (evening only fires if noon went unanswered).
  static const String billNoonTaskName = 'bill_noon_check';
  static const String billNoonUniqueName = 'budget_tracker_bill_noon';
  static const String billEveningTaskName = 'bill_evening_check';
  static const String billEveningUniqueName = 'budget_tracker_bill_evening';

  // Daily ~8 PM streak reminder: nudge if the user hasn't opened today and has
  // an active streak about to lapse.
  static const String streakReminderTaskName = 'streak_reminder_check';
  static const String streakReminderUniqueName =
      'budget_tracker_streak_reminder';

  static const int sipNoonHour = 12; // 12 PM
  static const int sipEveningHour = 20; // 8 PM

  // Preferences keys
  static const String _autoScanEnabledKey = 'auto_scan_enabled';
  static const String _scanIntervalHoursKey = 'scan_interval_hours';
  static const String _lastScanTimeKey = 'last_scan_time';

  static const int defaultIntervalHours = 1;

  /// Allowed scan intervals (hours) offered in settings.
  static const List<int> intervalOptions = [1, 3, 6, 12, 18, 24];

  /// Whether `Workmanager().initialize()` has run this process. WorkManager
  /// rejects task ops before it's initialized, so every entry point that
  /// registers or cancels work goes through [_ensureWorkmanager] first. This
  /// matters because [initialize] is now deferred past the first frame (see
  /// main.dart) while [saveScanSettings] can be called from onboarding — the
  /// guard makes their ordering irrelevant instead of a race.
  static bool _workmanagerReady = false;

  /// Idempotently initialize WorkManager. Safe to call from any task op.
  static Future<void> _ensureWorkmanager() async {
    if (_workmanagerReady) return;
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    _workmanagerReady = true;
  }

  /// Initialize the background service and make sure the periodic scan is
  /// scheduled whenever auto-scan is enabled.
  static Future<void> initialize() async {
    await _ensureWorkmanager();
    await _ensureScheduled();
    await _ensureWeeklyReminder();
    await _ensureSipPrompts();
    await _ensureBillPrompts();
    await _ensureStreakReminder();
  }

  /// Register the daily SIP/RD "Investment Alert" prompts at ~12 PM and ~8 PM
  /// local. Independent of auto-scan so they fire even with scanning off.
  static Future<void> _ensureSipPrompts() async {
    await _registerDailyAt(sipNoonUniqueName, sipNoonTaskName, sipNoonHour);
    await _registerDailyAt(
        sipEveningUniqueName, sipEveningTaskName, sipEveningHour);
  }

  /// Register the daily recurring-bill prompts at ~12 PM and ~8 PM local.
  static Future<void> _ensureBillPrompts() async {
    await _registerDailyAt(billNoonUniqueName, billNoonTaskName, sipNoonHour);
    await _registerDailyAt(
        billEveningUniqueName, billEveningTaskName, sipEveningHour);
  }

  static Future<void> _registerDailyAt(
    String uniqueName,
    String taskName,
    int hour,
  ) async {
    final now = DateTime.now();
    var firstRun = DateTime(now.year, now.month, now.day, hour);
    if (!firstRun.isAfter(now)) {
      firstRun = firstRun.add(const Duration(days: 1));
    }
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: const Duration(days: 1),
      initialDelay: firstRun.difference(now),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Register the weekly unclassified-transactions reminder. Independent of
  /// auto-scan — it nudges the user to tag whatever has accumulated.
  static Future<void> _ensureWeeklyReminder() async {
    await Workmanager().registerPeriodicTask(
      weeklyReminderUniqueName,
      weeklyReminderTaskName,
      frequency: const Duration(days: 7),
      initialDelay: const Duration(days: 7),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Register the daily streak reminder at ~8 PM local.
  static Future<void> _ensureStreakReminder() async {
    await _registerDailyAt(
        streakReminderUniqueName, streakReminderTaskName, sipEveningHour);
  }

  /// Daily ~8 PM check: if the user has an active streak but hasn't opened the
  /// app today, nudge them so they don't lose it — flagging a reward that's
  /// only a day or two away when one is close.
  static Future<void> performStreakReminder() async {
    try {
      final svc = GamificationService();
      final info = await svc.streakInfo();
      if (info.current <= 0) return; // nothing to protect

      final last = await svc.lastActiveDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (last != null && DateTime(last.year, last.month, last.day) == today) {
        return; // already opened today — streak is safe
      }

      // Closest still-locked reward and how far the best streak is from it.
      String? nextName;
      int? daysAway;
      for (final r in kStreakRewards) {
        if (!r.isUnlocked(info.longest)) {
          final away = (r.days - info.longest).clamp(0, r.days);
          if (away <= 2) {
            nextName = r.name;
            daysAway = away;
          }
          break;
        }
      }

      final notif = NotificationService();
      await notif.initialize();
      await notif.showStreakReminder(
        currentStreak: info.current,
        nextRewardName: nextName,
        daysToReward: daysAway,
      );
    } catch (_) {
      // Background best-effort; never throw.
    }
  }

  /// Check if auto-scan is enabled (default: on)
  static Future<bool> isAutoScanEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoScanEnabledKey) ?? true;
  }

  /// Get scan settings for the settings screen.
  static Future<Map<String, dynamic>> getScanSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_autoScanEnabledKey) ?? true,
      'intervalHours':
          prefs.getInt(_scanIntervalHoursKey) ?? defaultIntervalHours,
    };
  }

  /// Save scan settings and (re)apply the schedule.
  static Future<void> saveScanSettings({
    required bool enabled,
    int? intervalHours,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoScanEnabledKey, enabled);
    if (intervalHours != null) {
      await prefs.setInt(_scanIntervalHoursKey, intervalHours);
    }

    if (enabled) {
      await _registerBackgroundTask(replace: true);
    } else {
      await _cancelBackgroundTask();
    }
  }

  /// Re-assert the schedule on startup without resetting the period timer.
  static Future<void> _ensureScheduled() async {
    if (await isAutoScanEnabled()) {
      await _registerBackgroundTask(replace: false);
    }
  }

  /// Register the periodic scan task.
  static Future<void> _registerBackgroundTask({required bool replace}) async {
    await _ensureWorkmanager();
    final prefs = await SharedPreferences.getInstance();
    final hours = prefs.getInt(_scanIntervalHoursKey) ?? defaultIntervalHours;

    await Workmanager().registerPeriodicTask(
      scanTaskUniqueName,
      scanTaskName,
      frequency: Duration(hours: hours),
      // SMS scanning is local and cheap: no network, battery, or idle
      // constraints, so the OS has no reason to defer the task.
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: replace
          ? ExistingPeriodicWorkPolicy.replace
          : ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  /// Cancel background tasks
  static Future<void> _cancelBackgroundTask() async {
    await _ensureWorkmanager();
    await Workmanager().cancelByUniqueName(scanTaskUniqueName);
  }

  /// Record last scan time
  static Future<void> _recordScanTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastScanTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get last scan time
  static Future<DateTime?> getLastScanTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastScanTimeKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// Perform the background SMS scan.
  /// Shows a summary notification when new transactions are found, so
  /// background discoveries are no longer silent.
  static Future<void> performBackgroundScan() async {
    // Payment-app notification queue first: with the phone asleep all day,
    // this is the only drain that runs, and doing it before the SMS pass
    // lets a same-payment SMS below absorb the fresh notification row
    // instead of racing it. No-op (one prefs read) while capture is off,
    // and its failures never block the SMS scan.
    try {
      await NotificationCaptureService().drain();
    } catch (_) {
      // Silently fail in background
    }

    try {
      final smsService = SmsService();

      if (!await smsService.hasPermission()) {
        return;
      }

      final found = await smsService.scanExistingSms(maxCount: 100);
      await _recordScanTime();
      await WidgetService.update();

      if (found.isNotEmpty) {
        final notificationService = NotificationService();
        await notificationService.initialize();
        // Notify per-transaction for a small batch so each alert carries its
        // own amount + tag ("₹X debited towards Food & Dining"), matching the
        // real-time path. Fall back to a single summary for larger catch-up
        // scans so a long-offline gap never floods the notification shade.
        const perTxnCap = 3;
        if (found.length <= perTxnCap) {
          for (final t in found) {
            await notificationService.showTransactionNotification(t);
          }
        } else {
          final total = found.fold(0.0, (sum, t) => sum + t.amount);
          await notificationService.showScanSummaryNotification(
            count: found.length,
            totalAmount: total,
          );
        }
      }
    } catch (e) {
      // Silently fail in background
    }
  }

  /// Weekly reminder: count this month's unclassified transactions and, if
  /// any, post a notification nudging the user to tag them.
  static Future<void> performWeeklyReminder() async {
    try {
      final db = DatabaseService();
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final count = await db.countUnclassifiedInPeriod(monthStart, monthEnd);
      if (count <= 0) return;

      final ns = NotificationService();
      await ns.initialize();
      await ns.showUnclassifiedReminder(
        count: count,
        monthLabel: DateFormat('MMMM').format(now),
      );
    } catch (e) {
      // Best-effort reminder
    }
  }

  /// Send the noon / evening "Investment Alert" Yes/No prompt for any recurring
  /// investment due today and still unanswered.
  static Future<void> performSipPromptCheck({required bool evening}) async {
    try {
      await SipService().sendDuePrompts(evening: evening);
    } catch (e) {
      // Best-effort reminder
    }
  }

  /// Reconcile recurring bills against recent SMS debits, then send the
  /// noon / evening "Bill reminder" prompt for any cycle still unresolved and
  /// within its reminder window.
  static Future<void> performBillPromptCheck({required bool evening}) async {
    try {
      final recurring = RecurringService();
      await recurring.reconcile();
      await recurring.sendDuePrompts(evening: evening);
    } catch (e) {
      // Best-effort reminder
    }
  }

  /// Perform a foreground SMS scan (called when app opens).
  /// Returns the list of newly found transactions.
  static Future<List<TransactionModel>> performForegroundScan({
    int maxCount = 100,
  }) async {
    try {
      final smsService = SmsService();

      // Check if we have permission
      if (!await smsService.hasPermission()) {
        return [];
      }

      // Scan SMS and auto-classify
      final transactions = await smsService.scanExistingSms(
        maxCount: maxCount,
      );

      // Record scan time
      await _recordScanTime();

      return transactions;
    } catch (e) {
      // Silently fail
      return [];
    }
  }
}

/// Top-level callback for WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == BackgroundService.scanTaskName) {
      await BackgroundService.performBackgroundScan();
    } else if (taskName == BackgroundService.weeklyReminderTaskName) {
      await BackgroundService.performWeeklyReminder();
    } else if (taskName == BackgroundService.sipNoonTaskName) {
      await BackgroundService.performSipPromptCheck(evening: false);
    } else if (taskName == BackgroundService.sipEveningTaskName) {
      await BackgroundService.performSipPromptCheck(evening: true);
    } else if (taskName == BackgroundService.billNoonTaskName) {
      await BackgroundService.performBillPromptCheck(evening: false);
    } else if (taskName == BackgroundService.billEveningTaskName) {
      await BackgroundService.performBillPromptCheck(evening: true);
    } else if (taskName == BackgroundService.streakReminderTaskName) {
      await BackgroundService.performStreakReminder();
    }
    return Future.value(true);
  });
}
