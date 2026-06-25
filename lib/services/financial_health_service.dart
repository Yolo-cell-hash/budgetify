import '../models/holding.dart';
import '../models/sip.dart';
import 'database_service.dart';

/// One budget envelope's month-to-date usage: how much was allowed vs spent.
/// Kept tiny and pure so the adherence maths stays unit-testable.
class BudgetUsage {
  final double limit;
  final double spent;

  const BudgetUsage({required this.limit, required this.spent});
}

/// Qualitative band for a 0–100 health score. Drives the gauge colour and the
/// one-word label shown on the dashboard.
enum HealthBand { atRisk, needsWork, fair, good, excellent }

extension HealthBandInfo on HealthBand {
  String get label => switch (this) {
        HealthBand.atRisk => 'At risk',
        HealthBand.needsWork => 'Needs work',
        HealthBand.fair => 'Fair',
        HealthBand.good => 'Good',
        HealthBand.excellent => 'Excellent',
      };

  /// A short, human caption shown under the score.
  String get caption => switch (this) {
        HealthBand.excellent =>
          "Excellent — you're on strong financial footing.",
        HealthBand.good => 'Good — a few small tweaks could push you higher.',
        HealthBand.fair =>
          'Fair — room to save more or rein in spending.',
        HealthBand.needsWork =>
          'Needs attention — spending is outpacing what you keep.',
        HealthBand.atRisk =>
          'At risk — expenses and debts deserve a close look.',
      };
}

/// A single 0–100 **Financial Health Score** blended from up to four pillars:
/// savings rate, budget adherence, recurring-commitment load and net worth.
///
/// Pure and deterministic — no I/O — so the maths is unit-tested directly
/// (see [FinancialHealthService] for the database-backed assembly). Higher is
/// healthier: 100 is excellent, 0 is poor. Any pillar can be *unavailable*
/// (null) when there isn't enough data for it (no income yet, no budget set,
/// no holdings); the composite renormalises over whichever pillars are present
/// and is itself null only when none can be computed.
class FinancialHealth {
  // ── Pillar weights (relative; renormalised over the available pillars) ──
  static const double wSavings = 0.35;
  static const double wBudget = 0.25;
  static const double wRecurring = 0.20;
  static const double wNetWorth = 0.20;

  // ── Tuning constants (documented, so the score is explainable) ──
  /// Savings rate that earns a perfect savings pillar — 20% is the widely
  /// cited "healthy" personal savings rate.
  static const double targetSavingsRate = 0.20;

  /// Recurring commitments up to this share of income score full marks …
  static const double recurringComfort = 0.50;

  /// … and at/above this share they score zero (almost all income committed).
  static const double recurringStrain = 1.00;

  /// A budget envelope scores full marks at or under its limit, ramping to
  /// zero once spending runs this fraction past the limit (25% over → 0).
  static const double budgetOverrunToZero = 0.25;

  final double income;
  final double expenses;
  final List<BudgetUsage> budgets;
  final double recurringMonthly;
  final double assets;
  final double liabilities;

  const FinancialHealth({
    required this.income,
    required this.expenses,
    this.budgets = const [],
    this.recurringMonthly = 0,
    this.assets = 0,
    this.liabilities = 0,
  });

  bool get _hasIncome => income > 0;

  // ── Pillar 1 · Savings rate ───────────────────────────────────────────
  /// Fraction of income kept this period. Null when there's no income to
  /// divide by.
  double? get savingsRate => _hasIncome ? (income - expenses) / income : null;

  /// 0–100: a [targetSavingsRate] (or better) rate is a perfect 100; a 0%
  /// rate or overspending is 0. Null when there's no income.
  double? get savingsScore {
    final r = savingsRate;
    if (r == null) return null;
    return (r / targetSavingsRate).clamp(0.0, 1.0) * 100;
  }

  // ── Pillar 2 · Budget adherence ───────────────────────────────────────
  /// 0–100 across every budget envelope, weighted by envelope size: full
  /// marks at or under the limit, ramping to 0 once spending is
  /// [budgetOverrunToZero] past it. Null when no budgets are set.
  double? get budgetScore {
    final usable = budgets.where((b) => b.limit > 0).toList();
    if (usable.isEmpty) return null;
    double weighted = 0;
    double totalLimit = 0;
    for (final b in usable) {
      final utilisation = b.spent / b.limit;
      final s =
          (1 - (utilisation - 1) / budgetOverrunToZero).clamp(0.0, 1.0) * 100;
      weighted += s * b.limit;
      totalLimit += b.limit;
    }
    return weighted / totalLimit;
  }

  // ── Pillar 3 · Recurring load ─────────────────────────────────────────
  /// Recurring monthly commitments as a share of income. Null without income.
  double? get recurringRatio => _hasIncome ? recurringMonthly / income : null;

  /// 0–100: comfortable headroom (≤ [recurringComfort] of income) is 100,
  /// dropping to 0 once commitments reach [recurringStrain] of income. Null
  /// when there's no income to measure against.
  double? get recurringScore {
    final r = recurringRatio;
    if (r == null) return null;
    final t = (recurringStrain - r) / (recurringStrain - recurringComfort);
    return t.clamp(0.0, 1.0) * 100;
  }

  // ── Pillar 4 · Net worth (solvency) ───────────────────────────────────
  bool get hasHoldings => assets > 0 || liabilities > 0;
  double get netWorth => assets - liabilities;

  /// 0–100 equity (solvency) ratio: the share of gross holdings that is truly
  /// yours. All assets / no debt is 100; assets equal to debts is 50; mostly
  /// debt trends to 0. Null when there are no holdings to assess ("if any").
  double? get netWorthScore {
    if (!hasHoldings) return null;
    final gross = assets + liabilities;
    if (gross <= 0) return null;
    return (assets / gross).clamp(0.0, 1.0) * 100;
  }

  // ── Composite ─────────────────────────────────────────────────────────
  /// (score, weight) for whichever pillars can be computed right now.
  List<({double score, double weight})> get _availablePillars => [
        if (savingsScore != null) (score: savingsScore!, weight: wSavings),
        if (budgetScore != null) (score: budgetScore!, weight: wBudget),
        if (recurringScore != null)
          (score: recurringScore!, weight: wRecurring),
        if (netWorthScore != null) (score: netWorthScore!, weight: wNetWorth),
      ];

  /// Whether at least one pillar is available (so a score can be shown).
  bool get hasScore => _availablePillars.isNotEmpty;

  /// The composite 0–100 score, renormalised over available pillars, or null
  /// when nothing can be scored yet.
  double? get scoreValue {
    final pillars = _availablePillars;
    if (pillars.isEmpty) return null;
    final totalWeight = pillars.fold(0.0, (s, p) => s + p.weight);
    final weighted = pillars.fold(0.0, (s, p) => s + p.score * p.weight);
    return weighted / totalWeight;
  }

  /// The composite rounded to a whole number — what the gauge displays. Null
  /// when there's nothing to score.
  int? get score => scoreValue?.round();

  /// Band for the current score (defaults to the lowest band when unscored;
  /// callers should gate on [hasScore] before reading this).
  HealthBand get band => bandFor(scoreValue ?? 0);

  static HealthBand bandFor(double score) {
    if (score >= 80) return HealthBand.excellent;
    if (score >= 60) return HealthBand.good;
    if (score >= 40) return HealthBand.fair;
    if (score >= 20) return HealthBand.needsWork;
    return HealthBand.atRisk;
  }
}

/// Assembles a [FinancialHealth] for the current month from the local
/// database. Read-only and deterministic; safe to call from the dashboard on
/// every refresh. [income] and [expenses] are passed in by the caller so the
/// savings pillar matches the dashboard's savings-rate bar exactly (identical
/// income/expense basis); the remaining pillars are read here.
class FinancialHealthService {
  final DatabaseService _db;

  FinancialHealthService([DatabaseService? db])
      : _db = db ?? DatabaseService();

  Future<FinancialHealth> compute({
    required double income,
    required double expenses,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0, 23, 59, 59);

    // ── Budgets: overall envelope (vs total spend) + each category budget ──
    final budgets = <BudgetUsage>[];
    final overall = await _db.getActiveBudget();
    if (overall != null && overall.amount > 0) {
      budgets.add(BudgetUsage(limit: overall.amount, spent: expenses));
    }
    for (final b in await _db.getCategoryBudgets()) {
      if (b.amount <= 0 || b.category == null) continue;
      final spent = await _db.getSpendingForPeriod(
        startDate: monthStart,
        endDate: monthEnd,
        category: b.category,
      );
      budgets.add(BudgetUsage(limit: b.amount, spent: spent));
    }

    // ── Recurring monthly commitment ──
    // Both halves of "money committed every month": fixed-amount SIP/RD
    // investments and fixed-amount recurring bills (subscriptions, rent, EMIs,
    // insurance) normalised to a monthly figure.
    double recurring = 0;
    for (final sip in await _db.getSips()) {
      final amount = sip.amount;
      if (amount == null || amount <= 0 || !sip.amountIsFixed) continue;
      if (!_activeThisMonth(sip, today)) continue;
      recurring += amount;
    }
    for (final plan in await _db.getRecurringPayments()) {
      if (!plan.isActiveForMonth(today)) continue;
      recurring += plan.monthlyEquivalent; // 0 for variable-amount plans
    }

    // ── Net worth from manually-tracked holdings ──
    final summary = NetWorthSummary(await _db.getHoldings());

    return FinancialHealth(
      income: income,
      expenses: expenses,
      budgets: budgets,
      recurringMonthly: recurring,
      assets: summary.assets,
      liabilities: summary.liabilities,
    );
  }

  /// Whether [sip]'s instalment for the month containing [when] falls inside
  /// its optional start/end window (mirrors `SipService`'s own window check),
  /// so plans that haven't started or have already ended don't count toward
  /// the recurring load.
  static bool _activeThisMonth(Sip sip, DateTime when) {
    final due = sip.dueDateInMonth(when.year, when.month);
    final dueOnly = DateTime(due.year, due.month, due.day);
    final start = sip.startDate;
    if (start != null &&
        dueOnly.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    final end = sip.endDate;
    if (end != null &&
        dueOnly.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }
    return true;
  }
}
