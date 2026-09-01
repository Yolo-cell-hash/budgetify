import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_service.dart';

/// The real Google Play gateway, sitting behind [BillingGateway].
///
/// Kept in its OWN file on purpose: `billing_service.dart` must stay free of
/// the `in_app_purchase` import so the orchestration layer — and every test
/// that touches it — never drags a platform plugin into a unit test.
///
/// ## Why this works with INTERNET stripped
///
/// Budgetify's release manifest removes `android.permission.INTERNET`. Play
/// Billing still works because the plugin talks to the on-device Play Store
/// app over local IPC, and the Play Store — not Budgetify — makes the network
/// call. MUST-VERIFY on an internal-track build before trusting it in
/// production: a real sandbox purchase plus a restore round-trip with INTERNET
/// still removed.
///
/// ## Why this is stream-shaped
///
/// `in_app_purchase` is not request/response. `buyNonConsumable` reports only
/// whether the *flow launched*; the verdict arrives later on
/// [InAppPurchase.purchaseStream] — possibly minutes later (UPI mandates in
/// India routinely land as `pending` and settle afterwards), possibly with the
/// app backgrounded, and possibly for a purchase this session never started.
/// So one long-lived subscription owns every update and routes it two ways:
///
///   * a purchase that an in-flight [launchPurchase] is waiting on completes
///     that call's future, and
///   * anything else — a settled UPI payment, a purchase made on another
///     device, one recovered at startup — is published on [outOfBandPurchases]
///     for [BillingService] to grant.
///
/// ## Acknowledgement is not optional
///
/// Play REFUNDS any purchase left unacknowledged for three days.
/// `completePurchase` is the plugin's acknowledge, so it runs for every
/// delivered purchase that still wants it, on both paths, before anything else
/// that could throw.
class PlayBillingGateway implements BillingGateway {
  PlayBillingGateway({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Completers for purchases an active [launchPurchase] is awaiting, keyed by
  /// product id. At most one flow per product is in flight at a time.
  final Map<String, Completer<BillingResult>> _awaiting = {};

  /// Collector used only while [queryPurchases] is running.
  List<BillingPurchase>? _restoreBucket;

  final StreamController<BillingPurchase> _outOfBand =
      StreamController<BillingPurchase>.broadcast();

  /// Purchases that arrived with no in-flight [launchPurchase] waiting for
  /// them. [BillingService] grants these; grants are idempotent.
  Stream<BillingPurchase> get outOfBandPurchases => _outOfBand.stream;

  /// Begin listening. Safe to call more than once.
  void start() {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('PlayBillingGateway stream error: $e'),
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _outOfBand.close();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (e) {
      debugPrint('PlayBillingGateway.isAvailable failed: $e');
      return false;
    }
  }

  @override
  Future<List<BillingPurchase>> queryPurchases() async {
    if (!await isAvailable()) return const <BillingPurchase>[];
    start();
    // `restorePurchases()` has no completion signal — it re-emits what the
    // account owns onto the shared stream, sometimes across more than one
    // event. So collect for a short fixed window rather than guess at an end.
    // This only runs behind the explicit "Restore purchases" button.
    final bucket = <BillingPurchase>[];
    _restoreBucket = bucket;
    try {
      await _iap.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('PlayBillingGateway.queryPurchases failed: $e');
    } finally {
      _restoreBucket = null;
    }
    // De-duplicate: an account can report the same product across events, and
    // granting twice must never be able to stack a subscription window.
    final seen = <String>{};
    return bucket.where((p) => seen.add(p.purchaseToken)).toList();
  }

  @override
  Future<BillingResult> launchPurchase(String productId) async {
    if (!await isAvailable()) {
      return const BillingResult(BillingOutcome.unavailable);
    }
    start();

    final ProductDetailsResponse response;
    try {
      response = await _iap.queryProductDetails({productId});
    } catch (e) {
      debugPrint('queryProductDetails($productId) threw: $e');
      return const BillingResult(BillingOutcome.error);
    }
    if (response.error != null) {
      debugPrint('queryProductDetails($productId): ${response.error}');
      return const BillingResult(BillingOutcome.error);
    }
    if (response.productDetails.isEmpty) {
      // The id isn't live in the Play Console — not created, or not yet
      // propagated. Loud in logs because it is a release-blocking config bug,
      // not something the user did.
      debugPrint('PlayBillingGateway: "$productId" is not a live Play product '
          '- check the Play Console id matches PlusPlan exactly');
      return const BillingResult(BillingOutcome.unavailable);
    }

    // One flow per product; a second tap joins the first rather than opening
    // a second store sheet.
    final existing = _awaiting[productId];
    if (existing != null) return existing.future;

    final completer = Completer<BillingResult>();
    _awaiting[productId] = completer;

    bool launched;
    try {
      // Subscriptions go through buyNonConsumable too — "consumable" here
      // means a product meant to be bought repeatedly, which none of ours are.
      launched = await _iap.buyNonConsumable(
        purchaseParam:
            PurchaseParam(productDetails: response.productDetails.first),
      );
    } catch (e) {
      debugPrint('buyNonConsumable($productId) threw: $e');
      launched = false;
    }
    if (!launched) {
      _awaiting.remove(productId);
      return const BillingResult(BillingOutcome.error);
    }

    // The store UI owns the screen now. Nearly every path resolves promptly —
    // even a UPI mandate emits `pending` straight away — so this timeout is a
    // backstop against a verdict that never arrives, not a normal outcome. It
    // reports `pending`, not `error`, because the purchase may still be alive;
    // if it lands later it arrives out-of-band and is granted then.
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _awaiting.remove(productId);
        return const BillingResult(BillingOutcome.pending);
      },
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> updates) async {
    for (final d in updates) {
      // Acknowledge FIRST. Play auto-refunds anything unacknowledged after
      // three days, so this must not sit behind logic that can throw.
      if (d.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(d);
        } catch (e) {
          debugPrint('completePurchase(${d.productID}) failed: $e');
        }
      }

      final waiting = _awaiting[d.productID];
      switch (d.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final purchase = _toBillingPurchase(d);
          _restoreBucket?.add(purchase);
          if (waiting != null) {
            _awaiting.remove(d.productID);
            waiting.complete(
                BillingResult(BillingOutcome.success, purchase: purchase));
          } else if (!_outOfBand.isClosed) {
            _outOfBand.add(purchase);
          }
        case PurchaseStatus.pending:
          // Money not taken yet. Grant nothing — the settled purchase arrives
          // as its own later event.
          if (waiting != null) {
            _awaiting.remove(d.productID);
            waiting.complete(const BillingResult(BillingOutcome.pending));
          }
        case PurchaseStatus.canceled:
          if (waiting != null) {
            _awaiting.remove(d.productID);
            waiting.complete(const BillingResult(BillingOutcome.cancelled));
          }
        case PurchaseStatus.error:
          debugPrint('purchase error for ${d.productID}: ${d.error}');
          if (waiting != null) {
            _awaiting.remove(d.productID);
            waiting.complete(const BillingResult(BillingOutcome.error));
          }
      }
    }
  }

  BillingPurchase _toBillingPurchase(PurchaseDetails d) => BillingPurchase(
        productId: d.productID,
        // On Android serverVerificationData IS the Play purchase token.
        purchaseToken: d.verificationData.serverVerificationData,
        // Android reports ms-since-epoch as a string; a restored purchase can
        // omit it, in which case the window has to anchor at now.
        purchaseTimeMs: int.tryParse(d.transactionDate ?? '') ??
            DateTime.now().millisecondsSinceEpoch,
      );
}
