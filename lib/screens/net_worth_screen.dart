import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/holding.dart';
import '../models/sip.dart';
import '../providers/theme_provider.dart';
import '../services/custom_tag_service.dart';
import '../services/database_service.dart';
import '../services/sip_service.dart';
import '../services/widget_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/sip_editor_sheet.dart';

/// Net Worth + Investment tracker: manual holdings (FDs, RDs, MFs, stocks,
/// bonds, gold, savings, loans…) plus the total auto-detected from
/// Investments-tagged transactions. Fully offline; values are user-entered.
class NetWorthScreen extends StatefulWidget {
  /// When true (deep-linked from the SIP reminder notification), the screen
  /// opens the "confirm your due instalment" flow as soon as it loads.
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
  List<SipProgress> _sips = [];
  bool _loading = true;
  bool _reviewHandled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Credit any SMS-detected instalments before reading holdings, so detected
    // SIPs show up immediately.
    await _sipService.reconcile();

    final holdings = await _db.getHoldings();
    final invested = await _db.getInvestmentsTagTotal();
    final sips = await _db.getSips();
    final progress = <SipProgress>[
      for (final s in sips) await _sipService.progressFor(s),
    ];
    // Keep the home-screen widget's net worth in sync with any edits here.
    WidgetService.update();
    if (!mounted) return;
    setState(() {
      _summary = NetWorthSummary(holdings);
      _investedViaSms = invested;
      _sips = progress;
      _loading = false;
    });

    // Deep-linked from the evening reminder → walk the user through any due
    // instalments once.
    if (widget.reviewSips && !_reviewHandled) {
      _reviewHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reviewDueSips());
    }
  }

  bool get _hasAnything =>
      !_summary.isEmpty || _sips.isNotEmpty || _investedViaSms > 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Net Worth')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showHoldingDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
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

    final dueSips = _sips.where((p) => p.dueThisPeriod).toList();
    if (dueSips.isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(FadeSlideIn(
            order: order++, child: _buildDueBanner(colors, dueSips)));
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
          order: order++,
          child: _buildSection(
            colors,
            title: 'Investments',
            total: _summary.investments,
            items: _summary.investmentHoldings,
            footer: _investedViaSms > 0 ? _investedViaSmsNote(colors) : null,
          ),
        ));
    }

    // Recurring investments (SIP/RD) — the automation surface. Shows the
    // setup promo until the first plan exists.
    widgets
      ..add(const SizedBox(height: 16))
      ..add(FadeSlideIn(
        order: order++,
        child: _sips.isEmpty ? _buildAutomatePromo(colors) : _buildSipSection(colors),
      ));

    if (_summary.otherAssetHoldings.isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(FadeSlideIn(
          order: order++,
          child: _buildSection(
            colors,
            title: 'Other assets',
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
            title: 'Liabilities',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NET WORTH',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.gold.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          PrivacyAnimatedAmount(
            value: net,
            formatter: _fmt,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroStat('Assets', _summary.assets,
                    AppColors.successDark, Icons.arrow_upward),
              ),
              Container(
                width: 1,
                height: 38,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              Expanded(
                child: _heroStat('Liabilities', _summary.liabilities,
                    AppColors.dangerDark, Icons.arrow_downward,
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
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        PrivacyAmount(
          _fmt.format(value),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: Colors.white,
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
            'Allocation',
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

  // ==================== SECTION ====================
  Widget _buildSection(
    AppColors colors, {
    required String title,
    required double total,
    required List<Holding> items,
    Widget? footer,
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
          if (footer != null) ...[
            const SizedBox(height: 10),
            footer,
          ],
        ],
      ),
    );
  }

  Widget _holdingRow(AppColors colors, Holding h, {bool negative = false}) {
    return InkWell(
      onTap: () => _showHoldingDialog(existing: h),
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
              '${_fmt.format(_investedViaSms)} detected from your '
              'Investments-tagged transactions',
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

  // ==================== RECURRING (SIP / RD) ====================

  /// Prompt card shown until the first plan is created — the "do you want to
  /// automate?" invitation.
  Widget _buildAutomatePromo(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🔁', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Automate your SIPs & RDs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Stop logging every instalment by hand. Set the amount and day once — '
            'we\'ll detect the debit from your SMS, add it to your net worth, and '
            'remind you if it\'s ever missed.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openSipEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Set up automation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSipSection(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recurring (SIP / RD)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openSipEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          for (final p in _sips) _sipRow(colors, p),
        ],
      ),
    );
  }

  Widget _sipRow(AppColors colors, SipProgress p) {
    final sip = p.sip;
    return InkWell(
      onTap: () => _openSipEditor(existing: sip),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                    color: CustomTagService.colorFromName(sip.category)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(HoldingCategories.icon(sip.category),
                      style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sip.name,
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
                        _scheduleSummary(sip),
                        style: TextStyle(
                            fontSize: 11.5, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _statusChip(colors, p),
              ],
            ),
            if (sip.hasSchedule) ...[
              const SizedBox(height: 10),
              AnimatedProgressBar(
                value: p.fraction ?? 0,
                color: AppColors.gold,
                backgroundColor: colors.cardAlt,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${p.completed} of ${p.total} instalments',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '${((p.fraction ?? 0) * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "₹5,000 · 5th monthly" or "₹5,000 · 5th · Jan '26 – Dec '26".
  String _scheduleSummary(Sip sip) {
    final amt = sip.amount != null
        ? _fmt.format(sip.amount)
        : 'Variable';
    final day = '${_ordinalDay(sip.dayOfMonth)} monthly';
    if (sip.hasSchedule) {
      final s = DateFormat("MMM ''yy").format(sip.startDate!);
      final e = DateFormat("MMM ''yy").format(sip.endDate!);
      return '$amt · ${_ordinalDay(sip.dayOfMonth)} · $s – $e';
    }
    return '$amt · $day';
  }

  Widget _statusChip(AppColors colors, SipProgress p) {
    final sip = p.sip;
    final now = DateTime.now();
    final due = sip.dueDateInMonth(now.year, now.month);
    final today = DateTime(now.year, now.month, now.day);

    String label;
    Color color;
    if (p.isComplete) {
      label = 'Completed';
      color = colors.success;
    } else if (p.dueThisPeriod) {
      label = 'Action needed';
      color = AppColors.gold;
    } else if (due.isAfter(today)) {
      final next = sip.nextDueOnOrAfter(today) ?? due;
      label = 'Next ${DateFormat('d MMM').format(next)}';
      color = colors.textSecondary;
    } else {
      label = 'Logged ✓';
      color = colors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// Top-of-screen prompt deep-linked from the evening reminder.
  Widget _buildDueBanner(AppColors colors, List<SipProgress> due) {
    final single = due.length == 1 ? due.first.sip : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  single != null
                      ? 'Did you invest in ${single.name}?'
                      : '${due.length} investments to confirm',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            single != null
                ? 'We couldn\'t auto-detect this month\'s instalment. Confirm it to '
                    'keep your net worth up to date.'
                : 'Some recurring instalments couldn\'t be auto-detected this month.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF15110A),
              ),
              onPressed: _reviewDueSips,
              child: Text(single != null ? 'Review' : 'Review all'),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SIP ACTIONS ====================

  Future<void> _openSipEditor({
    Sip? existing,
    String? prefillName,
    String? prefillCategory,
    double? prefillAmount,
  }) async {
    final changed = await showSipEditor(
      context,
      existing: existing,
      prefillName: prefillName,
      prefillCategory: prefillCategory,
      prefillAmount: prefillAmount,
    );
    if (changed) {
      await _load();
      if (mounted) {
        showAppToast(context,
            message: existing != null ? 'Plan updated' : 'Automation set up',
            type: AppToastType.success);
      }
    }
  }

  /// Walk through every due-and-unresolved plan, asking the user to confirm.
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

  /// "Did you invest?" prompt for a single plan.
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
          icon: Icons.savings_outlined,
          title: 'Did you invest in ${sip.name}?',
          subtitle:
              'We couldn\'t auto-detect this month\'s instalment. If you completed '
              'it, confirm below and we\'ll add it to your net worth.',
          content: sip.amountIsFixed
              ? Row(
                  children: [
                    Text('Amount',
                        style: TextStyle(
                            fontSize: 13.5, color: colors.textSecondary)),
                    const Spacer(),
                    Text(
                      sip.amount != null ? _fmt.format(sip.amount) : '—',
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
                  decoration: const InputDecoration(
                    labelText: 'Amount invested',
                    prefixText: '₹ ',
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () {
                result = 'skip';
                Navigator.pop(ctx);
              },
              child: const Text('Skip this month'),
            ),
            ElevatedButton(
              onPressed: () {
                result = 'yes';
                Navigator.pop(ctx);
              },
              child: const Text('Yes, I did'),
            ),
          ],
        );
      },
    );

    if (result == 'yes') {
      final amount = sip.amountIsFixed
          ? sip.amount
          : double.tryParse(amountCtrl.text.trim());
      if (amount == null || amount <= 0) {
        if (mounted) {
          showAppToast(context,
              message: 'Enter a valid amount', type: AppToastType.warning);
        }
      } else {
        await _sipService.confirmCurrentInstallment(sip, amount: amount);
        if (mounted) {
          showAppToast(context,
              message: 'Added ${_fmt.format(amount)} to net worth',
              type: AppToastType.success);
        }
      }
    } else if (result == 'skip') {
      await _sipService.skipCurrentInstallment(sip);
      if (mounted) {
        showAppToast(context,
            message: 'Skipped this month', type: AppToastType.info);
      }
    }
    amountCtrl.dispose();
  }

  static String _ordinalDay(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
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
            'Track your net worth',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add your FDs, mutual funds, stocks, gold, savings and loans to see '
          'your complete picture — segregated and visualized, all on-device.',
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
            onPressed: () => _showHoldingDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add your first holding'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _openSipEditor(),
            icon: const Text('🔁', style: TextStyle(fontSize: 15)),
            label: const Text('Automate a SIP / RD'),
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

  // ==================== ADD / EDIT ====================
  Future<void> _showHoldingDialog({Holding? existing}) async {
    var kind = existing?.kind ?? HoldingKind.asset;
    var category = existing?.category ?? HoldingCategories.assetCategories.first;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amountCtrl = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(0),
    );
    final editing = existing != null;
    var automate = false;
    var result = '';

    await showAppDialog(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.account_balance_wallet_rounded,
        title: editing ? 'Edit holding' : 'Add holding',
        subtitle: 'Track an investment, savings balance, or a debt. Values are '
            'yours to update anytime.',
        content: StatefulBuilder(
          builder: (ctx, setLocal) {
            final colors = AppColors.of(ctx);
            final cats = HoldingCategories.forKind(kind);
            if (!cats.contains(category)) category = cats.first;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Asset / Liability toggle
                Row(
                  children: [
                    _kindChip(ctx, 'Asset', kind == HoldingKind.asset, () {
                      setLocal(() {
                        kind = HoldingKind.asset;
                        category = HoldingCategories.assetCategories.first;
                      });
                    }),
                    const SizedBox(width: 8),
                    _kindChip(
                        ctx, 'Liability', kind == HoldingKind.liability, () {
                      setLocal(() {
                        kind = HoldingKind.liability;
                        category = HoldingCategories.liabilities.first;
                      });
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = cats[i];
                      final sel = c == category;
                      return GestureDetector(
                        onTap: () => setLocal(() => category = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? AppColors.gold : colors.cardAlt,
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: sel ? AppColors.gold : colors.border,
                            ),
                          ),
                          child: Text(
                            '${HoldingCategories.icon(c)}  $c',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? const Color(0xFF15110A)
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. HDFC Tax Saver FD',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Current value',
                    prefixText: '₹ ',
                  ),
                ),
                if (!editing &&
                    kind == HoldingKind.asset &&
                    HoldingCategories.isInvestment(category)) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      children: [
                        const Text('🔁', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Recurring SIP / RD?',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: colors.text)),
                              const SizedBox(height: 2),
                              Text(
                                  'Automate it instead of logging every month',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: colors.textSecondary)),
                            ],
                          ),
                        ),
                        Switch(
                          value: automate,
                          onChanged: (v) => setLocal(() => automate = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          if (editing)
            OutlinedButton(
              onPressed: () {
                result = 'delete';
                Navigator.pop(ctx);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerLight,
              ),
              child: const Text('Delete'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ElevatedButton(
            onPressed: () {
              result = 'save';
              Navigator.pop(ctx);
            },
            child: Text(editing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );

    // Chose to automate an investment → hand off to the SIP/RD editor instead
    // of creating a one-off holding. The editor seeds its own backing holding.
    if (result == 'save' && automate && !editing) {
      final name = nameCtrl.text.trim();
      nameCtrl.dispose();
      amountCtrl.dispose();
      await _openSipEditor(
        prefillName: name.isEmpty ? null : name,
        prefillCategory: category,
      );
      return;
    }

    if (result == 'save') {
      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
      final name = nameCtrl.text.trim();
      if (amt > 0 && name.isNotEmpty) {
        final holding = Holding(
          id: existing?.id,
          name: name,
          kind: kind,
          category: category,
          amount: amt,
          updatedAt: DateTime.now(),
        );
        if (editing) {
          await _db.updateHolding(holding);
        } else {
          await _db.insertHolding(holding);
        }
        await _load();
        if (mounted) {
          showAppToast(context,
              message: editing ? 'Holding updated' : 'Holding added',
              type: AppToastType.success);
        }
      } else if (mounted) {
        showAppToast(context,
            message: 'Enter a name and a value above ₹0',
            type: AppToastType.warning);
      }
    } else if (result == 'delete' && existing?.id != null) {
      await _db.deleteHolding(existing!.id!);
      await _load();
      if (mounted) {
        showAppToast(context,
            message: 'Holding deleted', type: AppToastType.info);
      }
    }

    nameCtrl.dispose();
    amountCtrl.dispose();
  }

  Widget _kindChip(BuildContext ctx, String label, bool selected, VoidCallback onTap) {
    final colors = AppColors.of(ctx);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : colors.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.gold : colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? const Color(0xFF15110A) : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
