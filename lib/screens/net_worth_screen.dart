import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/cashflow.dart';
import '../models/holding.dart';
import '../models/net_worth_projection.dart';
import '../models/sip.dart';
import '../providers/theme_provider.dart';
import '../services/custom_tag_service.dart';
import '../services/database_service.dart';
import '../services/sip_service.dart';
import '../services/widget_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/net_worth_projection_card.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/holding_editor_sheet.dart';

/// Net Worth + Investment tracker: manual holdings (FDs, RDs, MFs, stocks,
/// bonds, gold, savings, loans…). Recurring investments (SIP/RD) carry an
/// inline schedule + progress and are logged by the user — either via the
/// "Investment Alert" prompt or here in-app. Fully offline; values are
/// user-entered (the app never invents instalments from SMS).
class NetWorthScreen extends StatefulWidget {
  /// When true (deep-linked from the Investment Alert), the screen opens the
  /// "did you invest?" prompt for any due instalment as soon as it loads.
  final bool reviewSips;

  const NetWorthScreen({super.key, this.reviewSips = false});

  @override
  State<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends State<NetWorthScreen> {
  final DatabaseService _db = DatabaseService();
  final SipService _sipService = SipService();
  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  NetWorthSummary _summary = const NetWorthSummary([]);
  double _investedViaSms = 0;
  // Progress for each recurring plan, keyed by its backing holding id.
  Map<int, SipProgress> _sipByHolding = {};
  // Typical monthly savings used by the projection card; null until there are
  // enough completed months to estimate from.
  double? _savingsBaseline;
  bool _loading = true;
  bool _reviewHandled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final holdings = await _db.getHoldings();
    final invested = await _db.getInvestmentsTagTotal();
    final sips = await _db.getSips();
    final byHolding = <int, SipProgress>{};
    for (final s in sips) {
      if (s.holdingId == null) continue;
      byHolding[s.holdingId!] = await _sipService.progressFor(s);
    }
    // Typical monthly savings, for the forward projection.
    final txns = await _db.getAllTransactions();
    final baseline = monthlySavingsBaseline(
      buildMonthlyCashflow(txns),
      now: DateTime.now(),
    );
    // Keep the home-screen widget's net worth in sync with any edits here.
    WidgetService.update();
    if (!mounted) return;
    setState(() {
      _summary = NetWorthSummary(holdings);
      _investedViaSms = invested;
      _sipByHolding = byHolding;
      _savingsBaseline = baseline;
      _loading = false;
    });

    // Deep-linked from the Investment Alert → walk through any due instalments.
    if (widget.reviewSips && !_reviewHandled) {
      _reviewHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reviewDueSips());
    }
  }

  bool get _hasAnything => !_summary.isEmpty || _investedViaSms > 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.navNetWorth,
            icon: Icons.account_balance_wallet_rounded),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.addLabel),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AmbientBackground(
              child: RefreshIndicator(
                onRefresh: _load,
                child: !_hasAnything
                    ? _buildEmpty(colors)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        children: _buildContent(colors),
                      ),
              ),
            ),
    );
  }

  List<Widget> _buildContent(AppColors colors) {
    var order = 0;
    final widgets = <Widget>[
      FadeSlideIn(order: order++, child: _buildHero(colors)),
    ];

    // Forward projection — only once there's enough history to estimate a
    // typical monthly savings figure.
    if (_savingsBaseline != null) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(FadeSlideIn(
          order: order++,
          child: NetWorthProjectionCard(
            currentNetWorth: _summary.netWorth,
            monthlySavings: _savingsBaseline!,
          ),
        ));
    }

    if (_summary.assets > 0) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(FadeSlideIn(order: order++, child: _buildAllocation(colors)));
    }

    if (_summary.investmentHoldings.isNotEmpty || _investedViaSms > 0) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(FadeSlideIn(
            order: order++, child: _buildInvestmentsSection(colors)));
    }

    if (_summary.otherAssetHoldings.isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(FadeSlideIn(
          order: order++,
          child: _buildSection(
            colors,
            title: context.l10n.otherAssets,
            total: _summary.otherAssetHoldings.fold(0.0, (s, h) => s + h.amount),
            items: _summary.otherAssetHoldings,
          ),
        ));
    }

    if (_summary.liabilityHoldings.isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(FadeSlideIn(
          order: order++,
          child: _buildSection(
            colors,
            title: context.l10n.liabilities,
            total: _summary.liabilities,
            items: _summary.liabilityHoldings,
            negative: true,
          ),
        ));
    }

    return widgets;
  }

  // ==================== HERO ====================
  Widget _buildHero(AppColors colors) {
    final net = _summary.netWorth;
    final hero = HeroStyle.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: hero.gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hero.border),
        boxShadow: hero.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.netWorthLabel,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: hero.accent,
            ),
          ),
          const SizedBox(height: 10),
          PrivacyAnimatedAmount(
            value: net,
            formatter: _fmt,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: hero.foreground,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroStat(context.l10n.assets, _summary.assets,
                    colors.success, Icons.arrow_upward),
              ),
              Container(
                width: 1,
                height: 38,
                color: hero.divider,
              ),
              Expanded(
                child: _heroStat(context.l10n.liabilities, _summary.liabilities,
                    colors.danger, Icons.arrow_downward,
                    alignEnd: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, double value, Color color, IconData icon,
      {bool alignEnd = false}) {
    final hero = HeroStyle.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.3,
                color: hero.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        PrivacyAmount(
          _fmt.format(value),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: hero.foreground,
          ),
        ),
      ],
    );
  }

  // ==================== ALLOCATION DONUT ====================
  Widget _buildAllocation(AppColors colors) {
    final alloc = _summary.assetAllocation;
    final total = _summary.assets;
    final entries = alloc.entries.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.allocation,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 38,
                    sections: [
                      for (final e in entries)
                        PieChartSectionData(
                          value: e.value,
                          color: CustomTagService.colorFromName(e.key),
                          radius: 26,
                          showTitle: false,
                        ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in entries.take(6))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: CustomTagService.colorFromName(e.key),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              total > 0
                                  ? '${(e.value / total * 100).toStringAsFixed(0)}%'
                                  : '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== INVESTMENTS (with inline automation) ====================
  Widget _buildInvestmentsSection(AppColors colors) {
    final items = _summary.investmentHoldings;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.investments,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              PrivacyAmount(
                _fmt.format(_summary.investments),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) const SizedBox(height: 6),
          ..._groupedInvestments(colors, items),
          if (_investedViaSms > 0) ...[
            const SizedBox(height: 10),
            _investedViaSmsNote(colors),
          ],
        ],
      ),
    );
  }

  /// Investments grouped by type (all FDs together, all RDs together, …) in the
  /// canonical category order, each group under a small header — clearer than a
  /// flat amount-sorted list.
  List<Widget> _groupedInvestments(AppColors colors, List<Holding> items) {
    final grouped = <String, List<Holding>>{};
    for (final h in items) {
      (grouped[h.category] ??= []).add(h);
    }
    final ordered = [
      ...HoldingCategories.investments.where(grouped.containsKey),
      ...grouped.keys.where((c) => !HoldingCategories.investments.contains(c)),
    ];
    final out = <Widget>[];
    for (var i = 0; i < ordered.length; i++) {
      final cat = ordered[i];
      final group = grouped[cat]!;
      out.add(_investmentGroupHeader(colors, cat, group, topGap: i > 0));
      for (final h in group) {
        out.add(_investmentRow(colors, h));
      }
    }
    return out;
  }

  Widget _investmentGroupHeader(
    AppColors colors,
    String cat,
    List<Holding> group, {
    bool topGap = false,
  }) {
    final total = group.fold(0.0, (s, h) => s + h.amount);
    return Padding(
      padding: EdgeInsets.only(top: topGap ? 12 : 4, bottom: 2),
      child: Row(
        children: [
          Text(HoldingCategories.icon(cat), style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            context.l10n.holdingCategoryName(cat).toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text('· ${group.length}',
              style: TextStyle(fontSize: 10.5, color: colors.textTertiary)),
          const Spacer(),
          PrivacyAmount(
            _fmt.format(total),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _investmentRow(AppColors colors, Holding h) {
    final progress = h.id == null ? null : _sipByHolding[h.id];
    final sip = progress?.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _openEditor(existingHolding: h, existingSip: sip),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CustomTagService.colorFromName(h.category)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(HoldingCategories.icon(h.category),
                      style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sip != null
                            ? _scheduleLine(sip)
                            : context.l10n.holdingCategoryName(h.category),
                        style: TextStyle(
                            fontSize: 11.5, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (progress != null) _statusChip(colors, progress),
                const SizedBox(width: 8),
                PrivacyAmount(
                  _fmt.format(h.amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (progress != null && sip != null && sip.hasSchedule) ...[
          const SizedBox(height: 2),
          AnimatedProgressBar(
            value: progress.fraction ?? 0,
            color: AppColors.gold,
            backgroundColor: colors.cardAlt,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                context.l10n
                    .instalmentsProgress(progress.completed, progress.total),
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${((progress.fraction ?? 0) * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ],
        if (progress != null && progress.dueThisPeriod && sip != null) ...[
          const SizedBox(height: 10),
          _dueInlinePrompt(colors, sip),
        ],
      ],
    );
  }

  /// The "same prompt" the notification sends — shown inline on a due plan.
  Widget _dueInlinePrompt(AppColors colors, Sip sip) {
    final amt = sip.amount != null ? '${_fmt.format(sip.amount)} ' : '';
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.didYouInvestThisMonth(amt),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _answerDue(sip, didInvest: false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(context.l10n.no),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _answerDue(sip, didInvest: true),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(context.l10n.yesIDid),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "₹5,000 · 5th monthly" or "₹5,000 · 5th · Jan '26 – Dec '26".
  String _scheduleLine(Sip sip) {
    final amt = sip.amount != null
        ? _fmt.format(sip.amount)
        : context.l10nRead.variableAmount;
    if (sip.hasSchedule) {
      return context.l10nRead.scheduleRange(
        amt,
        sip.dayOfMonth,
        sip.startDate!,
        sip.endDate!,
      );
    }
    return context.l10nRead.scheduleMonthly(amt, sip.dayOfMonth);
  }

  Widget _statusChip(AppColors colors, SipProgress p) {
    final sip = p.sip;
    final now = DateTime.now();
    final due = sip.dueDateInMonth(now.year, now.month);
    final today = DateTime(now.year, now.month, now.day);

    String label;
    Color color;
    if (p.isComplete) {
      label = context.l10n.statusCompleted;
      color = colors.success;
    } else if (p.dueThisPeriod) {
      label = context.l10n.statusDue;
      color = AppColors.gold;
    } else if (due.isAfter(today)) {
      final next = sip.nextDueOnOrAfter(today) ?? due;
      label = context.l10n.nextDue(next);
      color = colors.textSecondary;
    } else {
      label = context.l10n.statusLogged;
      color = colors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ==================== GENERIC SECTION (other assets / liabilities) ====
  Widget _buildSection(
    AppColors colors, {
    required String title,
    required double total,
    required List<Holding> items,
    bool negative = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              PrivacyAmount(
                '${negative ? '−' : ''}${_fmt.format(total)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: negative ? colors.danger : colors.text,
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) const SizedBox(height: 6),
          for (final h in items) _holdingRow(colors, h, negative: negative),
        ],
      ),
    );
  }

  Widget _holdingRow(AppColors colors, Holding h, {bool negative = false}) {
    return InkWell(
      onTap: () => _openEditor(existingHolding: h),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CustomTagService.colorFromName(h.category)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(HoldingCategories.icon(h.category),
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    h.category,
                    style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            PrivacyAmount(
              '${negative ? '−' : ''}${_fmt.format(h.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: negative ? colors.danger : colors.text,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _investedViaSmsNote(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Text('🤖', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: PrivacyAmount(
              context.l10n.investedViaSmsNote(_fmt.format(_investedViaSms)),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EMPTY ====================
  Widget _buildEmpty(AppColors colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Icon(Icons.account_balance_wallet_outlined,
            size: 60, color: colors.textTertiary),
        const SizedBox(height: 16),
        Center(
          child: Text(
            context.l10n.trackYourNetWorth,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.netWorthEmptyDesc,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.45, color: colors.textSecondary),
        ),
        if (_investedViaSms > 0) ...[
          const SizedBox(height: 16),
          _investedViaSmsNote(colors),
        ],
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addFirstHolding),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration(AppColors colors) => BoxDecoration(
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
      );

  // ==================== ACTIONS ====================

  Future<void> _openEditor({Holding? existingHolding, Sip? existingSip}) async {
    final changed = await showHoldingEditor(
      context,
      existingHolding: existingHolding,
      existingSip: existingSip,
    );
    if (changed) {
      await _load();
      if (mounted) {
        showAppToast(context,
            message: existingHolding != null
                ? context.l10nRead.savedToast
                : context.l10nRead.addedToast,
            type: AppToastType.success);
      }
    }
  }

  /// Answer the inline due prompt for a single plan.
  Future<void> _answerDue(Sip sip, {required bool didInvest}) async {
    if (didInvest) {
      await _sipService.confirmCurrentInstallment(sip, amount: sip.amount);
    } else {
      await _sipService.skipCurrentInstallment(sip);
    }
    await _load();
    if (mounted) {
      showAppToast(
        context,
        message: didInvest
            ? context.l10nRead.addedToNetWorth(_fmt.format(sip.amount ?? 0))
            : context.l10nRead.markedNotDone,
        type: didInvest ? AppToastType.success : AppToastType.info,
      );
    }
  }

  /// Walk through every due-and-unresolved plan (deep-link from the alert).
  Future<void> _reviewDueSips() async {
    final sips = await _db.getSips();
    for (final sip in sips) {
      final p = await _sipService.progressFor(sip);
      if (!p.dueThisPeriod) continue;
      if (!mounted) return;
      await _confirmSip(sip);
    }
    await _load();
  }

  /// "Investment Alert" dialog (Yes/No) for one plan.
  Future<void> _confirmSip(Sip sip) async {
    final amountCtrl = TextEditingController(
      text: sip.amount?.toStringAsFixed(0) ?? '',
    );
    var result = '';

    await showAppDialog(
      context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AppDialog(
          icon: Icons.notifications_active_outlined,
          title: context.l10nRead.didYouInvestIn(sip.name),
          subtitle: context.l10nRead.confirmInstalmentDesc,
          content: sip.amount != null
              ? Row(
                  children: [
                    Text(context.l10nRead.amount,
                        style: TextStyle(
                            fontSize: 13.5, color: colors.textSecondary)),
                    const Spacer(),
                    Text(
                      _fmt.format(sip.amount),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ],
                )
              : TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.l10nRead.amountInvested,
                    prefixText: '₹ ',
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () {
                result = 'no';
                Navigator.pop(ctx);
              },
              child: Text(context.l10nRead.no),
            ),
            ElevatedButton(
              onPressed: () {
                result = 'yes';
                Navigator.pop(ctx);
              },
              child: Text(context.l10nRead.yesIDid),
            ),
          ],
        );
      },
    );

    if (result == 'yes') {
      final amount = sip.amount ?? double.tryParse(amountCtrl.text.trim());
      if (amount == null || amount <= 0) {
        if (mounted) {
          showAppToast(context,
              message: context.l10nRead.enterValidAmount,
              type: AppToastType.warning);
        }
      } else {
        await _sipService.confirmCurrentInstallment(sip, amount: amount);
        if (mounted) {
          showAppToast(context,
              message: context.l10nRead.addedToNetWorth(_fmt.format(amount)),
              type: AppToastType.success);
        }
      }
    } else if (result == 'no') {
      await _sipService.skipCurrentInstallment(sip);
      if (mounted) {
        showAppToast(context,
            message: context.l10nRead.markedNotDone, type: AppToastType.info);
      }
    }
    amountCtrl.dispose();
  }

}
