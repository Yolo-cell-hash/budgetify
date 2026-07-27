import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/models/plus_products.dart';
import 'package:budget_tracker/services/entitlement_service.dart';

/// The silent trial clock (stamp first-use once, guard against clock
/// rollback, carry the anchor through backup/restore without ever extending
/// the trial) plus the paywall-prep layer: the Plus ownership cache, the
/// dormant feature gates, and purchased-royal tracking. All gates pass while
/// the trial runs, so nothing user-visible changes on current installs.
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

  // Stand in for Android's package install record. Null unsets the handler,
  // which is what every non-Android platform looks like from Dart.
  const installChannel = MethodChannel('budgetify/install_info');
  void mockFirstInstall(int? ms) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      installChannel,
      ms == null ? null : (call) async => ms,
    );
  }

  tearDown(() => mockFirstInstall(null));

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

  group('install-record floor', () {
    test('a data wipe cannot buy a fresh window', () async {
      // "Clear data" leaves no anchor, so initialize() stamps today — but the
      // package record still knows the app went on 200 days ago.
      mockFirstInstall(daysAgo(200));
      await svc.initialize();
      expect(svc.trialActive, isTrue); // the wipe appeared to work…
      await svc.applyInstallRecordFloor();

      expect(svc.trialActive, isFalse); // …until the install record spoke
      expect(svc.firstLaunchAt!.millisecondsSinceEpoch,
          closeTo(daysAgo(200), 1000));
    });

    test('the floor persists, so it only has to be read once', () async {
      mockFirstInstall(daysAgo(200));
      await svc.initialize();
      await svc.applyInstallRecordFloor();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('entitlement_first_launch_at'),
          closeTo(daysAgo(200), 1000));
    });

    test('a later install record never moves the anchor forward', () async {
      // Reinstall-then-restore order: the anchor is already older than the
      // (fresh) package record, and must survive untouched.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(200));
      mockFirstInstall(DateTime.now().millisecondsSinceEpoch);
      await svc.initialize();
      await svc.applyInstallRecordFloor();

      expect(svc.trialActive, isFalse);
      expect(svc.firstLaunchAt!.millisecondsSinceEpoch,
          closeTo(daysAgo(200), 1000));
    });

    test('no channel (non-Android, isolate) leaves the anchor alone', () async {
      mockFirstInstall(null);
      await svc.initialize();
      await svc.applyInstallRecordFloor();

      expect(svc.trialActive, isTrue);
      expect(svc.firstLaunchAt, isNotNull);
    });

    test('a nonsense install time is ignored', () async {
      mockFirstInstall(0);
      await svc.initialize();
      await svc.applyInstallRecordFloor();

      expect(svc.trialActive, isTrue);
      expect(svc.trialDaysLeft, greaterThanOrEqualTo(180));
    });

    test('the gate path never touches the channel', () async {
      // allowsAsync runs in the background isolate, where an unbound channel
      // would stall a notification. It must resolve on prefs alone.
      mockFirstInstall(null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(200));
      await prefs.setInt(
          'entitlement_last_seen_at', DateTime.now().millisecondsSinceEpoch);

      expect(
        await svc
            .allowsAsync(PlusFeature.spendingNotifications)
            .timeout(const Duration(seconds: 2)),
        isFalse,
      );
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
      await svc.importSettings({}, backupCreatedAtMs: 0);

      expect(svc.firstLaunchAt, before);
    });

    test('the backup file stamp ages the anchor on its own', () async {
      // The tamper case: entitlement block stripped out of a decrypted
      // backup, but the file was written 200 days ago and says so.
      await svc.initialize(); // stamps ~now
      await svc.importSettings(null, backupCreatedAtMs: daysAgo(200));

      expect(svc.trialActive, isFalse);
    });

    test('the file stamp never moves the anchor forward', () async {
      await svc.initialize();
      final before = svc.firstLaunchAt!.millisecondsSinceEpoch;
      await svc.importSettings({}, backupCreatedAtMs: daysAhead(200));

      expect(svc.firstLaunchAt!.millisecondsSinceEpoch, before);
    });

    test('the earliest of the two witnesses wins', () async {
      await svc.initialize();
      // File written recently, but it carries a much older anchor.
      await svc.importSettings({'first_launch_at': daysAgo(200)},
          backupCreatedAtMs: daysAgo(3));

      expect(svc.firstLaunchAt!.millisecondsSinceEpoch,
          closeTo(daysAgo(200), 1000));
    });
  });

  group('product catalog', () {
    test('Plus SKUs carry the agreed ids and prices', () {
      expect(PlusPlan.monthly.productId, 'plus_monthly');
      expect(PlusPlan.monthly.priceInr, 29);
      expect(PlusPlan.yearly.productId, 'plus_yearly');
      expect(PlusPlan.yearly.priceInr, 299);
      expect(PlusPlan.lifetime.productId, 'plus_lifetime');
      expect(PlusPlan.lifetime.priceInr, 699);
      expect(PlusPlan.byProductId('plus_lifetime'), PlusPlan.lifetime);
      expect(PlusPlan.byProductId('nope'), isNull);
    });

    test('royal products are ₹49 and round-trip their royal id', () {
      expect(kRoyalAvatarPriceInr, 49);
      expect(royalProductId('sovereign'), 'royal_sovereign');
      expect(royalIdFromProduct('royal_darkprince'), 'darkprince');
      expect(royalIdFromProduct('plus_monthly'), isNull);
    });
  });

  group('feature gates', () {
    Future<void> seedExpiredTrial() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(200));
      await prefs.setInt(
          'entitlement_last_seen_at', DateTime.now().millisecondsSinceEpoch);
    }

    test('every feature is allowed while the trial runs', () async {
      await svc.initialize();
      expect(svc.hasPlus, isFalse);
      expect(svc.hasFullAccess, isTrue);
      for (final f in PlusFeature.values) {
        expect(svc.allows(f), isTrue, reason: f.name);
        expect(await svc.allowsAsync(f), isTrue, reason: f.name);
      }
    });

    test('every feature locks once the trial elapsed without Plus', () async {
      await seedExpiredTrial();
      await svc.initialize();
      expect(svc.hasFullAccess, isFalse);
      for (final f in PlusFeature.values) {
        expect(svc.allows(f), isFalse, reason: f.name);
      }
    });

    test('lifetime purchase reopens everything, forever', () async {
      await seedExpiredTrial();
      await svc.initialize();
      await svc.registerPlusPurchase('plus_lifetime');
      expect(svc.hasPlus, isTrue);
      expect(svc.hasFullAccess, isTrue);

      // Survives a cold start.
      svc.resetForTest();
      await svc.initialize();
      expect(svc.hasPlus, isTrue);
    });

    test('monthly purchase opens a bounded window with grace', () async {
      await seedExpiredTrial();
      await svc.initialize();
      await svc.registerPlusPurchase('plus_monthly');
      expect(svc.hasPlus, isTrue);

      // A month-old monthly purchase (plus grace) has lapsed by day 40.
      svc.resetForTest();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'entitlement_plus_until',
          DateTime.now()
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch);
      await svc.initialize();
      expect(svc.hasPlus, isFalse);
    });

    test('unknown product ids grant nothing', () async {
      await seedExpiredTrial();
      await svc.initialize();
      await svc.registerPlusPurchase('plus_diamond');
      expect(svc.hasPlus, isFalse);
    });

    test('allowsAsync self-initializes (background-isolate path)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('entitlement_first_launch_at', daysAgo(200));
      await prefs.setInt(
          'entitlement_last_seen_at', DateTime.now().millisecondsSinceEpoch);
      // No explicit initialize() — the gate must do it itself.
      expect(
          await svc.allowsAsync(PlusFeature.spendingNotifications), isFalse);
    });
  });

  group('royal purchases', () {
    test('grants persist, are idempotent, and read back sorted', () async {
      await svc.initialize();
      expect(svc.ownsRoyal('empress'), isFalse);

      await svc.registerRoyalPurchase('empress');
      await svc.registerRoyalPurchase('empress'); // no double entry
      await svc.registerRoyalPurchase('darkprince');

      svc.resetForTest();
      await svc.initialize();
      expect(svc.ownsRoyal('empress'), isTrue);
      expect(svc.purchasedRoyalIds, {'darkprince', 'empress'});
    });
  });

  group('paid cache in backup', () {
    test('export carries plus + royals; import merges add-only', () async {
      await svc.initialize();
      await svc.registerPlusPurchase('plus_lifetime');
      await svc.registerRoyalPurchase('prince');

      final exported = await svc.exportSettings();
      expect(exported['plus_lifetime'], isTrue);
      expect(exported['owned_royals'], ['prince']);

      // Fresh install imports the backup: ownership arrives.
      SharedPreferences.setMockInitialValues({});
      svc.resetForTest();
      await svc.initialize();
      await svc.importSettings(exported);
      expect(svc.hasPlus, isTrue);
      expect(svc.ownsRoyal('prince'), isTrue);

      // Importing an EMPTY backup can never remove ownership.
      await svc.importSettings({});
      expect(svc.hasPlus, isTrue);
      expect(svc.ownsRoyal('prince'), isTrue);
    });

    test('import takes the larger subscription window', () async {
      await svc.initialize();
      final far = daysAhead(300);
      await svc.importSettings({'plus_until': far});
      expect(svc.hasPlus, isTrue);

      // A shorter window from another backup must not shrink it.
      await svc.importSettings({'plus_until': daysAhead(2)});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('entitlement_plus_until'), far);
    });
  });
}
