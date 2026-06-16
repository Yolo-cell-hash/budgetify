/// One merchant's spend over a period.
class MerchantSpend {
  final String name;
  final double total;
  final int count;

  const MerchantSpend({
    required this.name,
    required this.total,
    required this.count,
  });

  /// Average spend per transaction.
  double get average => count > 0 ? total / count : 0;

  /// Build from a `getMerchantBreakdown` row map.
  factory MerchantSpend.fromRow(Map<String, dynamic> row) => MerchantSpend(
        name: row['merchant'] as String? ?? 'Other',
        total: (row['total'] as num?)?.toDouble() ?? 0,
        count: (row['count'] as num?)?.toInt() ?? 0,
      );
}

/// Pure, derived summary over a merchant breakdown — total, distinct count,
/// the top merchant and its share. No I/O, fully testable.
class MerchantSummary {
  /// Sorted by spend descending.
  final List<MerchantSpend> merchants;

  const MerchantSummary(this.merchants);

  factory MerchantSummary.fromRows(List<Map<String, dynamic>> rows) {
    final list = rows.map(MerchantSpend.fromRow).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return MerchantSummary(list);
  }

  bool get isEmpty => merchants.isEmpty;
  int get merchantCount => merchants.length;
  double get total => merchants.fold(0.0, (sum, m) => sum + m.total);
  int get transactionCount => merchants.fold(0, (sum, m) => sum + m.count);

  MerchantSpend? get top => merchants.isEmpty ? null : merchants.first;

  /// Top merchant's share of the period total (0..1).
  double get topShare {
    final t = total;
    return (t > 0 && top != null) ? top!.total / t : 0;
  }

  /// Fraction of [m.total] relative to the top merchant (for bar widths, 0..1).
  double barFraction(MerchantSpend m) {
    final peak = top?.total ?? 0;
    return peak > 0 ? (m.total / peak).clamp(0.0, 1.0).toDouble() : 0;
  }

  /// Fraction of [m.total] relative to the whole period (for "% of spending").
  double share(MerchantSpend m) {
    final t = total;
    return t > 0 ? m.total / t : 0;
  }
}
