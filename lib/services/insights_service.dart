import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import 'database_service.dart';

/// Visual weight / tone of an insight, used to pick its accent color.
enum InsightTone { neutral, positive, caution, alert }

/// A single rendered insight ("Food ↑38% vs last month", etc.).
class Insight {
  final String icon; // emoji, to stay dependency-free and themeable
  final String title;
  final String detail;
  final InsightTone tone;

  const Insight({
    required this.icon,
    required this.title,
    required this.detail,
    this.tone = InsightTone.neutral,
  });
}

/// Month-end spending forecast for the current month.
class SpendingForecast {
  final double spentSoFar;
  final double projected; // projected total for the whole month
  final int daysElapsed;
  final int daysInMonth;
  final double? budget; // overall monthly budget, if one is set
  final double? safeToSpendPerDay; // remaining budget / days left

  const SpendingForecast({
    required this.spentSoFar,
    required this.projected,
    required this.daysElapsed,
    required this.daysInMonth,
    this.budget,
    this.safeToSpendPerDay,
  });

  /// Projected over/under vs budget (positive = over). Null if no budget.
  double? get projectedVsBudget =>
      budget == null ? null : projected - budget!;
}

/// Bundle returned for the insights UI.
class InsightsResult {
  final SpendingForecast? forecast; // null until there's enough of the month
  final List<Insight> insights;
  final bool hasHistory; // false on a brand-new install (cold start)

  const InsightsResult({
    required this.forecast,
    required this.insights,
    required this.hasHistory,
  });

  bool get isEmpty => forecast == null && insights.isEmpty;
}

/// Computes on-device spending insights and a cash-flow forecast from data
/// already in the local database. Pure statistics + heuristics — no network,
/// no model, fully deterministic. Read-only: never mutates anything.
class InsightsService {
  final DatabaseService _db;

  InsightsService([DatabaseService? db]) : _db = db ?? DatabaseService();

  // Tuning knobs
  static const double _minPrevForDelta = 500; // ignore tiny-base % blowups

  Future<InsightsResult> compute({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 0, 23, 59, 59);
    final lastMonthStart = DateTime(today.year, today.month - 1, 1);
    final lastMonthEnd = DateTime(today.year, today.month, 0, 23, 59, 59);

    // Pull current + previous month aggregates (these queries already
    // exclude non-expense categories like Self Transfer / Investments).
    final spentThis = await _db.getSpendingForPeriod(
      startDate: monthStart,
      endDate: monthEnd,
    );
    final spentLast = await _db.getSpendingForPeriod(
      startDate: lastMonthStart,
      endDate: lastMonthEnd,
    );
    final catThis = await _db.getSpendingByCategory(
      startDate: monthStart,
      endDate: monthEnd,
    );
    final catLast = await _db.getSpendingByCategory(
      startDate: lastMonthStart,
      endDate: lastMonthEnd,
    );

    final hasHistory = spentLast > 0 || catLast.isNotEmpty;
    final insights = <Insight>[];

    // ── Forecast ──────────────────────────────────────────────────────
    final daysInMonth = monthEnd.day;
    final daysElapsed = today.day;
    SpendingForecast? forecast;
    if (spentThis > 0) {
      final runRate = spentThis / daysElapsed * daysInMonth;
      // Blend run-rate with history, trusting run-rate more as the month
      // progresses, so an early big purchase doesn't over-project.
      final w = daysElapsed / daysInMonth;
      final projected = hasHistory ? w * runRate + (1 - w) * spentLast : runRate;

      final budget = await _db.getActiveBudget();
      double? safe;
      if (budget != null && budget.amount > 0) {
        final remainingDays = (daysInMonth - daysElapsed).clamp(1, 31);
        final perDay = (budget.amount - spentThis) / remainingDays;
        safe = perDay < 0 ? 0 : perDay; // already over budget → nothing safe
      }
      forecast = SpendingForecast(
        spentSoFar: spentThis,
        projected: projected,
        daysElapsed: daysElapsed,
        daysInMonth: daysInMonth,
        budget: budget?.amount,
        safeToSpendPerDay: safe,
      );

      // Pace vs budget insight
      if (budget != null && budget.amount > 0) {
        if (projected > budget.amount * 1.05) {
          insights.add(Insight(
            icon: '⚠️',
            title: 'On track to exceed your budget',
            detail:
                'At this pace you\'ll spend about ₹${_round(projected)} — '
                '₹${_round(projected - budget.amount)} over your '
                '₹${_round(budget.amount)} budget.',
            tone: InsightTone.alert,
          ));
        } else if (projected < budget.amount * 0.9) {
          insights.add(Insight(
            icon: '✅',
            title: 'Comfortably within budget',
            detail:
                'Projected ₹${_round(projected)} this month — under your '
                '₹${_round(budget.amount)} budget.',
            tone: InsightTone.positive,
          ));
        }
      }
    }

    // ── Month-over-month movers ───────────────────────────────────────
    if (hasHistory) {
      final movers = <({String cat, double change, double pct})>[];
      for (final entry in catThis.entries) {
        final prev = catLast[entry.key] ?? 0;
        if (prev < _minPrevForDelta) continue; // avoid tiny-base noise
        final change = entry.value - prev;
        if (change.abs() < _minPrevForDelta * 0.4) continue;
        movers.add((cat: entry.key, change: change, pct: change / prev * 100));
      }
      movers.sort((a, b) => b.change.abs().compareTo(a.change.abs()));
      for (final m in movers.take(2)) {
        final up = m.change > 0;
        insights.add(Insight(
          icon: ExpenseCategories.getIcon(m.cat),
          title:
              '${m.cat} ${up ? '↑' : '↓'} ${m.pct.abs().toStringAsFixed(0)}%',
          detail:
              '₹${_round(m.change.abs())} ${up ? 'more' : 'less'} than last '
              'month so far.',
          tone: up ? InsightTone.caution : InsightTone.positive,
        ));
      }
    }

    // ── Top category this month ───────────────────────────────────────
    if (catThis.isNotEmpty) {
      final top =
          catThis.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final share = spentThis > 0 ? (top.value / spentThis * 100) : 0;
      insights.add(Insight(
        icon: ExpenseCategories.getIcon(top.key),
        title: 'Top category: ${top.key}',
        detail:
            '₹${_round(top.value)} — ${share.toStringAsFixed(0)}% of this '
            'month\'s spending.',
        tone: InsightTone.neutral,
      ));
    }

    // ── Savings rate (income vs expense) ──────────────────────────────
    final monthTxns =
        await _db.getTransactionsByDateRange(monthStart, monthEnd);
    double income = 0;
    for (final t in monthTxns) {
      if (t.type == TransactionType.credit) income += t.amount;
    }
    if (income > 0 && spentThis > 0) {
      final rate = (income - spentThis) / income * 100;
      insights.add(Insight(
        icon: rate >= 0 ? '🐷' : '🔻',
        title: rate >= 0
            ? 'Saving ${rate.toStringAsFixed(0)}% of income'
            : 'Spending exceeds income',
        detail: rate >= 0
            ? 'Income ₹${_round(income)}, spent ₹${_round(spentThis)} so far.'
            : 'Spent ₹${_round(spentThis)} against ₹${_round(income)} income.',
        tone: rate >= 0 ? InsightTone.positive : InsightTone.alert,
      ));
    }

    return InsightsResult(
      forecast: forecast,
      insights: insights,
      hasHistory: hasHistory,
    );
  }

  static final NumberFormat _fmt = NumberFormat.decimalPattern('en_IN');

  /// Round to whole rupees, grouped in the Indian style (1,23,456).
  static String _round(double v) => _fmt.format(v.round());
}
