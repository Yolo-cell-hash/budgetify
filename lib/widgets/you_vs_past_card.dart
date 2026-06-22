import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/cashflow.dart';
import '../models/period_comparison.dart';
import '../providers/theme_provider.dart';

/// "You vs Past You": a reflective card comparing the most recent completed
/// month (or quarter) against the one before it — spending, income, savings and
/// savings rate, each with a good/bad delta. Self-contained: give it the
/// monthly cashflow series and it builds the comparison for either period.
class YouVsPastCard extends StatefulWidget {
  final List<MonthlyCashflow> series;
  final DateTime? now;

  const YouVsPastCard({super.key, required this.series, this.now});

  @override
  State<YouVsPastCard> createState() => _YouVsPastCardState();
}

class _YouVsPastCardState extends State<YouVsPastCard> {
  ComparePeriod _period = ComparePeriod.month;

  static final NumberFormat _grouped = NumberFormat.decimalPattern('en_IN');
  static String _inr(double v) {
    final neg = v < 0;
    return '${neg ? '-' : ''}₹${_grouped.format(v.abs().round())}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = context.l10n;
    final cmp = buildPeriodComparison(
      widget.series,
      now: widget.now ?? DateTime.now(),
      period: _period,
    );
    final isMonth = _period == ComparePeriod.month;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🪞', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.youVsPastYou,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: colors.text,
                  ),
                ),
              ),
              _periodToggle(colors, s),
            ],
          ),
          const SizedBox(height: 16),
          if (!cmp.hasComparison)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                s.notEnoughHistory,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: colors.textSecondary,
                ),
              ),
            )
          else ...[
            _header(colors, s, isMonth),
            const SizedBox(height: 10),
            _metricRow(
              colors,
              label: s.mSpending,
              current: cmp.current.expense,
              previous: cmp.previous.expense,
              delta: cmp.expenseDelta,
              higherIsBetter: false,
              format: _inr,
            ),
            _divider(colors),
            _metricRow(
              colors,
              label: s.mIncome,
              current: cmp.current.income,
              previous: cmp.previous.income,
              delta: cmp.incomeDelta,
              higherIsBetter: true,
              format: _inr,
            ),
            _divider(colors),
            _metricRow(
              colors,
              label: s.mSavings,
              current: cmp.current.savings,
              previous: cmp.previous.savings,
              delta: cmp.savingsDelta,
              higherIsBetter: true,
              format: _inr,
            ),
            _divider(colors),
            _rateRow(colors, s, cmp),
            const SizedBox(height: 14),
            _verdict(colors, s, cmp),
          ],
        ],
      ),
    );
  }

  Widget _periodToggle(AppColors colors, AppStrings s) {
    Widget seg(String label, ComparePeriod p) {
      final sel = _period == p;
      return GestureDetector(
        onTap: () => setState(() => _period = p),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: sel
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF15110A)
                      : Colors.white)
                  : colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          seg(s.periodMonth, ComparePeriod.month),
          seg(s.periodQuarter, ComparePeriod.quarter),
        ],
      ),
    );
  }

  Widget _header(AppColors colors, AppStrings s, bool isMonth) {
    final curLabel = isMonth ? s.lastMonth : s.lastQuarter;
    final prevLabel = isMonth ? s.priorMonth : s.priorQuarter;
    TextStyle st(Color c) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: c,
        );
    return Row(
      children: [
        const Expanded(flex: 4, child: SizedBox()),
        Expanded(
          flex: 3,
          child: Text(curLabel, textAlign: TextAlign.end, style: st(colors.text)),
        ),
        Expanded(
          flex: 3,
          child: Text(prevLabel,
              textAlign: TextAlign.end, style: st(colors.textTertiary)),
        ),
      ],
    );
  }

  Widget _metricRow(
    AppColors colors, {
    required String label,
    required double current,
    required double previous,
    required double delta,
    required bool higherIsBetter,
    required String Function(double) format,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _deltaArrow(colors, delta, higherIsBetter),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              format(current),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              format(previous),
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13, color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateRow(AppColors colors, AppStrings s, PeriodComparison cmp) {
    String fmtRate(double? r) => r == null ? '—' : '${(r * 100).round()}%';
    final deltaPts = cmp.savingsRateDeltaPoints ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    s.mSavingsRate,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _deltaArrow(colors, deltaPts, true),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              fmtRate(cmp.current.savingsRate),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              fmtRate(cmp.previous.savingsRate),
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13, color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deltaArrow(AppColors colors, double delta, bool higherIsBetter) {
    if (delta.abs() < 0.0001) {
      return Icon(Icons.remove_rounded, size: 14, color: colors.textTertiary);
    }
    final up = delta > 0;
    final good = up == higherIsBetter;
    return Icon(
      up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      size: 14,
      color: good ? colors.success : colors.danger,
    );
  }

  Widget _divider(AppColors colors) =>
      Divider(height: 1, color: colors.border);

  Widget _verdict(AppColors colors, AppStrings s, PeriodComparison cmp) {
    final d = cmp.savingsDelta;
    final String text;
    final Color color;
    if (d > 1) {
      text = s.savedMoreVerdict(_inr(d));
      color = colors.success;
    } else if (d < -1) {
      text = s.savedLessVerdict(_inr(d.abs()));
      color = colors.danger;
    } else {
      text = s.savedSameVerdict;
      color = colors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
