import 'transaction_model.dart';

/// One calendar month's income vs expense, derived from transactions using the
/// same rules as the rest of the app (credits in income categories count as
/// income; debits in expense categories count as expense via
/// [TransactionModel.effectiveAmount]; Self Transfer & Investments are
/// excluded). Pure data — no I/O — so it's unit-tested directly.
class MonthlyCashflow {
  final int year;
  final int month;
  final double income;
  final double expense;

  const MonthlyCashflow({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });

  /// Net kept this month (may be negative when overspending).
  double get savings => income - expense;

  /// Fraction of income kept, or null when there was no income to divide by.
  double? get savingsRate => income > 0 ? (income - expense) / income : null;

  DateTime get monthStart => DateTime(year, month);

  static String keyFor(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  String get key => keyFor(year, month);
}

/// Build an ascending (oldest → newest) monthly income/expense series from
/// [txns]. Only months that had at least one income or expense transaction
/// appear; gaps are simply absent (callers treat a missing month as zero).
List<MonthlyCashflow> buildMonthlyCashflow(Iterable<TransactionModel> txns) {
  final income = <String, double>{};
  final expense = <String, double>{};
  final keys = <String>{};

  for (final t in txns) {
    final d = t.detectedAt;
    final k = MonthlyCashflow.keyFor(d.year, d.month);
    if (t.type == TransactionType.credit &&
        ExpenseCategories.isIncomeCategory(t.category)) {
      income[k] = (income[k] ?? 0) + t.amount;
      keys.add(k);
    } else if (t.type == TransactionType.debit &&
        ExpenseCategories.isExpenseCategory(t.category)) {
      expense[k] = (expense[k] ?? 0) + t.effectiveAmount;
      keys.add(k);
    }
  }

  final sorted = keys.toList()..sort();
  return [
    for (final k in sorted)
      MonthlyCashflow(
        year: int.parse(k.substring(0, 4)),
        month: int.parse(k.substring(5)),
        income: income[k] ?? 0,
        expense: expense[k] ?? 0,
      ),
  ];
}

/// Look up a single month in a cashflow [series], returning a zero entry when
/// that month is absent.
MonthlyCashflow cashflowForMonth(
  List<MonthlyCashflow> series,
  int year,
  int month,
) {
  for (final m in series) {
    if (m.year == year && m.month == month) return m;
  }
  return MonthlyCashflow(year: year, month: month, income: 0, expense: 0);
}
