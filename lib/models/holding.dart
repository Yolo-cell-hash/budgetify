/// Whether a holding adds to (asset) or subtracts from (liability) net worth.
enum HoldingKind { asset, liability }

/// A single manually-tracked holding — an investment, a savings balance, a
/// property, or a debt. Values are entered by the user (market values move),
/// matching how net-worth tracking works in other finance apps.
class Holding {
  final int? id;
  final String name; // user label, e.g. "HDFC Tax Saver FD"
  final HoldingKind kind;
  final String category; // one of HoldingCategories.*
  final double amount; // current value (always positive)
  final String? note;
  final DateTime updatedAt;

  Holding({
    this.id,
    required this.name,
    required this.kind,
    required this.category,
    required this.amount,
    this.note,
    required this.updatedAt,
  });

  bool get isInvestment =>
      kind == HoldingKind.asset && HoldingCategories.isInvestment(category);

  factory Holding.fromMap(Map<String, dynamic> m) => Holding(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        kind: (m['kind'] as String?) == 'liability'
            ? HoldingKind.liability
            : HoldingKind.asset,
        category: m['category'] as String? ?? 'Other Asset',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        note: m['note'] as String?,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updated_at'] as int?) ?? 0,
        ),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'kind': kind == HoldingKind.liability ? 'liability' : 'asset',
        'category': category,
        'amount': amount,
        'note': note,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  Holding copyWith({
    int? id,
    String? name,
    HoldingKind? kind,
    String? category,
    double? amount,
    String? note,
    DateTime? updatedAt,
  }) =>
      Holding(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        note: note ?? this.note,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// The catalog of holding categories, split into investments, other assets and
/// liabilities, each with an emoji for a consistent, dependency-free look.
class HoldingCategories {
  static const List<String> investments = [
    'Fixed Deposit',
    'Recurring Deposit',
    'Mutual Fund',
    'Stocks',
    'Bonds',
    'Gold',
    'PPF / EPF',
    'Crypto',
    'Other Investment',
  ];

  static const List<String> otherAssets = [
    'Savings',
    'Cash',
    'Real Estate',
    'Vehicle',
    'Other Asset',
  ];

  static const List<String> liabilities = [
    'Home Loan',
    'Personal Loan',
    'Car Loan',
    'Credit Card',
    'Other Liability',
  ];

  static List<String> get assetCategories => [...investments, ...otherAssets];

  static bool isInvestment(String category) => investments.contains(category);

  /// Investment categories that are contributed to on a recurring schedule
  /// (SIP / RD), so the automation suite is offered for them. Lump-sum
  /// categories (Fixed Deposit, Gold, Other Investment) are excluded.
  static const Set<String> _recurringCapable = {
    'Recurring Deposit',
    'Mutual Fund',
    'Stocks',
    'Bonds',
    'PPF / EPF',
    'Crypto',
  };

  static bool supportsRecurring(String category) =>
      _recurringCapable.contains(category);

  static List<String> forKind(HoldingKind kind) =>
      kind == HoldingKind.liability ? liabilities : assetCategories;

  static String icon(String category) {
    switch (category) {
      case 'Fixed Deposit':
        return '🏦';
      case 'Recurring Deposit':
        return '🔁';
      case 'Mutual Fund':
        return '📊';
      case 'Stocks':
        return '📈';
      case 'Bonds':
        return '📜';
      case 'Gold':
        return '🪙';
      case 'PPF / EPF':
        return '🛡️';
      case 'Crypto':
        return '💠';
      case 'Other Investment':
        return '📦';
      case 'Savings':
        return '🐷';
      case 'Cash':
        return '💵';
      case 'Real Estate':
        return '🏠';
      case 'Vehicle':
        return '🚗';
      case 'Home Loan':
        return '🏠';
      case 'Personal Loan':
        return '💸';
      case 'Car Loan':
        return '🚗';
      case 'Credit Card':
        return '💳';
      case 'Other Liability':
        return '🧾';
      default:
        return '💼';
    }
  }
}

/// Pure, derived net-worth figures over a set of holdings. No I/O — testable.
class NetWorthSummary {
  final List<Holding> holdings;

  const NetWorthSummary(this.holdings);

  Iterable<Holding> get _assets =>
      holdings.where((h) => h.kind == HoldingKind.asset);
  Iterable<Holding> get _liabilities =>
      holdings.where((h) => h.kind == HoldingKind.liability);

  double get assets => _assets.fold(0.0, (s, h) => s + h.amount);
  double get liabilities => _liabilities.fold(0.0, (s, h) => s + h.amount);
  double get netWorth => assets - liabilities;
  double get investments =>
      holdings.where((h) => h.isInvestment).fold(0.0, (s, h) => s + h.amount);

  bool get isEmpty => holdings.isEmpty;

  List<Holding> get investmentHoldings =>
      holdings.where((h) => h.isInvestment).toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  List<Holding> get otherAssetHoldings =>
      holdings.where((h) => h.kind == HoldingKind.asset && !h.isInvestment).toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

  List<Holding> get liabilityHoldings =>
      _liabilities.toList()..sort((a, b) => b.amount.compareTo(a.amount));

  /// Asset value grouped by category (for the allocation donut), largest first.
  Map<String, double> get assetAllocation {
    final map = <String, double>{};
    for (final h in _assets) {
      map[h.category] = (map[h.category] ?? 0) + h.amount;
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }
}
