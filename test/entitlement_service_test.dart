import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/services/entitlement_service.dart';

/// Phase 0 covers only the silent trial clock: stamp first-use once, guard
/// against clock rollback, and carry the anchor through backup/restore without
/// ever extending the trial. No feature is gated on any of this yet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final svc = EntitlementService();

  setUp(() async {
    // Clear the live instance too, so seeded values from one test can't leak
    // into the next regardless of the plugin's instance caching.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    svc.resetForTest();
  });

  int daysAgo(int d) =>
      DateTime.now().subtract(Duration(days: d)).millisecondsSinceEpoch;
  int daysAhead(int d) =>
      DateTime.now().add(Duration(days: d)).millisecondsSinceEpoch;

  group('trial anchor', () {
    test('stamps first-launch once and does not move it on re-init', () async {
      await svc.initialize();
      final first = svc.firstLaunchAt;
      expect(first, isNotNull);

      // Simulate a later cold start: drop in-memory state, keep prefs.
      svc.resetForTest();
      await svc.initialize();

      expect(svc.firstLaunchAt, first);
    });

    test('trial is active immediately after first launch', () async {
      await svc.initialize();
      expect(svc.trialActive, isTrue);
      expect(svc.trialDaysLeft, greaterThanOrEqualTo(180));
      expect(svc.trialDaysLeft, lessThanOrEqualTo(182));
    });

    test('trial is inactive once the window has elapsed', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(200));
      await prefs.setInt(
          'entitlement_last_seen_at', DateTime.now().millisecondsSinceEpoch);
      await svc.initialize();

      expect(svc.trialActive, isFalse);
      expect(svc.trialDaysLeft, 0);
    });
  });

  group('rollback guard', () {
    test('a last-seen clock in the future drives trial math', () async {
      // Anchored only 10 days ago (normally deep in trial), but a previously
      // observed clock 200 days ahead must make the trial read as elapsed:
      // you cannot gain trial time by winding the clock forward then back.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(10));
      await prefs.setInt('entitlement_last_seen_at', daysAhead(200));
      await svc.initialize();

      expect(svc.trialActive, isFalse);
    });
  });

  group('backup export / import', () {
    test('export captures the persisted anchor', () async {
      await svc.initialize();
      final prefs = await SharedPreferences.getInstance();
      final exported = await svc.exportSettings();

      expect(exported['first_launch_at'],
          prefs.getInt('entitlement_first_launch_at'));
    });

    test('import adopts an earlier anchor', () async {
      await svc.initialize(); // stamps ~now
      final earlier = daysAgo(120);
      await svc.importSettings({'first_launch_at': earlier});

      expect(svc.firstLaunchAt!.millisecondsSinceEpoch, earlier);
    });

    test('import never moves the anchor forward', () async {
      await svc.initialize(); // stamps ~now
      final before = svc.firstLaunchAt!.millisecondsSinceEpoch;
      await svc.importSettings({'first_launch_at': daysAhead(120)});

      expect(svc.firstLaunchAt!.millisecondsSinceEpoch, before);
    });

    test('import is null- and garbage-safe', () async {
      await svc.initialize();
      final before = svc.firstLaunchAt;
      await svc.importSettings(null);
      await svc.importSettings({'first_launch_at': 'not-an-int'});
      await svc.importSettings({});

      expect(svc.firstLaunchAt, before);
    });
  });
}
