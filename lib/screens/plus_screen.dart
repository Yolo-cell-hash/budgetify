import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/plus_offers.dart';
import '../models/plus_products.dart';
import '../providers/theme_provider.dart';
import '../services/billing_service.dart';
import '../services/entitlement_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/brand_logo.dart';

/// The Budgetify Plus paywall.
///
/// Three ways in: the Settings → Budgetify Plus row and the feature gates
/// ([maybePush]), both of which stay shut for the whole free window, and the
/// last-fortnight heads-up card, which does NOT — it appears while the trial
/// is still running, which is why the hero copy is trial-aware. Telling
/// someone mid-trial that their free months "included" everything would be a
/// lie about a window that is still open.
///
/// Purchases resolve through [BillingService], which ships with the
/// unavailable-store stub until Play billing is approved; buying/restoring
/// here today lands on the calm "purchases open soon" toast.
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key, this.nowSource});

  /// Injectable clock. Prices depend on the calendar (festive windows), so a
  /// test must be able to pin the date — otherwise the same suite would show
  /// different prices in November than in July. Null in production.
  final DateTime Function()? nowSource;

  /// The gate-keeper entry point: pushes the paywall only when the free
  /// window is over AND Plus isn't owned. Returns whether the caller's
  /// feature is usable (true = proceed, false = it stayed locked). Fail-open:
  /// any error counts as usable, so a broken entitlement read can never wall
  /// off a user.
  static Future<bool> maybePush(
      BuildContext context, PlusFeature feature) async {
    try {
      final svc = EntitlementService();
      if (await svc.allowsAsync(feature)) return true;
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlusScreen()),
        );
      }
      // Re-check: the user may have just bought/restored Plus on the screen.
      return svc.allows(feature);
    } catch (_) {
      return true;
    }
  }

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen>
    with TickerProviderStateMixin {
  /// Lifetime leads — the anti-subscription offer is the brand's headline.
  PlusPlan _selected = PlusPlan.lifetime;
  bool _busy = false;

  late final DateTime? _nowOverride = widget.nowSource?.call();

  /// The discount running when this screen opened, or null at the everyday
  /// price. Read once: the screen is short-lived, and a window flipping
  /// mid-session would swap prices under the user's finger.
  late final PlusOffer? _offer = _nowOverride == null
      ? EntitlementService().activeOffer
      : EntitlementService().offerAt(_nowOverride);

  bool get _onOffer => _offer != null;

  /// Whether the free window is still open. Read once, like [_offer], so the
  /// copy can't change under the user mid-session.
  late final bool _trialRunning = EntitlementService().trialActive;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  /// Slow shimmer sweep across the CTA. Disabled with system animations.
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// Play's own formatted prices, keyed by product id, once the store has
  /// answered. Empty until then and whenever the store can't answer, which is
  /// why every read falls back to the catalogue constant.
  Map<String, StorePrice> _livePrices = const <String, StorePrice>{};

  /// Whether the struck-through everyday price is a TRUE claim for [plan]
  /// right now — i.e. Play is really about to charge less than [priceInr].
  ///
  /// An offer window is our calendar, not Play's. If the Console isn't
  /// running a matching discount, Play charges the everyday price and the
  /// strikethrough would either advertise a saving that doesn't exist (before
  /// live prices) or cross out a number identical to the one beside it. Both
  /// are wrong, so the "was" price only appears once the store's own answer
  /// says it's a real reduction. Before the store answers we fall back to the
  /// catalogue, which is honest exactly while it mirrors the Console — the
  /// same assumption the constants already rest on.
  bool _discountIsReal(PlusPlan plan) {
    if (!_onOffer) return false;
    final live = _livePrices[plan.productId];
    if (live == null) return true;
    return live.amount < plan.priceInr;
  }

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) {
        _shimmer.repeat();
      }
    });
    _loadLivePrices();
  }

  /// Replace the previewed constants with what Play will actually charge.
  ///
  /// The constants are honest only while they match the Play Console; this
  /// makes them a fallback rather than a claim. It also localizes for free —
  /// Play returns the price already formatted for the buyer's country and
  /// tax rules, which no hardcoded ₹ string can do.
  Future<void> _loadLivePrices() async {
    final prices = await BillingService()
        .prices(PlusPlan.values.map((p) => p.productId));
    if (!mounted || prices.isEmpty) return;
    setState(() => _livePrices = prices);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  /// Fade+rise entrance for section [index] (0-based, top to bottom).
  Widget _staggered(int index, Widget child) {
    final start = (0.08 * index).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    );
  }

  static final NumberFormat _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  String _rupees(int amount) => _inr.format(amount);

  /// What [plan] costs right now — Play's own price when the store has
  /// answered, the catalogue constant until then.
  ///
  /// Play charges what the Console says, offer window or not, so its answer
  /// wins outright: during a campaign the Console's discounted price IS the
  /// live price. The constant only fills the gap before the store replies (or
  /// when it can't), and the struck-through base price below stays ours —
  /// Play has no notion of "what this used to cost".
  String _price(PlusPlan plan) =>
      _livePrices[plan.productId]?.formatted ??
      _rupees(plan.priceFor(onOffer: _onOffer));

  Future<void> _buy() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = context.l10nRead;
    final outcome = await BillingService().purchase(_selected.productId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case BillingOutcome.success:
        showAppToast(context,
            message: l10n.plusActive, type: AppToastType.success);
        Navigator.of(context).pop();
      case BillingOutcome.unavailable:
        showAppToast(context,
            message: l10n.plusStoreUnavailable, type: AppToastType.info);
      case BillingOutcome.cancelled:
      case BillingOutcome.pending:
      case BillingOutcome.error:
        break; // store UI already told the story; nothing to add
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = context.l10nRead;
    final result = await BillingService().restorePurchases();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result.outcome) {
      case BillingOutcome.success:
        if (result.restoredCount > 0) {
          showAppToast(context,
              message: l10n.plusRestoreDone(result.restoredCount),
              type: AppToastType.success);
          if (EntitlementService().hasPlus) Navigator.of(context).pop();
        } else {
          showAppToast(context,
              message: l10n.plusRestoreNone, type: AppToastType.info);
        }
      case BillingOutcome.unavailable:
        showAppToast(context,
            message: l10n.plusStoreUnavailable, type: AppToastType.info);
      case BillingOutcome.cancelled:
      case BillingOutcome.pending:
      case BillingOutcome.error:
        showAppToast(context,
            message: l10n.plusRestoreNone, type: AppToastType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _staggered(0, _hero(colors, l10n)),
                    const SizedBox(height: 22),
                    // Gated on the discount being REAL, not merely on our
                    // calendar saying a window is open: the banner quotes a
                    // saving percentage, which is a claim about what Play is
                    // about to charge. See [_discountIsReal].
                    if (_offer != null && _discountIsReal(_selected)) ...[
                      _staggered(1, _offerBanner(colors, l10n, _offer)),
                      const SizedBox(height: 14),
                    ],
                    _staggered(2, _featureList(colors, l10n)),
                    const SizedBox(height: 22),
                    for (final (i, plan) in const [
                      PlusPlan.lifetime,
                      PlusPlan.yearly,
                      PlusPlan.monthly,
                    ].indexed) ...[
                      _staggered(3 + i, _planCard(colors, l10n, plan)),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            _staggered(6, _footer(colors, l10n)),
          ],
        ),
      ),
    );
  }

  /// The dark "luxury card" hero: brand mark, title, promise.
  Widget _hero(AppColors colors, AppStrings l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const BrandLogo(size: 54),
          const SizedBox(height: 14),
          Text(
            l10n.plusTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.plusTagline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _trialRunning ? l10n.plusHeroBodyTrial : l10n.plusHeroBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  /// The live-campaign strip: which offer is running, how much the selected
  /// plan saves, and when it closes. Only built while [_offer] is non-null.
  Widget _offerBanner(AppColors colors, AppStrings l10n, PlusOffer offer) {
    final welcome = offer.kind == PlusOfferKind.welcome;
    final daysLeft = offer.daysLeftFrom(_nowOverride ?? DateTime.now());
    final title = welcome
        ? l10n.plusOfferWelcomeTitle
        : l10n.plusOfferFestiveTitle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.brandAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brandAccentDeep.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            welcome ? Icons.card_giftcard_rounded : Icons.celebration_rounded,
            size: 20,
            color: colors.brandAccentDeep,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title · ${l10n.plusOfferSave(_selected.offerSavingPercent)}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: colors.brandAccentDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  daysLeft == 0
                      ? l10n.plusOfferEndsToday
                      : l10n.plusOfferEndsInDays(daysLeft),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureList(AppColors colors, AppStrings l10n) {
    final features = [
      l10n.plusFeatCategoryBudgets,
      l10n.plusFeatSpendAlerts,
      l10n.plusFeatRecurring,
      l10n.plusFeatInvestments,
      l10n.plusFeatTagging,
      l10n.plusFeatAiPredictions,
      l10n.plusFeatTaxExport,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.plusFeaturesHeader.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: colors.brandAccentDeep),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _planCard(AppColors colors, AppStrings l10n, PlusPlan plan) {
    final selected = _selected == plan;
    final (name, cadence, chip) = switch (plan) {
      PlusPlan.monthly => (l10n.plusPlanMonthly, l10n.plusPerMonth, null),
      PlusPlan.yearly => (l10n.plusPlanYearly, l10n.plusPerYear, l10n.plusBestValue),
      PlusPlan.lifetime => (l10n.plusPlanLifetime, l10n.plusOneTime, l10n.plusMostLoved),
    };
    return GestureDetector(
      onTap: () => setState(() => _selected = plan),
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.98,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? colors.cardAlt : colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.brandAccentDeep : colors.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.brandAccent.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors.brandAccentDeep : Colors.transparent,
                  border: Border.all(
                    color:
                        selected ? colors.brandAccentDeep : colors.textTertiary,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        if (chip != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color:
                                  colors.brandAccent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              chip,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: colors.brandAccentDeep,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cadence,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // The everyday price, struck through. Honest because it is
                  // what this plan actually costs once the window closes —
                  // which is also why it is drawn to be READ rather than
                  // whispered: a saving the user can't see isn't a saving.
                  // Secondary (not tertiary) ink and a double-weight rule keep
                  // the line crisp at 13.5sp on every theme; the price below
                  // still wins on size and weight, so the hierarchy holds.
                  if (_discountIsReal(plan)) ...[
                    Text(
                      _rupees(plan.priceInr),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: colors.textSecondary,
                        decorationThickness: 2.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    _price(plan),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: selected ? colors.brandAccentDeep : colors.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(AppColors colors, AppStrings l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CtaButton(
            label: l10n.plusContinueCta(_price(_selected)),
            busy: _busy,
            shimmer: _shimmer,
            onPressed: _buy,
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _busy ? null : _restore,
            icon: Icon(Icons.restore_rounded,
                size: 16, color: colors.brandAccentDeep),
            label: Text(
              l10n.plusRestore,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: colors.brandAccentDeep,
              ),
            ),
          ),
          Text(
            _discountIsReal(_selected)
                ? '${l10n.plusOfferFootnote}\n${l10n.plusFootnote}'
                : l10n.plusFootnote,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.45,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The gold CTA with a slow diagonal shimmer sweep — the "premium" motion cue.
/// The sweep is purely decorative and stops with system animations off.
class _CtaButton extends StatelessWidget {
  final String label;
  final bool busy;
  final Animation<double> shimmer;
  final VoidCallback onPressed;

  const _CtaButton({
    required this.label,
    required this.busy,
    required this.shimmer,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.brandAccentDeep, colors.brandAccent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: shimmer,
              builder: (context, _) {
                // Sweep a soft white band across; -1.5 → 1.5 keeps it fully
                // off-card at both ends of the loop.
                final dx = -1.5 + 3.0 * shimmer.value;
                return FractionalTranslation(
                  translation: Offset(dx, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: busy ? null : onPressed,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
