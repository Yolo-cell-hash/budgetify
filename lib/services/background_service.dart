import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'sip_service.dart';
import 'sms_service.dart';
import 'widget_service.dart';

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

  // Daily evening check for due SIP/RD instalments (~7:30 PM)
  static const String sipEveningCheckTaskName = 'sip_evening_check';
  static const String sipEveningCheckUniqueName = 'budget_tracker_sip_evening';

  /// Hour/minute the evening SIP reminder aims for (local time).
  static const int sipReminderHour = 19;
  static const int sipReminderMinute = 30;

  // Preferences keys
  static const String _autoScanEnabledKey = 'auto_scan_enabled';
  static const String _scanIntervalHoursKey = 'scan_interval_hours';
  static const String _lastScanTimeKey = 'last_scan_time';

  static const int defaultIntervalHours = 1;

  /// Allowed scan intervals (hours) offered in settings.
  static const List<int> intervalOptions = [1, 3, 6, 12, 18, 24];

  /// Initialize the background service and make sure the periodic scan is
  /// scheduled whenever auto-scan is enabled.
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await _ensureScheduled();
    await _ensureWeeklyReminder();
    await _ensureSipEveningCheck();
  }

  /// Register the daily evening SIP/RD reminder, anchored to ~7:30 PM local.
  /// Kept independent of auto-scan so it fires even with scanning off.
  static Future<void> _ensureSipEveningCheck() async {
    final now = DateTime.now();
    var firstRun =
        DateTime(now.year, now.month, now.day, sipReminderHour, sipReminderMinute);
    if (!firstRun.isAfter(now)) {
      firstRun = firstRun.add(const Duration(days: 1));
    }
    await Workmanager().registerPeriodicTask(
      sipEveningCheckUniqueName,
      sipEveningCheckTaskName,
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
    try {
      final smsService = SmsService();

      if (!await smsService.hasPermission()) {
        return;
      }

      final found = await smsService.scanExistingSms(maxCount: 100);
      await _recordScanTime();
      // Credit any newly-detected SIP/RD instalments to their holdings.
      await SipService().reconcile();
      await WidgetService.update();

      if (found.isNotEmpty) {
        final notificationService = NotificationService();
        await notificationService.initialize();
        if (found.length == 1) {
          await notificationService.showTransactionNotification(found.first);
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

  /// Evening check: reconcile detected instalments, then nudge the user about
  /// any recurring investment still due and unconfirmed for today.
  static Future<void> performSipEveningCheck() async {
    try {
      await SipService().runEveningCheck();
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
    } else if (taskName == BackgroundService.sipEveningCheckTaskName) {
      await BackgroundService.performSipEveningCheck();
    }
    return Future.value(true);
  });
}
