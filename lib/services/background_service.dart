import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
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

  // Retired: the original weekly "tag your transactions" reminder. It fired on
  // whatever weekday the app happened to be installed, because its initial
  // delay was simply "7 days from now". Kept only so [initialize] can cancel
  // it — registration used ExistingPeriodicWorkPolicy.keep, so re-anchoring the
  // same unique name to Sunday would be a silent no-op on every install that
  // already has it, and those users would keep their install-day slot forever.
  static const String weeklyReminderUniqueName =
      'budget_tracker_weekly_reminder';

  // The weekend tidy-up nudge. ONE task, not two: it alternates between the
  // tagging reminder and the review reminder by the parity of the week it
  // actually fires in (see [performWeekendNudge]).
  //
  // Two fortnightly tasks would have been the obvious build and the wrong one.
  // WorkManager periodic work isn't exact — Doze defers it and every reschedule
  // shifts the anchor — so two independent 14-day tasks drift relative to each
  // other and eventually land on the same weekend, which is the one thing the
  // alternation exists to prevent. Deciding from the calendar at fire time
  // can't drift: a late run still knows which week it is in.
  static const String weekendNudgeTaskName = 'weekend_tidy_up_nudge';
  static const String weekendNudgeUniqueName =
      'budget_tracker_weekend_nudge';

  /// Sunday, late morning. Saturday mornings people are out; 8 PM already
  /// belongs to the streak reminder, and stacking two nudges in one evening is
  /// how both get muted.
  static const int weekendNudgeWeekday = DateTime.sunday;
  static const int weekendNudgeHour = 11;

  /// Below this, a review nudge isn't worth a Sunday interruption. One
  /// uncertain payee is a chore; three entries, or one flagged entry carrying
  /// real money, is a reason to open the app.
  static const int reviewNudgeMinCount = 3;
  static const double reviewNudgeMinAmount = 1000;

  /// Last week index a weekend nudge was actually posted for. Makes the nudge
  /// exactly-once-per-week even if WorkManager runs the task late enough to
  /// land twice inside one parity window.
  static const String _lastNudgeWeekKey = 'last_weekend_nudge_week';

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
    await _ensureWeekendNudge();
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

  /// Register the Sunday-morning tidy-up nudge, and retire the old
  /// install-day weekly reminder it replaces. Independent of auto-scan — it
  /// nudges about whatever has accumulated either way.
  static Future<void> _ensureWeekendNudge() async {
    await Workmanager().cancelByUniqueName(weeklyReminderUniqueName);
    await _registerWeeklyOn(
      weekendNudgeUniqueName,
      weekendNudgeTaskName,
      weekendNudgeWeekday,
      weekendNudgeHour,
    );
  }

  /// Register a weekly task anchored to the next [weekday] at [hour] local.
  static Future<void> _registerWeeklyOn(
    String uniqueName,
    String taskName,
    int weekday,
    int hour,
  ) async {
    final now = DateTime.now();
    // Rebuilt from parts rather than advanced by Duration(days: 1): adding a
    // fixed 24 hours drifts the wall-clock hour across a DST boundary, and
    // this needs to stay at [hour] wherever the user is.
    var firstRun = DateTime(now.year, now.month, now.day, hour);
    for (var i = 0; i < 8; i++) {
      if (firstRun.weekday == weekday && firstRun.isAfter(now)) break;
      firstRun =
          DateTime(firstRun.year, firstRun.month, firstRun.day + 1, hour);
    }
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: const Duration(days: 7),
      initialDelay: firstRun.difference(now),
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
  /// Whole weeks between [day] and a fixed Monday. Only its parity is used —
  /// the absolute value is meaningless, and it deliberately isn't the ISO week
  /// number (which resets each year and would double-up or skip a nudge at
  /// every year boundary).
  ///
  /// Computed in UTC so the subtraction is exact: `inDays` over local midnights
  /// returns 0 for a 23-hour DST day, which would stall the alternation for a
  /// week in any region that observes it.
  static int weekIndexFor(DateTime day) {
    final epoch = DateTime.utc(2024, 1, 1); // a Monday
    final d = DateTime.utc(day.year, day.month, day.day);
    return d.difference(epoch).inDays ~/ 7;
  }

  /// Whether [day] falls in a tagging week (the alternative is a review week).
  static bool isTaggingWeek(DateTime day) => weekIndexFor(day) % 2 == 0;

  /// The Sunday-morning tidy-up nudge: tagging one week, review the next.
  ///
  /// Sends nothing when the week's chosen queue is empty. It deliberately does
  /// *not* fall back to the other nudge — substituting would mean there is
  /// always a Sunday notification, which is the habit this alternation exists
  /// to avoid. A quiet fortnight is the feature.
  static Future<void> performWeekendNudge() async {
    try {
      final db = DatabaseService();
      final now = DateTime.now();
      final week = weekIndexFor(now);

      // Exactly once per parity window, however late WorkManager runs it.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt(_lastNudgeWeekKey) == week) return;

      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final monthLabel = DateFormat('MMMM').format(now);

      final ns = NotificationService();
      final posted = isTaggingWeek(now)
          ? await _nudgeTagging(db, ns, monthStart, monthEnd, monthLabel)
          : await _nudgeReview(db, ns, monthStart, monthEnd, monthLabel);

      if (posted) await prefs.setInt(_lastNudgeWeekKey, week);
    } catch (e) {
      // Best-effort reminder
    }
  }

  /// "Tag your transactions." Scoped to the month in progress: an all-time
  /// backlog is a number that never reaches zero, and a nudge you can't
  /// finish is one you learn to ignore.
  static Future<bool> _nudgeTagging(
    DatabaseService db,
    NotificationService ns,
    DateTime monthStart,
    DateTime monthEnd,
    String monthLabel,
  ) async {
    final count = await db.countUnclassifiedInPeriod(monthStart, monthEnd);
    if (count <= 0) return false;
    await ns.initialize();
    await ns.showUnclassifiedReminder(count: count, monthLabel: monthLabel);
    return true;
  }

  /// "Check the entries the reader wasn't sure about."
  ///
  /// Held to a floor, unlike the tagging nudge. Most review queues are one or
  /// two rows, and a Sunday interruption for a single uncertain payee spends
  /// attention the app will want later. Either a handful of entries or one
  /// carrying real money clears the bar — the amount test is what catches the
  /// case this whole feature came from, a lone phantom worth ₹10,000.
  static Future<bool> _nudgeReview(
    DatabaseService db,
    NotificationService ns,
    DateTime monthStart,
    DateTime monthEnd,
    String monthLabel,
  ) async {
    final backlog = await db.reviewBacklogForPeriod(monthStart, monthEnd);
    if (!reviewNudgeClears(
      count: backlog.count,
      unconfirmedSpend: backlog.unconfirmedSpend,
    )) {
      return false;
    }
    await ns.initialize();
    await ns.showReviewReminder(
      count: backlog.count,
      unconfirmedSpend: backlog.unconfirmedSpend,
      monthLabel: monthLabel,
    );
    return true;
  }

  /// Whether a review backlog is worth interrupting a Sunday for.
  static bool reviewNudgeClears({
    required int count,
    required double unconfirmedSpend,
  }) {
    if (count <= 0) return false;
    return count >= reviewNudgeMinCount ||
        unconfirmedSpend >= reviewNudgeMinAmount;
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
    } else if (taskName == BackgroundService.weekendNudgeTaskName) {
      await BackgroundService.performWeekendNudge();
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
