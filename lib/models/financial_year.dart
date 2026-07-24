/// The Indian financial year runs 1 April – 31 March, not the calendar year.
/// Every tax total, cap and export is scoped to one of these windows, so the
/// boundary logic lives here in one place rather than being re-derived at each
/// call site.
class FinancialYear {
  /// First instant of the FY: 1 April, 00:00 of [startYear].
  final int startYear;

  const FinancialYear(this.startYear);

  /// The FY that [date] falls in. Jan–Mar belong to the FY that started the
  /// previous April (e.g. 15 Feb 2026 is FY 2025-26, startYear 2025).
  factory FinancialYear.forDate(DateTime date) {
    // April (month 4) is the cut. Months 1–3 roll back to the prior year.
    final start = date.month >= DateTime.april ? date.year : date.year - 1;
    return FinancialYear(start);
  }

  /// The FY containing "now".
  factory FinancialYear.current() => FinancialYear.forDate(DateTime.now());

  /// Inclusive lower bound: 1 Apr [startYear], 00:00:00.000.
  DateTime get start => DateTime(startYear, DateTime.april, 1);

  /// Exclusive upper bound: 1 Apr of the next year, 00:00. Using a half-open
  /// interval [start, endExclusive) avoids the classic "last millisecond of
  /// 31 March" boundary bug — a 31 Mar 23:59:59.999 transaction is inside,
  /// a 1 Apr 00:00 transaction is not.
  DateTime get endExclusive => DateTime(startYear + 1, DateTime.april, 1);

  /// Whether [date] is within this FY.
  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);

  /// The previous / next financial year.
  FinancialYear get previous => FinancialYear(startYear - 1);
  FinancialYear get next => FinancialYear(startYear + 1);

  /// Display label, e.g. "FY 2025-26" (two-digit end year, zero-padded).
  String get label {
    final endShort = ((startYear + 1) % 100).toString().padLeft(2, '0');
    return 'FY $startYear-$endShort';
  }

  /// The current FY and the [count] preceding ones, newest first — the option
  /// list for the year selector. People file for past years too, so a few
  /// back is useful; nothing in the future (you can't have spent it yet).
  static List<FinancialYear> recent({int count = 4}) {
    final current = FinancialYear.current();
    return [for (var i = 0; i < count; i++) FinancialYear(current.startYear - i)];
  }

  @override
  bool operator ==(Object other) =>
      other is FinancialYear && other.startYear == startYear;

  @override
  int get hashCode => startYear.hashCode;

  @override
  String toString() => label;
}
