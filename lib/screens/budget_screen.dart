import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
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
  Map<DateTime, double> _dailySpending = {};
  List<Map<String, dynamic>> _monthlySpending = [];
  bool _loading = true;

  // Month selector - generated list of last 6 months
  List<DateTime> _availableMonths = [];

  // Overview tab month selection
  DateTime _selectedOverviewMonth = DateTime.now();
  double _overviewMonthSpent = 0;
  double _overviewMonthIncome = 0;
  Map<String, double> _overviewTopCategories = {};

  // Categories tab month selection
  DateTime _selectedCategoryMonth = DateTime.now();
  Map<String, double> _selectedCategorySpending = {};

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
    _tabController = TabController(length: 3, vsync: this);
    _generateAvailableMonths();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateAvailableMonths() {
    final now = DateTime.now();
    _availableMonths = List.generate(
      6,
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
    Map<DateTime, double> daily = {};

    if (budget != null) {
      spent = await _db.getSpendingForPeriod(
        startDate: budget.currentPeriodStart,
        endDate: budget.currentPeriodEnd,
      );
      daily = await _db.getDailySpending(
        startDate: budget.currentPeriodStart,
        endDate: budget.currentPeriodEnd,
      );
    }

    setState(() {
      _budget = budget;
      _spent = spent;
      _dailySpending = daily;
      _monthlySpending = monthlySpending;
      _loading = false;
    });

    // Load data for default selected months
    await _loadOverviewMonth(_selectedOverviewMonth);
    await _loadCategoryMonth(_selectedCategoryMonth);
  }

  /// Load overview data for a specific month
  Future<void> _loadOverviewMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final spent = await _db.getSpendingForPeriod(
      startDate: start,
      endDate: end,
    );

    // Get income for the month
    final transactions = await _db.getTransactionsByDateRange(start, end);
    double income = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.credit) {
        income += t.amount;
      }
    }

    // Get top categories
    final catSpending = await _db.getSpendingByCategory(
      startDate: start,
      endDate: end,
    );
    // Take top 3
    final sorted = catSpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCats = Map<String, double>.fromEntries(sorted.take(3));

    if (mounted) {
      setState(() {
        _selectedOverviewMonth = month;
        _overviewMonthSpent = spent;
        _overviewMonthIncome = income;
        _overviewTopCategories = topCats;
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
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget & Analytics'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Categories'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBudgetDialog,
        icon: Icon(_budget == null ? Icons.add : Icons.edit),
        label: Text(_budget == null ? 'Set Budget' : 'Edit'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AmbientBackground(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(isDark, fmt),
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
    final monthFormat = DateFormat('MMM yyyy');
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
                isCurrent ? 'This Month' : monthFormat.format(month),
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
  Widget _buildOverviewTab(bool isDark, NumberFormat fmt) {
    final now = DateTime.now();
    final isCurrentMonth = _selectedOverviewMonth.year == now.year &&
        _selectedOverviewMonth.month == now.month;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FadeSlideIn(
            order: 0,
            child: _buildMonthSelector(
              selected: _selectedOverviewMonth,
              onSelect: _loadOverviewMonth,
            ),
          ),
          const SizedBox(height: 16),
          if (isCurrentMonth && _budget != null) ...[
            FadeSlideIn(order: 1, child: _buildProgressCard(isDark, fmt)),
            const SizedBox(height: 20),
            FadeSlideIn(order: 2, child: _buildDailyChart(isDark)),
          ] else ...[
            FadeSlideIn(order: 1, child: _buildMonthSummaryCard(isDark, fmt)),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Summary card for a previous (or current) month when no budget context
  Widget _buildMonthSummaryCard(bool isDark, NumberFormat fmt) {
    final monthName = DateFormat('MMMM yyyy').format(_selectedOverviewMonth);
    final net = _overviewMonthIncome - _overviewMonthSpent;

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
            monthName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          // Income & Expenses row
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  label: 'Income',
                  amount: _overviewMonthIncome,
                  fmt: fmt,
                  color: Color(0xFF2AA76F),
                  icon: Icons.arrow_downward,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
                  label: 'Expenses',
                  amount: _overviewMonthSpent,
                  fmt: fmt,
                  color: Color(0xFFD25A5F),
                  icon: Icons.arrow_upward,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Net balance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: net >= 0 ? Color(0xFF2AA76F).withAlpha(30) : Color(0xFFD25A5F).withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  net >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: net >= 0 ? Color(0xFF2AA76F) : Color(0xFFD25A5F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  net >= 0
                      ? 'Net Savings: ${fmt.format(net)}'
                      : 'Net Deficit: ${fmt.format(net.abs())}',
                  style: TextStyle(
                    color: net >= 0 ? Color(0xFF2AA76F) : Color(0xFFD25A5F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_overviewTopCategories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Top Spending Categories',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Color(0xFFD5D5CF) : Color(0xFF4E525C),
              ),
            ),
            const SizedBox(height: 12),
            ..._overviewTopCategories.entries.map((e) {
              final pct = _overviewMonthSpent > 0
                  ? (e.value / _overviewMonthSpent * 100)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ExpenseCategories.getColor(e.key).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          ExpenseCategories.getIcon(e.key),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: isDark
                                  ? Color(0xFF2E313A)
                                  : Color(0xFFE9E9E4),
                              valueColor: AlwaysStoppedAnimation(
                                ExpenseCategories.getColor(e.key),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      fmt.format(e.value),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
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
          Text(
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
    // Gauge color: gold while healthy, amber near the limit, rose when over
    final color = pct >= 1
        ? const Color(0xFFE8888C)
        : pct >= 0.9
        ? const Color(0xFFD79A3C)
        : AppColors.gold;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
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
                _budget!.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
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
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation(color),
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CountUpAmount(
                      value: _spent,
                      formatter: fmt,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of ${fmt.format(_budget!.amount)}',
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: remaining >= 0
                  ? const Color(0xFF4CC795).withAlpha(28)
                  : const Color(0xFFE8888C).withAlpha(28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: remaining >= 0
                    ? const Color(0xFF4CC795).withAlpha(60)
                    : const Color(0xFFE8888C).withAlpha(60),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  remaining >= 0 ? Icons.savings_outlined : Icons.warning_amber,
                  color: remaining >= 0
                      ? const Color(0xFF4CC795)
                      : const Color(0xFFE8888C),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  remaining >= 0
                      ? '${fmt.format(remaining)} left'
                      : '${fmt.format(remaining.abs())} over!',
                  style: TextStyle(
                    color: remaining >= 0
                        ? const Color(0xFF4CC795)
                        : const Color(0xFFE8888C),
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

  Widget _buildDailyChart(bool isDark) {
    final start = _budget!.currentPeriodStart;
    final end = _budget!.currentPeriodEnd;
    final days = end.difference(start).inDays + 1;

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
      cum += _dailySpending[day] ?? 0;
      if (cum > maxCum) maxCum = cum;
      spots.add(FlSpot(i.toDouble(), cum));
    }

    // Scale Y-axis to fit whichever is larger: the budget or actual spending
    final chartMaxY = (maxCum > _budget!.amount ? maxCum : _budget!.amount) * 1.15;

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
          const Text(
            'Daily Spending',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: spots.isEmpty
                ? const Center(child: Text('No data yet'))
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
                              '₹${(v / 1000).toStringAsFixed(0)}k',
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
          const SizedBox(height: 16),
          if (spendingData.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(Icons.pie_chart_outline, size: 48, color: Color(0xFF9A9DA6)),
                  const SizedBox(height: 12),
                  Text(
                    'No spending data for this month',
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
    final total = spending.values.fold(0.0, (a, b) => a + b);
    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: sorted.take(6).map((e) {
              final pct = (e.value / total * 100);
              return PieChartSectionData(
                value: e.value,
                color: ExpenseCategories.getColor(e.key),
                title: '${pct.toStringAsFixed(0)}%',
                radius: 50,
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
        ),
      ),
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
                Text(
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
                                DateFormat('MMM d, yyyy').format(txn.detectedAt),
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
                        Text(
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
      return const Center(child: Text('No historical data available'));
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
                      const Text(
                        'Monthly Spending Trend',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        barTouchData: BarTouchData(enabled: true),
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
                '₹${spot.y.toStringAsFixed(0)}',
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
            '₹${(v / 1000).toStringAsFixed(0)}k',
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
                monthFormat.format(_monthlySpending[v.toInt()]['month']),
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
                    child: const Text(
                      'NOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(month),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                Text(
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
                  Text(
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

  Future<void> _showBudgetDialog() async {
    final nameCtrl = TextEditingController(
      text: _budget?.name ?? 'Monthly Budget',
    );
    final amountCtrl = TextEditingController(
      text: _budget?.amount.toStringAsFixed(0) ?? '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _budget == null ? 'Set Budget' : 'Edit Budget',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_budget != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _db.deleteBudget(_budget!.id!);
                        Navigator.pop(ctx);
                        _loadData();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFFD25A5F),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                if (_budget != null) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final amt = double.tryParse(amountCtrl.text) ?? 0;
                      if (amt <= 0) return;
                      final b = Budget(
                        id: _budget?.id,
                        name: nameCtrl.text,
                        amount: amt,
                        startDate: DateTime.now(),
                      );
                      _budget == null
                          ? await _db.insertBudget(b)
                          : await _db.updateBudget(b);
                      Navigator.pop(ctx);
                      _loadData();
                    },
                    child: Text(_budget == null ? 'Set' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
