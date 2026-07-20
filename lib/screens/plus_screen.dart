import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/plus_products.dart';
import '../providers/theme_provider.dart';
import '../services/billing_service.dart';
import '../services/entitlement_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/brand_logo.dart';

/// The Budgetify Plus paywall.
///
/// NOT reachable from any menu today: the only ways in are the feature gates
/// ([maybePush]), and those stay dormant until a trial actually expires — the
/// free window is silent by design, so no current user ever sees this screen.
/// Purchases resolve through [BillingService], which ships with the
/// unavailable-store stub until Play billing is approved; buying/restoring
/// here today lands on the calm "purchases open soon" toast.
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});

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

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  /// Slow shimmer sweep across the CTA. Disabled with system animations.
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !MediaQuery.of(context).disableAnimations) {
        _shimmer.repeat();
      }
    });
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

  String _price(PlusPlan plan) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(plan.priceInr);

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
            l10n.plusHeroBody,
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

  Widget _featureList(AppColors colors, AppStrings l10n) {
    final features = [
      l10n.plusFeatCategoryBudgets,
      l10n.plusFeatSpendAlerts,
      l10n.plusFeatRecurring,
      l10n.plusFeatInvestments,
      l10n.plusFeatTagging,
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
                      size: 17, color: colors.brandAccentDeep),
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
                        size: 13, color: Colors.white)
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
                size: 17, color: colors.brandAccentDeep),
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
            l10n.plusFootnote,
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
