import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../models/plus_products.dart';
import 'entitlement_service.dart';

/// How a purchase / restore attempt ended, in app terms.
enum BillingOutcome {
  /// Purchase completed and the entitlement was granted locally.
  success,

  /// Billing isn't wired yet (pre-approval stub) or Play isn't reachable.
  unavailable,

  /// The user backed out of the purchase flow.
  cancelled,

  /// Play accepted the order but payment is still settling (e.g. pending
  /// UPI). Grant nothing yet; a later queryPurchases pass picks it up.
  pending,

  /// Anything else went wrong. The user was charged nothing.
  error,
}

/// One owned purchase as reported by the store. Field names mirror Play
/// Billing's `Purchase` so the real gateway is a mechanical mapping.
class BillingPurchase {
  final String productId;

  /// Play's opaque receipt token. Needed later for acknowledge/consume.
  final String purchaseToken;

  /// When the purchase was made (ms since epoch). Anchors subscription
  /// windows on restore.
  final int purchaseTimeMs;

  const BillingPurchase({
    required this.productId,
    required this.purchaseToken,
    required this.purchaseTimeMs,
  });
}

/// How a purchase attempt ended, plus the purchase itself when there was one.
///
/// The purchase travels back with the outcome so [BillingService] can grant
/// from the REAL receipt — its token and its purchase time — instead of
/// re-deriving them. That matters for subscriptions: the window is anchored to
/// the purchase instant, so a buy and a later "Restore" of the same receipt
/// resolve to the same expiry instead of stacking two.
class BillingResult {
  final BillingOutcome outcome;

  /// Present only on [BillingOutcome.success].
  final BillingPurchase? purchase;

  const BillingResult(this.outcome, {this.purchase});
}

/// The seam where Google Play Billing plugs in.
///
/// [PlayBillingGateway] is the live implementation, installed from `main.dart`
/// via [BillingService.installGateway]. This file stays free of the
/// `in_app_purchase` import so the orchestration layer remains unit-testable;
/// [UnavailableBillingGateway] is still the default, so anything that never
/// installs a gateway (every test, and any non-Android platform) behaves as
/// before.
///
/// Play Billing talks to the on-device Play Store app over local IPC, so it
/// works even though Budgetify strips INTERNET from the release manifest — the
/// Play Store app is the network proxy. VERIFIED on the merged release
/// manifest: the billing integration adds exactly one permission,
/// `com.android.vending.BILLING`, and INTERNET stays absent.
/// STILL MUST-VERIFY on a device before trusting revenue to it: a real sandbox
/// purchase and a restore round-trip on an internal-track build with INTERNET
/// still stripped.
abstract class BillingGateway {
  /// Whether the store can take purchases right now.
  Future<bool> isAvailable();

  /// Everything the signed-in store account currently owns (non-consumed
  /// one-time products + active subscriptions). This is the restore
  /// primitive: Play keys purchases to the GOOGLE ACCOUNT, not the install,
  /// so a reinstall recovers ownership with no app-side login.
  Future<List<BillingPurchase>> queryPurchases();

  /// Launch the store purchase flow for [productId].
  ///
  /// [preferOffer] asks for the discounted offer rather than the everyday base
  /// plan. A Play subscription can return several entries for one product id —
  /// the base plan plus every offer the buyer is eligible for — and the entry
  /// handed to the billing flow decides what Play charges. The caller owns
  /// that decision because the calendar that governs it ([PlusOffer]) lives in
  /// this app, not in the Console.
  Future<BillingResult> launchPurchase(String productId,
      {bool preferOffer = false});

  /// Play's own price for each of [productIds], keyed by product id.
  ///
  /// Ids the store doesn't know are simply absent, so a caller must always be
  /// able to fall back. This is what stops the paywall advertising a number
  /// Play won't charge: the catalogue constants are a preview, this is truth.
  /// [preferOffer] must match what [launchPurchase] will be given, or the
  /// paywall would quote one entry's price and buy another's.
  Future<Map<String, StorePrice>> queryPrices(Iterable<String> productIds,
      {bool preferOffer = false});
}

/// One price as the store states it.
///
/// [formatted] is what to show — already localized, tax-inclusive and in the
/// buyer's currency, which no hardcoded ₹ string can be. [amount] is the same
/// price as a number, and exists for exactly one reason: deciding whether a
/// discount is real. A struck-through "was" price is a factual claim, and the
/// only way to keep it true under any Console configuration is to compare
/// what Play charges against what we say the everyday price is.
class StorePrice {
  final String formatted;
  final double amount;

  const StorePrice({required this.formatted, required this.amount});
}

/// The pre-approval gateway: reports the store as unavailable and owns
/// nothing. Keeping the whole purchase path executable against this stub
/// means the paywall UI, gates and restore flow are testable today and need
/// zero changes on billing day beyond swapping the gateway.
class UnavailableBillingGateway implements BillingGateway {
  const UnavailableBillingGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<BillingPurchase>> queryPurchases() async =>
      const <BillingPurchase>[];

  @override
  Future<BillingResult> launchPurchase(String productId,
          {bool preferOffer = false}) async =>
      const BillingResult(BillingOutcome.unavailable);

  @override
  Future<Map<String, StorePrice>> queryPrices(Iterable<String> productIds,
          {bool preferOffer = false}) async =>
      const <String, StorePrice>{};
}

/// What a "Restore purchases" pass found.
class RestoreResultSummary {
  final BillingOutcome outcome;

  /// How many owned products were (re-)granted locally.
  final int restoredCount;

  const RestoreResultSummary(this.outcome, this.restoredCount);
}

/// Orchestrates purchases: gateway in, entitlement grants out.
///
/// Deliberately stateless beyond the gateway — all ownership persistence
/// lives in [EntitlementService], so a purchase, a restore and a backup
/// import all converge on the same two grant calls.
class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  BillingGateway _gateway = const UnavailableBillingGateway();

  /// Swap point for the real Play gateway (and for tests).
  @visibleForTesting
  set gateway(BillingGateway g) => _gateway = g;

  StreamSubscription<BillingPurchase>? _outOfBandSub;

  /// Whether one of the app's own discount windows is running right now.
  ///
  /// This is the whole reason the Console offer can stay permanently active:
  /// its eligibility is "Developer determined", so Play never applies it
  /// unasked, and [PlusOffer] alone decides when a discount runs. Both the
  /// price shown and the price charged are driven from this one answer.
  ///
  /// Fails CLOSED — any doubt means the everyday price. Quoting the base price
  /// and charging it is merely unexciting; quoting a discount Play won't
  /// honour is a refund and a one-star review.
  @visibleForTesting
  bool get offerWindowOpen {
    try {
      return EntitlementService().activeOffer != null;
    } catch (e) {
      debugPrint('BillingService: offer window unreadable, using base price: $e');
      return false;
    }
  }

  /// Production wiring: install the live [gateway] and, if it reports
  /// purchases arriving outside a purchase flow, grant those too.
  ///
  /// That second half is what makes UPI work. An Indian user paying by UPI
  /// mandate gets `pending` while the bank settles — sometimes minutes later,
  /// often with the app already backgrounded — and the settled purchase then
  /// arrives with nothing awaiting it. Without this subscription their money
  /// is taken and the entitlement never lands until they happen to tap
  /// "Restore purchases". Grants are idempotent, so a purchase seen on both
  /// paths is harmless.
  ///
  /// Deliberately takes a plain [Stream] rather than the concrete gateway so
  /// this file never imports `in_app_purchase`; the platform plugin is
  /// constructed in `main.dart` and stays out of every unit test.
  Future<void> installGateway(
    BillingGateway gateway, {
    Stream<BillingPurchase>? outOfBandPurchases,
  }) async {
    _gateway = gateway;
    await _outOfBandSub?.cancel();
    _outOfBandSub = outOfBandPurchases?.listen(
      (p) async {
        try {
          await _grant(p.productId, purchaseTimeMs: p.purchaseTimeMs);
        } catch (e) {
          debugPrint('BillingService: out-of-band grant failed: $e');
        }
      },
      onError: (Object e) =>
          debugPrint('BillingService: out-of-band stream error: $e'),
    );
  }

  /// Whether the store can take purchases right now. The paywall uses this to
  /// show its "purchases open soon" state instead of a dead buy button.
  Future<bool> get storeAvailable async {
    try {
      return await _gateway.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Buy [productId] (a [PlusPlan] SKU or a `royal_*` product) and grant the
  /// entitlement locally on success.
  Future<BillingOutcome> purchase(String productId) async {
    try {
      final result = await _gateway.launchPurchase(productId,
          preferOffer: offerWindowOpen);
      if (result.outcome == BillingOutcome.success) {
        final p = result.purchase;
        await _grant(p?.productId ?? productId,
            purchaseTimeMs: p?.purchaseTimeMs);
      }
      return result.outcome;
    } catch (e) {
      debugPrint('BillingService.purchase($productId) failed: $e');
      return BillingOutcome.error;
    }
  }

  /// Play's own formatted prices for [productIds], or an empty map when the
  /// store can't answer. Never throws — the paywall falls back to the
  /// catalogue constants.
  Future<Map<String, StorePrice>> prices(Iterable<String> productIds) async {
    try {
      return await _gateway.queryPrices(productIds,
          preferOffer: offerWindowOpen);
    } catch (e) {
      debugPrint("BillingService.prices failed: $e");
      return const <String, StorePrice>{};
    }
  }

  /// Re-grant everything the store account owns. Safe to run any time —
  /// grants are idempotent and only ever ADD ownership. This is the whole
  /// "restore purchases" story for an app with no accounts: the Google
  /// account IS the account.
  ///
  /// The count reports how many owned products were RECOGNIZED, not how many
  /// changed anything — a second restore of the same account reports the same
  /// number, which is what the user means by "what do I own".
  Future<RestoreResultSummary> restorePurchases() async {
    try {
      if (!await _gateway.isAvailable()) {
        return const RestoreResultSummary(BillingOutcome.unavailable, 0);
      }
      final owned = await _gateway.queryPurchases();
      var granted = 0;
      for (final p in owned) {
        // Straight from `queryPurchases`: Play is asserting ownership as of
        // right now, which is the only signal that survives a renewal.
        if (await _grant(p.productId,
            purchaseTimeMs: p.purchaseTimeMs, confirmedActiveNow: true)) {
          granted++;
        }
      }
      return RestoreResultSummary(BillingOutcome.success, granted);
    } catch (e) {
      debugPrint('BillingService.restorePurchases failed: $e');
      return const RestoreResultSummary(BillingOutcome.error, 0);
    }
  }

  /// When the last silent refresh actually reached the store. Session-only:
  /// a cold start runs [refreshEntitlements] again regardless.
  DateTime? _lastRefresh;

  /// How often the resume-triggered refresh is allowed to hit the store.
  /// Frequent enough that a renewal is seen long before the sighting window
  /// lapses, rare enough that flicking in and out of the app isn't a storm of
  /// IPC calls.
  static const Duration refreshInterval = Duration(hours: 6);

  /// Silent counterpart to [restorePurchases], for app start and resume.
  ///
  /// This is what keeps a paying subscriber entitled. Play does not push
  /// renewals to the purchase stream — querying is the documented way to
  /// observe them — so without a call on this path the window set at purchase
  /// is the only one the app would ever have, and a monthly subscriber would
  /// go dark on day 34 while still being charged. It also collects a UPI
  /// payment that settled while the app was closed, which the out-of-band
  /// stream cannot see because that stream only exists while the process does.
  ///
  /// Never throws, never shows anything, and grants are add-only, so the worst
  /// case of a spurious call is a wasted IPC round trip.
  Future<void> refreshEntitlements({bool force = false}) async {
    final last = _lastRefresh;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < refreshInterval) {
      return;
    }
    try {
      if (!await _gateway.isAvailable()) return;
      final owned = await _gateway.queryPurchases();
      _lastRefresh = DateTime.now();
      for (final p in owned) {
        await _grant(p.productId,
            purchaseTimeMs: p.purchaseTimeMs, confirmedActiveNow: true);
      }
    } catch (e) {
      debugPrint('BillingService.refreshEntitlements failed: $e');
    }
  }

  @visibleForTesting
  void resetRefreshThrottleForTest() => _lastRefresh = null;

  /// Route one owned product to its entitlement. Returns whether the product
  /// was recognized. [confirmedActiveNow] is passed through from a live
  /// `queryPurchases` answer — see [EntitlementService.registerPlusPurchase].
  Future<bool> _grant(String productId,
      {int? purchaseTimeMs, bool confirmedActiveNow = false}) async {
    final svc = EntitlementService();
    await svc.initialize();
    if (PlusPlan.byProductId(productId) != null) {
      await svc.registerPlusPurchase(productId,
          purchaseTimeMs: purchaseTimeMs,
          confirmedActiveNow: confirmedActiveNow);
      return true;
    }
    final royalId = royalIdFromProduct(productId);
    if (royalId != null) {
      await svc.registerRoyalPurchase(royalId);
      return true;
    }
    debugPrint('BillingService: unknown product "$productId" ignored');
    return false;
  }
}
