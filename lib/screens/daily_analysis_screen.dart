import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import 'transaction_detail_screen.dart';

/// Screen showing daily analysis with a pie chart and transaction list
class DailyAnalysisScreen extends StatefulWidget {
  final DateTime date;

  const DailyAnalysisScreen({super.key, required this.date});

  @override
  State<DailyAnalysisScreen> createState() => _DailyAnalysisScreenState();
}

class _DailyAnalysisScreenState extends State<DailyAnalysisScreen> {
  final DatabaseService _db = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _expensesKey = GlobalKey();
  final GlobalKey _incomeKey = GlobalKey();
  List<TransactionModel> _transactions = [];
  Map<String, double> _categoryBreakdown = {};
  double _totalSpent = 0;
  double _totalReceived = 0;
  bool _loading = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final startOfDay = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(
      const Duration(milliseconds: 1),
    );

    final transactions = await _db.getTransactionsByDateRange(
      startOfDay,
      endOfDay,
    );

    double totalSpent = 0;
    double totalReceived = 0;
    final Map<String, double> categoryBreakdown = {};

    for (final txn in transactions) {
      if (txn.type == TransactionType.debit) {
        totalSpent += txn.amount;
        final cat = txn.category ?? 'Uncategorized';
        categoryBreakdown[cat] = (categoryBreakdown[cat] ?? 0) + txn.amount;
      } else {
        totalReceived += txn.amount;
      }
    }

    setState(() {
      _transactions = transactions;
      _categoryBreakdown = categoryBreakdown;
      _totalSpent = totalSpent;
      _totalReceived = totalReceived;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('EEEE, MMMM d, y').format(widget.date);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    final bgColor = isDark ? const Color(0xFF0A0B0E) : Color(0xFFF6F6F3);
    final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Daily Analysis'),
        backgroundColor: cardColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? _buildEmptyState(isDark, dateStr)
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        _buildDateHeader(
                          isDark,
                          cardColor,
                          textColor,
                          subtextColor,
                          dateStr,
                          fmt,
                        ),
                        const SizedBox(height: 16),

                        // Pie chart section
                        if (_categoryBreakdown.isNotEmpty)
                          _buildPieChart(isDark, cardColor, textColor, fmt),

                        const SizedBox(height: 16),

                        // Category legend
                        if (_categoryBreakdown.isNotEmpty)
                          _buildCategoryLegend(
                            isDark,
                            cardColor,
                            textColor,
                            subtextColor,
                            fmt,
                          ),

                        const SizedBox(height: 16),

                        // Transaction list
                        _buildTransactionList(
                          isDark,
                          cardColor,
                          textColor,
                          subtextColor,
                          fmt,
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark, String dateStr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 80,
            color: isDark ? Color(0xFF4E525C) : Color(0xFFD5D5CF),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Color(0xFF6E727C) : Color(0xFF9A9DA6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    String dateStr,
    NumberFormat fmt,
  ) {
    final netAmount = _totalReceived - _totalSpent;
    final isPositive = netAmount >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Spent
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_expensesKey.currentContext != null) {
                      Scrollable.ensureVisible(
                        _expensesKey.currentContext!,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: _buildSummaryItem(
                    icon: Icons.arrow_upward,
                    label: 'Spent',
                    amount: fmt.format(_totalSpent),
                    color: Color(0xFFD25A5F),
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Received
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_incomeKey.currentContext != null) {
                      Scrollable.ensureVisible(
                        _incomeKey.currentContext!,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: _buildSummaryItem(
                    icon: Icons.arrow_downward,
                    label: 'Received',
                    amount: fmt.format(_totalReceived),
                    color: Color(0xFF2AA76F),
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Net
              Expanded(
                child: _buildSummaryItem(
                  icon: isPositive ? Icons.trending_up : Icons.trending_down,
                  label: 'Net',
                  amount: '${isPositive ? '+' : ''}${fmt.format(netAmount)}',
                  color: isPositive ? Color(0xFF4A6489) : Color(0xFFD79A3C),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Transaction count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Color(0xFFA8843C).withAlpha(30)
                  : Color(0xFFF5EFE3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_transactions.length} transaction${_transactions.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFC8A75E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String amount,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 20 : 15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    bool isDark,
    Color cardColor,
    Color textColor,
    NumberFormat fmt,
  ) {
    final total = _categoryBreakdown.values.fold(0.0, (a, b) => a + b);
    final sorted = _categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 45,
                sections: sorted.map((entry) {
                  final pct = total > 0 ? (entry.value / total * 100) : 0;
                  final color = _getCategoryColor(entry.key);
                  return PieChartSectionData(
                    value: entry.value,
                    color: color,
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 55,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    titlePositionPercentageOffset: 0.55,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLegend(
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    NumberFormat fmt,
  ) {
    final total = _categoryBreakdown.values.fold(0.0, (a, b) => a + b);
    final sorted = _categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sorted.map((entry) {
          final pct = total > 0 ? (entry.value / total * 100) : 0;
          final color = _getCategoryColor(entry.key);
          final icon = _getCategoryIcon(entry.key);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total > 0 ? entry.value / total : 0,
                          backgroundColor: isDark
                              ? Color(0xFF2E313A)
                              : Color(0xFFE9E9E4),
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt.format(entry.value),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionList(
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    NumberFormat fmt,
  ) {
    final timeFormat = DateFormat('h:mm a');

    // Split transactions by type and classification
    final classifiedDebits = _transactions
        .where((t) => t.type == TransactionType.debit && t.isClassified)
        .toList();
    final unclassifiedDebits = _transactions
        .where((t) => t.type == TransactionType.debit && !t.isClassified)
        .toList();
    final credits = _transactions
        .where((t) => t.type == TransactionType.credit)
        .toList();

    Widget buildTxnTile(TransactionModel txn) {
      final isCredit = txn.type == TransactionType.credit;
      final cat = txn.category ?? 'Uncategorized';

      return ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: txn),
            ),
          ).then((result) {
            if (result == true) _loadData();
          });
        },
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isCredit ? Color(0xFF2AA76F) : _getCategoryColor(cat))
                .withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              isCredit ? '💰' : _getCategoryIcon(cat),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        title: Text(
          txn.merchantName ?? txn.category ?? txn.sender,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              timeFormat.format(txn.detectedAt),
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
            if (txn.category != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: subtextColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  cat,
                  style: TextStyle(fontSize: 12, color: subtextColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          '${isCredit ? '+' : '-'} ${fmt.format(txn.amount)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isCredit ? Color(0xFF2AA76F) : Color(0xFFD25A5F),
          ),
        ),
      );
    }

    Widget buildDivider() => Divider(
      height: 1,
      indent: 68,
      endIndent: 16,
      color: isDark ? Color(0xFF2E313A) : Color(0xFFE9E9E4),
    );

    Widget buildSectionHeader({
      required String title,
      required IconData icon,
      required Color color,
      required String amount,
      Key? key,
    }) {
      return Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const Spacer(),
            Text(
              amount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildSubHeader(String title, Color color) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // === EXPENSES SECTION ===
        if (classifiedDebits.isNotEmpty || unclassifiedDebits.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSectionHeader(
                  key: _expensesKey,
                  title: 'Expenses',
                  icon: Icons.arrow_upward,
                  color: Color(0xFFD25A5F),
                  amount: fmt.format(_totalSpent),
                ),
                // Classified debits
                ...classifiedDebits.expand((txn) sync* {
                  yield buildTxnTile(txn);
                  if (txn != classifiedDebits.last ||
                      unclassifiedDebits.isNotEmpty) {
                    yield buildDivider();
                  }
                }),
                // Unclassified debits
                if (unclassifiedDebits.isNotEmpty) ...[
                  buildSubHeader('Unclassified', Color(0xFFD79A3C)),
                  ...unclassifiedDebits.expand((txn) sync* {
                    yield buildTxnTile(txn);
                    if (txn != unclassifiedDebits.last) {
                      yield buildDivider();
                    }
                  }),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),

        if (credits.isNotEmpty) const SizedBox(height: 16),

        // === INCOME SECTION ===
        if (credits.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSectionHeader(
                  key: _incomeKey,
                  title: 'Income',
                  icon: Icons.arrow_downward,
                  color: Color(0xFF2AA76F),
                  amount: fmt.format(_totalReceived),
                ),
                ...credits.expand((txn) sync* {
                  yield buildTxnTile(txn);
                  if (txn != credits.last) {
                    yield buildDivider();
                  }
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    return ExpenseCategories.getColor(category);
  }

  String _getCategoryIcon(String category) {
    if (category == 'Uncategorized') return '📌';
    return ExpenseCategories.getIcon(category);
  }
}
