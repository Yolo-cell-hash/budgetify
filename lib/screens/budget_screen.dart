import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
import '../models/budget_model.dart';
import '../models/merchant_summary.dart';
import '../models/transaction_model.dart';
import '../providers/app_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/custom_tag_service.dart';
import '../services/database_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/category_donut.dart';
import '../widgets/glass.dart';
import '../widgets/merchant_bar.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/savings_summary.dart';
import '../widgets/spending_calendar.dart';
import 'category_budget_insights_screen.dart';
import 'merchant_detail_screen.dart';
import 'merchants_screen.dart';
import 'transaction_detail_screen.dart';

/// Chart display mode for trends
enum _TrendsChartMode { bar, line }

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;

  Budget? _budget;
  double _spent = 0;
  List<Map<String, dynamic>> _monthlySpending = [];
  bool _loading = true;

  // Month selector - generated list of recent months
  List<DateTime> _availableMonths = [];

  // Overview tab: swipeable month pager with per-month data cache
  late PageController _overviewPageController;
  DateTime _selectedOverviewMonth = DateTime.now();
  final Map<DateTime, _MonthOverviewData> _overviewCache = {};

  // Categories tab month selection
  DateTime _selectedCategoryMonth = DateTime.now();
  Map<String, double> _selectedCategorySpending = {};

  // Per-category budgets (evaluated against the current month) and the
  // "you spend here a lot but have no budget" suggestion.
  static const int _minSuggestionCount = 5;
  List<Budget> _categoryBudgets = [];
  final Map<String, double> _categoryBudgetSpent = {};
  String? _suggestedCategory;
  int _suggestedCount = 0;

  // Whether monetary figures should render masked (privacy mode on, not
  // revealed). Refreshed every build so charts & axis labels track the toggle.
  bool _hideAmounts = false;

  // Trends tab state
  _TrendsChartMode _trendsChartMode = _TrendsChartMode.bar;

  // For expandable months in trends - now category-based
  DateTime? _expandedMonth;
  Map<String, double> _expandedMonthCategories = {};

  // For expandable categories
  String? _expandedCategory;
  List<TransactionModel> _expandedTransactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _overviewPageController = PageController();
    _generateAvailableMonths();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _overviewPageController.dispose();
    super.dispose();
  }

  void _generateAvailableMonths() {
    final now = DateTime.now();
    _availableMonths = List.generate(
      12,
      (i) => DateTime(now.year, now.month - i, 1),
    );
    _selectedOverviewMonth = _availableMonths.first;
    _selectedCategoryMonth = _availableMonths.first;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final budget = await _db.getActiveBudget();
    final monthlySpending = await _db.getMonthlySpending(months: 6);

    double spent = 0;

    if (budget != null) {
      spent = await _db.getSpendingForPeriod(
        startDate: budget.currentPeriodStart,
        endDate: budget.currentPeriodEnd,
      );
    }

    setState(() {
      _budget = budget;
      _spent = spent;
      _monthlySpending = monthlySpending;
      _loading = false;
    });

    // Load data for the overview pager and the categories tab
    await _loadOverviewMonths();
    await _loadCategoryMonth(_selectedCategoryMonth);
    await _loadCategoryBudgets();
  }

  /// Load every per-category budget, its current-month spend, and compute the
  /// single best "set a budget" suggestion (the most-tagged expense category
  /// this month that has no budget yet).
  Future<void> _loadCategoryBudgets() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final budgets = await _db.getCategoryBudgets();
    _categoryBudgetSpent.clear();
    for (final b in budgets) {
      final cat = b.category;
      if (cat == null) continue;
      _categoryBudgetSpent[cat] = await _db.getSpendingForPeriod(
        startDate: b.currentPeriodStart,
        endDate: b.currentPeriodEnd,
        category: cat,
      );
    }

    final counts = await _db.getCategoryTransactionCounts(
      startDate: monthStart,
      endDate: monthEnd,
    );
    final budgeted = budgets.map((b) => b.category).toSet();
    String? suggestion;
    int suggestionCount = 0;
    // counts are ordered most-frequent first, so the first eligible wins.
    for (final entry in counts.entries) {
      if (budgeted.contains(entry.key)) continue;
      if (_suggestionExcluded.contains(entry.key)) continue;
      if (entry.value < _minSuggestionCount) continue;
      suggestion = entry.key;
      suggestionCount = entry.value;
      break;
    }

    if (!mounted) return;
    setState(() {
      _categoryBudgets = budgets;
      _suggestedCategory = suggestion;
      _suggestedCount = suggestionCount;
    });
  }

  /// Categories that aren't really discretionary "spending" you'd cap with a
  /// budget, so they never trigger the suggestion or appear in the picker.
  /// (Self Transfer / Investments are already excluded at the query level.)
  static const Set<String> _suggestionExcluded = {
    'Transfer',
    'Cash Conversion',
    'Salary',
    'Refund',
  };

  /// Preload overview data for every pager month. Months fill in order
  /// (current month first) and the UI refreshes as each arrives, so the
  /// visible page renders immediately.
  Future<void> _loadOverviewMonths() async {
    for (final month in _availableMonths) {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final spent = await _db.getSpendingForPeriod(
        startDate: start,
        endDate: end,
      );

      final transactions = await _db.getTransactionsByDateRange(start, end);
      double income = 0;
      for (final t in transactions) {
        // Self-transfers and investment redemptions aren't real income.
        if (t.type == TransactionType.credit &&
            ExpenseCategories.isIncomeCategory(t.category)) {
          income += t.amount;
        }
      }

      final categories = await _db.getSpendingByCategory(
        startDate: start,
        endDate: end,
      );
      final daily = await _db.getDailySpending(
        startDate: start,
        endDate: end,
      );
      final merchants = await _db.getMerchantBreakdown(
        startDate: start,
        endDate: end,
        limit: 6,
      );

      if (!mounted) return;
      setState(() {
        _overviewCache[month] = _MonthOverviewData(
          spent: spent,
          income: income,
          categories: categories,
          daily: daily,
          merchants: merchants,
        );
      });
    }
  }

  /// Load category spending for a specific month
  Future<void> _loadCategoryMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final catSpending = await _db.getSpendingByCategory(
      startDate: start,
      endDate: end,
    );

    if (mounted) {
      setState(() {
        _selectedCategoryMonth = month;
        _selectedCategorySpending = catSpending;
        // Reset expanded category when month changes
        _expandedCategory = null;
        _expandedTransactions = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _hideAmounts = context.watch<AppPreferences>().amountsHidden;
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.budgetAndAnalytics,
            icon: Icons.donut_small_rounded),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: context.l10n.tabOverview),
            Tab(text: context.l10n.tabCalendar),
            Tab(text: context.l10n.tabCategories),
            Tab(text: context.l10n.tabTrends),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBudgetDialog,
        icon: Icon(_budget == null ? Icons.add : Icons.edit),
        label: Text(_budget == null ? context.l10n.setBudget : context.l10n.commonEdit),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AmbientBackground(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(isDark, fmt),
                  const SpendingCalendar(),
                  _buildCategoriesTab(isDark, fmt),
                  _buildTrendsTab(isDark, fmt),
                ],
              ),
            ),
    );
  }

  // ==================== MONTH SELECTOR ====================
  Widget _buildMonthSelector({
    required DateTime selected,
    required ValueChanged<DateTime> onSelect,
  }) {
    final now = DateTime.now();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _availableMonths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final month = _availableMonths[index];
          final isSelected = month.year == selected.year &&
              month.month == selected.month;
          final isCurrent = month.year == now.year &&
              month.month == now.month;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return GestureDetector(
            onTap: () => onSelect(month),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color(0xFFA8843C)
                    : isDark
                        ? const Color(0xFF262931)
                        : Color(0xFFF6F6F3),
                borderRadius: BorderRadius.circular(20),
                border: isCurrent && !isSelected
                    ? Border.all(color: Color(0xFFC8A75E), width: 1.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                isCurrent
                    ? context.l10n.thisMonth
                    : context.l10n.monthYearShort(month),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isDark
                          ? Color(0xFFD5D5CF)
                          : Color(0xFF4E525C),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== OVERVIEW TAB ====================
  // Swipeable month pager: every month gets the same full view —
  // stats, category donut, and daily spending — instead of the old
  // tap-a-chip selector that only showed a partial summary.
  Widget _buildOverviewTab(bool isDark, NumberFormat fmt) {
    return Column(
      children: [
        const SizedBox(height: 4),
        _buildMonthPagerHeader(isDark),
        Expanded(
          child: PageView.builder(
            controller: _overviewPageController,
            // Current month sits at the right edge; dragging right reveals
            // older months, matching calendar intuition
            reverse: true,
            itemCount: _availableMonths.length,
            onPageChanged: (i) => setState(
              () => _selectedOverviewMonth = _availableMonths[i],
            ),
            itemBuilder: (_, i) =>
                _buildOverviewMonthPage(_availableMonths[i], isDark, fmt),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthPagerHeader(bool isDark) {
    final now = DateTime.now();
    final month = _selectedOverviewMonth;
    final isCurrent = month.year == now.year && month.month == now.month;
    final index = _availableMonths.indexWhere(
      (m) => m.year == month.year && m.month == month.month,
    );
    final colors = AppColors.of(context);

    void goTo(int i) {
      _overviewPageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: index < _availableMonths.length - 1
                ? () => goTo(index + 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  isCurrent
                      ? context.l10n.thisMonth
                      : context.l10n.monthYear(month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: colors.text,
                  ),
                ),
                Text(
                  context.l10n.swipeForOtherMonths,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: index > 0 ? () => goTo(index - 1) : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMonthPage(
    DateTime month,
    bool isDark,
    NumberFormat fmt,
  ) {
    final data = _overviewCache[month];
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final hasBudgetGauge = isCurrentMonth && _budget != null;
    final hasData = data.spent > 0 || data.income > 0;
    var order = 0;

    if (!hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: AppColors.of(context).textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.noActivityIn(context.l10n.monthYear(month)),
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          if (hasBudgetGauge) ...[
            FadeSlideIn(order: order++, child: _buildProgressCard(isDark, fmt)),
            const SizedBox(height: 16),
          ],
          FadeSlideIn(
            order: order++,
            child: _buildMonthStatsCard(data, isDark, fmt),
          ),
          if (data.categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            FadeSlideIn(
              order: order++,
              child: _buildOverviewCard(
                isDark: isDark,
                title: context.l10n.whereItWent,
                child: CategoryDonut(spending: data.categories),
              ),
            ),
          ],
          if (data.daily.isNotEmpty) ...[
            const SizedBox(height: 16),
            FadeSlideIn(
              order: order++,
              child: _buildMonthDailyChart(month, data, isDark),
            ),
          ],
          if (data.merchants.isNotEmpty) ...[
            const SizedBox(height: 16),
            FadeSlideIn(
              order: order++,
              child: _buildTopMerchantsCard(month, data, isDark),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Card shell shared by the overview sections.
  Widget _buildOverviewCard({
    required bool isDark,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262931) : const Color(0xFFE9E9E4),
        ),
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// Income / Expenses / Net for the selected month.
  Widget _buildMonthStatsCard(
    _MonthOverviewData data,
    bool isDark,
    NumberFormat fmt,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262931) : const Color(0xFFE9E9E4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  label: context.l10n.commonIncome,
                  amount: data.income,
                  fmt: fmt,
                  color: const Color(0xFF2AA76F),
                  icon: Icons.arrow_downward,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
                  label: context.l10n.commonExpenses,
                  amount: data.spent,
                  fmt: fmt,
                  color: const Color(0xFFD25A5F),
                  icon: Icons.arrow_upward,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SavingsRateBar(income: data.income, expenses: data.spent),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required double amount,
    required NumberFormat fmt,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PrivacyAmount(
            fmt.format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildProgressCard(bool isDark, NumberFormat fmt) {
    final pct = _budget!.amount > 0 ? _spent / _budget!.amount : 0.0;
    final remaining = _budget!.amount - _spent;
    final colors = AppColors.of(context);
    final hero = HeroStyle.of(context);
    // Gauge color: gold while healthy, amber near the limit, rose when over
    final color = pct >= 1
        ? colors.danger
        : pct >= 0.9
        ? const Color(0xFFD79A3C)
        : AppColors.gold;
    final pillColor = remaining >= 0 ? colors.success : colors.danger;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: hero.gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hero.border),
        boxShadow: hero.shadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _budget!.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: hero.accent,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withAlpha(36),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 160,
            width: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct.clamp(0, 1).toDouble()),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, animated, _) {
                      return CircularProgressIndicator(
                        value: animated,
                        strokeWidth: 12,
                        strokeCap: StrokeCap.round,
                        backgroundColor: hero.foregroundAlpha(0.10),
                        valueColor: AlwaysStoppedAnimation(color),
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PrivacyAnimatedAmount(
                      value: _spent,
                      formatter: fmt,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: hero.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PrivacyAmount(
                      context.l10n.budgetOf(fmt.format(_budget!.amount)),
                      style: TextStyle(
                        fontSize: 12,
                        color: hero.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pillColor.withAlpha(28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pillColor.withAlpha(60)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  remaining >= 0 ? Icons.savings_outlined : Icons.warning_amber,
                  color: pillColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                PrivacyAmount(
                  remaining >= 0
                      ? context.l10n.amountLeft(fmt.format(remaining))
                      : context.l10n.amountOver(fmt.format(remaining.abs())),
                  style: TextStyle(
                    color: pillColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Top merchants for [month]: the 5 biggest, each tappable to drill in,
  /// plus "See all" to the full merchant list. Reuses the shared MerchantBar.
  Widget _buildTopMerchantsCard(
    DateTime month,
    _MonthOverviewData data,
    bool isDark,
  ) {
    final colors = AppColors.of(context);
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final summary = MerchantSummary.fromRows(data.merchants);
    final top = summary.merchants.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.storefront_outlined,
                  size: 18, color: colors.textSecondary),
              const SizedBox(width: 8),
              Text(
                context.l10n.topMerchants,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MerchantsScreen(month: month),
                  ),
                ).then((_) => _loadData()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.goldDeep,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(context.l10n.seeAllLower),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            MerchantBar(
              rank: i + 1,
              name: top[i].name,
              amountLabel: fmt.format(top[i].total),
              count: top[i].count,
              fraction: summary.barFraction(top[i]),
              shareOfTotal: summary.share(top[i]),
              color: CustomTagService.colorFromName(top[i].name),
              isTop: i == 0,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MerchantDetailScreen(
                    merchant: top[i].name,
                    month: month,
                  ),
                ),
              ).then((_) => _loadData()),
            ),
          ],
        ],
      ),
    );
  }

  /// Cumulative spending across [month]. When viewing the current month
  /// with an active budget, a dashed budget pace line is drawn for context.
  Widget _buildMonthDailyChart(
    DateTime month,
    _MonthOverviewData data,
    bool isDark,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final days = end.difference(start).inDays + 1;

    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final showBudgetLine = isCurrentMonth && _budget != null;

    List<FlSpot> spots = [];
    double cum = 0;
    double maxCum = 0;
    for (
      int i = 0;
      i < days &&
          start
              .add(Duration(days: i))
              .isBefore(DateTime.now().add(const Duration(days: 1)));
      i++
    ) {
      final day = DateTime(start.year, start.month, start.day + i);
      cum += data.daily[day] ?? 0;
      if (cum > maxCum) maxCum = cum;
      spots.add(FlSpot(i.toDouble(), cum));
    }

    // Scale Y-axis to fit whichever is larger: the budget or actual spending
    final reference = showBudgetLine ? _budget!.amount : 0.0;
    final chartMaxY =
        ((maxCum > reference ? maxCum : reference) * 1.15).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262931) : const Color(0xFFE9E9E4),
        ),
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
          Text(
            context.l10n.dailySpending,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: spots.isEmpty
                ? Center(child: Text(context.l10n.noDataYet))
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (days - 1).toDouble(),
                      minY: 0,
                      maxY: chartMaxY,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (v, _) => Text(
                              _hideAmounts
                                  ? '₹•••'
                                  : '₹${(v / 1000).toStringAsFixed(0)}k',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 25,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt() + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        if (showBudgetLine)
                          LineChartBarData(
                            spots: [
                              FlSpot(0, 0),
                              FlSpot((days - 1).toDouble(), _budget!.amount),
                            ],
                            isCurved: false,
                            color: Color(0xFF8A8D96),
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            dashArray: [5, 5],
                          ),
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Color(0xFFA8843C),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Color(0xFFA8843C).withAlpha(40),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== CATEGORIES TAB ====================
  Widget _buildCategoriesTab(bool isDark, NumberFormat fmt) {
    final spendingData = _selectedCategorySpending;
    final now = DateTime.now();
    final isCurrentMonth = _selectedCategoryMonth.year == now.year &&
        _selectedCategoryMonth.month == now.month;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FadeSlideIn(
            order: 0,
            child: _buildMonthSelector(
              selected: _selectedCategoryMonth,
              onSelect: _loadCategoryMonth,
            ),
          ),
          // Per-category budgets only make sense for the live month.
          if (isCurrentMonth) ...[
            const SizedBox(height: 16),
            FadeSlideIn(
              order: 1,
              child: _buildCategoryBudgetsSection(isDark, fmt),
            ),
          ],
          const SizedBox(height: 16),
          if (spendingData.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(Icons.pie_chart_outline, size: 48, color: Color(0xFF9A9DA6)),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.noSpendingThisMonth,
                    style: TextStyle(color: Color(0xFF8A8D96)),
                  ),
                ],
              ),
            )
          else ...[
            FadeSlideIn(
              order: 1,
              child: _buildCategoryPieChart(spendingData, isDark),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              order: 2,
              child: Column(
                children: _buildCategoryList(spendingData, fmt, isDark),
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(Map<String, double> spending, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF262931) : const Color(0xFFE9E9E4),
        ),
      ),
      // The expandable category list below the chart carries the detail,
      // so the donut stays legend-free here
      child: CategoryDonut(spending: spending, showLegend: false),
    );
  }

  List<Widget> _buildCategoryList(
    Map<String, double> spending,
    NumberFormat fmt,
    bool isDark,
  ) {
    final total = spending.values.fold(0.0, (a, b) => a + b);
    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map(
      (e) => _buildExpandableCategoryItem(
        e.key,
        e.value,
        total,
        fmt,
        isDark,
      ),
    ).toList();
  }

  Widget _buildExpandableCategoryItem(
    String category,
    double amount,
    double total,
    NumberFormat fmt,
    bool isDark,
  ) {
    final isExpanded = _expandedCategory == category;
    final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            if (isExpanded) {
              setState(() {
                _expandedCategory = null;
                _expandedTransactions = [];
              });
            } else {
              // Load transactions for this category in the selected month
              final start = DateTime(
                _selectedCategoryMonth.year,
                _selectedCategoryMonth.month,
                1,
              );
              final end = DateTime(
                _selectedCategoryMonth.year,
                _selectedCategoryMonth.month + 1,
                0,
                23, 59, 59,
              );
              final allCatTxns = await _db.getTransactionsByCategory(category);
              final filtered = allCatTxns.where((t) {
                return t.detectedAt.isAfter(start.subtract(const Duration(days: 1))) &&
                    t.detectedAt.isBefore(end.add(const Duration(days: 1)));
              }).toList();

              setState(() {
                _expandedCategory = category;
                _expandedTransactions = filtered;
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: isExpanded
                  ? Border.all(
                      color: ExpenseCategories.getColor(category),
                      width: 2,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ExpenseCategories.getColor(category).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      ExpenseCategories.getIcon(category),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${(amount / total * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: isDark ? Color(0xFF9A9DA6) : Color(0xFF8A8D96),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PrivacyAmount(
                  fmt.format(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Color(0xFF8A8D96),
                ),
              ],
            ),
          ),
        ),
        // Expanded transaction list
        if (isExpanded && _expandedTransactions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12, left: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121318) : Color(0xFFFAFAF8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: _expandedTransactions.take(10).map((txn) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(transaction: txn),
                      ),
                    ).then((_) => _loadData());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn.merchantName ?? txn.sender,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                context.l10n.mediumDate(txn.detectedAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Color(0xFF8A8D96)
                                      : Color(0xFF8A8D96),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PrivacyAmount(
                          fmt.format(txn.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: txn.type == TransactionType.credit
                                ? Color(0xFF2AA76F)
                                : Color(0xFFD25A5F),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: isDark ? Color(0xFF6E727C) : Color(0xFF9A9DA6),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ==================== TRENDS TAB ====================
  Widget _buildTrendsTab(bool isDark, NumberFormat fmt) {
    if (_monthlySpending.isEmpty) {
      return Center(child: Text(context.l10n.noHistoricalData));
    }

    final maxValue = _monthlySpending
        .map((m) => m['total'] as double)
        .reduce((a, b) => a > b ? a : b);
    final maxY = maxValue > 0 ? maxValue * 1.2 : 1000.0;
    final monthFormat = DateFormat('MMM');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FadeSlideIn(
            order: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16181E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF262931)
                      : const Color(0xFFE9E9E4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.monthlySpendingTrend,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      _buildTrendsChartToggle(isDark),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: _trendsChartMode == _TrendsChartMode.bar
                          ? _buildTrendsBarChart(maxY, monthFormat, isDark)
                          : _buildTrendsLineChart(maxY, monthFormat, isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Monthly breakdown list - Expandable with category data
          FadeSlideIn(
            order: 1,
            child: Column(
              children: (_monthlySpending.reversed.toList()).map((m) {
                final month = m['month'] as DateTime;
                final total = m['total'] as double;
                return _buildExpandableMonthItem(month, total, fmt, isDark);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Toggle control for bar/line chart mode in Trends
  Widget _buildTrendsChartToggle(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262931) : Color(0xFFF6F6F3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleBtn(
            icon: Icons.bar_chart_rounded,
            isSelected: _trendsChartMode == _TrendsChartMode.bar,
            onTap: () => setState(() => _trendsChartMode = _TrendsChartMode.bar),
            isDark: isDark,
          ),
          _buildToggleBtn(
            icon: Icons.show_chart_rounded,
            isSelected: _trendsChartMode == _TrendsChartMode.line,
            onTap: () => setState(() => _trendsChartMode = _TrendsChartMode.line),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Color(0xFFA8843C) : Color(0xFFA8843C))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected
              ? Colors.white
              : (isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C)),
        ),
      ),
    );
  }

  Widget _buildTrendsBarChart(double maxY, DateFormat monthFormat, bool isDark) {
    return BarChart(
      key: const ValueKey('trends_bar'),
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        // Match the line chart's dark tooltip with light text — the default
        // bar tooltip is a light surface with black text, unreadable here.
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF2E313A),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                _hideAmounts ? '₹••••' : '₹${rod.toY.toStringAsFixed(0)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: _buildTrendsTitles(monthFormat),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: _monthlySpending.asMap().entries.map((e) {
          final isCurrentMonth = e.key == _monthlySpending.length - 1;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value['total'],
                color: isCurrentMonth
                    ? Color(0xFFA8843C)
                    : Color(0xFFA8843C).withAlpha(120),
                width: 24,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendsLineChart(double maxY, DateFormat monthFormat, bool isDark) {
    return LineChart(
      key: const ValueKey('trends_line'),
      LineChartData(
        maxY: maxY,
        minY: 0,
        titlesData: _buildTrendsTitles(monthFormat),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Color(0xFF2E313A),
            getTooltipItems: (spots) => spots.map((spot) {
              return LineTooltipItem(
                _hideAmounts ? '₹••••' : '₹${spot.y.toStringAsFixed(0)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _monthlySpending.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), (e.value['total'] as double));
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: Color(0xFFA8843C),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isLast = index == _monthlySpending.length - 1;
                return FlDotCirclePainter(
                  radius: isLast ? 5 : 3.5,
                  color: isLast ? Color(0xFFA8843C) : Color(0xFFD8BC7E),
                  strokeWidth: isLast ? 2.5 : 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Color(0xFFA8843C).withAlpha(80),
                  Color(0xFFA8843C).withAlpha(10),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  FlTitlesData _buildTrendsTitles(DateFormat monthFormat) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          getTitlesWidget: (v, _) => Text(
            _hideAmounts ? '₹•••' : '₹${(v / 1000).toStringAsFixed(0)}k',
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (v, _) {
            if (v.toInt() < _monthlySpending.length) {
              return Text(
                context.l10nRead.monthAbbr(
                  (_monthlySpending[v.toInt()]['month'] as DateTime).month,
                ),
                style: const TextStyle(fontSize: 10),
              );
            }
            return const Text('');
          },
        ),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  Widget _buildExpandableMonthItem(
    DateTime month,
    double total,
    NumberFormat fmt,
    bool isDark,
  ) {
    final isCurrentMonth =
        month.month == DateTime.now().month &&
        month.year == DateTime.now().year;
    final isExpanded =
        _expandedMonth?.month == month.month &&
        _expandedMonth?.year == month.year;
    final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            if (isExpanded) {
              setState(() {
                _expandedMonth = null;
                _expandedMonthCategories = {};
              });
            } else {
              // Load category-wise spending for this month
              final start = DateTime(month.year, month.month, 1);
              final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
              final catSpending = await _db.getSpendingByCategory(
                startDate: start,
                endDate: end,
              );
              setState(() {
                _expandedMonth = month;
                _expandedMonthCategories = catSpending;
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: isCurrentMonth
                  ? Border.all(color: Color(0xFFA8843C), width: 2)
                  : isExpanded
                  ? Border.all(color: Color(0xFFC8A75E), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                if (isCurrentMonth)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFFA8843C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      context.l10n.nowBadge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    context.l10n.monthYear(month),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                PrivacyAmount(
                  fmt.format(total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Color(0xFF8A8D96),
                ),
              ],
            ),
          ),
        ),
        // Expanded category breakdown
        if (isExpanded && _expandedMonthCategories.isNotEmpty)
          _buildExpandedMonthCategories(fmt, isDark, total),
      ],
    );
  }

  /// Build category-wise breakdown for an expanded month in Trends
  Widget _buildExpandedMonthCategories(
    NumberFormat fmt,
    bool isDark,
    double monthTotal,
  ) {
    final sorted = _expandedMonthCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final catTotal = _expandedMonthCategories.values.fold(0.0, (a, b) => a + b);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121318) : Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Mini pie chart
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: sorted.take(6).map((e) {
                  final pct = catTotal > 0 ? (e.value / catTotal * 100) : 0.0;
                  return PieChartSectionData(
                    value: e.value,
                    color: ExpenseCategories.getColor(e.key),
                    title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                    radius: 35,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Category list
          ...sorted.map((e) {
            final pct = catTotal > 0 ? (e.value / catTotal * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ExpenseCategories.getColor(e.key).withAlpha(30),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(
                        ExpenseCategories.getIcon(e.key),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Color(0xFF8A8D96) : Color(0xFF8A8D96),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PrivacyAmount(
                    fmt.format(e.value),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== CATEGORY BUDGETS ====================

  /// The suggestion hint (when applicable) plus the list of category budgets
  /// and an "add" affordance. Lives at the top of the Categories tab.
  Widget _buildCategoryBudgetsSection(bool isDark, NumberFormat fmt) {
    final colors = AppColors.of(context);
    final prefs = context.watch<AppPreferences>();
    final showSuggestion = _suggestedCategory != null &&
        !prefs.isBudgetSuggestionDismissed(_suggestedCategory!);

    return Column(
      children: [
        if (showSuggestion) ...[
          _buildSuggestionHint(colors),
          const SizedBox(height: 12),
        ],
        Container(
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
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, size: 18, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.categoryBudgets,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCategoryBudgetDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.add),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.goldDeep,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (_categoryBudgets.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 6, 8, 4),
                  child: Text(
                    context.l10n.categoryBudgetsEmptyDesc,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      for (final b in _categoryBudgets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildCategoryBudgetRow(b, fmt, colors),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionHint(AppColors colors) {
    final cat = _suggestedCategory!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withOpacity(0.16),
            AppColors.gold.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withAlpha(40),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              ExpenseCategories.getIcon(cat),
              style: const TextStyle(fontSize: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.setBudgetForCategory(cat),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.suggestionMostTagged(_suggestedCount),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () =>
                        _showCategoryBudgetDialog(presetCategory: cat),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(context.l10n.setBudgetLower),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: colors.textTertiary,
            tooltip: context.l10n.notNow,
            onPressed: () =>
                context.read<AppPreferences>().dismissBudgetSuggestion(cat),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetRow(Budget b, NumberFormat fmt, AppColors colors) {
    final cat = b.category!;
    final spent = _categoryBudgetSpent[cat] ?? 0;
    final pct = b.amount > 0 ? spent / b.amount : 0.0;
    final over = spent > b.amount;
    final barColor = pct >= 1
        ? colors.danger
        : pct >= 0.9
            ? const Color(0xFFD79A3C)
            : AppColors.gold;

    return PressableScale(
      onTap: () => _openCategoryInsights(b),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF121318) : const Color(0xFFFAFAF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ExpenseCategories.getColor(cat).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    ExpenseCategories.getIcon(cat),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      PrivacyAmount(
                        context.l10n.budgetSpentOf(
                            fmt.format(spent), fmt.format(b.amount)),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(pct * 100).clamp(0, 999).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: barColor,
                      ),
                    ),
                    if (over)
                      Text(
                        context.l10n.over,
                        style: TextStyle(fontSize: 10, color: colors.danger),
                      ),
                  ],
                ),
                Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedProgressBar(
              value: pct,
              color: barColor,
              backgroundColor: colors.border,
            ),
          ],
        ),
      ),
    );
  }

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  void _openCategoryInsights(Budget b) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryBudgetInsightsScreen(
          category: b.category!,
          initialBudget: b,
        ),
      ),
    ).then((_) => _loadData());
  }

  /// Add a per-category budget. [presetCategory] pre-selects a category (used
  /// by the suggestion hint).
  Future<void> _showCategoryBudgetDialog({String? presetCategory}) async {
    final budgeted =
        _categoryBudgets.map((b) => b.category).whereType<String>().toSet();
    final available = ExpenseCategories.allCategories
        .where((c) =>
            !budgeted.contains(c) &&
            !_suggestionExcluded.contains(c) &&
            ExpenseCategories.isExpenseCategory(c))
        .toList();

    if (available.isEmpty) {
      showAppToast(
        context,
        message: context.l10nRead.everyCategoryHasBudget,
        type: AppToastType.info,
      );
      return;
    }

    var selected = (presetCategory != null && available.contains(presetCategory))
        ? presetCategory
        : available.first;
    final amountCtrl = TextEditingController();
    var saved = false;

    await showAppDialog(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.flag_outlined,
        title: context.l10nRead.newCategoryBudget,
        subtitle: context.l10nRead.newCategoryBudgetDesc,
        content: StatefulBuilder(
          builder: (ctx, setLocal) {
            final colors = AppColors.of(ctx);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount first so it (and the confirm button) is always in
                // view above the keyboard, regardless of the category list.
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10nRead.monthlyAmount,
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      context.l10nRead.category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selected,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Single-line, horizontally scrollable picker keeps the dialog
                // short. The selected chip auto-stays highlighted in gold.
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = available[i];
                      final isSel = c == selected;
                      return GestureDetector(
                        onTap: () => setLocal(() => selected = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.gold
                                : colors.cardAlt,
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: isSel ? AppColors.gold : colors.border,
                            ),
                          ),
                          child: Text(
                            '${ExpenseCategories.getIcon(c)}  $c',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? const Color(0xFF15110A)
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10nRead.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              await _db.insertBudget(
                Budget(
                  name: selected,
                  amount: amt,
                  category: selected,
                  startDate: DateTime.now(),
                ),
              );
              saved = true;
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(context.l10nRead.setBudgetLower),
          ),
        ],
      ),
    );

    amountCtrl.dispose();
    if (saved) {
      await _loadData();
      if (mounted) {
        showAppToast(
          context,
          message: context.l10nRead.categoryBudgetSet(selected),
          type: AppToastType.success,
        );
      }
    }
  }

  Future<void> _showBudgetDialog() async {
    final nameCtrl = TextEditingController(
      text: _budget?.name ?? 'Monthly Budget',
    );
    final amountCtrl = TextEditingController(
      text: _budget?.amount.toStringAsFixed(0) ?? '',
    );
    final editing = _budget != null;

    await showAppDialog(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.account_balance_wallet_rounded,
        title: editing ? context.l10nRead.editBudget : context.l10nRead.setBudget,
        subtitle: context.l10nRead.budgetDialogDesc,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: context.l10nRead.name),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10nRead.monthlyAmount,
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          if (editing)
            OutlinedButton(
              onPressed: () async {
                await _db.deleteBudget(_budget!.id!);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD25A5F),
              ),
              child: Text(context.l10nRead.commonDelete),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10nRead.commonCancel),
            ),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text) ?? 0;
              if (amt <= 0) return;
              final b = Budget(
                id: _budget?.id,
                name: nameCtrl.text.trim().isEmpty
                    ? 'Monthly Budget'
                    : nameCtrl.text.trim(),
                amount: amt,
                startDate: DateTime.now(),
              );
              editing ? await _db.updateBudget(b) : await _db.insertBudget(b);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: Text(editing ? context.l10nRead.commonSave : context.l10nRead.setBudget),
          ),
        ],
      ),
    );
  }
}

/// Per-month data backing one page of the Overview pager.
class _MonthOverviewData {
  final double spent;
  final double income;
  final Map<String, double> categories;
  final Map<DateTime, double> daily;
  final List<Map<String, dynamic>> merchants;

  const _MonthOverviewData({
    required this.spent,
    required this.income,
    required this.categories,
    required this.daily,
    this.merchants = const [],
  });
}
