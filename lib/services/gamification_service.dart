import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/holding.dart';
import '../models/streak_reward.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'savings_goal_service.dart';

/// The user's customizable profile for Gamified Budgets. Fully offline and
/// included in encrypted backups.
class GamiProfile {
  final String username;
  final String avatarKind; // 'emoji' | 'pixel'
  final String avatarValue; // emoji glyph, or pixel seed index as a string
  final int avatarAccent; // index into the accent palette
  final List<String> showcasedBadgeIds; // up to 5, shown on the profile
  final String? primaryTitleId;

  const GamiProfile({
    this.username = '',
    this.avatarKind = 'emoji',
    this.avatarValue = '🦊',
    this.avatarAccent = 0,
    this.showcasedBadgeIds = const [],
    this.primaryTitleId,
  });

  GamiProfile copyWith({
    String? username,
    String? avatarKind,
    String? avatarValue,
    int? avatarAccent,
    List<String>? showcasedBadgeIds,
    String? primaryTitleId,
    bool clearPrimaryTitle = false,
  }) =>
      GamiProfile(
        username: username ?? this.username,
        avatarKind: avatarKind ?? this.avatarKind,
        avatarValue: avatarValue ?? this.avatarValue,
        avatarAccent: avatarAccent ?? this.avatarAccent,
        showcasedBadgeIds: showcasedBadgeIds ?? this.showcasedBadgeIds,
        primaryTitleId:
            clearPrimaryTitle ? null : (primaryTitleId ?? this.primaryTitleId),
      );

  Map<String, dynamic> toMap() => {
        'username': username,
        'avatarKind': avatarKind,
        'avatarValue': avatarValue,
        'avatarAccent': avatarAccent,
        'showcasedBadgeIds': showcasedBadgeIds,
        if (primaryTitleId != null) 'primaryTitleId': primaryTitleId,
      };

  factory GamiProfile.fromMap(Map<String, dynamic> m) => GamiProfile(
        username: m['username'] as String? ?? '',
        avatarKind: m['avatarKind'] as String? ?? 'emoji',
        avatarValue: m['avatarValue'] as String? ?? '🦊',
        avatarAccent: (m['avatarAccent'] as num?)?.toInt() ?? 0,
        showcasedBadgeIds:
            (m['showcasedBadgeIds'] as List?)?.cast<String>() ?? const [],
        primaryTitleId: m['primaryTitleId'] as String?,
      );
}

/// Persistence + stats for Gamified Budgets. All state lives in one
/// SharedPreferences JSON blob (profile, streak, unlock dates, debt-free
/// anchor) so it round-trips through backups via [exportSettings] /
/// [importSettings]. Achievement *progress* is derived live from the database.
class GamificationService {
  static const String _key = 'gamification_v1';

  final DatabaseService _db;

  GamificationService([DatabaseService? db]) : _db = db ?? DatabaseService();

  // The nine predefined spend categories that "Category Explorer" counts.
  static const List<String> _spendCategories = [
    'Food & Dining',
    'Groceries',
    'Shopping',
    'Transportation',
    'Bills & Utilities',
    'Entertainment',
    'Health & Medical',
    'Travel',
    'Education',
  ];

  Future<Map<String, dynamic>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> blob) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(blob));
  }

  // ── Profile ──────────────────────────────────────────────────────────
  Future<GamiProfile> loadProfile() async {
    final blob = await _read();
    final p = blob['profile'];
    return p is Map
        ? GamiProfile.fromMap(p.cast<String, dynamic>())
        : const GamiProfile();
  }

  Future<void> saveProfile(GamiProfile profile) async {
    final blob = await _read();
    blob['profile'] = profile.toMap();
    await _write(blob);
  }

  // ── Streak (daily usage) ─────────────────────────────────────────────
  /// Pure streak transition, exposed for testing. Returns the new
  /// (current, longest) given the last-active date and today (date-only).
  static ({int current, int longest}) advanceStreak({
    required DateTime? last,
    required int current,
    required int longest,
    required DateTime today,
  }) {
    final t = DateTime(today.year, today.month, today.day);
    if (last != null) {
      final l = DateTime(last.year, last.month, last.day);
      if (l == t) return (current: current, longest: longest); // already counted
      final gap = t.difference(l).inDays;
      final newCurrent = gap == 1 ? current + 1 : 1;
      return (current: newCurrent, longest: newCurrent > longest ? newCurrent : longest);
    }
    return (current: 1, longest: longest < 1 ? 1 : longest);
  }

  /// Record that the app was opened today and roll the streak forward. Safe to
  /// call on every launch/resume; a no-op if today is already counted. Runs
  /// regardless of whether the mode is enabled, so the streak is accurate if
  /// the user turns it on later.
  Future<void> recordActiveDay({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final blob = await _read();
    final s = (blob['streak'] as Map?)?.cast<String, dynamic>() ?? {};
    final lastIso = s['last'] as String?;
    final last = lastIso == null ? null : DateTime.tryParse(lastIso);
    final result = advanceStreak(
      last: last,
      current: (s['current'] as num?)?.toInt() ?? 0,
      longest: (s['longest'] as num?)?.toInt() ?? 0,
      today: today,
    );
    final t = DateTime(today.year, today.month, today.day);
    if (last != null && DateTime(last.year, last.month, last.day) == t) {
      return; // nothing changed
    }
    blob['streak'] = {
      'last': t.toIso8601String(),
      'current': result.current,
      'longest': result.longest,
    };
    await _write(blob);
  }

  // TEMPORARY TEST HOOK — REMOVE BEFORE RELEASE.
  /// Forces the streak to [days] so locked streak-reward themes (e.g. Onyx &
  /// Amber at 14 days) can be tested on a real device without waiting. Stamps
  /// today as the last-active day, so the normal [recordActiveDay] on launch
  /// is a no-op and these values survive.
  Future<void> debugSeedStreak(int days, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final blob = await _read();
    blob['streak'] = {
      'last': t.toIso8601String(),
      'current': days,
      'longest': days,
    };
    await _write(blob);
  }

  /// Lightweight streak read (no database hit) for the theme picker and the
  /// Streak Reward Road, which only need the current/longest day counts.
  Future<({int current, int longest})> streakInfo() async {
    final blob = await _read();
    final s = (blob['streak'] as Map?)?.cast<String, dynamic>() ?? {};
    return (
      current: (s['current'] as num?)?.toInt() ?? 0,
      longest: (s['longest'] as num?)?.toInt() ?? 0,
    );
  }

  /// Streak-reward ids newly unlocked since the user last saw them, marking them
  /// seen. On the first run it silently adopts whatever is already earned (no
  /// celebration for history) — mirrors [popNewlyUnlocked].
  Future<List<String>> popNewlyUnlockedStreakRewards() async {
    final blob = await _read();
    final s = (blob['streak'] as Map?)?.cast<String, dynamic>() ?? {};
    final longest = (s['longest'] as num?)?.toInt() ?? 0;
    final unlocked = unlockedStreakRewardIds(longest);

    final seenRaw = blob['seenStreakRewards'] as List?;
    if (seenRaw == null) {
      blob['seenStreakRewards'] = unlocked.toList();
      await _write(blob);
      return const []; // first run — adopt, don't celebrate history
    }
    final seen = seenRaw.cast<String>().toSet();
    final fresh = unlocked.difference(seen).toList();
    if (fresh.isNotEmpty) {
      blob['seenStreakRewards'] = unlocked.toList();
      await _write(blob);
    }
    return fresh;
  }

  // ── Stats ────────────────────────────────────────────────────────────
  Future<GamiStats> computeStats({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final txns = await _db.getAllTransactions();
    final blob = await _read();
    final streak = (blob['streak'] as Map?)?.cast<String, dynamic>() ?? {};
    final currentStreak = (streak['current'] as num?)?.toInt() ?? 0;
    final longestStreak = (streak['longest'] as num?)?.toInt() ?? 0;

    final currentKey = _monthKey(today);

    double totalTracked = 0;
    DateTime? earliest;
    final monthTxn = <String, int>{};
    final monthUntagged = <String, int>{};
    final monthIncome = <String, double>{};
    final monthExpense = <String, double>{};
    final monthCat = <String, Map<String, double>>{}; // month → category → spend
    final expenseDays = <String>{};
    final spendCatsUsed = <String>{};

    for (final t in txns) {
      totalTracked += t.amount;
      final d = t.detectedAt;
      if (earliest == null || d.isBefore(earliest)) earliest = d;
      final mk = _monthKey(d);
      monthTxn[mk] = (monthTxn[mk] ?? 0) + 1;
      if (t.category == null) {
        monthUntagged[mk] = (monthUntagged[mk] ?? 0) + 1;
      } else if (_spendCategories.contains(t.category)) {
        spendCatsUsed.add(t.category!);
      }

      final isIncome = t.type == TransactionType.credit &&
          ExpenseCategories.isIncomeCategory(t.category);
      final isExpense = t.type == TransactionType.debit &&
          ExpenseCategories.isExpenseCategory(t.category);

      if (isIncome) monthIncome[mk] = (monthIncome[mk] ?? 0) + t.amount;
      if (isExpense) {
        monthExpense[mk] = (monthExpense[mk] ?? 0) + t.effectiveAmount;
        expenseDays.add(_dayKey(d));
        if (t.category != null && _spendCategories.contains(t.category)) {
          final m = monthCat[mk] ??= {};
          m[t.category!] = (m[t.category!] ?? 0) + t.effectiveAmount;
        }
      }
      // Investments are a non-expense debit, but still count toward the
      // Investor title's share of income.
      if (t.type == TransactionType.debit && t.category == 'Investments') {
        final m = monthCat[mk] ??= {};
        m['Investments'] = (m['Investments'] ?? 0) + t.effectiveAmount;
      }
    }

    final monthsOfData = earliest == null
        ? 0.0
        : today.difference(_dateOnly(earliest)).inDays / 30.44;

    var fullyTagged = 0;
    for (final mk in monthTxn.keys) {
      if ((monthTxn[mk] ?? 0) > 0 && (monthUntagged[mk] ?? 0) == 0) {
        fullyTagged++;
      }
    }

    // Budget Hero / Super Saver count completed months only.
    final budget = await _db.getActiveBudget();
    final budgetAmt = budget?.amount ?? 0;
    var monthsWithinBudget = 0;
    var monthsSaver = 0;
    for (final mk in monthTxn.keys) {
      if (mk == currentKey) continue; // skip the in-progress month
      final exp = monthExpense[mk] ?? 0;
      final inc = monthIncome[mk] ?? 0;
      if (budgetAmt > 0 && exp <= budgetAmt) monthsWithinBudget++;
      if (inc > 0 && (inc - exp) / inc >= 0.20) monthsSaver++;
    }

    // No-spend days across the tracked span.
    var noSpendDays = 0;
    if (earliest != null) {
      final span = today.difference(_dateOnly(earliest)).inDays + 1;
      noSpendDays = (span - expenseDays.length).clamp(0, span).toInt();
    }

    // Net worth + debt-free streak.
    final summary = NetWorthSummary(await _db.getHoldings());
    final debtFreeNow = summary.assets > 0 && summary.liabilities <= 0;
    var debtFreeSince = blob['debtFreeSince'] as String?;
    if (debtFreeNow) {
      debtFreeSince ??= today.toIso8601String();
    } else {
      debtFreeSince = null;
    }
    blob['debtFreeSince'] = debtFreeSince;
    final debtFreeDays = debtFreeSince == null
        ? 0
        : today.difference(_dateOnly(DateTime.parse(debtFreeSince))).inDays + 1;

    // Titles: per-month figures for completed months that had income, so the
    // engine can count how many months each title's rule was actually met.
    final monthStats = <MonthStat>[];
    for (final mk in monthIncome.keys) {
      if (mk == currentKey) continue; // skip the in-progress month
      final inc = monthIncome[mk] ?? 0;
      if (inc <= 0) continue;
      final exp = monthExpense[mk] ?? 0;
      final cats = monthCat[mk] ?? const {};
      monthStats.add(MonthStat(
        categoryShare: {for (final e in cats.entries) e.key: e.value / inc},
        savingsRate: (inc - exp) / inc,
      ));
    }

    final goalsCompleted = await SavingsGoalService(_db).completedGoalsCount();

    final stats = GamiStats(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalTracked: totalTracked,
      txnCount: txns.length,
      monthsOfData: monthsOfData,
      fullyTaggedMonths: fullyTagged,
      monthsWithinBudget: monthsWithinBudget,
      monthsSavingsRate20: monthsSaver,
      noSpendDays: noSpendDays,
      distinctCategories: spendCatsUsed.length,
      netWorth: summary.netWorth,
      debtFreeDays: debtFreeDays,
      goalsCompleted: goalsCompleted,
      monthStats: monthStats,
    );

    // Lazily stamp unlock dates for any newly-earned badge (today; we can't
    // know historical earn dates on first run).
    final unlocks = (blob['unlockedAt'] as Map?)?.cast<String, dynamic>() ?? {};
    final iso = today.toIso8601String();
    var changed = false;
    for (final id in earnedBadgeIds(stats)) {
      if (!unlocks.containsKey(id)) {
        unlocks[id] = iso;
        changed = true;
      }
    }
    if (changed || blob['debtFreeSince'] != null || debtFreeSince == null) {
      blob['unlockedAt'] = unlocks;
      await _write(blob);
    }

    return stats;
  }

  /// Map of badgeId → earned date (ISO), for "earned on" labels.
  Future<Map<String, DateTime>> unlockDates() async {
    final blob = await _read();
    final raw = (blob['unlockedAt'] as Map?)?.cast<String, dynamic>() ?? {};
    final out = <String, DateTime>{};
    raw.forEach((k, v) {
      final d = DateTime.tryParse(v as String? ?? '');
      if (d != null) out[k] = d;
    });
    return out;
  }

  /// Badge ids newly unlocked since the user last saw the Rewards hub, marking
  /// them seen. On the very first run it silently adopts whatever is already
  /// earned (no celebration for pre-existing achievements). Call after
  /// [computeStats], which stamps [unlockDates].
  Future<List<String>> popNewlyUnlocked() async {
    final blob = await _read();
    final unlocked =
        (blob['unlockedAt'] as Map?)?.cast<String, dynamic>().keys.toSet() ??
            <String>{};
    final seenRaw = blob['seenUnlocks'] as List?;
    if (seenRaw == null) {
      blob['seenUnlocks'] = unlocked.toList();
      await _write(blob);
      return const []; // first run — adopt, don't celebrate history
    }
    final seen = seenRaw.cast<String>().toSet();
    final fresh = unlocked.difference(seen).toList();
    if (fresh.isNotEmpty) {
      blob['seenUnlocks'] = unlocked.toList();
      await _write(blob);
    }
    return fresh;
  }

  // ── Backup hooks (mirrors CustomTagService.export/importSettings) ──────
  Future<Map<String, dynamic>> exportSettings() async => await _read();

  Future<void> importSettings(Map<String, dynamic>? data) async {
    if (data == null || data.isEmpty) return;
    await _write(Map<String, dynamic>.from(data));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
