import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/services/entitlement_service.dart';

/// Two things the free window must get right, both of which are really about
/// not lying to the user.
///
/// 1. The RESTART that hands the closed-testing cohort a clean 90 days. It has
///    to be idempotent — a reset that a data wipe can re-trigger is an
///    unlimited free trial.
/// 2. The DISCLOSURE. The countdown is hidden on purpose, so the two heads-ups
///    and the single lapse notice are the entire warning a user gets before
///    their alerts go quiet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final svc = EntitlementService();

  int daysAgo(int d) =>
      DateTime.now().subtract(Duration(days: d)).millisecondsSinceEpoch;

  const installChannel = MethodChannel('budgetify/install_info');
  void mockFirstInstall(int? ms) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      installChannel,
      ms == null ? null : (call) async => ms,
    );
  }

  Future<void> reset() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    svc.resetForTest();
  }

  tearDown(() {
    mockFirstInstall(null);
    EntitlementService.debugTrialRestartAt = null;
  });

  group('trial restart', () {
    test('an existing tester gets a full window from the restart', () async {
      await reset();
      // Anchored 200 days back — long expired under the old clock.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(200));
      // Restart 10 days ago, so 80 of the 90 days remain.
      EntitlementService.debugTrialRestartAt =
          DateTime.now().subtract(const Duration(days: 10));
      await svc.initialize();

      expect(svc.trialActive, isTrue);
      expect(svc.trialDaysLeft, closeTo(80, 1));
    });

    test('a newer install keeps its own, later anchor', () async {
      await reset();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(30));
      // Restart predates this install: it must NOT hand out extra time.
      EntitlementService.debugTrialRestartAt =
          DateTime.now().subtract(const Duration(days: 100));
      await svc.initialize();

      expect(svc.trialDaysLeft, closeTo(60, 1));
    });

    test('the raw anchor is left untouched — only the reading moves', () async {
      await reset();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(200));
      EntitlementService.debugTrialRestartAt =
          DateTime.now().subtract(const Duration(days: 10));
      await svc.initialize();

      // The stored history is still true, so a later restart date (or none)
      // reads the real origin rather than a rewritten one.
      expect(svc.firstLaunchAt!.millisecondsSinceEpoch,
          closeTo(daysAgo(200), 2000));
    });

    test('clearing data cannot buy a SECOND restart', () async {
      // The whole reason the restart is a clamp and not a migration flag. A
      // flag would live in app data; wiping it would re-run the reset forever.
      EntitlementService.debugTrialRestartAt =
          DateTime.now().subtract(const Duration(days: 40));
      mockFirstInstall(daysAgo(200));

      await reset();
      await svc.initialize();
      await svc.applyInstallRecordFloor();
      final firstReading = svc.trialDaysLeft;

      // "Clear data": every pref gone, install record survives.
      await reset();
      await svc.initialize();
      await svc.applyInstallRecordFloor();

      // Same restart, same remaining days — the wipe gained nothing.
      expect(svc.trialDaysLeft, closeTo(firstReading, 1));
      expect(svc.trialDaysLeft, closeTo(50, 1));
    });

    test('a restart dated in the future never reports more than a full window',
        () async {
      await reset();
      EntitlementService.debugTrialRestartAt =
          DateTime.now().add(const Duration(days: 30));
      await svc.initialize();

      expect(svc.trialActive, isTrue);
      expect(svc.trialDaysLeft, EntitlementService.trialDuration.inDays);
    });
  });

  group('pre-expiry heads-up', () {
    setUp(() async {
      await reset();
      EntitlementService.debugTrialRestartAt = DateTime.utc(2000);
    });

    Future<void> seedDaysIn(int days) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(days));
      svc.resetForTest();
      await svc.initialize();
    }

    test('stays silent through the bulk of the window', () async {
      await seedDaysIn(30); // 60 days left
      expect(svc.pendingTrialNotice, isNull);
      await seedDaysIn(70); // 20 days left — still outside the 14-day mark
      expect(svc.pendingTrialNotice, isNull);
    });

    test('appears at 14 days, then again at 3', () async {
      await seedDaysIn(80); // ~10 days left
      expect(svc.pendingTrialNotice, 14);

      await seedDaysIn(88); // ~2 days left — the more urgent mark wins
      expect(svc.pendingTrialNotice, 3);
    });

    test('dismissing means silence, not a fallback to a gentler notice',
        () async {
      await seedDaysIn(88); // 3-day mark
      expect(svc.pendingTrialNotice, 3);
      await svc.dismissTrialNotice(3);
      expect(svc.pendingTrialNotice, isNull);
    });

    test('a dismissal survives a cold start', () async {
      await seedDaysIn(80);
      await svc.dismissTrialNotice(14);
      svc.resetForTest();
      await svc.initialize();

      expect(svc.pendingTrialNotice, isNull);
    });

    test('the 14-day dismissal does not silence the 3-day one', () async {
      await seedDaysIn(80);
      await svc.dismissTrialNotice(14);
      await seedDaysIn(88);

      expect(svc.pendingTrialNotice, 3);
    });

    test('nothing is shown once the window has closed', () async {
      await seedDaysIn(95);
      expect(svc.trialActive, isFalse);
      expect(svc.pendingTrialNotice, isNull);
    });

    test('a payer is never nudged', () async {
      await seedDaysIn(88);
      await svc.registerPlusPurchase('plus_lifetime');
      expect(svc.pendingTrialNotice, isNull);
    });
  });

  group('lapse notice', () {
    setUp(() async {
      await reset();
      EntitlementService.debugTrialRestartAt = DateTime.utc(2000);
    });

    Future<void> seedDaysIn(int days) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(days));
      svc.resetForTest();
      await svc.initialize();
    }

    test('is owed once the window closes', () async {
      await seedDaysIn(95);
      expect(await svc.shouldSendLapseNotice(), isTrue);
    });

    test('is not owed during the window', () async {
      await seedDaysIn(30);
      expect(await svc.shouldSendLapseNotice(), isFalse);
    });

    test('fires only once, however many gates trip', () async {
      await seedDaysIn(95);
      expect(await svc.shouldSendLapseNotice(), isTrue);
      await svc.markLapseNoticeSent();

      // Four gated notification paths share the dedup — a lapsed user gets
      // one notice, not one per suppressed alert.
      for (var i = 0; i < 4; i++) {
        expect(await svc.shouldSendLapseNotice(), isFalse);
      }
    });

    test('a payer is never told their alerts paused', () async {
      await seedDaysIn(95);
      await svc.registerPlusPurchase('plus_lifetime');
      expect(await svc.shouldSendLapseNotice(), isFalse);
    });

    test('re-arms if the window itself changes', () async {
      // Anchored 200 days back, so the original window closed 110 days ago.
      await seedDaysIn(200);
      await svc.markLapseNoticeSent();
      expect(await svc.shouldSendLapseNotice(), isFalse);

      // A restart LATER than the anchor is a genuinely new window — exactly
      // what the shipping restart does to the closed-testing cohort. The
      // notice is owed again rather than staying suppressed by a stale flag
      // pointing at the old window's end.
      EntitlementService.debugTrialRestartAt =
          DateTime.now().subtract(const Duration(days: 95));
      svc.resetForTest();
      await svc.initialize();

      expect(svc.trialActive, isFalse); // new window closed 5 days ago
      expect(await svc.shouldSendLapseNotice(), isTrue);
    });
  });
}
