import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../providers/app_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/insights_service.dart';
import 'privacy_amount.dart';

/// Premium "safe to spend" card: how much the user can still spend per day for
/// the rest of the month without breaking their plan. Works off an explicit
/// budget or — when none is set — the user's own typical month, so it shows up
/// for everyone with a little history.
///
/// The bar reads at a glance: the gold fill is what's spent so far, the thin
/// marker is where you'd be if you spent evenly. Fill left of the marker means
/// you're ahead of plan.
class SafeToSpendCard extends StatelessWidget {
  final SpendingForecast forecast;
  const SafeToSpendCard({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final f = forecast;
    final hidden = context.select<AppPreferences, bool>((p) => p.amountsHidden);
    String mask(String s) => hidden ? maskRupeeFigures(s) : s;

    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final over = f.isOverTarget;
    final paceFrac = (f.daysElapsed / f.daysInMonth).clamp(0.0, 1.0);
    final spentFrac =
        f.hasTarget ? (f.spentSoFar / f.target!).clamp(0.0, 1.0) : 0.0;
    final aheadOfPace = spentFrac > paceFrac + 0.03;

    // Green when comfortably on/under the time-pace, the theme accent when
    // running a touch fast, red once the whole target is gone.
    final Color accent = over
        ? colors.danger
        : (aheadOfPace ? colors.brandAccent : colors.success);

    final perDay = f.safeToSpendPerDay ?? 0;
    final remaining = f.safeToSpendTotal ?? 0;
    final targetWord =
        f.targetFromBudget ? context.l10n.budgetWord : context.l10n.typicalMonth;
    final monthName = context.l10n.monthName(DateTime.now().month);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  over
                      ? Icons.error_outline_rounded
                      : Icons.savings_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.safeToSpend,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  f.targetFromBudget
                      ? context.l10n.vsBudget
                      : context.l10n.vsTypical,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Headline figure
          if (!over)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                PrivacyAmount(
                  fmt.format(perDay),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.1,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '/day',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            )
          else
            PrivacyAmount(
              '${fmt.format(remaining.abs())} over',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.9,
                color: accent,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            over
                ? mask(context.l10n.passedTarget(
                    targetWord, monthName, fmt.format(remaining.abs())))
                : mask(context.l10n
                    .amountLeftDays(fmt.format(remaining), f.daysRemaining)),
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          _PaceBar(spentFrac: spentFrac, paceFrac: paceFrac, accent: accent),
          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                over
                    ? Icons.trending_up_rounded
                    : aheadOfPace
                        ? Icons.speed_rounded
                        : Icons.check_circle_rounded,
                size: 15,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  over
                      ? context.l10n.overTargetMsg(targetWord, monthName)
                      : aheadOfPace
                          ? context.l10n.aheadOfPaceMsg
                          : context.l10n.onTrackMsg,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Spent-vs-target track with a "where you'd be if spending evenly" marker.
class _PaceBar extends StatelessWidget {
  final double spentFrac; // 0..1
  final double paceFrac; // 0..1
  final Color accent;

  const _PaceBar({
    required this.spentFrac,
    required this.paceFrac,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const h = 12.0;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track
              Container(
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(h / 2),
                  border: Border.all(color: colors.border),
                ),
              ),
              // Animated spent fill
              ClipRRect(
                borderRadius: BorderRadius.circular(h / 2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: spentFrac),
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(width: w * v, height: h, color: accent),
                  ),
                ),
              ),
              // Even-pace marker
              Positioned(
                left: (w * paceFrac).clamp(0.0, w - 2.5),
                top: -3,
                bottom: -3,
                child: Container(
                  width: 2.5,
                  decoration: BoxDecoration(
                    color: colors.text.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
