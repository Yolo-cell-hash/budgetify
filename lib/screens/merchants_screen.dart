import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/merchant_summary.dart';
import '../providers/theme_provider.dart';
import '../services/custom_tag_service.dart';
import '../services/database_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/glass.dart';
import '../widgets/merchant_bar.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';
import 'merchant_detail_screen.dart';

/// Full "where your money goes by merchant" view for a month: a headline
/// insight card plus a ranked, animated list. Tap a merchant to drill in.
class MerchantsScreen extends StatefulWidget {
  final DateTime month;

  const MerchantsScreen({super.key, required this.month});

  @override
  State<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends State<MerchantsScreen> {
  final DatabaseService _db = DatabaseService();
  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  MerchantSummary _summary = const MerchantSummary([]);
  double? _topVsLastMonth; // % change of the top merchant vs previous month
  bool _loading = true;

  DateTime get _start => DateTime(widget.month.year, widget.month.month, 1);
  DateTime get _end =>
      DateTime(widget.month.year, widget.month.month + 1, 0, 23, 59, 59);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _db.getMerchantBreakdown(startDate: _start, endDate: _end);
    final summary = MerchantSummary.fromRows(rows);

    double? topVs;
    final top = summary.top;
    if (top != null) {
      final prevStart = DateTime(widget.month.year, widget.month.month - 1, 1);
      final prevEnd =
          DateTime(widget.month.year, widget.month.month, 0, 23, 59, 59);
      final prevRows = await _db.getMerchantBreakdown(
          startDate: prevStart, endDate: prevEnd);
      final prev = prevRows.firstWhere(
        (r) => r['merchant'] == top.name,
        orElse: () => const {'total': 0.0},
      );
      final prevTotal = (prev['total'] as num).toDouble();
      if (prevTotal > 0) topVs = (top.total - prevTotal) / prevTotal * 100;
    }

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _topVsLastMonth = topVs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final isCurrent =
        widget.month.year == now.year && widget.month.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.topMerchants,
            icon: Icons.storefront_rounded),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              isCurrent
                  ? context.l10n.thisMonth
                  : context.l10n.monthYear(widget.month),
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AmbientBackground(
              child: _summary.isEmpty
                  ? _emptyState(colors)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        FadeSlideIn(order: 0, child: _buildHeader(colors)),
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          order: 1,
                          child: _buildList(colors),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _emptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 56, color: colors.textTertiary),
          const SizedBox(height: 12),
          Text(context.l10n.noMerchantSpending,
              style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    final top = _summary.top!;
    final vs = _topVsLastMonth;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.of(context).brandAccent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SPENT ACROSS ${_summary.merchantCount} MERCHANT'
            '${_summary.merchantCount == 1 ? '' : 'S'}',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).brandAccent.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          PrivacyAnimatedAmount(
            value: _summary.total,
            formatter: _fmt,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.topMerchantLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        top.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        context.l10n
                            .pctOfMerchantSpend((_summary.topShare * 100).round()),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (vs != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (vs >= 0
                              ? AppColors.dangerDark
                              : AppColors.successDark)
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${vs >= 0 ? '↑' : '↓'} ${vs.abs().toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: vs >= 0
                            ? AppColors.dangerDark
                            : AppColors.successDark,
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

  Widget _buildList(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _summary.merchants.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            MerchantBar(
              rank: i + 1,
              name: _summary.merchants[i].name,
              amountLabel: _fmt.format(_summary.merchants[i].total),
              count: _summary.merchants[i].count,
              fraction: _summary.barFraction(_summary.merchants[i]),
              shareOfTotal: _summary.share(_summary.merchants[i]),
              color: CustomTagService.colorFromName(_summary.merchants[i].name),
              isTop: i == 0,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MerchantDetailScreen(
                    merchant: _summary.merchants[i].name,
                    month: widget.month,
                  ),
                ),
              ).then((_) => _load()),
            ),
          ],
        ],
      ),
    );
  }
}
