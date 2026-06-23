import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import 'privacy_amount.dart';

/// Pure, testable savings math for a period: income in, expenses out, and the
/// "true" savings rate derived from them. Callers pass income that already
/// excludes non-income credits (Self Transfer / Investment redemptions).
class SavingsStats {
  final double income;
  final double expenses;

  const SavingsStats({required this.income, required this.expenses});

  double get savings => income - expenses;
  bool get hasIncome => income > 0;
  bool get isOverspent => savings < 0;

  /// Savings as a percentage of income, or null when there's no income to
  /// divide by (rate is undefined).
  double? get ratePercent => hasIncome ? (savings / income) * 100 : null;

  /// Fraction of income kept (0..1), used for the bar fill.
  double get savedFraction =>
      hasIncome ? (savings / income).clamp(0.0, 1.0).toDouble() : 0.0;
}

/// Compact "income vs expense vs savings rate" summary: a labelled percentage,
/// an animated fill bar, and a caption. Adapts to a dark hero surface
/// ([onDark]) or a normal themed card, and respects privacy mode for figures.
class SavingsRateBar extends StatelessWidget {
  final double income;
  final double expenses;
  final bool onDark;

  const SavingsRateBar({
    super.key,
    required this.income,
    required this.expenses,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final stats = SavingsStats(income: income, expenses: expenses);
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final labelColor = onDark ? AppColors.gold : colors.textSecondary;
    final subText =
        onDark ? Colors.white.withValues(alpha: 0.62) : colors.textSecondary;
    final track =
        onDark ? Colors.white.withValues(alpha: 0.12) : colors.border;
    final pos = onDark ? AppColors.successDark : AppColors.successLight;
    final neg = onDark ? AppColors.dangerDark : AppColors.dangerLight;

    final rate = stats.ratePercent;
    final rateColor =
        !stats.hasIncome ? subText : (stats.isOverspent ? neg : pos);
    final rateText = rate == null ? '—' : '${rate.toStringAsFixed(0)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.savingsRateUpper,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            Text(
              rateText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: rateColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 8, color: track),
              if (stats.isOverspent)
                Container(height: 8, color: neg.withValues(alpha: 0.85))
              else if (stats.hasIncome)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: stats.savedFraction),
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [pos.withValues(alpha: 0.7), pos],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _caption(context, stats, fmt, subText, neg),
      ],
    );
  }

  Widget _caption(
    BuildContext context,
    SavingsStats stats,
    NumberFormat fmt,
    Color subText,
    Color neg,
  ) {
    if (!stats.hasIncome) {
      return Text(
        stats.expenses > 0
            ? context.l10n.noIncomeThisMonth
            : context.l10n.noActivityThisMonth,
        style: TextStyle(fontSize: 12, color: subText),
      );
    }
    if (stats.isOverspent) {
      return PrivacyAmount(
        'Overspent by ${fmt.format(stats.savings.abs())}',
        style: TextStyle(fontSize: 12, color: neg, fontWeight: FontWeight.w600),
      );
    }
    return PrivacyAmount(
      '${fmt.format(stats.savings)} saved of ${fmt.format(stats.income)} income',
      style: TextStyle(fontSize: 12, color: subText),
    );
  }
}
