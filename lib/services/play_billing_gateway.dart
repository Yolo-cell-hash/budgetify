import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../models/plus_products.dart';

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
/// One entry as Play described it, reduced to just what picking needs.
///
/// Deliberately plugin-free so [selectEntry] can be unit-tested without a
/// platform channel: the messy extraction lives in [_describe], the decision
/// lives here in the open.
class OfferCandidate {
  /// Null for a base plan. Non-null for an offer.
  final String? offerId;
  final List<String> tags;

  /// First pricing phase — the discounted one when this is an offer.
  final double price;

  const OfferCandidate({
    required this.offerId,
    required this.tags,
    required this.price,
  });
}

/// Which of [candidates] to buy (and to quote), or null if there is nothing.
///
/// A Play subscription returns ONE entry per base plan or eligible offer, all
/// under the same product id, and Play does not order them by price or by
/// anything else useful. Taking `.first` — which this gateway used to do — is
/// therefore a coin toss between the everyday price and a discount, and the
/// paywall would quote one while Play charged the other.
///
///   * In a discount window, take the cheapest entry tagged [kPlusOfferTag].
///     Cheapest is only a tiebreak; the tag is what identifies OUR offer, so
///     an unrelated one Play happens to return can never be picked by accident.
///   * Otherwise take the base plan — the entry with no offer id — so a
///     permanently-active Console offer is simply not used out of season.
///   * A one-time product has a single, offer-less entry and falls through to
///     the base-plan branch unchanged.
///
/// Fails CLOSED: with no base plan and no eligible offer it returns the
/// dearest entry rather than the cheapest, so an unreadable catalogue can
/// never quietly undercharge.
@visibleForTesting
int? selectEntry(List<OfferCandidate> candidates, {required bool preferOffer}) {
  if (candidates.isEmpty) return null;

  if (preferOffer) {
    int? best;
    for (var i = 0; i < candidates.length; i++) {
      if (!candidates[i].tags.contains(kPlusOfferTag)) continue;
      if (best == null || candidates[i].price < candidates[best].price) best = i;
    }
    if (best != null) return best;
    // Window open but the Console has no matching offer live. Fall through to
    // the base plan: the paywall's own guard already refuses to draw a
    // strikethrough unless Play confirms a real reduction.
  }

  for (var i = 0; i < candidates.length; i++) {
    if (candidates[i].offerId == null) return i;
  }

  var dearest = 0;
  for (var i = 1; i < candidates.length; i++) {
    if (candidates[i].price > candidates[dearest].price) dearest = i;
  }
  return dearest;
}

class PlayBillingGateway implements BillingGateway {
  PlayBillingGateway({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Completers for purchases an active [launchPurchase] is awaiting, keyed by
  /// product id. At most one flow per product is in flight at a time.
  final Map<String, Completer<BillingResult>> _awaiting = {};

  /// The raw Play receipt for everything currently owned, keyed by product id.
  ///
  /// A subscription swap has to hand Play the OLD purchase, and it wants the
  /// plugin's own [GooglePlayPurchaseDetails] -- our [BillingPurchase] carries
  /// too little. Filled from every purchased/restored update, including the
  /// restore pass [queryPurchases] runs.
  final Map<String, GooglePlayPurchaseDetails> _owned = {};

  /// Collector used only while [queryPurchases] is running.
  List<BillingPurchase>? _restoreBucket;

  /// Completed once the restore stream has gone quiet, so a collection ends as
  /// soon as the account has finished answering instead of always waiting out
  /// the cap.
  Completer<void>? _restoreSettled;
  Timer? _restoreQuietTimer;

  /// Quiet period after the last restored purchase before a collection is
  /// considered complete.
  static const Duration _restoreQuiet = Duration(milliseconds: 800);

  /// Hard ceiling on one collection — what an account owning nothing costs,
  /// and the backstop if the store never answers at all.
  static const Duration _restoreCap = Duration(seconds: 6);

  /// The collection currently running, if any. Collection state
  /// ([_restoreBucket] and friends) is single-instance, so two overlapping
  /// callers would clobber each other — the first to finish nulls the bucket
  /// out from under the second, which then returns a truncated answer and
  /// under-grants. That is reachable now that a silent refresh runs at app
  /// start while the Restore button is still tappable, so a second caller
  /// joins the first instead of starting its own.
  Future<List<BillingPurchase>>? _inFlightQuery;

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
    final running = _inFlightQuery;
    if (running != null) return running;
    final query = _collectPurchases();
    _inFlightQuery = query;
    try {
      return await query;
    } finally {
      _inFlightQuery = null;
    }
  }

  Future<List<BillingPurchase>> _collectPurchases() async {
    if (!await isAvailable()) return const <BillingPurchase>[];
    start();
    // `restorePurchases()` has no completion signal — it re-emits what the
    // account owns onto the shared stream, sometimes across more than one
    // event. So collect until the stream goes quiet rather than guess at an
    // end: settle [_restoreQuiet] after the last arrival, and give up after
    // [_restoreCap] if nothing ever comes. A fixed wait had to be long enough
    // for the slowest cold Play Store, which meant every owner — and every
    // silent refresh — paid that worst case, and an account that answered a
    // beat late still came back empty and told its owner they own nothing.
    final bucket = <BillingPurchase>[];
    _restoreBucket = bucket;
    _restoreSettled = Completer<void>();
    try {
      await _iap.restorePurchases();
      await _restoreSettled!.future.timeout(_restoreCap, onTimeout: () {});
    } catch (e) {
      debugPrint('PlayBillingGateway.queryPurchases failed: $e');
    } finally {
      _restoreBucket = null;
      _restoreQuietTimer?.cancel();
      _restoreQuietTimer = null;
      _restoreSettled = null;
    }
    // De-duplicate: an account can report the same product across events, and
    // granting twice must never be able to stack a subscription window.
    final seen = <String>{};
    return bucket.where((p) => seen.add(p.purchaseToken)).toList();
  }

  @override
  Future<Map<String, StorePrice>> queryPrices(Iterable<String> productIds,
      {bool preferOffer = false}) async {
    final ids = productIds.toSet();
    if (ids.isEmpty || !await isAvailable()) return const <String, StorePrice>{};
    final ProductDetailsResponse response;
    try {
      response = await _iap.queryProductDetails(ids);
    } catch (e) {
      debugPrint('PlayBillingGateway.queryPrices threw: $e');
      return const <String, StorePrice>{};
    }
    if (response.error != null) {
      debugPrint('PlayBillingGateway.queryPrices: ${response.error}');
      return const <String, StorePrice>{};
    }
    // `price` is already formatted, localized and tax-inclusive — exactly the
    // string Play will show on its own sheet, which is the point: the two can
    // no longer disagree.
    //
    // A subscription repeats its id once per base plan and per eligible offer,
    // so group first and then apply the SAME choice [launchPurchase] will make.
    // Quoting and charging therefore agree by construction rather than by
    // coincidence.
    final grouped = <String, List<ProductDetails>>{};
    for (final p in response.productDetails) {
      (grouped[p.id] ??= <ProductDetails>[]).add(p);
    }
    final out = <String, StorePrice>{};
    for (final entry in grouped.entries) {
      final pick = _choose(entry.value, preferOffer);
      if (pick != null) {
        out[entry.key] =
            StorePrice(formatted: pick.price, amount: pick.rawPrice);
      }
    }
    for (final missing in ids.difference(out.keys.toSet())) {
      debugPrint('PlayBillingGateway.queryPrices: "$missing" is not a live '
          'Play product - the paywall will fall back to its constant');
    }
    return out;
  }

  @override
  Future<BillingResult> launchPurchase(String productId,
      {bool preferOffer = false, String? replaces}) async {
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

    final chosen = _choose(response.productDetails, preferOffer);
    if (chosen == null) return const BillingResult(BillingOutcome.error);

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
      // Hand back the token of the entry we actually chose. The platform
      // would fall back to reading it off productDetails anyway, but saying it
      // out loud is the point of this change: the offer is applied because the
      // calendar asked for it, never because it happened to sort first.
      launched = await _iap.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: chosen,
          offerToken:
              chosen is GooglePlayProductDetails ? chosen.offerToken : null,
          changeSubscriptionParam: await _swapFrom(replaces),
        ),
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

  /// Reduce one Play entry to the fields [selectEntry] needs.
  ///
  /// For subscriptions the offer metadata hangs off the wrapper at
  /// [GooglePlayProductDetails.subscriptionIndex]; a one-time product has none,
  /// which correctly reads as a base plan.
  OfferCandidate _describe(ProductDetails pd) {
    if (pd is GooglePlayProductDetails) {
      final idx = pd.subscriptionIndex;
      final all = pd.productDetails.subscriptionOfferDetails;
      if (idx != null && all != null && idx < all.length) {
        final d = all[idx];
        return OfferCandidate(
          offerId: d.offerId,
          tags: d.offerTags,
          price: pd.rawPrice,
        );
      }
    }
    return OfferCandidate(offerId: null, tags: const [], price: pd.rawPrice);
  }

  /// The entry to buy/quote for one product, applying [selectEntry].
  ProductDetails? _choose(List<ProductDetails> entries, bool preferOffer) {
    final i = selectEntry(
      entries.map(_describe).toList(growable: false),
      preferOffer: preferOffer,
    );
    return i == null ? null : entries[i];
  }

  /// Describe the subscription [replaces] is on, so Play REPLACES it rather
  /// than selling a second one alongside it.
  ///
  /// plus_monthly and plus_yearly are separate Play products, not two base
  /// plans of one subscription, so without this a monthly subscriber who
  /// "upgrades" simply ends up paying for both. withTimeProration switches
  /// them over immediately and credits the time they already paid for -- the
  /// only fair mode when the billing periods differ.
  ///
  /// Null when there is nothing to replace, so an ordinary first purchase
  /// falls through unchanged.
  Future<ChangeSubscriptionParam?> _swapFrom(String? replaces) async {
    if (replaces == null) return null;
    var old = _owned[replaces];
    if (old == null) {
      // Cold start: nothing has come down the stream yet. A restore pass
      // re-emits everything the account owns, which fills the cache.
      await queryPurchases();
      old = _owned[replaces];
    }
    if (old == null) {
      // Play does not think they own it, so there is nothing to replace and
      // selling the new plan outright is the correct outcome.
      debugPrint('PlayBillingGateway: asked to replace "$replaces" but Play '
          'reports no such purchase; buying outright instead');
      return null;
    }
    return ChangeSubscriptionParam(
      oldPurchaseDetails: old,
      replacementMode: ReplacementMode.withTimeProration,
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

      // A verdict with NO product attached. The plugin synthesises one of
      // these whenever Play answers with an empty purchase list -- the user
      // backing out, ITEM_ALREADY_OWNED, most billing errors -- and it carries
      // `productID: ''`. Keyed by product it would match no waiter at all, so
      // the purchase future would hang until its five-minute timeout: a buy
      // button spinning long after the buyer simply changed their mind. Route
      // it to whatever flow is actually in flight instead.
      if (d.productID.isEmpty) {
        _resolveAllAwaiting(switch (d.status) {
          PurchaseStatus.canceled => BillingOutcome.cancelled,
          PurchaseStatus.pending => BillingOutcome.pending,
          _ => BillingOutcome.error,
        }, d);
        continue;
      }

      final waiting = _awaiting[d.productID];
      switch (d.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final purchase = _toBillingPurchase(d);
          if (d is GooglePlayPurchaseDetails) _owned[d.productID] = d;
          final bucket = _restoreBucket;
          if (bucket != null) {
            bucket.add(purchase);
            // Restart the quiet countdown: an account answering across several
            // events keeps the collection open until it really has finished.
            _restoreQuietTimer?.cancel();
            _restoreQuietTimer = Timer(_restoreQuiet, () {
              final settled = _restoreSettled;
              if (settled != null && !settled.isCompleted) settled.complete();
            });
          }
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

  /// Hand [outcome] to every in-flight purchase. Used only for verdicts Play
  /// reports without naming a product; there is at most one flow open per
  /// product and, in practice, only one open at all.
  void _resolveAllAwaiting(BillingOutcome outcome, PurchaseDetails d) {
    if (_awaiting.isEmpty) return;
    debugPrint('PlayBillingGateway: product-less ${d.status} '
        '(${d.error?.message ?? 'no message'}) -> resolving '
        '${_awaiting.length} in-flight purchase(s) as $outcome');
    for (final completer in List.of(_awaiting.values)) {
      if (!completer.isCompleted) completer.complete(BillingResult(outcome));
    }
    _awaiting.clear();
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
