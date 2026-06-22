import 'cashflow.dart';

/// Which window "You vs Past You" compares.
enum ComparePeriod { month, quarter }

/// Income/expense totals for one period.
class PeriodStat {
  final double income;
  final double expense;
  const PeriodStat({required this.income, required this.expense});

  double get savings => income - expense;
  double? get savingsRate => income > 0 ? (income - expense) / income : null;

  bool get hasData => income != 0 || expense != 0;

  static const zero = PeriodStat(income: 0, expense: 0);
}

/// A completed-period-over-period comparison: the most recent *completed*
/// period vs the one before it (the in-progress period at `now` is excluded so
/// we never compare a partial month/quarter against a full one). Pure data.
class PeriodComparison {
  final ComparePeriod period;
  final PeriodStat current; // most recent completed period
  final PeriodStat previous; // the period before that

  const PeriodComparison({
    required this.period,
    required this.current,
    required this.previous,
  });

  double get incomeDelta => current.income - previous.income;
  double get expenseDelta => current.expense - previous.expense;
  double get savingsDelta => current.savings - previous.savings;

  /// Savings-rate change in percentage points, or null if either side lacks
  /// income to form a rate.
  double? get savingsRateDeltaPoints {
    final a = current.savingsRate, b = previous.savingsRate;
    if (a == null || b == null) return null;
    return (a - b) * 100;
  }

  /// Whether there's enough on both sides to show a real comparison.
  bool get hasComparison => current.hasData && previous.hasData;
}

/// Build a [PeriodComparison] from a monthly cashflow [series]. For
/// [ComparePeriod.month], compares the last full calendar month to the one
/// before. For [ComparePeriod.quarter], compares the last completed calendar
/// quarter to the prior quarter.
PeriodComparison buildPeriodComparison(
  List<MonthlyCashflow> series, {
  required DateTime now,
  ComparePeriod period = ComparePeriod.month,
}) {
  PeriodStat sumMonths(DateTime start, int count) {
    var income = 0.0, expense = 0.0;
    for (var i = 0; i < count; i++) {
      final d = DateTime(start.year, start.month + i, 1);
      final m = cashflowForMonth(series, d.year, d.month);
      income += m.income;
      expense += m.expense;
    }
    return PeriodStat(income: income, expense: expense);
  }

  if (period == ComparePeriod.month) {
    final cur = DateTime(now.year, now.month - 1, 1); // last full month
    final prev = DateTime(now.year, now.month - 2, 1);
    return PeriodComparison(
      period: period,
      current: sumMonths(cur, 1),
      previous: sumMonths(prev, 1),
    );
  }

  // Quarter: the in-progress quarter contains `now`; step back to the last
  // completed quarter and the one before it.
  final curQStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
  final lastCompletedQStart = DateTime(now.year, curQStartMonth - 3, 1);
  final priorQStart = DateTime(now.year, curQStartMonth - 6, 1);
  return PeriodComparison(
    period: period,
    current: sumMonths(lastCompletedQStart, 3),
    previous: sumMonths(priorQStart, 3),
  );
}
