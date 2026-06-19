import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/insights_service.dart';
import '../widgets/category_donut.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/safe_to_spend_card.dart';

/// Full-screen, illustrated breakdown of on-device spending insights:
/// month-end forecast, a 6-month trend chart, this month's category mix,
/// and the headline insight rows. Reached by tapping the Insights card.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final DatabaseService _db = DatabaseService();
  final InsightsService _service = InsightsService();

  InsightsResult? _result;
  List<Map<String, dynamic>> _monthly = const [];
  Map<String, double> _categories = const {};
  bool _loading = true;

  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final result = await _service.compute();
    final monthly = await _db.getMonthlySpending(months: 6);
    final categories = await _db.getSpendingByCategory(
      startDate: monthStart,
      endDate: monthEnd,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _monthly = monthly;
      _categories = categories;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final r = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.gold),
            SizedBox(width: 8),
            Text(
              'Insights',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
      body: AmbientBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    if (r?.forecast != null) ...[
                      if (r!.forecast!.hasTarget) ...[
                        FadeSlideIn(
                          order: 0,
                          child: SafeToSpendCard(forecast: r.forecast!),
                        ),
                        const SizedBox(height: 14),
                      ],
                      FadeSlideIn(order: 0, child: _forecastCard(r.forecast!)),
                      const SizedBox(height: 14),
                    ],
                    FadeSlideIn(
                      order: 1,
                      child: _sectionCard(
                        colors,
                        title: 'Spending trend',
                        subtitle: 'Last 6 months',
                        child: _trendChart(colors),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_categories.isNotEmpty) ...[
                      FadeSlideIn(
                        order: 2,
                        child: _sectionCard(
                          colors,
                          title: 'Where it went',
                          subtitle: 'This month',
                          child: CategoryDonut(spending: _categories),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (r != null && r.insights.isNotEmpty)
                      FadeSlideIn(
                        order: 3,
                        child: _sectionCard(
                          colors,
                          title: 'Highlights',
                          child: Column(
                            children: [
                              for (var i = 0; i < r.insights.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _insightRow(colors, r.insights[i]),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (r != null && !r.hasHistory)
                      _emptyHint(colors),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Forecast hero ───────────────────────────────────────────────────
  Widget _forecastCard(SpendingForecast f) {
    final overUnder = f.projectedVsBudget;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROJECTED THIS MONTH',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 8),
          PrivacyAnimatedAmount(
            value: f.projected,
            formatter: _fmt,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Day ${f.daysElapsed} of ${f.daysInMonth} · '
            '${_fmt.format(f.spentSoFar)} spent so far',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          if (overUnder != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (overUnder > 0
                        ? AppColors.dangerDark
                        : AppColors.successDark)
                    .withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    overUnder > 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 16,
                    color: overUnder > 0
                        ? AppColors.dangerDark
                        : AppColors.successDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    overUnder > 0
                        ? '${_fmt.format(overUnder)} over budget'
                        : '${_fmt.format(-overUnder)} under budget',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: overUnder > 0
                          ? AppColors.dangerDark
                          : AppColors.successDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 6-month trend bar chart ─────────────────────────────────────────
  Widget _trendChart(AppColors colors) {
    if (_monthly.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('Not enough history yet',
              style: TextStyle(color: colors.textSecondary)),
        ),
      );
    }
    final maxV = _monthly
        .map((m) => (m['total'] as double))
        .fold<double>(0, (a, b) => b > a ? b : a);
    final maxY = maxV > 0 ? maxV * 1.2 : 1000.0;
    final monthFmt = DateFormat('MMM');

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF2E313A),
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '₹${rod.toY.round()}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _monthly.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      monthFmt.format(_monthly[i]['month'] as DateTime),
                      style: TextStyle(fontSize: 11, color: colors.textTertiary),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: _monthly.asMap().entries.map((e) {
            final isCurrent = e.key == _monthly.length - 1;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value['total'] as double,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  color: isCurrent
                      ? AppColors.gold
                      : AppColors.gold.withOpacity(0.4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Section shell ───────────────────────────────────────────────────
  Widget _sectionCard(
    AppColors colors, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 11.5, color: colors.textTertiary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _insightRow(AppColors colors, Insight insight) {
    final accent = switch (insight.tone) {
      InsightTone.positive => AppColors.successLight,
      InsightTone.caution => const Color(0xFFD79A3C),
      InsightTone.alert => AppColors.dangerLight,
      InsightTone.neutral => colors.textSecondary,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(insight.icon, style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(insight.title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.text)),
              const SizedBox(height: 2),
              Text(insight.detail,
                  style: TextStyle(
                      fontSize: 12.5, height: 1.35, color: colors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyHint(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'Building your baseline. Trends and forecasts sharpen after a few '
        'weeks of activity.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.textSecondary, height: 1.4),
      ),
    );
  }
}
