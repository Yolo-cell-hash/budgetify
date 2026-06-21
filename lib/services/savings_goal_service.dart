import '../models/savings_goal.dart';
import 'database_service.dart';

/// A goal paired with its saved total and derived progress.
class GoalView {
  final SavingsGoal goal;
  final double saved;
  final GoalProgress progress;
  const GoalView(this.goal, this.saved, this.progress);
}

/// Read/write savings goals and their manual contributions. Money is a tracked
/// earmark — nothing moves automatically. All on-device; the goals/contributions
/// tables flow through the encrypted backup automatically.
class SavingsGoalService {
  final DatabaseService _db;

  SavingsGoalService([DatabaseService? db]) : _db = db ?? DatabaseService();

  Future<List<GoalView>> goalsWithProgress({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final goals = await _db.getGoals();
    final saved = await _db.getGoalSavedTotals();
    return [
      for (final g in goals)
        GoalView(
          g,
          saved[g.id] ?? 0,
          GoalProgress(
            target: g.targetAmount,
            saved: saved[g.id] ?? 0,
            deadline: g.deadline,
            now: today,
          ),
        ),
    ];
  }

  Future<GoalView?> goalView(int id, {DateTime? now}) async {
    final g = await _db.getGoal(id);
    if (g == null) return null;
    final saved = (await _db.getGoalSavedTotals())[id] ?? 0;
    return GoalView(
      g,
      saved,
      GoalProgress(
          target: g.targetAmount,
          saved: saved,
          deadline: g.deadline,
          now: now ?? DateTime.now()),
    );
  }

  Future<int> createGoal(SavingsGoal g) => _db.insertGoal(g);
  Future<void> updateGoal(SavingsGoal g) async => _db.updateGoal(g);
  Future<void> deleteGoal(int id) => _db.deleteGoal(id);
  Future<void> setArchived(SavingsGoal g, bool archived) async =>
      _db.updateGoal(g.copyWith(archived: archived));

  Future<List<GoalContribution>> contributions(int goalId) =>
      _db.getGoalContributions(goalId);
  Future<void> deleteContribution(int id) => _db.deleteGoalContribution(id);

  /// Add a contribution. Returns the goal if **this** contribution is the one
  /// that reaches the target (so the caller can celebrate + notify); else null.
  Future<SavingsGoal?> addContribution({
    required int goalId,
    required double amount,
    DateTime? date,
    String? note,
  }) async {
    final goal = await _db.getGoal(goalId);
    if (goal == null) return null;
    final savedBefore = (await _db.getGoalSavedTotals())[goalId] ?? 0;
    final wasComplete =
        goal.targetAmount > 0 && savedBefore >= goal.targetAmount;

    await _db.insertGoalContribution(GoalContribution(
      goalId: goalId,
      amount: amount,
      date: date ?? DateTime.now(),
      note: note,
    ));

    final nowComplete =
        goal.targetAmount > 0 && (savedBefore + amount) >= goal.targetAmount;
    if (nowComplete && !wasComplete) {
      final completed = goal.copyWith(completedAt: DateTime.now());
      await _db.updateGoal(completed);
      return completed;
    }
    return null;
  }

  /// How many goals have reached their target (used by gamification).
  Future<int> completedGoalsCount() async {
    final goals = await _db.getGoals(includeArchived: true);
    final saved = await _db.getGoalSavedTotals();
    var n = 0;
    for (final g in goals) {
      if (g.targetAmount > 0 && (saved[g.id] ?? 0) >= g.targetAmount) n++;
    }
    return n;
  }
}
