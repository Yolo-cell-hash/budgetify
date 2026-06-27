import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/holding.dart';
import '../models/streak_reward.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'savings_goal_service.dart';

/// Playful "time in app this month" titles — a separate axis from the
/// money-behaviour [GamiTitle]s. Each tier needs at least [minHours] of
/// foreground time in the current calendar month. Rename/extend freely.
class UsageTitle {
  final double minHours;
  final String id;
  final String emoji;
  final String name;
  const UsageTitle(this.minHours, this.id, this.emoji, this.name);
}

/// Ascending by [UsageTitle.minHours].
const List<UsageTitle> kUsageTitles = [
  UsageTitle(0.5, 'usage_curious', '👀', 'Curious Browser'),
  UsageTitle(1, 'usage_buddy', '🤝', 'Budget Buddy'),
  UsageTitle(3, 'usage_maven', '💸', 'Money Maven'),
  UsageTitle(6, 'usage_fanatic', '📊', 'Finance Fanatic'),
  UsageTitle(12, 'usage_wizard', '🧙', 'Wealth Wizard'),
];

/// The highest usage title earned for [monthlyHours] of app time, or null when
/// under the first tier.
UsageTitle? usageTitleFor(double monthlyHours) {
  UsageTitle? best;
  for (final t in kUsageTitles) {
    if (monthlyHours >= t.minHours) best = t;
  }
  return best;
}

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
  /// One streak freeze is earned for every this-many days of streak.
  static const int freezeEarnInterval = 5;

  /// Most freezes a user can stockpile at once.
  static const int maxFreezes = 5;

  /// Pure streak transition, exposed for testing. Returns the new
  /// (current, longest) given the last-active date and today (date-only).
  /// When [freezeArmed] is set and exactly one day was missed (a gap of 2), the
  /// freeze bridges it — the streak continues instead of resetting — and
  /// [freezeUsed] is returned true so the caller can consume the freeze.
  static ({int current, int longest, bool freezeUsed}) advanceStreak({
    required DateTime? last,
    required int current,
    required int longest,
    required DateTime today,
    bool freezeArmed = false,
  }) {
    final t = DateTime(today.year, today.month, today.day);
    if (last != null) {
      final l = DateTime(last.year, last.month, last.day);
      if (l == t) {
        return (current: current, longest: longest, freezeUsed: false);
      }
      final gap = t.difference(l).inDays;
      final int newCurrent;
      var freezeUsed = false;
      if (gap == 1) {
        newCurrent = current + 1;
      } else if (gap == 2 && freezeArmed) {
        newCurrent = current + 1; // armed freeze covers the single missed day
        freezeUsed = true;
      } else {
        newCurrent = 1;
      }
      return (
        current: newCurrent,
        longest: newCurrent > longest ? newCurrent : longest,
        freezeUsed: freezeUsed,
      );
    }
    return (current: 1, longest: longest < 1 ? 1 : longest, freezeUsed: false);
  }

  /// Record that the app was opened today and roll the streak forward. Safe to
  /// call on every launch/resume; a no-op if today is already counted. Earns a
  /// freeze each time the streak lands on a multiple of [freezeEarnInterval],
  /// and clears an armed freeze that just bridged a missed day.
  Future<void> recordActiveDay({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final blob = await _read();
    final s = (blob['streak'] as Map?)?.cast<String, dynamic>() ?? {};
    final lastIso = s['last'] as String?;
    final last = lastIso == null ? null : DateTime.tryParse(lastIso);
    final t = DateTime(today.year, today.month, today.day);
    if (last != null && DateTime(last.year, last.month, last.day) == t) {
      return; // nothing changed
    }

    var freezes = (s['freezes'] as num?)?.toInt() ?? 0;
    final armed = s['freezeArmed'] == true;
    final prevCurrent = (s['current'] as num?)?.toInt() ?? 0;
    final result = advanceStreak(
      last: last,
      current: prevCurrent,
      longest: (s['longest'] as num?)?.toInt() ?? 0,
      today: today,
      freezeArmed: armed,
    );

    // The armed freeze (already moved out of `freezes` when armed) is spent.
    final stillArmed = armed && !result.freezeUsed;
    // Earn a freeze whenever the streak climbs onto a new multiple of N.
    if (result.current > prevCurrent &&
        result.current % freezeEarnInterval == 0) {
      freezes = (freezes + 1).clamp(0, maxFreezes);
    }

    blob['streak'] = {
      'last': t.toIso8601String(),
      'current': result.current,
      'longest': result.longest,
      'freezes': freezes,
      'freezeArmed': stillArmed,
    };
    await _write(blob);
  }

  /// Available (un-armed) streak freezes and whether one is currently armed.
  Future<({int available, bool armed})> freezeInfo() async {
    final blob = await _read();
    final s = (blob['streak'] as Map?)?.cast<String, dynamic>() ?? {};
    return (
      available: (s['freezes'] as num?)?.toInt() ?? 0,
      armed: s['freezeArmed'] == true,
    );
  }

  /// Arm a freeze to protect the next missed day, moving it from the available
  /// pool to "equipped". No-op (returns false) if none are available or one is
  /// already armed.
  Future<bool> armFreeze() async {
    final blob = await _read();
    final s = (blob['streak'] as Map?)?.cast<String, dynamic>() ?? {};
    final freezes = (s['freezes'] as num?)?.toInt() ?? 0;
    if (freezes <= 0 || s['freezeArmed'] == true) return false;
    s['freezes'] = freezes - 1;
    s['freezeArmed'] = true;
    blob['streak'] = s;
    await _write(blob);
    return true;
  }

  // ── Time in app (consistency heatmap + usage title) ──────────────────
  /// Add [seconds] of foreground time to today's tally. Called when the app is
  /// backgrounded; cheap and a no-op for non-positive values.
  Future<void> recordAppTime(int seconds, {DateTime? now}) async {
    if (seconds <= 0) return;
    final key = _dayKey(now ?? DateTime.now());
    final blob = await _read();
    final t = (blob['appTime'] as Map?)?.cast<String, dynamic>() ?? {};
    t[key] = ((t[key] as num?)?.toInt() ?? 0) + seconds;
    blob['appTime'] = t;
    await _write(blob);
  }

  /// Foreground seconds per day (date-only → seconds), for the heatmap.
  Future<Map<DateTime, int>> appTimeByDay() async {
    final blob = await _read();
    final t = (blob['appTime'] as Map?)?.cast<String, dynamic>() ?? {};
    final out = <DateTime, int>{};
    t.forEach((k, v) {
      final d = DateTime.tryParse(k);
      if (d != null) out[_dateOnly(d)] = (v as num).toInt();
    });
    return out;
  }

  /// Total foreground seconds in the current calendar month — drives the
  /// usage title (see [usageTitleFor]).
  Future<int> monthAppSeconds({DateTime? now}) async {
    final mk = _monthKey(now ?? DateTime.now());
    final blob = await _read();
    final t = (blob['appTime'] as Map?)?.cast<String, dynamic>() ?? {};
    var total = 0;
    t.forEach((k, v) {
      if (k.startsWith(mk)) total += (v as num).toInt();
    });
    return total;
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

  /// The day the streak was last advanced (the user's last active day), or
  /// null. Used by the streak reminder to tell if today is already covered.
  Future<DateTime?> lastActiveDate() async {
    final blob = await _read();
    final s = (blob['streak'] as Map?)?.cast<String, dynamic>() ?? {};
    final iso = s['last'] as String?;
    return iso == null ? null : DateTime.tryParse(iso);
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
