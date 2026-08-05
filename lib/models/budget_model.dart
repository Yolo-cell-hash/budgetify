/// Budget model for tracking spending limits
class Budget {
  final int? id;
  final String name;
  final double amount;
  final String period; // 'monthly', 'weekly'
  final String? category; // null = overall budget
  final DateTime startDate;
  /// The highest budget threshold percentage the user has been notified about.
  /// Thresholds: 50, 75, 90, 100, 120, 150, 200, 250, 300, ...
  /// 0 means no notification has been sent yet.
  final int lastNotifiedThreshold;

  /// The budget period [lastNotifiedThreshold] belongs to (e.g. "2026-06").
  /// When the period rolls over, alerts reset so a new month starts fresh —
  /// without this, hitting 100% in one month would silence every alert in
  /// the next until spending exceeded that old high-water mark again.
  final String? notifiedPeriod;

  Budget({
    this.id,
    required this.name,
    required this.amount,
    this.period = 'monthly',
    this.category,
    required this.startDate,
    this.lastNotifiedThreshold = 0,
    this.notifiedPeriod,
  });

  /// Whether this is a per-category budget (vs. the overall monthly budget).
  bool get isCategoryBudget => category != null;

  factory Budget.fromMap(Map<String, dynamic> map) {
    // Support both old boolean flags and new threshold integer
    int threshold = (map['last_notified_threshold'] as int?) ?? 0;
    if (threshold == 0) {
      // Backward compatibility: derive from old boolean flags if present
      if ((map['notified_100'] as int?) == 1) {
        threshold = 100;
      } else if ((map['notified_90'] as int?) == 1) {
        threshold = 90;
      } else if ((map['notified_50'] as int?) == 1) {
        threshold = 50;
      }
    }

    return Budget(
      id: map['id'] as int?,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      period: map['period'] as String? ?? 'monthly',
      category: map['category'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      lastNotifiedThreshold: threshold,
      notifiedPeriod: map['notified_period'] as String?,
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
      'last_notified_threshold': lastNotifiedThreshold,
      'notified_period': notifiedPeriod,
      // Keep old columns for backward compat during migration
      'notified_50': lastNotifiedThreshold >= 50 ? 1 : 0,
      'notified_90': lastNotifiedThreshold >= 90 ? 1 : 0,
      'notified_100': lastNotifiedThreshold >= 100 ? 1 : 0,
    };
  }

  Budget copyWith({
    int? id,
    String? name,
    double? amount,
    String? period,
    String? category,
    DateTime? startDate,
    int? lastNotifiedThreshold,
    String? notifiedPeriod,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      lastNotifiedThreshold:
          lastNotifiedThreshold ?? this.lastNotifiedThreshold,
      notifiedPeriod: notifiedPeriod ?? this.notifiedPeriod,
    );
  }

  DateTime get currentPeriodStart {
    final now = DateTime.now();
    if (period == 'weekly') {
      return DateTime(now.year, now.month, now.day - (now.weekday - 1));
    }
    return DateTime(now.year, now.month, 1);
  }

  /// The last instant of the current period — the period's final *day*, at
  /// 23:59:59.
  ///
  /// The time matters: every spend query bounds on `detected_at <= end`, so a
  /// midnight end silently drops the whole of the last day. That put the
  /// budget gauge, the threshold alerts and the home widget a day behind
  /// everything else on the 31st, and made the widget disagree with its own
  /// "spent this month" figure — which is computed to 23:59:59 like the rest
  /// of the app.
  DateTime get currentPeriodEnd {
    final now = DateTime.now();
    if (period == 'weekly') {
      final s = currentPeriodStart;
      // Built by calendar arithmetic rather than `add(Duration(days: 6))` so
      // the end lands on the right *date* regardless of any offset shift.
      return DateTime(s.year, s.month, s.day + 6, 23, 59, 59);
    }
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  /// Stable identifier for the current period, used to reset alert state when
  /// the period rolls over. Monthly → "2026-06"; weekly → "2026-06-08" (the
  /// week's Monday).
  String get currentPeriodKey {
    final s = currentPeriodStart;
    if (period == 'weekly') {
      return '${s.year}-${_two(s.month)}-${_two(s.day)}';
    }
    return '${s.year}-${_two(s.month)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
