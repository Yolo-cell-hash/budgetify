/// Budget model for tracking spending limits
class Budget {
  final int? id;
  final String name;
  final double amount;
  final String period; // 'monthly', 'weekly'
  final String? category; // null = overall budget
  final DateTime startDate;
  final bool notified50;
  final bool notified90;
  final bool notified100;

  Budget({
    this.id,
    required this.name,
    required this.amount,
    this.period = 'monthly',
    this.category,
    required this.startDate,
    this.notified50 = false,
    this.notified90 = false,
    this.notified100 = false,
  });

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      period: map['period'] as String? ?? 'monthly',
      category: map['category'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      notified50: (map['notified_50'] as int?) == 1,
      notified90: (map['notified_90'] as int?) == 1,
      notified100: (map['notified_100'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'amount': amount,
      'period': period,
      'category': category,
      'start_date': startDate.toIso8601String(),
      'notified_50': notified50 ? 1 : 0,
      'notified_90': notified90 ? 1 : 0,
      'notified_100': notified100 ? 1 : 0,
    };
  }

  Budget copyWith({
    int? id,
    String? name,
    double? amount,
    String? period,
    String? category,
    DateTime? startDate,
    bool? notified50,
    bool? notified90,
    bool? notified100,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      notified50: notified50 ?? this.notified50,
      notified90: notified90 ?? this.notified90,
      notified100: notified100 ?? this.notified100,
    );
  }

  DateTime get currentPeriodStart {
    final now = DateTime.now();
    if (period == 'weekly') {
      return DateTime(now.year, now.month, now.day - (now.weekday - 1));
    }
    return DateTime(now.year, now.month, 1);
  }

  DateTime get currentPeriodEnd {
    final now = DateTime.now();
    if (period == 'weekly') {
      return currentPeriodStart.add(const Duration(days: 6));
    }
    return DateTime(now.year, now.month + 1, 0);
  }
}
