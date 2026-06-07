import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../screens/daily_analysis_screen.dart';

/// Chart display mode
enum ChartMode { bar, line }

/// A beautiful expense trend chart widget showing 7-day spending patterns
/// with a toggle to switch between bar chart and line chart.
class ExpenseChartWidget extends StatefulWidget {
  final List<TransactionModel> transactions;

  const ExpenseChartWidget({super.key, required this.transactions});

  @override
  State<ExpenseChartWidget> createState() => _ExpenseChartWidgetState();
}

class _ExpenseChartWidgetState extends State<ExpenseChartWidget> {
  ChartMode _chartMode = ChartMode.bar;

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
              Row(
                children: [
                  _buildChartModeToggle(isDark),
                  const SizedBox(width: 8),
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
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: _chartMode == ChartMode.bar
                        ? _buildBarChart(dailyData, maxY, isDark)
                        : _buildLineChart(dailyData, maxY, isDark),
                  ),
          ),
        ],
      ),
    );
  }

  /// Build the bar/line toggle control
  Widget _buildChartModeToggle(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            icon: Icons.bar_chart_rounded,
            isSelected: _chartMode == ChartMode.bar,
            onTap: () => setState(() => _chartMode = ChartMode.bar),
            isDark: isDark,
          ),
          _buildToggleButton(
            icon: Icons.show_chart_rounded,
            isSelected: _chartMode == ChartMode.line,
            onTap: () => setState(() => _chartMode = ChartMode.line),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
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
              ? (isDark ? Colors.red.shade700 : Colors.red.shade400)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
      ),
    );
  }

  /// Build the bar chart (existing implementation)
  Widget _buildBarChart(
    List<_DailyExpense> dailyData,
    double maxY,
    bool isDark,
  ) {
    return BarChart(
      key: const ValueKey('bar_chart'),
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
          touchCallback:
              (FlTouchEvent event, BarTouchResponse? response) {
            if (event is FlTapUpEvent &&
                response != null &&
                response.spot != null) {
              final index = response.spot!.touchedBarGroupIndex;
              if (index >= 0 && index < dailyData.length) {
                _navigateToDailyAnalysis(
                  context,
                  dailyData[index].date,
                );
              }
            }
          },
        ),
        titlesData: _buildTitlesData(dailyData),
        gridData: _buildGridData(maxY, isDark),
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
    );
  }

  /// Build the line chart variant
  Widget _buildLineChart(
    List<_DailyExpense> dailyData,
    double maxY,
    bool isDark,
  ) {
    return LineChart(
      key: const ValueKey('line_chart'),
      LineChartData(
        maxY: maxY,
        minY: 0,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.grey.shade800,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '₹${spot.y.toStringAsFixed(0)}\n',
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
              }).toList();
            },
          ),
          touchCallback:
              (FlTouchEvent event, LineTouchResponse? response) {
            if (event is FlTapUpEvent &&
                response != null &&
                response.lineBarSpots != null &&
                response.lineBarSpots!.isNotEmpty) {
              final index = response.lineBarSpots!.first.spotIndex;
              if (index >= 0 && index < dailyData.length) {
                _navigateToDailyAnalysis(
                  context,
                  dailyData[index].date,
                );
              }
            }
          },
        ),
        titlesData: _buildTitlesData(dailyData),
        gridData: _buildGridData(maxY, isDark),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: dailyData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.amount);
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: Colors.red.shade400,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isToday = index == dailyData.length - 1;
                return FlDotCirclePainter(
                  radius: isToday ? 5 : 3.5,
                  color: isToday
                      ? Colors.red.shade400
                      : Colors.red.shade200,
                  strokeWidth: isToday ? 2.5 : 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade300.withOpacity(0.35),
                  Colors.red.shade100.withOpacity(0.05),
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

  /// Shared title configuration for both chart types
  FlTitlesData _buildTitlesData(List<_DailyExpense> dailyData) {
    return FlTitlesData(
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
    );
  }

  /// Shared grid configuration for both chart types
  FlGridData _buildGridData(double maxY, bool isDark) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 250,
      getDrawingHorizontalLine: (value) => FlLine(
        color: isDark ? const Color(0xFF2D3748) : Colors.grey.shade200,
        strokeWidth: 1,
        dashArray: [5, 5],
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
      for (final t in widget.transactions) {
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
    for (final t in widget.transactions) {
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
