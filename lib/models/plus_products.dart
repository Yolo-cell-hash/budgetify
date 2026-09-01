/// The Budgetify Plus product catalog — every purchasable thing in one place.
///
/// These ids and prices are the single source of truth the live Play Billing
/// integration mirrors: every product here MUST exist in the Play Console
/// under exactly this id, or `queryProductDetails` returns nothing and the
/// paywall reports the store closed. Prices shown here are only for the
/// paywall preview and tests — the charged price always comes from Play's
/// `ProductDetails` at purchase time (localized and tax-aware).
library;

/// The three ways to buy Plus. One entitlement ("plus"), three SKUs.
enum PlusPlan {
  /// Auto-renewing monthly subscription.
  monthly('plus_monthly', 49, 29),

  /// Auto-renewing yearly subscription.
  yearly('plus_yearly', 499, 299),

  /// One-time, non-consumable, forever. Lead offer for the anti-subscription
  /// audience — and the cleanest fit for an offline app, since a lifetime
  /// purchase never needs re-verification against Play.
  lifetime('plus_lifetime', 1499, 999);

  const PlusPlan(this.productId, this.priceInr, this.offerPriceInr);

  /// Play product id. Must match the Play Console exactly, forever —
  /// product ids are immutable once a purchase exists.
  final String productId;

  /// The everyday price in whole rupees — what a user pays on any ordinary
  /// day. The REAL charged price always comes from Play's `ProductDetails` at
  /// purchase time (localized, tax-aware); this constant is only for the
  /// pre-billing paywall preview and tests.
  final int priceInr;

  /// The discounted price during an active [PlusOffer] window. Must mirror the
  /// introductory/promotional offer configured on this product in the Play
  /// Console, or the paywall would advertise a discount Play doesn't honour.
  final int offerPriceInr;

  /// Price to display right now.
  int priceFor({required bool onOffer}) => onOffer ? offerPriceInr : priceInr;

  /// Whole-percent saving of the offer price against the base price, for the
  /// "SAVE x%" chip. Rounded for display only.
  int get offerSavingPercent =>
      (((priceInr - offerPriceInr) / priceInr) * 100).round();

  static PlusPlan? byProductId(String id) {
    for (final p in PlusPlan.values) {
      if (p.productId == id) return p;
    }
    return null;
  }
}

/// Grace window added on top of a subscription period so a lapsed renewal
/// (offline device, temporary card failure) never locks features the moment
/// the clock ticks over. Truth is re-established by `queryPurchases` whenever
/// billing is reachable.
const Duration kPlusSubscriptionGrace = Duration(days: 3);

/// How long a LIVE sighting of an owned subscription keeps access open.
///
/// Play returning a subscription from `queryPurchases` is itself proof that
/// the account owns it *right now* — so a sighting extends access from now,
/// independently of the purchase-anchored window. Without this a renewing
/// subscriber lapses the moment the first period elapses: the renewal keeps
/// the same purchase token, so the anchored window recomputes to the same
/// stale instant and the "only ever extend" guard discards it.
///
/// Seven days is the deliberate trade-off. A paying user who opens the app at
/// least weekly can never be locked out of something they are still being
/// charged for; a user who cancels keeps access at most seven days past the
/// period they already paid for. That asymmetry is the one this codebase
/// already chose everywhere else — fail open, never strand a payer.
const Duration kPlusLiveSightingWindow = Duration(days: 7);

/// Everyday price of a single royal avatar (one-time, non-consumable).
const int kRoyalAvatarPriceInr = 49;

/// Royal avatar price during an active [PlusOffer] window. Royals go on offer
/// alongside Plus itself, so a festive week discounts the whole catalogue.
const int kRoyalAvatarOfferPriceInr = 29;

/// Price of a royal avatar right now.
int royalAvatarPriceInr({required bool onOffer}) =>
    onOffer ? kRoyalAvatarOfferPriceInr : kRoyalAvatarPriceInr;

/// Play product id for a purchasable royal avatar. The royal [id] is the
/// stable `RoyalAvatar.id` ('sovereign', 'empress', ...) — persisted in
/// profiles, so it is already immutable, which makes it safe to bake into a
/// product id.
String royalProductId(String royalId) => 'royal_$royalId';

/// The royal id encoded in a `royal_*` product id, or null for other products.
String? royalIdFromProduct(String productId) =>
    productId.startsWith('royal_') ? productId.substring(6) : null;

/// Features that lock behind Plus once the free window (3 months from first
/// launch) has elapsed. Everything NOT listed here stays free forever — most
/// notably the overall monthly budget and its alerts, SMS transaction
/// detection itself, manual tagging of a single transaction, applying a tag to
/// all existing transactions for a merchant, and tagging transactions into tax
/// buckets (only the tax EXPORT locks).
enum PlusFeature {
  /// Per-category budgets: creating new ones and their threshold alerts.
  /// Existing budget DATA is never deleted on lock — it just goes quiet.
  categoryBudgets,

  /// "₹X debited / ₹Y credited" transaction alerts.
  spendingNotifications,

  /// Bill reminders for recurring payments (noon prompt + 8 PM follow-up).
  recurringNotifications,

  /// "Investment Alert" prompts for SIP/RD instalments.
  investmentReminders,

  /// Tagging: "Apply to All" (future + existing for a merchant). "Apply to All
  /// Existing" and "Only this one" both stay free.
  tagApplyToAll,

  /// AI Prediction Mode: the Insights card on Home and the forecasts feeding
  /// it. Gated at BOTH ends — turning the setting on opens the paywall, and
  /// an already-on setting simply goes quiet once locked. The stored
  /// preference is never flipped, so buying Plus brings the card straight
  /// back with no re-toggling, mirroring how category budget DATA survives.
  aiPredictionMode,

  /// Exporting the tax-deduction summary for a financial year (Excel/CSV).
  /// Tagging transactions into tax buckets and reading the on-screen summary
  /// stay free, so a lapsed user's data is never trapped behind the wall.
  taxDeductionsExport,
}
