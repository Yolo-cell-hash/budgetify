import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../screens/daily_analysis_screen.dart';

/// A beautiful expense trend chart widget showing 7-day spending patterns
class ExpenseChartWidget extends StatelessWidget {
  final List<TransactionModel> transactions;

  const ExpenseChartWidget({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dailyData = _calculateDailyExpenses();
    final maxExpense = dailyData.isEmpty
        ? 0.0
        : dailyData.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    // Ensure maxY is never 0 to avoid division by zero
    final maxY = maxExpense > 0 ? maxExpense * 1.2 : 1000.0;
    final hasExpenses = maxExpense > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2333) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expense Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Last 7 Days',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a day for detailed analysis',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total: ₹${_getTotalExpenses().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: !hasExpenses
                ? _buildEmptyState()
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.grey.shade800,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '₹${rod.toY.toStringAsFixed(0)}\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Tap for details',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(180),
                                    fontWeight: FontWeight.normal,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        touchCallback: (FlTouchEvent event,
                            BarTouchResponse? response) {
                          if (event is FlTapUpEvent &&
                              response != null &&
                              response.spot != null) {
                            final index =
                                response.spot!.touchedBarGroupIndex;
                            if (index >= 0 && index < dailyData.length) {
                              _navigateToDailyAnalysis(
                                context,
                                dailyData[index].date,
                              );
                            }
                          }
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= dailyData.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  dailyData[value.toInt()].dayLabel,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 250,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark
                              ? const Color(0xFF2D3748)
                              : Colors.grey.shade200,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: dailyData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        final isToday = index == dailyData.length - 1;

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data.amount,
                              width: 28,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                              gradient: LinearGradient(
                                colors: isToday
                                    ? [Colors.red.shade400, Colors.red.shade300]
                                    : [
                                        Colors.red.shade200,
                                        Colors.red.shade100,
                                      ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
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
    );
  }

  void _navigateToDailyAnalysis(BuildContext context, DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyAnalysisScreen(date: date),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            'No expense data yet',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ],
      ),
    );
  }

  List<_DailyExpense> _calculateDailyExpenses() {
    final now = DateTime.now();
    final dayFormat = DateFormat('E');
    final List<_DailyExpense> result = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      double total = 0;
      for (final t in transactions) {
        if (t.type == TransactionType.debit &&
            t.detectedAt.isAfter(startOfDay) &&
            t.detectedAt.isBefore(endOfDay)) {
          total += t.amount;
        }
      }

      result.add(
        _DailyExpense(
          date: date,
          amount: total,
          dayLabel: i == 0 ? 'Today' : dayFormat.format(date),
        ),
      );
    }

    return result;
  }

  double _getTotalExpenses() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    double total = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.debit &&
          t.detectedAt.isAfter(sevenDaysAgo)) {
        total += t.amount;
      }
    }
    return total;
  }
}

class _DailyExpense {
  final DateTime date;
  final double amount;
  final String dayLabel;

  _DailyExpense({
    required this.date,
    required this.amount,
    required this.dayLabel,
  });
}
