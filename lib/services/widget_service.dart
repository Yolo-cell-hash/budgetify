import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/holding.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';

/// Pushes an at-a-glance financial snapshot to the Android home-screen widget
/// (BudgetWidgetProvider): month-to-date spend, budget progress, net worth,
/// income and savings rate, plus the top spending category.
class WidgetService {
  static const String _androidProvider = 'BudgetWidgetProvider';

  /// Recompute widget data from the database and refresh the widget.
  /// Safe to call from background isolates; failures are swallowed because
  /// a widget refresh must never break a scan.
  static Future<void> update() async {
    try {
      final db = DatabaseService();
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final fmt = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      );
      // Compact form for the small insight cells (₹4.2L, ₹85k).
      String compact(double v) => _compactInr(v);

      final monthSpent = await db.getSpendingForPeriod(
        startDate: monthStart,
        endDate: monthEnd,
      );

      // True income for the month: credits, excluding self-transfers and
      // investment redemptions (mirrors the in-app savings rate).
      final monthTxns =
          await db.getTransactionsByDateRange(monthStart, monthEnd);
      double income = 0;
      for (final t in monthTxns) {
        if (t.type == TransactionType.credit &&
            ExpenseCategories.isIncomeCategory(t.category)) {
          income += t.amount;
        }
      }
      final savingsRate =
          income > 0 ? ((income - monthSpent) / income * 100).round() : null;

      // Net worth from manual holdings (assets − liabilities).
      final netWorth = NetWorthSummary(await db.getHoldings()).netWorth;

      // Top spending category (already excludes self-transfer/investments).
      final byCategory = await db.getSpendingByCategory(
        startDate: monthStart,
        endDate: monthEnd,
      );
      String topCategory = '';
      if (byCategory.isNotEmpty) {
        final top = byCategory.entries.first; // query is ordered desc
        topCategory =
            '${ExpenseCategories.getIcon(top.key)} ${top.key} · ${compact(top.value)}';
      }

      final budget = await db.getActiveBudget();
      String subtitle;
      int progressPercent = -1; // -1 hides the progress bar
      if (budget != null && budget.amount > 0) {
        final budgetSpent = await db.getSpendingForPeriod(
          startDate: budget.currentPeriodStart,
          endDate: budget.currentPeriodEnd,
        );
        progressPercent = ((budgetSpent / budget.amount) * 100).round();
        final left = budget.amount - budgetSpent;
        subtitle = left >= 0
            ? '${fmt.format(left)} left of ${fmt.format(budget.amount)}'
            : '${fmt.format(-left)} over ${fmt.format(budget.amount)}';
      } else {
        subtitle = 'Tap to set a budget';
      }

      // Header + hero
      await HomeWidget.saveWidgetData<String>(
        'title_text',
        '${DateFormat('MMMM').format(now).toUpperCase()} · SPENT',
      );
      await HomeWidget.saveWidgetData<String>(
        'spent_text',
        fmt.format(monthSpent),
      );
      await HomeWidget.saveWidgetData<String>('subtitle_text', subtitle);
      await HomeWidget.saveWidgetData<int>('progress_percent', progressPercent);
      await HomeWidget.saveWidgetData<String>('top_category_text', topCategory);

      // Insight row: Net Worth · Income · Saved (savings rate)
      await HomeWidget.saveWidgetData<String>(
        'networth_text',
        compact(netWorth),
      );
      await HomeWidget.saveWidgetData<String>('income_text', compact(income));
      await HomeWidget.saveWidgetData<String>(
        'savings_text',
        savingsRate == null ? '—' : '$savingsRate%',
      );
      await HomeWidget.saveWidgetData<bool>(
        'savings_positive',
        savingsRate == null || savingsRate >= 0,
      );

      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (_) {
      // Widget refresh is best-effort.
    }
  }

  /// Indian-style compact currency for tight widget cells:
  /// 4,20,000 → "₹4.2L", 85,000 → "₹85k", 999 → "₹999". Negatives keep the
  /// sign (net worth can be negative).
  static String _compactInr(double value) {
    final neg = value < 0;
    final v = value.abs();
    String body;
    if (v >= 10000000) {
      body = '${_trim(v / 10000000)}Cr';
    } else if (v >= 100000) {
      body = '${_trim(v / 100000)}L';
    } else if (v >= 1000) {
      body = '${_trim(v / 1000)}k';
    } else {
      body = v.round().toString();
    }
    return '${neg ? '-' : ''}₹$body';
  }

  /// One decimal place, but drop a trailing ".0" (4.0 → "4", 4.2 → "4.2").
  static String _trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}
