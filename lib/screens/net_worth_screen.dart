import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/holding.dart';
import '../providers/theme_provider.dart';
import '../services/custom_tag_service.dart';
import '../services/database_service.dart';
import '../services/widget_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';

/// Net Worth + Investment tracker: manual holdings (FDs, RDs, MFs, stocks,
/// bonds, gold, savings, loans…) plus the total auto-detected from
/// Investments-tagged transactions. Fully offline; values are user-entered.
class NetWorthScreen extends StatefulWidget {
  const NetWorthScreen({super.key});

  @override
  State<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends State<NetWorthScreen> {
  final DatabaseService _db = DatabaseService();
  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  NetWorthSummary _summary = const NetWorthSummary([]);
  double _investedViaSms = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final holdings = await _db.getHoldings();
    final invested = await _db.getInvestmentsTagTotal();
    // Keep the home-screen widget's net worth in sync with any edits here.
    WidgetService.update();
    if (!mounted) return;
    setState(() {
      _summary = NetWorthSummary(holdings);
      _investedViaSms = invested;
      _loading = false;
    });
  }

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
                child: _summary.isEmpty
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
