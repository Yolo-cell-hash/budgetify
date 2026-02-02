import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

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
  Map<String, double> _categorySpending = {};
  List<Map<String, dynamic>> _monthlySpending = [];
  bool _loading = true;

  // For expandable categories and months
  String? _expandedCategory;
  DateTime? _expandedMonth;
  List<TransactionModel> _expandedTransactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final budget = await _db.getActiveBudget();
    final monthlySpending = await _db.getMonthlySpending(months: 6);

    double spent = 0;
    Map<DateTime, double> daily = {};
    Map<String, double> byCategory = {};

    if (budget != null) {
      spent = await _db.getSpendingForPeriod(
        startDate: budget.currentPeriodStart,
        endDate: budget.currentPeriodEnd,
      );
      daily = await _db.getDailySpending(
        startDate: budget.currentPeriodStart,
        endDate: budget.currentPeriodEnd,
      );
      byCategory = await _db.getSpendingByCategory(
        startDate: budget.currentPeriodStart,
        endDate: budget.currentPeriodEnd,
      );
    }

    setState(() {
      _budget = budget;
      _spent = spent;
      _dailySpending = daily;
      _categorySpending = byCategory;
      _monthlySpending = monthlySpending;
      _loading = false;
    });
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isDark, fmt),
                _buildCategoriesTab(isDark, fmt),
                _buildTrendsTab(isDark, fmt),
              ],
            ),
    );
  }

  // ==================== OVERVIEW TAB ====================
  Widget _buildOverviewTab(bool isDark, NumberFormat fmt) {
    if (_budget == null) return _buildEmpty(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProgressCard(isDark, fmt),
          const SizedBox(height: 20),
          _buildDailyChart(isDark),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 80,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        const Text(
          'No Budget Set',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text('Tap the button below to set a budget'),
      ],
    ),
  );

  Widget _buildProgressCard(bool isDark, NumberFormat fmt) {
    final pct = _budget!.amount > 0 ? _spent / _budget!.amount : 0.0;
    final remaining = _budget!.amount - _spent;
    final color = pct >= 1
        ? Colors.red
        : pct >= 0.9
        ? Colors.orange
        : pct >= 0.5
        ? Colors.amber
        : Colors.green;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2333) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _budget!.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            width: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: CircularProgressIndicator(
                    value: pct.clamp(0, 1),
                    strokeWidth: 14,
                    backgroundColor: isDark
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fmt.format(_spent),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of ${fmt.format(_budget!.amount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: remaining >= 0
                  ? Colors.green.withAlpha(30)
                  : Colors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  remaining >= 0 ? Icons.savings : Icons.warning,
                  color: remaining >= 0 ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  remaining >= 0
                      ? '${fmt.format(remaining)} left'
                      : '${fmt.format(remaining.abs())} over!',
                  style: TextStyle(
                    color: remaining >= 0 ? Colors.green : Colors.red,
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
      spots.add(FlSpot(i.toDouble(), cum));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2333) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
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
                      maxY: _budget!.amount * 1.2,
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
                          color: Colors.grey,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          dashArray: [5, 5],
                        ),
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.indigo,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.indigo.withAlpha(40),
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
    if (_categorySpending.isEmpty) {
      return const Center(child: Text('No spending data for this period'));
    }

    final total = _categorySpending.values.fold(0.0, (a, b) => a + b);
    final sorted = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Pie Chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2333) : Colors.white,
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
          ),
          const SizedBox(height: 16),
          // Category List - Expandable
          ...sorted.map(
            (e) => _buildExpandableCategoryItem(
              e.key,
              e.value,
              total,
              fmt,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableCategoryItem(
    String category,
    double amount,
    double total,
    NumberFormat fmt,
    bool isDark,
  ) {
    final isExpanded = _expandedCategory == category;
    final cardColor = isDark ? const Color(0xFF1C2333) : Colors.white;
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
              // Load transactions for this category
              final transactions = await _db.getTransactionsByCategory(
                category,
              );
              setState(() {
                _expandedCategory = category;
                _expandedTransactions = transactions;
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
                          color: isDark ? Colors.grey.shade400 : Colors.grey,
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
                  color: Colors.grey,
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
              color: isDark ? const Color(0xFF161B22) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: _expandedTransactions.take(10).map((txn) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txn.sender,
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
                                    ? Colors.grey.shade500
                                    : Colors.grey,
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
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
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
    final monthFormat = DateFormat('MMM');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2333) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Spending Trend',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxValue * 1.2,
                      barTouchData: BarTouchData(enabled: true),
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
                            reservedSize: 30,
                            getTitlesWidget: (v, _) {
                              if (v.toInt() < _monthlySpending.length) {
                                return Text(
                                  monthFormat.format(
                                    _monthlySpending[v.toInt()]['month'],
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
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _monthlySpending.asMap().entries.map((e) {
                        final isCurrentMonth =
                            e.key == _monthlySpending.length - 1;
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value['total'],
                              color: isCurrentMonth
                                  ? Colors.indigo
                                  : Colors.indigo.withAlpha(120),
                              width: 24,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Monthly breakdown list - Expandable
          ...(_monthlySpending.reversed.toList()).map((m) {
            final month = m['month'] as DateTime;
            final total = m['total'] as double;
            return _buildExpandableMonthItem(month, total, fmt, isDark);
          }),
        ],
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
    final cardColor = isDark ? const Color(0xFF1C2333) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            if (isExpanded) {
              setState(() {
                _expandedMonth = null;
                _expandedTransactions = [];
              });
            } else {
              final transactions = await _db.getTransactionsByMonth(month);
              setState(() {
                _expandedMonth = month;
                _expandedTransactions = transactions;
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
                  ? Border.all(color: Colors.indigo, width: 2)
                  : isExpanded
                  ? Border.all(color: Colors.indigo.shade300, width: 1)
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
                      color: Colors.indigo,
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
                  color: Colors.grey,
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
              color: isDark ? const Color(0xFF161B22) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: _expandedTransactions.take(15).map((txn) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: ExpenseCategories.getColor(
                            txn.category ?? 'Other',
                          ).withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            ExpenseCategories.getIcon(txn.category ?? 'Other'),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txn.category ?? 'Uncategorized',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            Text(
                              txn.sender,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        fmt.format(txn.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
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
                        foregroundColor: Colors.red,
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
