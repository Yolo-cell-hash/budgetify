import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/custom_tag_service.dart';
import '../services/database_service.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';
import 'transaction_detail_screen.dart';

/// Per-merchant analytics: how much, how often, the 6-month trend, and the
/// transactions behind it — for the selected month.
class MerchantDetailScreen extends StatefulWidget {
  final String merchant;
  final DateTime month;

  const MerchantDetailScreen({
    super.key,
    required this.merchant,
    required this.month,
  });

  @override
  State<MerchantDetailScreen> createState() => _MerchantDetailScreenState();
}

class _MerchantDetailScreenState extends State<MerchantDetailScreen> {
  final DatabaseService _db = DatabaseService();
  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  List<Map<String, dynamic>> _trend = [];
  List<TransactionModel> _txns = [];
  bool _loading = true;

  late final Color _accent = CustomTagService.colorFromName(widget.merchant);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final start = DateTime(widget.month.year, widget.month.month, 1);
    final end =
        DateTime(widget.month.year, widget.month.month + 1, 0, 23, 59, 59);
    final trend = await _db.getMerchantMonthlyTrend(widget.merchant, months: 6);
    final txns = await _db.getMerchantTransactions(
      widget.merchant,
      startDate: start,
      endDate: end,
    );
    if (!mounted) return;
    setState(() {
      _trend = trend;
      _txns = txns;
      _loading = false;
    });
  }

  double get _monthTotal => _txns.fold(0.0, (s, t) => s + t.amount);
  double get _avg => _txns.isEmpty ? 0 : _monthTotal / _txns.length;
  double get _largest =>
      _txns.isEmpty ? 0 : _txns.map((t) => t.amount).reduce((a, b) => a > b ? a : b);

  /// Percent change vs the previous month from the trend (null if not enough).
  double? get _vsLastMonth {
    if (_trend.length < 2) return null;
    final prev = (_trend[_trend.length - 2]['total'] as double);
    final curr = (_trend.last['total'] as double);
    if (prev <= 0) return null;
    return (curr - prev) / prev * 100;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.merchant, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AmbientBackground(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  FadeSlideIn(order: 0, child: _buildHero(colors)),
                  const SizedBox(height: 14),
                  FadeSlideIn(order: 1, child: _buildStatChips(colors)),
                  const SizedBox(height: 16),
                  if (_trend.any((m) => (m['total'] as double) > 0))
                    FadeSlideIn(order: 2, child: _buildTrendCard(colors)),
                  const SizedBox(height: 16),
                  FadeSlideIn(order: 3, child: _buildTxnsCard(colors)),
                ],
              ),
            ),
    );
  }

  Widget _buildHero(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  _initial(widget.merchant),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${DateFormat('MMMM yyyy').format(widget.month)} spend',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.4,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrivacyAnimatedAmount(
            value: _monthTotal,
            formatter: _fmt,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_txns.length} transaction${_txns.length == 1 ? '' : 's'} this month',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChips(AppColors colors) {
    final vs = _vsLastMonth;
    return Row(
      children: [
        _statChip(colors, context.l10n.avgPerTxn, _fmt.format(_avg)),
        const SizedBox(width: 10),
        _statChip(colors, context.l10n.largestLabel, _fmt.format(_largest)),
        const SizedBox(width: 10),
        _statChip(
          colors,
          context.l10n.vsLastMonth,
          vs == null ? '—' : '${vs >= 0 ? '↑' : '↓'} ${vs.abs().toStringAsFixed(0)}%',
          valueColor: vs == null
              ? null
              : (vs >= 0 ? AppColors.dangerLight : AppColors.successLight),
        ),
      ],
    );
  }

  Widget _statChip(AppColors colors, String label, String value,
      {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            PrivacyAmount(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor ?? colors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(AppColors colors) {
    final maxY = _trend
            .map((m) => m['total'] as double)
            .fold(0.0, (a, b) => a > b ? a : b) *
        1.25;
    final monthFmt = DateFormat('MMM');

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
          Text(
            'Last 6 months',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY <= 0 ? 1 : maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF2E313A),
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '₹${rod.toY.toStringAsFixed(0)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= _trend.length) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            monthFmt.format(_trend[i]['month'] as DateTime),
                            style: TextStyle(
                                fontSize: 10, color: colors.textSecondary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < _trend.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _trend[i]['total'] as double,
                          width: 18,
                          color: i == _trend.length - 1
                              ? _accent
                              : _accent.withValues(alpha: 0.45),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxnsCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.transactions,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          if (_txns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(context.l10n.noTxnsThisMonth,
                  style: TextStyle(color: colors.textSecondary)),
            )
          else
            for (final t in _txns)
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionDetailScreen(transaction: t),
                  ),
                ).then((_) => _load()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.category != null
                                  ? context.l10n.categoryName(t.category!)
                                  : context.l10n.unclassified,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d, yyyy').format(t.detectedAt),
                              style: TextStyle(
                                  fontSize: 11, color: colors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      PrivacyAmount(
                        _fmt.format(t.amount),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 16, color: colors.textTertiary),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final c = t[0].toUpperCase();
    return RegExp(r'[A-Z0-9]').hasMatch(c) ? c : '#';
  }
}
