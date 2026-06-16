/// A single highlight on the Wrapped card (top category / top merchant): a
/// label, an emoji icon, and its share of the month's spend as a percentage.
class RecapHighlight {
  final String label;
  final String icon;
  final int sharePct;

  const RecapHighlight({
    required this.label,
    required this.icon,
    required this.sharePct,
  });
}

/// The biggest category mover vs last month (percentage change).
class RecapMover {
  final String label;
  final String icon;
  final int changePct; // positive = up vs last month

  const RecapMover({
    required this.label,
    required this.icon,
    required this.changePct,
  });

  bool get up => changePct >= 0;
}

/// A privacy-safe monthly recap ("Wrapped"). Deliberately holds only
/// percentages, counts and names — no rupee amounts — so the card is safe to
/// share publicly.
class MonthlyRecap {
  /// A month qualifies for a Wrapped only once it has at least this many days
  /// of recorded activity (span from first to last transaction).
  static const int minDays = 24;

  final DateTime month;
  final int availableDays;
  final bool hasData;

  final int? savingsRatePct; // null when there's no income to divide by
  final int? spendVsLastMonthPct; // negative = spent less (good)
  final RecapHighlight? topCategory;
  final RecapHighlight? topMerchant;
  final RecapMover? categoryMover;
  final int? netWorthChangePct; // null until two monthly snapshots exist
  final int? investedPct; // investments as a % of assets (fallback wealth stat)
  final int transactionCount;
  final int merchantCount;

  const MonthlyRecap({
    required this.month,
    required this.availableDays,
    required this.hasData,
    this.savingsRatePct,
    this.spendVsLastMonthPct,
    this.topCategory,
    this.topMerchant,
    this.categoryMover,
    this.netWorthChangePct,
    this.investedPct,
    this.transactionCount = 0,
    this.merchantCount = 0,
  });

  /// Not-enough-data sentinel for a month that hasn't met [minDays].
  factory MonthlyRecap.insufficient(DateTime month, int availableDays) =>
      MonthlyRecap(month: month, availableDays: availableDays, hasData: false);

  bool get isEligible => hasData && availableDays >= minDays;

  /// Calendar-day span covered by [dates] (first → last, inclusive). 0 if empty.
  /// This is the "days of data available" used for the [minDays] gate.
  static int availableDaysFor(Iterable<DateTime> dates) {
    DateTime? lo;
    DateTime? hi;
    for (final d in dates) {
      final day = DateTime(d.year, d.month, d.day);
      if (lo == null || day.isBefore(lo)) lo = day;
      if (hi == null || day.isAfter(hi)) hi = day;
    }
    if (lo == null) return 0;
    return hi!.difference(lo).inDays + 1;
  }

  /// Rounded percentage of [part] out of [whole]; null when [whole] <= 0.
  static int? pct(num part, num whole) =>
      whole > 0 ? (part / whole * 100).round() : null;
}
