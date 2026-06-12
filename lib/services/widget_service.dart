import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'database_service.dart';

/// Pushes month-to-date spend and budget progress to the Android
/// home-screen widget (BudgetWidgetProvider).
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
      final monthEnd = DateTime(now.year, now.month + 1, 1);

      final fmt = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      );

      final monthSpent = await db.getSpendingForPeriod(
        startDate: monthStart,
        endDate: monthEnd,
      );

      final budget = await db.getActiveBudget();
      String subtitle;
      int progressPercent = -1; // -1 hides the progress bar
      if (budget != null && budget.amount > 0) {
        final budgetSpent = await db.getSpendingForPeriod(
          startDate: budget.currentPeriodStart,
          endDate: budget.currentPeriodEnd,
        );
        progressPercent = ((budgetSpent / budget.amount) * 100).round();
        subtitle =
            '$progressPercent% of ${fmt.format(budget.amount)} budget used';
      } else {
        subtitle = 'Tap to set a budget';
      }

      await HomeWidget.saveWidgetData<String>(
        'title_text',
        '${DateFormat('MMMM').format(now).toUpperCase()} EXPENSES',
      );
      await HomeWidget.saveWidgetData<String>(
        'spent_text',
        fmt.format(monthSpent),
      );
      await HomeWidget.saveWidgetData<String>('subtitle_text', subtitle);
      await HomeWidget.saveWidgetData<int>('progress_percent', progressPercent);

      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (_) {
      // Widget refresh is best-effort.
    }
  }
}
