import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/models/achievement.dart';
import 'package:budget_tracker/models/savings_goal.dart';

void main() {
  final now = DateTime(2026, 6, 20);

  group('GoalProgress', () {
    test('basic progress with no deadline', () {
      final p = GoalProgress(target: 40000, saved: 10000, now: now);
      expect(p.fraction, closeTo(0.25, 1e-9));
      expect(p.remaining, 30000);
      expect(p.isComplete, isFalse);
      expect(p.daysLeft, isNull);
      expect(p.neededPerMonth, isNull);
      expect(p.status, GoalStatus.active);
    });

    test('over-funded clamps to complete', () {
      final p = GoalProgress(target: 40000, saved: 50000, now: now);
      expect(p.fraction, 1.0);
      expect(p.remaining, 0);
      expect(p.isComplete, isTrue);
      expect(p.status, GoalStatus.completed);
    });

    test('deadline drives the per-month pace', () {
      final p = GoalProgress(
        target: 40000,
        saved: 10000,
        deadline: now.add(const Duration(days: 90)),
        now: now,
      );
      expect(p.daysLeft, 90);
      expect(p.isOverdue, isFalse);
      // 30,000 remaining over ~3 months.
      expect(p.neededPerMonth, closeTo(10000, 1));
    });

    test('past deadline is overdue (pace floors at one month)', () {
      final p = GoalProgress(
        target: 40000,
        saved: 10000,
        deadline: now.subtract(const Duration(days: 5)),
        now: now,
      );
      expect(p.isOverdue, isTrue);
      expect(p.status, GoalStatus.overdue);
      expect(p.neededPerMonth, 30000);
    });

    test('completed overrides an expired deadline', () {
      final p = GoalProgress(
        target: 40000,
        saved: 40000,
        deadline: now.subtract(const Duration(days: 5)),
        now: now,
      );
      expect(p.isComplete, isTrue);
      expect(p.isOverdue, isFalse);
      expect(p.status, GoalStatus.completed);
    });
  });

  group('SavingsGoal', () {
    test('round-trips through toMap/fromMap', () {
      final g = SavingsGoal(
        id: 7,
        name: 'Goa trip',
        emoji: '🏖️',
        targetAmount: 40000,
        deadline: DateTime(2026, 12, 1),
        accent: 3,
        createdAt: DateTime(2026, 6, 1),
      );
      final back = SavingsGoal.fromMap(g.toMap());
      expect(back.name, 'Goa trip');
      expect(back.emoji, '🏖️');
      expect(back.targetAmount, 40000);
      expect(back.deadline, DateTime(2026, 12, 1));
      expect(back.accent, 3);
      expect(back.archived, isFalse);
    });
  });

  group('Goal Getter badge', () {
    test('earns tiers as goals are completed', () {
      final group = kAchievementGroups.firstWhere((g) => g.id == 'goals');
      expect(evaluateGroup(group, const GamiStats(goalsCompleted: 0)).earnedCount, 0);
      // 1 and 3 earned at three completed goals; 5 and 10 still locked.
      final p = evaluateGroup(group, const GamiStats(goalsCompleted: 3));
      expect(p.earnedCount, 2);
      expect(p.nextTier!.threshold, 5);
    });
  });
}
