import 'dart:async';

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
  final Map<String, StorePrice> priceList;

  /// How many times the store was asked what the account owns — the whole
  /// point of the refresh throttle.
  int queryCount = 0;

  _FakeGateway({
    this.available = true,
    this.owned = const [],
    this.purchaseOutcome = BillingOutcome.success,
    this.priceList = const <String, StorePrice>{},
  });

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<BillingPurchase>> queryPurchases() async {
    queryCount++;
    return owned;
  }

  /// What the service last asked for, so a test can assert the CALENDAR is
  /// what drives offer selection rather than the gateway guessing.
  bool? lastPreferOffer;

  /// The subscription the service asked Play to replace, if any.
  String? lastReplaces;

  @override
  Future<BillingResult> launchPurchase(String productId,
      {bool preferOffer = false, String? replaces}) async {
    lastPreferOffer = preferOffer;
    lastReplaces = replaces;
    return purchaseOutcome == BillingOutcome.success
        // A real store hands back the receipt with the verdict; the fake
        // must too, or the grant path never sees a purchase time.
        ? BillingResult(purchaseOutcome, purchase: _p(productId))
        : BillingResult(purchaseOutcome);
  }

  @override
  Future<Map<String, StorePrice>> queryPrices(Iterable<String> productIds,
      {bool preferOffer = false}) async {
    lastPreferOffer = preferOffer;
    return priceList;
  }
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
    billing.resetRefreshThrottleForTest();
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

  group('grants are replay-safe (what real billing will actually do)', () {
    Future<int?> plusUntil() async =>
        (await SharedPreferences.getInstance()).getInt('entitlement_plus_until');

    test('replaying one subscription receipt does not stack the window',
        () async {
      await entitlements.initialize();
      final boughtAt = DateTime.now().millisecondsSinceEpoch;

      await entitlements.registerPlusPurchase('plus_monthly',
          purchaseTimeMs: boughtAt);
      final afterBuy = await plusUntil();

      // Exactly what "buy, then tap Restore" does: the same receipt, twice.
      await entitlements.registerPlusPurchase('plus_monthly',
          purchaseTimeMs: boughtAt);
      expect(await plusUntil(), afterBuy,
          reason: 'a replayed receipt must resolve to the same expiry, '
              'not hand out a second month');
    });

    test('a genuine later renewal still moves the window forward', () async {
      await entitlements.initialize();
      final first = DateTime.now().millisecondsSinceEpoch;
      await entitlements.registerPlusPurchase('plus_monthly',
          purchaseTimeMs: first);
      final afterFirst = await plusUntil();

      // Play delivers a renewal as a NEW purchase with its own later time.
      await entitlements.registerPlusPurchase('plus_monthly',
          purchaseTimeMs: first + const Duration(days: 30).inMilliseconds);
      expect(await plusUntil(), greaterThan(afterFirst!));
    });

    test('a purchase settling out of band is granted without a restore',
        () async {
      // The UPI story: money leaves, `pending` comes back, and the real
      // purchase lands later with nothing awaiting it.
      final settled = StreamController<BillingPurchase>();
      addTearDown(settled.close);
      await billing.installGateway(_FakeGateway(),
          outOfBandPurchases: settled.stream);

      settled.add(_p('plus_lifetime'));
      await Future<void>.delayed(Duration.zero);

      await entitlements.initialize();
      expect(entitlements.hasPlus, isTrue,
          reason: 'a settled UPI purchase must land on its own — the user '
              'should never have to discover "Restore purchases"');
    });
  });

  group('a renewing subscriber never goes dark', () {
    /// A monthly receipt older than one period + grace: the state a real
    /// subscriber is in on day 40, having been charged twice.
    BillingPurchase agedMonthly() => BillingPurchase(
          productId: 'plus_monthly',
          purchaseToken: 'tok_plus_monthly',
          purchaseTimeMs: DateTime.now()
              .subtract(const Duration(days: 40))
              .millisecondsSinceEpoch,
        );

    test('an aged receipt on its own leaves the window expired', () async {
      await entitlements.initialize();
      await entitlements.registerPlusPurchase('plus_monthly',
          purchaseTimeMs: agedMonthly().purchaseTimeMs);
      expect(entitlements.hasPlus, isFalse,
          reason: 'the purchase-anchored window really has elapsed — this is '
              'the state the live sighting has to rescue');
    });

    test('Play still reporting the subscription keeps access open', () async {
      // Play keeps the SAME purchase token across renewals, so the receipt
      // this returns carries the ORIGINAL purchase time even though the user
      // has renewed. Before the live-sighting rule this recomputed the same
      // expired instant and the "only ever extend" guard discarded it,
      // locking out someone who was still being charged.
      billing.gateway = _FakeGateway(owned: [agedMonthly()]);

      await billing.refreshEntitlements();

      await entitlements.initialize();
      expect(entitlements.hasPlus, isTrue,
          reason: 'presence in queryPurchases IS proof of ownership now');
    });

    test('the same aged receipt replayed WITHOUT the store grants nothing',
        () async {
      // A backup import or a re-read of a stored receipt proves nothing about
      // the present, so it must not be able to resurrect a lapsed window.
      await entitlements.initialize();
      await entitlements.registerPlusPurchase('plus_monthly',
          purchaseTimeMs: agedMonthly().purchaseTimeMs,
          confirmedActiveNow: false);
      expect(entitlements.hasPlus, isFalse);
    });

    test('a live sighting still cannot stack a second window', () async {
      billing.gateway = _FakeGateway(owned: [_p('plus_monthly')]);
      await billing.refreshEntitlements();
      await entitlements.initialize();
      final first = (await SharedPreferences.getInstance())
          .getInt('entitlement_plus_until');

      await billing.refreshEntitlements(force: true);
      expect(
          (await SharedPreferences.getInstance())
              .getInt('entitlement_plus_until'),
          first,
          reason: 'a fresh purchase already reaches further than the sighting '
              'window, so repeated sightings must change nothing');
    });

    test('refresh is throttled, and force overrides it', () async {
      final gw = _FakeGateway(owned: [_p('plus_lifetime')]);
      billing.gateway = gw;

      await billing.refreshEntitlements();
      await billing.refreshEntitlements();
      expect(gw.queryCount, 1, reason: 'resume must not storm the store');

      await billing.refreshEntitlements(force: true);
      expect(gw.queryCount, 2);
    });

    test('a closed store leaves entitlements untouched', () async {
      billing.gateway = _FakeGateway(available: false, owned: [_p('plus_yearly')]);
      await billing.refreshEntitlements();
      await entitlements.initialize();
      expect(entitlements.hasPlus, isFalse);
    });
  });

  group('the paywall prices what Play will actually charge', () {
    test('live prices come back keyed by product id', () async {
      billing.gateway = _FakeGateway(priceList: const {
        'plus_lifetime': StorePrice(formatted: '₹1,499.00', amount: 1499),
        'plus_monthly': StorePrice(formatted: '₹49.00', amount: 49),
      });
      final prices =
          await billing.prices(PlusPlan.values.map((p) => p.productId));
      expect(prices['plus_lifetime']?.formatted, '₹1,499.00');
      expect(prices['plus_lifetime']?.amount, 1499);
      expect(prices['plus_monthly']?.formatted, '₹49.00');
      expect(prices.containsKey('plus_yearly'), isFalse,
          reason: 'an id the store does not know must be absent, not guessed, '
              'so the caller falls back to its constant');
    });

    test('the shipped stub prices nothing and never throws', () async {
      expect(await billing.prices(const ['plus_lifetime']), isEmpty);
    });
  });

  group('the calendar decides the price, not the store', () {
    /// Push first-launch back far enough that the free window has just closed,
    /// which opens the seven-day welcome offer. Deterministic in a way a
    /// festive window is not -- a suite run during Diwali must not see
    /// different prices than one run in July.
    Future<void> seedJustLapsedTrial() async {
      // Make the 15 Aug 2026 restart clamp inert; otherwise every seeded
      // anchor is dragged forward to it and no trial can ever have lapsed.
      EntitlementService.debugTrialRestartAt = DateTime.utc(2020, 1, 1);
      final prefs = await SharedPreferences.getInstance();
      final ended = DateTime.now()
          .subtract(EntitlementService.trialDuration)
          .subtract(const Duration(days: 1));
      await prefs.setInt(
          'entitlement_first_launch_at', ended.millisecondsSinceEpoch);
      await prefs.setInt(
          'entitlement_last_seen_at', DateTime.now().millisecondsSinceEpoch);
      entitlements.resetForTest();
      await entitlements.initialize();
    }

    test('a live window asks the store for the offer', () async {
      await seedJustLapsedTrial();
      expect(entitlements.activeOffer, isNotNull,
          reason: 'welcome week should be running');

      final gw = _FakeGateway();
      billing.gateway = gw;
      await billing.purchase('plus_monthly');

      expect(gw.lastPreferOffer, isTrue,
          reason: 'the ₹29 offer is only ever applied because OUR calendar '
              'asked for it - Play never applies it unasked');
    });

    test('what is quoted is what will be bought', () async {
      // The paywall must not price one entry and purchase another, so both
      // calls have to be handed the same answer.
      await seedJustLapsedTrial();
      final gw = _FakeGateway();
      billing.gateway = gw;

      await billing.prices(const ['plus_monthly']);
      final quoted = gw.lastPreferOffer;
      await billing.purchase('plus_monthly');

      expect(gw.lastPreferOffer, quoted);
    });

    test('the flag always mirrors the offer window', () async {
      // Whatever today happens to be, the two must never disagree.
      EntitlementService.debugTrialRestartAt = DateTime.utc(2020, 1, 1);
      await entitlements.initialize();
      final gw = _FakeGateway();
      billing.gateway = gw;
      await billing.purchase('plus_lifetime');

      expect(gw.lastPreferOffer, billing.offerWindowOpen);
      expect(billing.offerWindowOpen, entitlements.activeOffer != null);
    });
  });

}
