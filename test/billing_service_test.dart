import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/models/plus_products.dart';
import 'package:budget_tracker/services/billing_service.dart';
import 'package:budget_tracker/services/entitlement_service.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';

/// A store that owns whatever the test seeds — the shape the eventual
/// PlayBillingGateway will fill from real `queryPurchases()` results.
class _FakeGateway implements BillingGateway {
  final bool available;
  final List<BillingPurchase> owned;
  final BillingOutcome purchaseOutcome;

  _FakeGateway({
    this.available = true,
    this.owned = const [],
    this.purchaseOutcome = BillingOutcome.success,
  });

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<BillingPurchase>> queryPurchases() async => owned;

  @override
  Future<BillingOutcome> launchPurchase(String productId) async =>
      purchaseOutcome;
}

BillingPurchase _p(String id) => BillingPurchase(
      productId: id,
      purchaseToken: 'tok_$id',
      purchaseTimeMs: DateTime.now().millisecondsSinceEpoch,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final billing = BillingService();
  final entitlements = EntitlementService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    entitlements.resetForTest();
    billing.gateway = const UnavailableBillingGateway();
  });

  group('shipped (unavailable) gateway', () {
    test('store reports closed and a purchase attempt grants nothing',
        () async {
      expect(await billing.storeAvailable, isFalse);
      expect(await billing.purchase('plus_lifetime'),
          BillingOutcome.unavailable);
      await entitlements.initialize();
      expect(entitlements.hasPlus, isFalse);
    });

    test('restore reports unavailable and restores nothing', () async {
      final result = await billing.restorePurchases();
      expect(result.outcome, BillingOutcome.unavailable);
      expect(result.restoredCount, 0);
    });
  });

  group('purchase flow (future gateway)', () {
    test('successful Plus purchase grants the entitlement', () async {
      billing.gateway = _FakeGateway();
      expect(await billing.purchase('plus_lifetime'), BillingOutcome.success);
      await entitlements.initialize();
      expect(entitlements.hasPlus, isTrue);
    });

    test('successful royal purchase records ownership', () async {
      billing.gateway = _FakeGateway();
      await billing.purchase(royalProductId('princess'));
      await entitlements.initialize();
      expect(entitlements.ownsRoyal('princess'), isTrue);
    });

    test('cancelled purchase grants nothing', () async {
      billing.gateway =
          _FakeGateway(purchaseOutcome: BillingOutcome.cancelled);
      expect(await billing.purchase('plus_yearly'), BillingOutcome.cancelled);
      await entitlements.initialize();
      expect(entitlements.hasPlus, isFalse);
    });
  });

  group('restore purchases (the no-login reinstall story)', () {
    test('re-grants everything the store account owns', () async {
      billing.gateway = _FakeGateway(owned: [
        _p('plus_lifetime'),
        _p('royal_sovereign'),
        _p('royal_empress'),
      ]);

      final result = await billing.restorePurchases();
      expect(result.outcome, BillingOutcome.success);
      expect(result.restoredCount, 3);

      await entitlements.initialize();
      expect(entitlements.hasPlus, isTrue);
      expect(entitlements.purchasedRoyalIds, {'empress', 'sovereign'});
    });

    test('unknown products are skipped, known ones still land', () async {
      billing.gateway = _FakeGateway(owned: [
        _p('some_retired_sku'),
        _p('plus_monthly'),
      ]);

      final result = await billing.restorePurchases();
      expect(result.outcome, BillingOutcome.success);
      expect(result.restoredCount, 1);
      await entitlements.initialize();
      expect(entitlements.hasPlus, isTrue);
    });

    test('empty store account restores zero without failing', () async {
      billing.gateway = _FakeGateway();
      final result = await billing.restorePurchases();
      expect(result.outcome, BillingOutcome.success);
      expect(result.restoredCount, 0);
    });
  });

  group('purchased royals & the streak-pick economy', () {
    final gami = GamificationService();

    test('a bought royal is equippable but never consumes a streak pick',
        () async {
      billing.gateway = _FakeGateway();
      await billing.purchase(royalProductId('darkprince'));

      // Equippable: the union includes the purchase…
      expect(await gami.unlockedRoyalIds(), contains('darkprince'));
      // …but pick accounting only counts streak-picked royals.
      expect(await gami.streakPickedRoyalIds(), isEmpty);
    });

    test('loadProfile honours a worn PURCHASED royal', () async {
      billing.gateway = _FakeGateway();
      await billing.purchase(royalProductId('empress'));

      final empressSeed = kRoyalAvatars
          .firstWhere((r) => r.id == 'empress')
          .spriteIndex
          .toString();
      await gami.saveProfile(GamiProfile(
        username: 'T',
        avatarKind: 'pixel',
        avatarValue: empressSeed,
      ));

      final profile = await gami.loadProfile();
      expect(profile.avatarValue, empressSeed,
          reason: 'a paid royal must never be reset to a basic avatar');
    });

    test('loadProfile still re-locks a royal that was never earned', () async {
      final princeSeed = kRoyalAvatars
          .firstWhere((r) => r.id == 'prince')
          .spriteIndex
          .toString();
      await gami.saveProfile(GamiProfile(
        username: 'T',
        avatarKind: 'pixel',
        avatarValue: princeSeed,
      ));

      final profile = await gami.loadProfile();
      expect(profile.avatarValue, '0',
          reason: 'unearned royals are reset, exactly as before');
    });
  });
}
