import 'cashflow.dart';

/// Projects net worth forward from the current value plus a steady monthly
/// contribution, optionally compounding at an annual return rate. Pure and
/// deterministic so the maths is unit-tested directly; the UI supplies the
/// inputs and renders the result. This is an estimate, not financial advice.
class NetWorthProjection {
  final double currentNetWorth;

  /// Typical monthly amount added (the savings baseline). May be negative if
  /// the user has been spending more than they earn.
  final double monthlyContribution;

  /// Assumed annual growth on the balance (e.g. 0.08 for 8%). 0 = a flat
  /// "savings only" projection.
  final double annualReturnRate;

  const NetWorthProjection({
    required this.currentNetWorth,
    required this.monthlyContribution,
    this.annualReturnRate = 0,
  });

  double get _monthlyRate => annualReturnRate / 12;

  /// Projected net worth [months] from now: the current balance grows at the
  /// rate while each month's contribution is added and compounds.
  double project(int months) {
    if (months <= 0) return currentNetWorth;
    final r = _monthlyRate;
    if (r == 0) return currentNetWorth + monthlyContribution * months;
    final growth = _pow1p(r, months);
    final fvCurrent = currentNetWorth * growth;
    final fvContributions = monthlyContribution * ((growth - 1) / r);
    return fvCurrent + fvContributions;
  }

  /// Projected net worth [years] from now (fractional years allowed).
  double projectYears(double years) => project((years * 12).round());

  /// Whole months until net worth first reaches [target], or null if it never
  /// does within [maxMonths] (e.g. a non-growing balance below the target with
  /// no positive contribution). Iterative — cheap for the small horizons used.
  int? monthsToReach(double target, {int maxMonths = 1200}) {
    if (currentNetWorth >= target) return 0;
    final r = _monthlyRate;
    if (monthlyContribution <= 0 && r <= 0) return null;
    var nw = currentNetWorth;
    for (var m = 1; m <= maxMonths; m++) {
      nw = nw * (1 + r) + monthlyContribution;
      if (nw >= target) return m;
    }
    return null;
  }

  static double _pow1p(double r, int n) {
    var v = 1.0;
    for (var i = 0; i < n; i++) {
      v *= (1 + r);
    }
    return v;
  }
}

/// The typical monthly savings to project from: the median net savings of up to
/// [lookback] recent **completed** months (the in-progress month at [now] is
/// excluded). Returns null until there are at least [minMonths] completed
/// months to judge from. Median (not mean) so one unusual month doesn't skew it.
double? monthlySavingsBaseline(
  List<MonthlyCashflow> series, {
  required DateTime now,
  int lookback = 6,
  int minMonths = 2,
}) {
  // A "completed" month is one that has fully ended — strictly before the
  // month containing [now] (this also drops any stray future-dated months).
  final currentMonthStart = DateTime(now.year, now.month, 1);
  final completed = series
      .where((m) => m.monthStart.isBefore(currentMonthStart))
      .toList();
  if (completed.length < minMonths) return null;
  final recent = completed
      .sublist(completed.length - (lookback.clamp(0, completed.length)))
      .map((m) => m.savings)
      .toList();
  if (recent.length < minMonths) return null;
  return _median(recent);
}

/// Net-worth milestones (₹) used for the "you'd reach ₹X in ~Y" line.
const List<double> kNetWorthMilestones = [
  100000, // ₹1L
  500000, // ₹5L
  1000000, // ₹10L
  2500000, // ₹25L
  5000000, // ₹50L
  10000000, // ₹1Cr
  25000000, // ₹2.5Cr
  50000000, // ₹5Cr
  100000000, // ₹10Cr
];

/// The next milestone strictly above [netWorth], or null once past the top one.
double? nextNetWorthMilestone(double netWorth) {
  for (final m in kNetWorthMilestones) {
    if (m > netWorth) return m;
  }
  return null;
}

double _median(List<double> xs) {
  final s = [...xs]..sort();
  final n = s.length;
  if (n == 0) return 0;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}
