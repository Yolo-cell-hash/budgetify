/// Pure math for splitting a single transaction into "your share" and what the
/// other people owe you. No I/O and no Flutter — unit-tested in isolation so
/// the rupee arithmetic (which feeds budgets) is provably correct.
class TransactionSplitMath {
  const TransactionSplitMath._();

  /// Your share when [total] is split evenly among [people] people (including
  /// you). Floors to whole rupees and hands you the rounding remainder, so the
  /// parts always sum back to [total]. [people] is clamped to >= 1.
  static double equalShare(double total, int people) {
    final n = people < 1 ? 1 : people;
    if (total <= 0) return 0;
    final base = (total / n).floorToDouble();
    final remainder = total - base * n; // 0..n-1 rupees, handed to you
    return base + remainder;
  }

  /// What each of [owedBy] owes you, honouring the amounts the user typed by
  /// hand.
  ///
  /// [fixed] holds those hand-typed amounts, keyed by person. Everyone left
  /// over evenly absorbs what remains of ([total] − [myShare]) once the fixed
  /// amounts are taken out — so setting one person's figure realigns the rest
  /// instead of making the user do the arithmetic. An even split is just the
  /// case where [fixed] is empty.
  ///
  /// When the fixed amounts already swallow the remainder, the rest settle at
  /// ₹0 and the parts stop adding up; [allocationGap] measures by how much, and
  /// the caller decides whether to warn. Empty when no people are given.
  static List<({String person, double share})> owedShares(
    double total,
    double myShare,
    List<String> owedBy, {
    Map<String, double> fixed = const {},
  }) {
    if (owedBy.isEmpty) return const [];
    final free = [for (final p in owedBy) if (!fixed.containsKey(p)) p];
    var left = total - myShare;
    for (final p in owedBy) {
      left -= fixed[p] ?? 0;
    }
    final auto = <String, double>{};
    if (free.isNotEmpty) {
      final base = left <= 0 ? 0.0 : (left / free.length).floorToDouble();
      var leftover = left <= 0 ? 0.0 : left - base * free.length;
      for (final p in free) {
        var share = base;
        if (leftover > 0.0005) {
          share += 1;
          leftover -= 1;
        }
        auto[p] = share;
      }
    }
    return [
      for (final p in owedBy) (person: p, share: fixed[p] ?? auto[p] ?? 0),
    ];
  }

  /// Rounding residue below this is not a real mismatch.
  static const double gapTolerance = 1.0;

  /// How far the parts are from adding up: (your share + [shares]) − [total].
  /// Positive ⇒ more is allocated than was spent; negative ⇒ some of the bill
  /// is still unassigned.
  static double allocationGap(
    double total,
    double myShare,
    Iterable<double> shares,
  ) =>
      myShare + shares.fold<double>(0, (a, b) => a + b) - total;

  /// Whether the parts add back up to [total], give or take rounding.
  static bool isBalanced(
    double total,
    double myShare,
    Iterable<double> shares,
  ) =>
      allocationGap(total, myShare, shares).abs() <= gapTolerance;

  /// Whether [myShare] is a usable share of [total]: from ₹0 (you covered it
  /// entirely for others) up to the full amount.
  static bool isValidShare(double total, double myShare) =>
      myShare >= 0 && myShare <= total + 0.001;

  /// Whether [myShare] actually reduces the spend (i.e. it's a real split and
  /// not just the full amount).
  static bool reducesSpend(double total, double myShare) =>
      myShare < total - 0.001;
}
