import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../providers/app_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass.dart';
import '../widgets/merchant_bar.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';

/// Detailed insights for a single per-category budget: an animated spend
/// gauge, a daily-pace hint, and a merchant-wise breakdown of where the
/// money in this category actually goes.
class CategoryBudgetInsightsScreen extends StatefulWidget {
  final String category;
  final Budget? initialBudget;

  const CategoryBudgetInsightsScreen({
    super.key,
    required this.category,
    this.initialBudget,
  });

  @override
  State<CategoryBudgetInsightsScreen> createState() =>
      _CategoryBudgetInsightsScreenState();
}

class _CategoryBudgetInsightsScreenState
    extends State<CategoryBudgetInsightsScreen> {
  final DatabaseService _db = DatabaseService();

  Budget? _budget;
  double _spent = 0;
  List<Map<String, dynamic>> _merchants = [];
  bool _loading = true;

  final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _budget = widget.initialBudget;
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final budget =
        widget.initialBudget ?? await _db.getActiveBudget(category: widget.category);

    final start = budget?.currentPeriodStart ?? DateTime(now.year, now.month, 1);
    final end = budget?.currentPeriodEnd ??
        DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final spent = await _db.getSpendingForPeriod(
      startDate: start,
      endDate: end,
      category: widget.category,
    );
    final merchants = await _db.getMerchantBreakdownForCategory(
      category: widget.category,
      startDate: start,
      endDate: end,
    );

    if (!mounted) return;
    setState(() {
      _budget = budget;
      _spent = spent;
      _merchants = merchants;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              ExpenseCategories.getIcon(widget.category),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.l10n.categoryName(widget.category),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_budget != null)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: context.l10n.editBudget,
              onPressed: _editBudget,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AmbientBackground(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    FadeSlideIn(order: 0, child: _buildGaugeCard(colors)),
                    const SizedBox(height: 16),
                    FadeSlideIn(order: 1, child: _buildMerchantCard(colors)),
                  ],
                ),
              ),
            ),
    );
  }

  // ==================== GAUGE ====================
  Widget _buildGaugeCard(AppColors colors) {
    final budget = _budget;
    final amount = budget?.amount ?? 0;
    final pct = amount > 0 ? (_spent / amount) : 0.0;
    final remaining = amount - _spent;

    final ringColor = pct >= 1
        ? AppColors.dangerDark
        : pct >= 0.9
            ? const Color(0xFFD79A3C)
            : AppColors.of(context).brandAccent;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.of(context).brandAccent.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.categoryBudgetUpper,
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).brandAccent,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ringColor.withAlpha(36),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: ringColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 168,
            width: 168,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 168,
                  width: 168,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct.clamp(0, 1).toDouble()),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, animated, _) => CircularProgressIndicator(
                      value: animated,
                      strokeWidth: 13,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation(ringColor),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PrivacyAnimatedAmount(
                      value: _spent,
                      formatter: _fmt,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PrivacyAmount(
                      'of ${_fmt.format(amount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildRemainingPill(remaining),
          const SizedBox(height: 10),
          _buildPaceHint(remaining, colors),
        ],
      ),
    );
  }

  Widget _buildRemainingPill(double remaining) {
    final ok = remaining >= 0;
    final color = ok ? AppColors.successDark : AppColors.dangerDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ok ? Icons.savings_outlined : Icons.warning_amber_rounded,
              color: color, size: 20),
          const SizedBox(width: 8),
          PrivacyAmount(
            ok
                ? '${_fmt.format(remaining)} left this month'
                : '${_fmt.format(remaining.abs())} over budget',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// "₹X/day to stay under" — a gentle daily-allowance nudge.
  Widget _buildPaceHint(double remaining, AppColors colors) {
    final now = DateTime.now();
    final budget = _budget;
    // Only meaningful for the live month.
    final isCurrentMonth = budget == null ||
        (budget.currentPeriodStart.year == now.year &&
            budget.currentPeriodStart.month == now.month);
    if (!isCurrentMonth || remaining < 0) return const SizedBox.shrink();

    final end = budget?.currentPeriodEnd ??
        DateTime(now.year, now.month + 1, 0);
    final daysLeft = end.difference(DateTime(now.year, now.month, now.day)).inDays + 1;
    if (daysLeft <= 0) return const SizedBox.shrink();
    final perDay = remaining / daysLeft;
    final hidden = context.select<AppPreferences, bool>((p) => p.amountsHidden);
    final text = '$daysLeft day${daysLeft == 1 ? '' : 's'} left · '
        '${_fmt.format(perDay)}/day to stay under';

    return Text(
      hidden ? maskRupeeFigures(text) : text,
      style: TextStyle(
        fontSize: 12.5,
        color: Colors.white.withOpacity(0.6),
      ),
    );
  }

  // ==================== MERCHANT BREAKDOWN ====================
  Widget _buildMerchantCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              Icon(Icons.storefront_outlined, size: 18, color: colors.textSecondary),
              const SizedBox(width: 8),
              Text(
                context.l10n.whereItGoes,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n
                .topMerchantsIn(context.l10n.categoryName(widget.category)),
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_merchants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  context.l10n.noSpendingInCategory,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            )
          else
            ..._buildMerchantRows(colors),
        ],
      ),
    );
  }

  List<Widget> _buildMerchantRows(AppColors colors) {
    final top = (_merchants.first['total'] as double).clamp(1, double.infinity);
    final accent = ExpenseCategories.getColor(widget.category);
    final rows = <Widget>[];

    for (var i = 0; i < _merchants.length; i++) {
      final m = _merchants[i];
      final name = m['merchant'] as String;
      final total = m['total'] as double;
      final count = m['count'] as int;
      final fraction = (total / top).clamp(0.0, 1.0).toDouble();

      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i == _merchants.length - 1 ? 0 : 14),
        child: MerchantBar(
          rank: i + 1,
          name: name,
          amountLabel: _fmt.format(total),
          count: count,
          fraction: fraction,
          shareOfTotal: _spent > 0 ? total / _spent : 0.0,
          color: accent,
          isTop: i == 0,
          shareIsCategory: true,
        ),
      ));
    }
    return rows;
  }

  // ==================== EDIT ====================
  Future<void> _editBudget() async {
    final budget = _budget;
    if (budget == null) return;

    final amountCtrl =
        TextEditingController(text: budget.amount.toStringAsFixed(0));

    final action = await showAppDialog<String>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.tune_rounded,
        title: context.l10nRead
            .editCategoryBudget(context.l10nRead.categoryName(widget.category)),
        subtitle: context.l10nRead.setCategoryLimitDesc,
        content: TextField(
          controller: amountCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.l10nRead.monthlyAmount,
            prefixText: '₹ ',
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dangerLight,
            ),
            child: Text(context.l10nRead.commonDelete),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(context.l10nRead.commonSave),
          ),
        ],
      ),
    );

    if (action == 'save') {
      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
      if (amt <= 0) return;
      // Editing the amount resets the alert high-water mark so thresholds are
      // re-evaluated against the new limit.
      await _db.updateBudget(
        budget.copyWith(amount: amt, lastNotifiedThreshold: 0),
      );
      if (mounted) {
        showAppToast(context,
            message: context.l10nRead.budgetUpdated, type: AppToastType.success);
      }
      await _load();
    } else if (action == 'delete') {
      await _db.deleteBudget(budget.id!);
      if (mounted) Navigator.pop(context, true);
    }
    amountCtrl.dispose();
  }
}
