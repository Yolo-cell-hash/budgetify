import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import 'coach_service.dart';
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

  /// The spend target the safe-to-spend pool is measured against: the budget
  /// when one is set, otherwise the user's typical month (median of recent
  /// completed months). Null when there's neither.
  final double? target;

  /// True when [target] is an explicit budget, false when it's the
  /// typical-month fallback — lets the UI word things honestly.
  final bool targetFromBudget;

  /// Recurring spend already committed for the rest of this month (bills,
  /// EMIs, subscriptions). Subtracted from the safe-to-spend pool so money
  /// that's already spoken for never reads as "safe". 0 until recurring
  /// detection ships; wired so the figure tightens automatically once it does.
  final double committedRecurring;

  /// Money left to spend for the rest of the month: target − spent −
  /// committed. May be negative (already over). Null when there's no [target].
  final double? safeToSpendTotal;

  /// [safeToSpendTotal] spread over the days remaining (floored at 0).
  final double? safeToSpendPerDay;

  const SpendingForecast({
    required this.spentSoFar,
    required this.projected,
    required this.daysElapsed,
    required this.daysInMonth,
    this.budget,
    this.target,
    this.targetFromBudget = false,
    this.committedRecurring = 0,
    this.safeToSpendTotal,
    this.safeToSpendPerDay,
  });

  /// Projected over/under vs budget (positive = over). Null if no budget.
  double? get projectedVsBudget =>
      budget == null ? null : projected - budget!;

  /// Days left in the month (at least 1, so per-day math never divides by 0).
  int get daysRemaining => (daysInMonth - daysElapsed).clamp(1, 31);

  /// Whether a safe-to-spend figure can be shown at all.
  bool get hasTarget => target != null && target! > 0;

  /// Whether spending has already passed the target for the month.
  bool get isOverTarget =>
      safeToSpendTotal != null && safeToSpendTotal! < 0;
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

    final hasHistory = spentLast > 0;
    final insights = <Insight>[];

    // ── Forecast ──────────────────────────────────────────────────────
    final daysInMonth = monthEnd.day;
    final daysElapsed = today.day;

    // The user's typical month = median of recent *completed* months. Drives
    // both the safe-to-spend fallback (when no budget is set) and the pace
    // nudge, so we compute it once and share it.
    final monthly =
        await _db.getMonthlySpending(months: CoachStats.historyMonths + 1);
    final priorTotals = monthly
        .take(monthly.length - 1) // drop the in-progress current month
        .map((m) => m['total'] as double)
        .where((t) => t > 0)
        .toList();
    final double? typicalMonth =
        priorTotals.length >= CoachStats.minBaselineMonths
            ? CoachStats.median(priorTotals)
            : null;

    SpendingForecast? forecast;
    if (spentThis > 0) {
      final runRate = spentThis / daysElapsed * daysInMonth;
      // Blend run-rate with history, trusting run-rate more as the month
      // progresses, so an early big purchase doesn't over-project.
      final w = daysElapsed / daysInMonth;
      final projected = hasHistory ? w * runRate + (1 - w) * spentLast : runRate;

      final budget = await _db.getActiveBudget();
      // Safe-to-spend works off a budget when one exists, else the user's own
      // typical month — so the figure shows up even before they set a budget.
      final double? target =
          (budget != null && budget.amount > 0) ? budget.amount : typicalMonth;
      final bool targetFromBudget = budget != null && budget.amount > 0;

      // Money already spoken for this month (recurring bills/EMIs/SIPs). 0 for
      // now — recurring detection isn't built yet — but subtracted here so the
      // pool tightens automatically once it lands.
      const committed = 0.0;
      final remainingDays = (daysInMonth - daysElapsed).clamp(1, 31);
      double? safePerDay;
      double? safeTotal;
      if (target != null && target > 0) {
        final pool = target - spentThis - committed;
        safeTotal = pool;
        safePerDay = pool < 0 ? 0 : pool / remainingDays; // over → nothing safe
      }

      forecast = SpendingForecast(
        spentSoFar: spentThis,
        projected: projected,
        daysElapsed: daysElapsed,
        daysInMonth: daysInMonth,
        budget: budget?.amount,
        target: target,
        targetFromBudget: targetFromBudget,
        committedRecurring: committed,
        safeToSpendTotal: safeTotal,
        safeToSpendPerDay: safePerDay,
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

      // Coach: how this month's projected pace compares to the user's own
      // typical month. Suppressed when an overall budget exists (the
      // budget-pace insight above already speaks to that case).
      final pace = await _paceInsight(
        now: today,
        projected: projected,
        overallBudget: budget?.amount,
        typical: typicalMonth,
      );
      if (pace != null) insights.add(pace);
    }

    // ── Coach: category spikes vs your own day-aligned baseline ───────
    insights.addAll(await _categorySpikeInsights(today, catThis));

    // ── Coach: one unusually large transaction this month ─────────────
    final outlier = await _largeOutlierInsight(today);
    if (outlier != null) insights.add(outlier);

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

    // Savings rate (income vs expense) is now a core, always-on summary
    // (see SavingsRateBar on the dashboard and Budget → Overview), so it's no
    // longer duplicated here as an opt-in insight.

    return InsightsResult(
      forecast: forecast,
      insights: insights,
      hasHistory: hasHistory,
    );
  }

  // ── Coach detectors ──────────────────────────────────────────────────
  // These build the user-facing nudge text; the maths and false-alarm guards
  // live in [CoachStats] and are unit-tested independently.

  /// Categories whose month-to-date spend is meaningfully above (or below)
  /// the user's *own* pace for the same point in prior months.
  ///
  /// The comparison is **day-aligned**: this month's days 1..d are compared
  /// against days 1..d of each prior month, never against a full prior month.
  /// That removes the bias where, early in the month, everything looks "down",
  /// and where a real spike can't surface until late in the month.
  Future<List<Insight>> _categorySpikeInsights(
    DateTime now,
    Map<String, double> currentByCategory,
  ) async {
    if (currentByCategory.isEmpty) return const [];

    final d = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    // baselineByCat[cat] = that category's day-1..d spend in each prior month
    // that had any spend in it.
    final baselineByCat = <String, List<double>>{};
    for (int i = 1; i <= CoachStats.historyMonths; i++) {
      final mStart = DateTime(now.year, now.month - i, 1);
      final lastDay = DateTime(now.year, now.month - i + 1, 0).day;
      final dd = CoachStats.alignDay(d, lastDay);
      final mEnd = DateTime(now.year, now.month - i, dd, 23, 59, 59);
      final byCat =
          await _db.getSpendingByCategory(startDate: mStart, endDate: mEnd);
      byCat.forEach((cat, amt) {
        if (amt > 0) (baselineByCat[cat] ??= []).add(amt);
      });
    }

    final ups = <({String cat, double cur, double base})>[];
    final downs = <({String cat, double cur, double base})>[];
    currentByCategory.forEach((cat, cur) {
      final samples = baselineByCat[cat];
      if (samples == null || samples.length < CoachStats.minBaselineMonths) {
        return; // not enough comparable history → stay silent
      }
      final base = CoachStats.median(samples);
      if (CoachStats.spikeUp(current: cur, baseline: base)) {
        ups.add((cat: cat, cur: cur, base: base));
      } else if (CoachStats.spikeDown(current: cur, baseline: base) &&
          d >= daysInMonth * 0.5) {
        // Only praise a "down" category once we're at least halfway through the
        // month — otherwise it just means the month is young.
        downs.add((cat: cat, cur: cur, base: base));
      }
    });

    ups.sort((a, b) => (b.cur - b.base).compareTo(a.cur - a.base));
    downs.sort((a, b) => (a.cur - a.base).compareTo(b.cur - b.base));

    final out = <Insight>[];
    for (final m in ups.take(2)) {
      final pct = ((m.cur - m.base) / m.base * 100).round();
      out.add(Insight(
        icon: ExpenseCategories.getIcon(m.cat),
        title: '${m.cat} running hot · +$pct%',
        detail:
            '₹${_round(m.cur)} on ${m.cat} by day $d — about ₹${_round(m.cur - m.base)} '
            'more than your usual ₹${_round(m.base)} by now.',
        tone: InsightTone.caution,
      ));
    }
    if (downs.isNotEmpty) {
      final m = downs.first;
      final pct = ((m.base - m.cur) / m.base * 100).round();
      out.add(Insight(
        icon: ExpenseCategories.getIcon(m.cat),
        title: '${m.cat} down $pct%',
        detail:
            'Only ₹${_round(m.cur)} on ${m.cat} so far — ₹${_round(m.base - m.cur)} '
            'under your usual pace. Nice work.',
        tone: InsightTone.positive,
      ));
    }
    return out;
  }

  /// The single most unusual large transaction this month, judged against the
  /// user's typical transaction size *in that same category* over the prior
  /// six months (robust median + MAD). Returns null unless something clearly
  /// stands out — most months this is silent.
  Future<Insight?> _largeOutlierInsight(DateTime now) async {
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final histStart = DateTime(now.year, now.month - 6, 1);

    final thisMonth =
        await _db.getTransactionsByDateRange(monthStart, monthEnd);
    final candidates = thisMonth.where((t) =>
        t.type == TransactionType.debit &&
        t.category != null &&
        ExpenseCategories.isExpenseCategory(t.category));
    if (candidates.isEmpty) return null;

    // Per-category history (excludes the current month — ends one second
    // before it begins).
    final hist = await _db.getTransactionsByDateRange(
      histStart,
      monthStart.subtract(const Duration(seconds: 1)),
    );
    final byCat = <String, List<double>>{};
    for (final t in hist) {
      if (t.type != TransactionType.debit) continue;
      if (t.category == null ||
          !ExpenseCategories.isExpenseCategory(t.category)) {
        continue;
      }
      (byCat[t.category!] ??= []).add(t.amount);
    }

    TransactionModel? best;
    double bestRatio = 0;
    for (final t in candidates) {
      final samples = byCat[t.category!];
      if (samples == null) continue;
      if (!CoachStats.isLargeOutlier(amount: t.amount, history: samples)) {
        continue;
      }
      final ratio = t.amount / CoachStats.median(samples);
      if (ratio > bestRatio) {
        bestRatio = ratio;
        best = t;
      }
    }
    if (best == null) return null;

    final merchant = best.merchantName?.trim();
    final where =
        (merchant != null && merchant.isNotEmpty) ? ' at $merchant' : '';
    return Insight(
      icon: ExpenseCategories.getIcon(best.category!),
      title: 'Large ${best.category} spend',
      detail:
          '₹${_round(best.amount)}$where — about ${bestRatio.toStringAsFixed(1)}× '
          'your usual ${best.category} transaction. Worth a quick check it\'s right.',
      tone: InsightTone.caution,
    );
  }

  /// How the projected month total compares to the user's [typical] month.
  /// Skipped early in the month, without a baseline, and when an overall
  /// budget already drives the pace messaging.
  Future<Insight?> _paceInsight({
    required DateTime now,
    required double projected,
    required double? overallBudget,
    required double? typical,
  }) async {
    if (now.day < CoachStats.paceMinDay) return null;
    if (typical == null || typical <= 0) return null;

    if (CoachStats.pacesOver(projected: projected, typical: typical)) {
      if (overallBudget != null) return null; // budget-pace insight owns this
      return Insight(
        icon: '📈',
        title: 'Spending faster than usual',
        detail:
            'On pace for about ₹${_round(projected)} this month — ₹${_round(projected - typical)} '
            'above your typical ₹${_round(typical)}.',
        tone: InsightTone.caution,
      );
    }
    if (CoachStats.pacesUnder(projected: projected, typical: typical)) {
      return Insight(
        icon: '🌱',
        title: 'Lighter month so far',
        detail:
            'On pace for about ₹${_round(projected)} — ₹${_round(typical - projected)} '
            'under your typical ₹${_round(typical)}. Keep it up.',
        tone: InsightTone.positive,
      );
    }
    return null;
  }

  static final NumberFormat _fmt = NumberFormat.decimalPattern('en_IN');

  /// Round to whole rupees, grouped in the Indian style (1,23,456).
  static String _round(double v) => _fmt.format(v.round());
}
