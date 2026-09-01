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
  Future<BillingResult> launchPurchase(String productId);
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
  Future<BillingResult> launchPurchase(String productId) async =>
      const BillingResult(BillingOutcome.unavailable);
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
      final result = await _gateway.launchPurchase(productId);
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

  /// Re-grant everything the store account owns. Safe to run any time —
  /// grants are idempotent and only ever ADD ownership. This is the whole
  /// "restore purchases" story for an app with no accounts: the Google
  /// account IS the account.
  Future<RestoreResultSummary> restorePurchases() async {
    try {
      if (!await _gateway.isAvailable()) {
        return const RestoreResultSummary(BillingOutcome.unavailable, 0);
      }
      final owned = await _gateway.queryPurchases();
      var granted = 0;
      for (final p in owned) {
        if (await _grant(p.productId, purchaseTimeMs: p.purchaseTimeMs)) {
          granted++;
        }
      }
      return RestoreResultSummary(BillingOutcome.success, granted);
    } catch (e) {
      debugPrint('BillingService.restorePurchases failed: $e');
      return const RestoreResultSummary(BillingOutcome.error, 0);
    }
  }

  /// Route one owned product to its entitlement. Returns whether the product
  /// was recognized.
  Future<bool> _grant(String productId, {int? purchaseTimeMs}) async {
    final svc = EntitlementService();
    await svc.initialize();
    if (PlusPlan.byProductId(productId) != null) {
      await svc.registerPlusPurchase(productId, purchaseTimeMs: purchaseTimeMs);
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
