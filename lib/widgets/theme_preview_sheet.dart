import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import 'savings_summary.dart';

/// A still of the app dressed in one [AppThemeVariant], shown before the user
/// commits to it — or, for a locked theme, before they have earned it.
///
/// **Why this exists.** The Appearance picker's swatch is two colours:
/// `background` over `accent`. A variant actually defines 28 style decisions
/// (14 [AppColors] slots, 13 [HeroStyle] slots, a display face), and *none* of
/// the HeroStyle ones — the marquee card, the surface people look at most —
/// appear in that swatch. Vellum is the clearest case: its swatch shows the
/// right two tones but cannot show that the parchment is a *card sitting on*
/// the dark canvas rather than an accent on it, so it reads as an ordinary dark
/// theme. Two rectangles cannot describe a figure/ground inversion.
///
/// **Why a still and not a live try.** Applying the variant app-wide would
/// preview it perfectly, but it means non-persisted global state that must
/// never leak into what the user actually owns. This shows the same
/// information with nothing to leak. The live version is the right shape once a
/// theme costs money and the user is deciding with their wallet.
///
/// The figures are demo figures, deliberately: a fresh install has no data, and
/// a browsing-the-themes user is exactly the one most likely to be fresh. This
/// sells the *style*, so it must look composed on an empty account too.
Future<void> showThemePreviewSheet(
  BuildContext context, {
  required AppThemeVariant variant,
  required String name,

  /// Streak days needed, when this theme is not yet earned. Null when unlocked.
  int? unlockDays,

  /// Applies the theme and closes. Null when locked or already active.
  VoidCallback? onApply,

  /// True when this is the variant already in use.
  bool active = false,
}) {
  final colors = AppColors.of(context);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      // Scrolls on short screens and at large text scales — the still plus the
      // caption and action stack can outgrow a small viewport.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 12),
            ThemeStill(variant: variant),
            if (unlockDays != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline,
                      size: 14, color: colors.textSecondary),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      ctx.l10n.lockedThemeNudge(unlockDays),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: active
                  ? OutlinedButton(
                      onPressed: null,
                      child: Text(ctx.l10n.currentlyApplied),
                    )
                  : onApply != null
                      ? ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onApply();
                          },
                          child: Text(ctx.l10n.applyTheme),
                        )
                      : OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(ctx.l10n.gotIt),
                        ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The still itself: a compact facsimile of the dashboard — wordmark, the
/// marquee card, two canvas rows and the nav bar — rendered in [variant].
///
/// Wrapping in [Theme] is what makes this work with no per-variant code:
/// `AppColors.of` and `HeroStyle.of` both resolve through the [AppPalette]
/// extension on the ambient [ThemeData], so every child inks itself for
/// [variant] automatically. Adding a future variant needs nothing here.
///
/// It shows the marquee card *and* canvas content together on purpose. That
/// pairing is the only thing that reveals a theme whose card runs lighter than
/// the screen behind it, which is precisely what the swatch cannot say.
class ThemeStill extends StatelessWidget {
  final AppThemeVariant variant;

  /// An optional restyling pass over [variant], applied exactly as
  /// ThemeProvider applies it to the live app. Null leaves the variant as its
  /// designers made it — which is what the Appearance picker wants.
  ///
  /// This exists for the royal court sheet, where the question is not "what
  /// does this theme look like" but "what does this theme look like once a
  /// royal has dressed it". Routing that through the SAME still is what keeps
  /// the answer honest: the preview cannot flatter the dress, because it has
  /// no colours of its own to flatter it with.
  final ThemeDress? dress;

  const ThemeStill({super.key, required this.variant, this.dress});

  // Demo figures. Indian digit grouping, chosen to exercise the hero's
  // positive/negative slots and a healthy (not overspent) savings bar.
  static const double _income = 124500;
  static const double _expenses = 42318;

  @override
  Widget build(BuildContext context) {
    final outer = AppColors.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: outer.border),
        ),
        // Inside this Theme everything resolves to the previewed variant —
        // dressed, when a dress was handed in.
        child: Theme(
          data: _themeData,
          child: Builder(builder: _still),
        ),
      ),
    );
  }

  ThemeData get _themeData {
    final base = AppTheme.of(variant);
    return dress?.call(variant, base) ?? base;
  }

  Widget _still(BuildContext context) {
    final colors = AppColors.of(context);
    final hero = HeroStyle.of(context);

    return Container(
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budgetify',
            style: TextStyle(
              fontFamily: AppPalette.displayFamilyOf(context),
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 10),
          _heroCard(context, colors, hero),
          const SizedBox(height: 12),
          _canvasRow(colors, 'HDFC Bank', '₹24,180'),
          const SizedBox(height: 8),
          _canvasRow(colors, 'ICICI Bank', '₹12,940'),
          const SizedBox(height: 12),
          _navStrip(context, colors),
        ],
      ),
    );
  }

  /// The marquee card — the 13 HeroStyle slots the swatch cannot show.
  Widget _heroCard(BuildContext context, AppColors colors, HeroStyle hero) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: hero.gradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hero.border),
        boxShadow: hero.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The month, not "EXPENSES" — the split row below already says that,
          // and the real hero's eyebrow leads with the month too. (toUpperCase
          // is a no-op in the Indic scripts, which is the correct behaviour.)
          Text(
            context.l10n.monthName(DateTime.now().month).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: hero.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹42,318.60',
            style: TextStyle(
              fontFamily: AppPalette.displayFamilyOf(context),
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.9,
              color: hero.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _heroFigure(context, hero, context.l10n.commonIncome,
                    '₹1,24,500', hero.positive),
              ),
              Container(width: 1, height: 28, color: hero.divider),
              Expanded(
                child: _heroFigure(context, hero, context.l10n.commonExpenses,
                    '₹42,318', hero.negative,
                    alignEnd: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // The real widget, not a mock-up of it: SavingsRateBar takes the
          // HeroStyle it is drawn on, so this is a truthful test of the one
          // component that has to ink itself for the card rather than the
          // screen. If a future theme breaks that, it breaks here in the
          // preview too — visibly, before anyone ships it.
          SavingsRateBar(
            income: _income,
            expenses: _expenses,
            hero: hero,
          ),
        ],
      ),
    );
  }

  Widget _heroFigure(
    BuildContext context,
    HeroStyle hero,
    String label,
    String amount,
    Color amountColor, {
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 8.5,
            letterSpacing: 1.1,
            color: hero.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: amountColor,
          ),
        ),
      ],
    );
  }

  /// Canvas-side content. Paired with the hero above it, this is what makes a
  /// light-card-on-dark-screen theme legible as such.
  Widget _canvasRow(AppColors colors, String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.brandAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: colors.text),
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
      ],
    );
  }

  /// The nav bar carries two more slots the swatch misses: the selected and
  /// unselected item colours, which is where a theme's accent reads loudest.
  Widget _navStrip(BuildContext context, AppColors colors) {
    final nav = Theme.of(context).bottomNavigationBarTheme;
    final selected = nav.selectedItemColor ?? colors.accent;
    final unselected = nav.unselectedItemColor ?? colors.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: nav.backgroundColor ?? colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(Icons.home_rounded, size: 16, color: selected),
          Icon(Icons.pie_chart_outline, size: 16, color: unselected),
          Icon(Icons.event_repeat_outlined, size: 16, color: unselected),
          Icon(Icons.account_balance_wallet_outlined,
              size: 16, color: unselected),
          Icon(Icons.settings_outlined, size: 16, color: unselected),
        ],
      ),
    );
  }
}
