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

/// The seam where Google Play Billing plugs in.
///
/// The app ships with [UnavailableBillingGateway] until the bank/Play
/// approvals land. The real implementation (`PlayBillingGateway`, backed by
/// the `in_app_purchase` plugin) drops in behind this interface WITHOUT
/// touching any caller: Play Billing talks to the on-device Play Store app
/// over local IPC, so it works even though Budgetify strips INTERNET from the
/// release manifest — the Play Store app is the network proxy.
/// MUST-VERIFY before relying on that: a real sandbox purchase + a
/// queryPurchases round-trip on an internal-track build with INTERNET still
/// stripped.
abstract class BillingGateway {
  /// Whether the store can take purchases right now.
  Future<bool> isAvailable();

  /// Everything the signed-in store account currently owns (non-consumed
  /// one-time products + active subscriptions). This is the restore
  /// primitive: Play keys purchases to the GOOGLE ACCOUNT, not the install,
  /// so a reinstall recovers ownership with no app-side login.
  Future<List<BillingPurchase>> queryPurchases();

  /// Launch the store purchase flow for [productId].
  Future<BillingOutcome> launchPurchase(String productId);
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
  Future<BillingOutcome> launchPurchase(String productId) async =>
      BillingOutcome.unavailable;
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
      final outcome = await _gateway.launchPurchase(productId);
      if (outcome == BillingOutcome.success) {
        await _grant(productId);
      }
      return outcome;
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
