import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/budget_model.dart';
import '../services/database_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final DatabaseService _db = DatabaseService();
  Budget? _budget;
  double _spent = 0;
  Map<DateTime, double> _dailySpending = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final budget = await _db.getActiveBudget();
    if (budget != null) {
      final spent = await _db.getSpendingForPeriod(
        startDate: budget.currentPeriodStart,
        endDate: budget.currentPeriodEnd,
      );
      final daily = await _db.getDailySpending(
        startDate: budget.currentPeriodStart,
        endDate: budget.currentPeriodEnd,
      );
      setState(() {
        _budget = budget;
        _spent = spent;
        _dailySpending = daily;
      });
    }
    setState(() => _loading = false);
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
        title: const Text('Budget'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetDialog(),
        icon: Icon(_budget == null ? Icons.add : Icons.edit),
        label: Text(_budget == null ? 'Set Budget' : 'Edit'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _budget == null
          ? _buildEmpty(isDark)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProgressCard(isDark, fmt),
                  const SizedBox(height: 20),
                  _buildChart(isDark),
                  const SizedBox(height: 80),
                ],
              ),
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
        Text(
          'No Budget Set',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Set a monthly budget to track spending',
          style: TextStyle(color: Colors.grey),
        ),
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
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
            height: 140,
            width: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: pct.clamp(0, 1),
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fmt.format(_spent),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'of ${fmt.format(_budget!.amount)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget _buildChart(bool isDark) {
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
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending Trend',
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 3, color: Colors.indigo),
              const SizedBox(width: 4),
              const Text('Spending', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 16),
              Container(width: 12, height: 3, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('Budget', style: TextStyle(fontSize: 11)),
            ],
          ),
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
