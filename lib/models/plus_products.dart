/// The Budgetify Plus product catalog — every purchasable thing in one place.
///
/// PREPARATION ONLY: nothing here talks to Google Play. These ids and prices
/// are the single source of truth the eventual Play Billing integration will
/// mirror (the products created in the Play Console MUST use these exact ids).
/// Until billing is approved and wired, the catalog only feeds the dormant
/// gate/paywall code paths.
library;

/// The three ways to buy Plus. One entitlement ("plus"), three SKUs.
enum PlusPlan {
  /// Auto-renewing monthly subscription.
  monthly('plus_monthly', 29),

  /// Auto-renewing yearly subscription (~2 months free vs monthly).
  yearly('plus_yearly', 299),

  /// One-time, non-consumable, forever. Lead offer for the anti-subscription
  /// audience — and the cleanest fit for an offline app, since a lifetime
  /// purchase never needs re-verification against Play.
  lifetime('plus_lifetime', 699);

  const PlusPlan(this.productId, this.priceInr);

  /// Play product id. Must match the Play Console exactly, forever —
  /// product ids are immutable once a purchase exists.
  final String productId;

  /// Display price in whole rupees. The REAL price always comes from Play's
  /// `ProductDetails` at purchase time (localized, tax-aware); this constant
  /// is only for the pre-billing paywall preview and tests.
  final int priceInr;

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

/// Price of a single royal avatar (one-time, non-consumable).
const int kRoyalAvatarPriceInr = 49;

/// Play product id for a purchasable royal avatar. The royal [id] is the
/// stable `RoyalAvatar.id` ('sovereign', 'empress', ...) — persisted in
/// profiles, so it is already immutable, which makes it safe to bake into a
/// product id.
String royalProductId(String royalId) => 'royal_$royalId';

/// The royal id encoded in a `royal_*` product id, or null for other products.
String? royalIdFromProduct(String productId) =>
    productId.startsWith('royal_') ? productId.substring(6) : null;

/// Features that lock behind Plus once the free window (6 months from first
/// launch) has elapsed. Everything NOT listed here stays free forever — most
/// notably the overall monthly budget and its alerts, SMS transaction
/// detection itself, and manual tagging of a single transaction.
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

  /// Tagging: "Apply to All" (future + existing for a merchant).
  tagApplyToAll,

  /// Tagging: "Apply to All Existing". "Only this one" stays free.
  tagApplyToExisting,
}
