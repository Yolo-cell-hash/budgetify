import 'dart:math' as math;

/// A discrete savings goal — a named target amount, optionally by a deadline,
/// that the user funds with manual contributions ("Goa trip ₹40k by Dec").
/// Money is a tracked *earmark*; it isn't pulled automatically and doesn't
/// double-count into net worth.
class SavingsGoal {
  final int? id;
  final String name;
  final String emoji;
  final double targetAmount;
  final DateTime? deadline;
  final int accent; // index into the goal accent palette
  final String? note;
  final DateTime createdAt;
  final DateTime? completedAt; // when it first reached its target
  final bool archived;

  const SavingsGoal({
    this.id,
    required this.name,
    this.emoji = '🎯',
    required this.targetAmount,
    this.deadline,
    this.accent = 0,
    this.note,
    required this.createdAt,
    this.completedAt,
    this.archived = false,
  });

  SavingsGoal copyWith({
    int? id,
    String? name,
    String? emoji,
    double? targetAmount,
    DateTime? deadline,
    bool clearDeadline = false,
    int? accent,
    String? note,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? archived,
  }) =>
      SavingsGoal(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        targetAmount: targetAmount ?? this.targetAmount,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        accent: accent ?? this.accent,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        archived: archived ?? this.archived,
      );

  factory SavingsGoal.fromMap(Map<String, dynamic> m) => SavingsGoal(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        emoji: m['emoji'] as String? ?? '🎯',
        targetAmount: (m['target_amount'] as num?)?.toDouble() ?? 0,
        deadline: _fromMs(m['deadline'] as int?),
        accent: (m['accent'] as num?)?.toInt() ?? 0,
        note: m['note'] as String?,
        createdAt: _fromMs(m['created_at'] as int?) ?? DateTime.now(),
        completedAt: _fromMs(m['completed_at'] as int?),
        archived: (m['archived'] as int?) == 1,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'emoji': emoji,
        'target_amount': targetAmount,
        'deadline': deadline?.millisecondsSinceEpoch,
        'accent': accent,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
        'completed_at': completedAt?.millisecondsSinceEpoch,
        'archived': archived ? 1 : 0,
      };

  static DateTime? _fromMs(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

/// A single manual deposit toward a [SavingsGoal].
class GoalContribution {
  final int? id;
  final int goalId;
  final double amount;
  final DateTime date;
  final String? note;

  const GoalContribution({
    this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.note,
  });

  factory GoalContribution.fromMap(Map<String, dynamic> m) => GoalContribution(
        id: m['id'] as int?,
        goalId: m['goal_id'] as int,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as int?) ?? 0),
        note: m['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'goal_id': goalId,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'note': note,
      };
}

enum GoalStatus { active, completed, overdue }

/// Pure, derived progress for a goal given the total saved. No I/O — tested
/// directly.
class GoalProgress {
  final double target;
  final double saved;
  final DateTime? deadline;
  final DateTime now;

  const GoalProgress({
    required this.target,
    required this.saved,
    this.deadline,
    required this.now,
  });

  double get fraction =>
      target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0).toDouble();

  double get remaining {
    final r = target - saved;
    return r < 0 ? 0 : r;
  }

  bool get isComplete => target > 0 && saved >= target;

  /// Whole days until the deadline (negative once it's passed); null if none.
  int? get daysLeft => deadline == null ? null : deadline!.difference(now).inDays;

  bool get isOverdue =>
      deadline != null && !isComplete && now.isAfter(deadline!);

  GoalStatus get status => isComplete
      ? GoalStatus.completed
      : (isOverdue ? GoalStatus.overdue : GoalStatus.active);

  /// What the user must set aside per month to hit an upcoming deadline. Null
  /// when complete or without a (future) deadline.
  double? get neededPerMonth {
    if (deadline == null || isComplete) return null;
    final days = daysLeft ?? 0;
    final months = math.max(1, (days / 30.44).ceil());
    return remaining / months;
  }
}
