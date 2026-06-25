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

  /// The remainder ([total] − [myShare]) owed to you, split evenly among
  /// [owedBy]. Each entry sums back to the remainder (the first person absorbs
  /// the rounding remainder). Empty when nothing is owed or no people are given.
  static List<({String person, double share})> owedShares(
    double total,
    double myShare,
    List<String> owedBy,
  ) {
    final remainder = total - myShare;
    if (remainder <= 0 || owedBy.isEmpty) return const [];
    final n = owedBy.length;
    final base = (remainder / n).floorToDouble();
    var leftover = remainder - base * n;
    final out = <({String person, double share})>[];
    for (var i = 0; i < n; i++) {
      var share = base;
      if (leftover > 0.0005) {
        share += 1;
        leftover -= 1;
      }
      out.add((person: owedBy[i], share: share));
    }
    return out;
  }

  /// Whether [myShare] is a usable share of [total]: from ₹0 (you covered it
  /// entirely for others) up to the full amount.
  static bool isValidShare(double total, double myShare) =>
      myShare >= 0 && myShare <= total + 0.001;

  /// Whether [myShare] actually reduces the spend (i.e. it's a real split and
  /// not just the full amount).
  static bool reducesSpend(double total, double myShare) =>
      myShare < total - 0.001;
}
