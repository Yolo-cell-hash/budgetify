import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import 'database_service.dart';

/// Pushes month-to-date insights to the Android home-screen widget
/// (BudgetWidgetProvider): spend, budget progress, income, net, and the
/// top spending category — enough for a meaningful at-a-glance read.
class WidgetService {
  static const String _androidProvider = 'BudgetWidgetProvider';

  /// Recompute widget data from the database and refresh the widget.
  /// Safe to call from background isolates; failures are swallowed because
  /// widget updates must never break a scan.
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

      final monthSpent = await db.getSpendingForPeriod(
        startDate: monthStart,
        endDate: monthEnd,
      );

      // Income + transaction count for the month
      final monthTxns =
          await db.getTransactionsByDateRange(monthStart, monthEnd);
      double income = 0;
      for (final t in monthTxns) {
        if (t.type == TransactionType.credit) income += t.amount;
      }
      final net = income - monthSpent;

      // Top spending category (already excludes self-transfer/investments)
      final byCategory = await db.getSpendingByCategory(
        startDate: monthStart,
        endDate: monthEnd,
      );
      String topCategory = '—';
      if (byCategory.isNotEmpty) {
        final top = byCategory.entries.first; // query is ordered desc
        topCategory =
            '${ExpenseCategories.getIcon(top.key)} ${top.key} · ${fmt.format(top.value)}';
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

      // Insight row
      await HomeWidget.saveWidgetData<String>(
        'income_text',
        fmt.format(income),
      );
      await HomeWidget.saveWidgetData<String>(
        'net_text',
        '${net >= 0 ? '+' : '-'}${fmt.format(net.abs())}',
      );
      await HomeWidget.saveWidgetData<bool>('net_positive', net >= 0);
      await HomeWidget.saveWidgetData<String>('top_category_text', topCategory);

      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (_) {
      // Widget refresh is best-effort.
    }
  }
}
