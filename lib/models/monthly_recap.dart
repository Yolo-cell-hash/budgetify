import 'transaction_model.dart';

/// A single highlight on the Wrapped card (top category / top merchant): a
/// label, an emoji icon, its share of the month's spend as a percentage, and
/// (for the opt-in "reveal numbers" view only) the underlying rupee amount.
class RecapHighlight {
  final String label;
  final String icon;
  final int sharePct;

  /// Actual rupee figure behind [sharePct]. Only rendered when the user
  /// explicitly reveals amounts — the default card stays amount-free.
  final double? amount;

  const RecapHighlight({
    required this.label,
    required this.icon,
    required this.sharePct,
    this.amount,
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

/// Day-by-day texture of a month's spending — the material behind the
/// Wrapped card's rhythm strip and its busiest-day / no-spend-day tiles.
/// Pure math over a transaction list so it can be unit-tested without a
/// database.
class RecapTrends {
  /// Expense total per calendar day; index 0 is the 1st of the month. Always
  /// [daysInMonth] long, zero-filled for quiet days.
  final List<double> dailySpend;

  /// Day with the highest expense total, or null when nothing was spent.
  final DateTime? peakDay;
  final double peakDayAmount;

  /// Day with the most expense transactions, or null when there were none.
  final DateTime? busiestDay;
  final int busiestDayTxns;

  /// Days of the month considered "elapsed" (the full month for past months,
  /// days up to today for the in-progress one) and how many of those saw no
  /// expense at all.
  final int trackedDays;
  final int noSpendDays;

  const RecapTrends({
    required this.dailySpend,
    this.peakDay,
    this.peakDayAmount = 0,
    this.busiestDay,
    this.busiestDayTxns = 0,
    required this.trackedDays,
    required this.noSpendDays,
  });

  int get daysInMonth => dailySpend.length;

  /// The peak day's share of the month's spend (percent), or null.
  int? peakSharePct(double totalSpent) =>
      peakDay == null ? null : MonthlyRecap.pct(peakDayAmount, totalSpent);

  /// Derives the month's day-by-day trends from its transactions. Only
  /// expense debits count (mirrors the spending totals elsewhere), and split
  /// transactions count at the user's own share.
  static RecapTrends compute({
    required List<TransactionModel> txns,
    required DateTime month,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;
    final trackedDays =
        isCurrentMonth ? today.day.clamp(1, daysInMonth) : daysInMonth;

    final spend = List<double>.filled(daysInMonth, 0);
    final counts = List<int>.filled(daysInMonth, 0);
    for (final t in txns) {
      if (t.type != TransactionType.debit ||
          !ExpenseCategories.isExpenseCategory(t.category)) {
        continue;
      }
      final d = t.detectedAt;
      if (d.year != month.year || d.month != month.month) continue;
      spend[d.day - 1] += t.effectiveAmount;
      counts[d.day - 1] += 1;
    }

    var peakIdx = -1;
    var busyIdx = -1;
    var quiet = 0;
    for (var i = 0; i < daysInMonth; i++) {
      if (spend[i] > 0 && (peakIdx < 0 || spend[i] > spend[peakIdx])) {
        peakIdx = i;
      }
      // Busiest by count; break ties toward the day that also spent more.
      if (counts[i] > 0 &&
          (busyIdx < 0 ||
              counts[i] > counts[busyIdx] ||
              (counts[i] == counts[busyIdx] && spend[i] > spend[busyIdx]))) {
        busyIdx = i;
      }
      if (i < trackedDays && spend[i] <= 0) quiet++;
    }

    return RecapTrends(
      dailySpend: spend,
      peakDay:
          peakIdx < 0 ? null : DateTime(month.year, month.month, peakIdx + 1),
      peakDayAmount: peakIdx < 0 ? 0 : spend[peakIdx],
      busiestDay:
          busyIdx < 0 ? null : DateTime(month.year, month.month, busyIdx + 1),
      busiestDayTxns: busyIdx < 0 ? 0 : counts[busyIdx],
      trackedDays: trackedDays,
      noSpendDays: quiet,
    );
  }
}

/// A privacy-safe monthly recap ("Wrapped"). Deliberately holds only
/// percentages, counts and names — no rupee amounts — so the card is safe to
/// share publicly. Amount fields exist solely for the opt-in reveal view.
class MonthlyRecap {
  /// A month qualifies for a Wrapped only once it has at least this many days
  /// of recorded activity (span from first to last transaction).
  static const int minDays = 24;

  final DateTime month;
  final int availableDays;
  final bool hasData;

  final int? savingsRatePct; // null when there's no income to divide by
  final int? spendVsLastMonthPct; // negative = spent less (good)

  /// Biggest spending categories, largest first (up to three on the card).
  final List<RecapHighlight> topCategories;
  final RecapHighlight? topMerchant;
  final RecapMover? categoryMover;
  final int? netWorthChangePct; // null until two monthly snapshots exist
  final int? investedPct; // investments as a % of assets (fallback wealth stat)
  final int transactionCount;
  final int merchantCount;

  /// Day-by-day texture (rhythm strip, busiest day, no-spend days).
  final RecapTrends? trends;

  /// Foreground time spent in the app during this month, from the
  /// gamification tally. 0 when nothing was recorded (feature is newer than
  /// the month, or the user simply didn't open the app).
  final int appTimeSeconds;

  // ── Actual rupee figures (for the optional "reveal numbers" view) ──
  // These are never shown unless the user explicitly opts in, so the
  // default Wrapped card stays amount-free and safe to share.
  final double totalSpent;
  final double totalIncome;
  final double? categoryMoverAmount; // signed rupee change vs last month
  final double avgPerDay;
  final double? biggestTxnAmount;
  final String? biggestTxnLabel;

  const MonthlyRecap({
    required this.month,
    required this.availableDays,
    required this.hasData,
    this.savingsRatePct,
    this.spendVsLastMonthPct,
    this.topCategories = const [],
    this.topMerchant,
    this.categoryMover,
    this.netWorthChangePct,
    this.investedPct,
    this.transactionCount = 0,
    this.merchantCount = 0,
    this.trends,
    this.appTimeSeconds = 0,
    this.totalSpent = 0,
    this.totalIncome = 0,
    this.categoryMoverAmount,
    this.avgPerDay = 0,
    this.biggestTxnAmount,
    this.biggestTxnLabel,
  });

  /// Not-enough-data sentinel for a month that hasn't met [minDays].
  factory MonthlyRecap.insufficient(DateTime month, int availableDays) =>
      MonthlyRecap(month: month, availableDays: availableDays, hasData: false);

  bool get isEligible => hasData && availableDays >= minDays;

  /// The single biggest category (kept for callers that only need one).
  RecapHighlight? get topCategory =>
      topCategories.isEmpty ? null : topCategories.first;

  double? get topCategoryAmount => topCategory?.amount;
  double? get topMerchantAmount => topMerchant?.amount;

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
