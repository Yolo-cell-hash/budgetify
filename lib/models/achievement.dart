// Gamified Budgets — the pure achievement & title engine.
//
// No I/O and no Flutter imports: everything here is deterministic maths over a
// [GamiStats] snapshot, so the whole catalog (thresholds, progress, titles) is
// unit-tested directly. The service layer ([GamificationService]) builds the
// stats from the database and persists profile/unlock state; the widgets render
// the results. Higher rarity = rarer/harder badge, which also drives the visual
// and animation tier.

/// Visual + difficulty tier for a badge. Copper is the most common, diamond the
/// rarest. Drives the medallion's metal/gem treatment and its animation.
enum BadgeRarity { copper, bronze, silver, gold, platinum, ruby, diamond }

/// A snapshot of everything the engine needs, computed once from the database.
/// Plain data — no logic beyond trivial getters — so tests can construct it
/// directly.
class GamiStats {
  // Streak (daily app usage)
  final int currentStreak;
  final int longestStreak;

  // Volume
  final double totalTracked; // all money in + out
  final int txnCount;
  final double monthsOfData; // history span, in (fractional) months

  // Discipline
  final int fullyTaggedMonths; // months with >=1 txn and 0 unclassified
  final int monthsWithinBudget; // months total spend <= overall budget
  final int monthsSavingsRate20; // months with savings rate >= 20%
  final int noSpendDays; // cumulative days with zero spend
  final int distinctCategories; // distinct expense categories ever used

  // Wealth
  final double netWorth;
  final int debtFreeDays; // consecutive days debt-free (assets>0, no debt)
  final int goalsCompleted; // savings goals fully funded

  // Per-month history (one entry per completed month that had income), used to
  // count how many months a title's rule was actually met.
  final List<MonthStat> monthStats;

  const GamiStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalTracked = 0,
    this.txnCount = 0,
    this.monthsOfData = 0,
    this.fullyTaggedMonths = 0,
    this.monthsWithinBudget = 0,
    this.monthsSavingsRate20 = 0,
    this.noSpendDays = 0,
    this.distinctCategories = 0,
    this.netWorth = 0,
    this.debtFreeDays = 0,
    this.goalsCompleted = 0,
    this.monthStats = const [],
  });
}

/// One completed month's title-relevant figures: each category's share of that
/// month's income, and the month's savings rate.
class MonthStat {
  final Map<String, double> categoryShare;
  final double savingsRate;
  const MonthStat({required this.categoryShare, required this.savingsRate});
}

/// One rung of an [AchievementGroup].
class AchievementTier {
  final num threshold;
  final BadgeRarity rarity;
  final String label; // milestone label, e.g. "₹2L", "7-Day", "1 Year"

  const AchievementTier(this.threshold, this.rarity, this.label);
}

/// How a group's current value is formatted for display.
enum GamiUnit { days, rupees, count, months }

/// A ladder of badges measuring one dimension (streak, amount tracked, …).
class AchievementGroup {
  final String id;
  final String name;
  final String emblem; // emoji glyph at the medallion's centre
  final String blurb; // one-line description for the detail sheet
  final GamiUnit unit;
  final List<AchievementTier> tiers; // ascending by threshold
  final double Function(GamiStats) valueOf;

  const AchievementGroup({
    required this.id,
    required this.name,
    required this.emblem,
    required this.blurb,
    required this.unit,
    required this.tiers,
    required this.valueOf,
  });

  /// Stable id for a specific tier badge (used for showcase + unlock tracking).
  String badgeId(int tierIndex) => '$id.$tierIndex';
}

/// Evaluated state of a group against a [GamiStats].
class GroupProgress {
  final AchievementGroup group;
  final double value;
  final List<bool> earned; // one flag per tier
  final int nextTierIndex; // -1 when every tier is earned
  final double nextProgress; // 0..1 toward the next tier (1 when complete)

  const GroupProgress({
    required this.group,
    required this.value,
    required this.earned,
    required this.nextTierIndex,
    required this.nextProgress,
  });

  int get earnedCount => earned.where((e) => e).length;
  bool get isComplete => nextTierIndex < 0;
  AchievementTier? get nextTier =>
      isComplete ? null : group.tiers[nextTierIndex];
}

/// Evaluate one group: which tiers are earned and progress to the next.
GroupProgress evaluateGroup(AchievementGroup group, GamiStats stats) {
  final value = group.valueOf(stats);
  final earned = [for (final t in group.tiers) value >= t.threshold];
  final nextIndex = earned.indexWhere((e) => !e);
  double progress;
  if (nextIndex < 0) {
    progress = 1; // all done
  } else {
    final prev = nextIndex == 0 ? 0.0 : group.tiers[nextIndex - 1].threshold.toDouble();
    final next = group.tiers[nextIndex].threshold.toDouble();
    progress = ((value - prev) / (next - prev)).clamp(0.0, 1.0);
  }
  return GroupProgress(
    group: group,
    value: value,
    earned: earned,
    nextTierIndex: nextIndex,
    nextProgress: progress,
  );
}

/// Evaluate every group in the catalog.
List<GroupProgress> evaluateAchievements(GamiStats stats) =>
    [for (final g in kAchievementGroups) evaluateGroup(g, stats)];

/// Every earned badge id across all groups (for unlock tracking / showcase).
Set<String> earnedBadgeIds(GamiStats stats) {
  final out = <String>{};
  for (final g in kAchievementGroups) {
    final p = evaluateGroup(g, stats);
    for (var i = 0; i < g.tiers.length; i++) {
      if (p.earned[i]) out.add(g.badgeId(i));
    }
  }
  return out;
}

// ─────────────────────────── Titles ───────────────────────────

/// What a title measures. [master] is the final-boss crown: it counts every
/// badge in every ladder plus every other title.
enum TitleKind { category, savings, nospend, master }

/// Id of the "Master Budgeter" crown — earned only when every medal and every
/// other title is unlocked. UI special-cases it for the mythic treatment.
const String kMasterTitleId = 'masterbudgeter';

/// An earnable title. Declarative data so progress is computed purely: meet
/// [threshold] (a share of income) in [target] qualifying months, or reach
/// [target] no-spend days for [TitleKind.nospend].
class GamiTitle {
  final String id;
  final String emoji;
  final String name;
  final String blurb;
  final TitleKind kind;
  final String? category; // for TitleKind.category
  final double threshold; // income share; unused for nospend
  final int target; // qualifying months, or no-spend days

  const GamiTitle({
    required this.id,
    required this.emoji,
    required this.name,
    required this.blurb,
    required this.kind,
    this.category,
    this.threshold = 0,
    required this.target,
  });

  /// 'months' for category/savings titles, 'days' for no-spend, 'unlocks'
  /// for the master crown (badges + titles collected).
  String get unit => switch (kind) {
        TitleKind.nospend => 'days',
        TitleKind.master => 'unlocks',
        _ => 'months',
      };
}

/// A title with how far the user is toward earning it.
class TitleProgress {
  final GamiTitle title;
  final int current;
  final int target;
  const TitleProgress(this.title, this.current, this.target);

  bool get earned => current >= target;
  double get fraction => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);
}

/// Progress toward every title — counts the qualifying months (or no-spend
/// days) the user actually has, so the UI can show a "N / target" bar. The
/// master crown instead counts every earned badge and every earned regular
/// title against the full catalog.
List<TitleProgress> evaluateTitleProgress(GamiStats stats) {
  int monthsMeeting(bool Function(MonthStat) test) =>
      stats.monthStats.where(test).length;

  int currentFor(GamiTitle t) => switch (t.kind) {
        TitleKind.category => monthsMeeting(
            (m) => (m.categoryShare[t.category] ?? 0) >= t.threshold),
        TitleKind.savings => monthsMeeting((m) => m.savingsRate >= t.threshold),
        TitleKind.nospend => stats.noSpendDays,
        TitleKind.master => 0, // computed against the whole catalog below
      };

  final regular = [for (final t in kTitles) if (t.kind != TitleKind.master) t];
  final earnedRegular =
      regular.where((t) => currentFor(t) >= t.target).length;
  final totalBadges =
      kAchievementGroups.fold<int>(0, (n, g) => n + g.tiers.length);
  final earnedBadges = earnedBadgeIds(stats).length;

  return [
    for (final t in kTitles)
      t.kind == TitleKind.master
          ? TitleProgress(
              t, earnedBadges + earnedRegular, totalBadges + regular.length)
          : TitleProgress(t, currentFor(t), t.target),
  ];
}

/// All titles the user currently qualifies for (may be empty — titles are
/// earned, there is no default).
List<GamiTitle> evaluateTitles(GamiStats stats) =>
    [for (final p in evaluateTitleProgress(stats)) if (p.earned) p.title];

// ─────────────────────────── Catalog ───────────────────────────

const int _kCategoryExplorerAll = 9; // main predefined expense categories

/// The badge ladders. Thresholds and rarities are intentional and tunable.
final List<AchievementGroup> kAchievementGroups = [
  AchievementGroup(
    id: 'streak',
    name: 'Daily Streak',
    emblem: '🔥',
    blurb: 'Open Budgetify on consecutive days. Your best streak keeps the badge.',
    unit: GamiUnit.days,
    valueOf: (s) => s.longestStreak.toDouble(),
    tiers: const [
      AchievementTier(7, BadgeRarity.copper, '7-Day'),
      AchievementTier(30, BadgeRarity.bronze, '30-Day'),
      AchievementTier(50, BadgeRarity.silver, '50-Day'),
      AchievementTier(100, BadgeRarity.gold, '100-Day'),
      AchievementTier(200, BadgeRarity.platinum, '200-Day'),
      AchievementTier(300, BadgeRarity.ruby, '300-Day'),
      AchievementTier(365, BadgeRarity.diamond, '1 Year'),
      AchievementTier(548, BadgeRarity.diamond, '1.5 Years'),
      AchievementTier(730, BadgeRarity.diamond, '2 Years'),
    ],
  ),
  AchievementGroup(
    id: 'amount',
    name: 'Money Tracked',
    emblem: '💎',
    blurb: 'Total value tracked across every transaction, money in and out.',
    unit: GamiUnit.rupees,
    valueOf: (s) => s.totalTracked,
    tiers: const [
      AchievementTier(200000, BadgeRarity.copper, '₹2L'),
      AchievementTier(400000, BadgeRarity.bronze, '₹4L'),
      AchievementTier(800000, BadgeRarity.silver, '₹8L'),
      AchievementTier(1200000, BadgeRarity.gold, '₹12L'),
      AchievementTier(1800000, BadgeRarity.platinum, '₹18L'),
      AchievementTier(2500000, BadgeRarity.ruby, '₹25L'),
      AchievementTier(5000000, BadgeRarity.diamond, '₹50L'),
    ],
  ),
  AchievementGroup(
    id: 'txn',
    name: 'Transactions',
    emblem: '🧾',
    blurb: 'Every transaction the app has tracked for you.',
    unit: GamiUnit.count,
    valueOf: (s) => s.txnCount.toDouble(),
    tiers: const [
      AchievementTier(500, BadgeRarity.copper, '500'),
      AchievementTier(750, BadgeRarity.bronze, '750'),
      AchievementTier(1000, BadgeRarity.silver, '1,000'),
      AchievementTier(1500, BadgeRarity.gold, '1,500'),
      AchievementTier(2000, BadgeRarity.platinum, '2,000'),
      AchievementTier(4000, BadgeRarity.ruby, '4,000'),
      AchievementTier(8000, BadgeRarity.diamond, '8,000'),
    ],
  ),
  AchievementGroup(
    id: 'history',
    name: 'Time Tracked',
    emblem: '📅',
    blurb: 'How long your money history spans.',
    unit: GamiUnit.months,
    valueOf: (s) => s.monthsOfData,
    tiers: const [
      AchievementTier(3, BadgeRarity.copper, '3 Months'),
      AchievementTier(6, BadgeRarity.bronze, '6 Months'),
      AchievementTier(9, BadgeRarity.silver, '9 Months'),
      AchievementTier(12, BadgeRarity.gold, '1 Year'),
      AchievementTier(18, BadgeRarity.platinum, '1.5 Years'),
      AchievementTier(24, BadgeRarity.ruby, '2 Years'),
      AchievementTier(48, BadgeRarity.diamond, '4 Years'),
    ],
  ),
  AchievementGroup(
    id: 'tagged',
    name: 'Fully Tagged',
    emblem: '🏷️',
    blurb: 'Months where every transaction was categorised (need not be in a row).',
    unit: GamiUnit.months,
    valueOf: (s) => s.fullyTaggedMonths.toDouble(),
    tiers: const [
      AchievementTier(1, BadgeRarity.copper, '1 Month'),
      AchievementTier(2, BadgeRarity.bronze, '2 Months'),
      AchievementTier(4, BadgeRarity.silver, '4 Months'),
      AchievementTier(6, BadgeRarity.gold, '6 Months'),
      AchievementTier(12, BadgeRarity.platinum, '12 Months'),
      AchievementTier(18, BadgeRarity.ruby, '18 Months'),
      AchievementTier(36, BadgeRarity.diamond, '36 Months'),
    ],
  ),
  AchievementGroup(
    id: 'budget',
    name: 'Budget Hero',
    emblem: '🛡️',
    blurb: 'Months you finished within your overall budget.',
    unit: GamiUnit.months,
    valueOf: (s) => s.monthsWithinBudget.toDouble(),
    tiers: const [
      AchievementTier(1, BadgeRarity.copper, '1 Month'),
      AchievementTier(3, BadgeRarity.silver, '3 Months'),
      AchievementTier(6, BadgeRarity.gold, '6 Months'),
      AchievementTier(12, BadgeRarity.diamond, '12 Months'),
    ],
  ),
  AchievementGroup(
    id: 'saver',
    name: 'Super Saver',
    emblem: '💰',
    blurb: 'Months you saved at least 20% of your income.',
    unit: GamiUnit.months,
    valueOf: (s) => s.monthsSavingsRate20.toDouble(),
    tiers: const [
      AchievementTier(1, BadgeRarity.copper, '1 Month'),
      AchievementTier(3, BadgeRarity.silver, '3 Months'),
      AchievementTier(6, BadgeRarity.gold, '6 Months'),
      AchievementTier(12, BadgeRarity.diamond, '12 Months'),
    ],
  ),
  AchievementGroup(
    id: 'networth',
    name: 'Net Worth',
    emblem: '🏦',
    blurb: 'Your tracked net worth (assets minus debts).',
    unit: GamiUnit.rupees,
    valueOf: (s) => s.netWorth,
    tiers: const [
      AchievementTier(100000, BadgeRarity.copper, '₹1L'),
      AchievementTier(500000, BadgeRarity.bronze, '₹5L'),
      AchievementTier(1000000, BadgeRarity.silver, '₹10L'),
      AchievementTier(2500000, BadgeRarity.gold, '₹25L'),
      AchievementTier(5000000, BadgeRarity.platinum, '₹50L'),
      AchievementTier(10000000, BadgeRarity.diamond, '₹1Cr'),
    ],
  ),
  AchievementGroup(
    id: 'debtfree',
    name: 'Debt-Free',
    emblem: '🕊️',
    blurb: 'Stay debt-free (assets, zero liabilities) for 120 days straight.',
    unit: GamiUnit.days,
    valueOf: (s) => s.debtFreeDays.toDouble(),
    tiers: const [
      AchievementTier(120, BadgeRarity.platinum, '120-Day'),
    ],
  ),
  AchievementGroup(
    id: 'nospend',
    name: 'No-Spend Days',
    emblem: '🧘',
    blurb: 'Days with zero spending, totalled up over time.',
    unit: GamiUnit.days,
    valueOf: (s) => s.noSpendDays.toDouble(),
    tiers: const [
      AchievementTier(10, BadgeRarity.copper, '10 Days'),
      AchievementTier(30, BadgeRarity.silver, '30 Days'),
      AchievementTier(60, BadgeRarity.gold, '60 Days'),
    ],
  ),
  AchievementGroup(
    id: 'goals',
    name: 'Goal Getter',
    emblem: '🎯',
    blurb: 'Savings goals you have fully funded.',
    unit: GamiUnit.count,
    valueOf: (s) => s.goalsCompleted.toDouble(),
    tiers: const [
      AchievementTier(1, BadgeRarity.copper, '1 Goal'),
      AchievementTier(3, BadgeRarity.silver, '3 Goals'),
      AchievementTier(5, BadgeRarity.gold, '5 Goals'),
      AchievementTier(10, BadgeRarity.diamond, '10 Goals'),
    ],
  ),
  AchievementGroup(
    id: 'explorer',
    name: 'Category Explorer',
    emblem: '🧭',
    blurb: 'Different spending categories you have used.',
    unit: GamiUnit.count,
    valueOf: (s) => s.distinctCategories.toDouble(),
    tiers: const [
      AchievementTier(5, BadgeRarity.copper, '5'),
      AchievementTier(8, BadgeRarity.silver, '8'),
      AchievementTier(_kCategoryExplorerAll, BadgeRarity.gold, 'All'),
    ],
  ),
];

/// Tag-based titles. Earned by meeting the threshold in [target] qualifying
/// months (not an average), so the UI can show real progress toward each.
final List<GamiTitle> kTitles = [
  GamiTitle(id: 'foodie', emoji: '🍔', name: 'Foodie', kind: TitleKind.category, category: 'Food & Dining', threshold: 0.35, target: 6, blurb: 'Have 6 months where Food & Dining was 35%+ of your income.'),
  GamiTitle(id: 'homechef', emoji: '🍳', name: 'Home Chef', kind: TitleKind.category, category: 'Groceries', threshold: 0.25, target: 6, blurb: 'Have 6 months where Groceries were 25%+ of your income.'),
  GamiTitle(id: 'shopaholic', emoji: '🛍️', name: 'Shopaholic', kind: TitleKind.category, category: 'Shopping', threshold: 0.25, target: 6, blurb: 'Have 6 months where Shopping was 25%+ of your income.'),
  GamiTitle(id: 'roadwarrior', emoji: '🚗', name: 'Road Warrior', kind: TitleKind.category, category: 'Transportation', threshold: 0.20, target: 6, blurb: 'Have 6 months where Transportation was 20%+ of your income.'),
  GamiTitle(id: 'billmaster', emoji: '🧾', name: 'Bill Master', kind: TitleKind.category, category: 'Bills & Utilities', threshold: 0.25, target: 6, blurb: 'Have 6 months where Bills & Utilities were 25%+ of your income.'),
  GamiTitle(id: 'showstopper', emoji: '🎬', name: 'Showstopper', kind: TitleKind.category, category: 'Entertainment', threshold: 0.20, target: 6, blurb: 'Have 6 months where Entertainment was 20%+ of your income.'),
  GamiTitle(id: 'wellness', emoji: '🩺', name: 'Wellness Warrior', kind: TitleKind.category, category: 'Health & Medical', threshold: 0.15, target: 6, blurb: 'Have 6 months where Health & Medical was 15%+ of your income.'),
  GamiTitle(id: 'globetrotter', emoji: '✈️', name: 'Globetrotter', kind: TitleKind.category, category: 'Travel', threshold: 0.25, target: 3, blurb: 'Have 3 months where Travel was 25%+ of your income.'),
  GamiTitle(id: 'scholar', emoji: '🎓', name: 'Scholar', kind: TitleKind.category, category: 'Education', threshold: 0.15, target: 6, blurb: 'Have 6 months where Education was 15%+ of your income.'),
  GamiTitle(id: 'investor', emoji: '📈', name: 'Investor', kind: TitleKind.category, category: 'Investments', threshold: 0.20, target: 6, blurb: 'Have 6 months where you invested 20%+ of your income.'),
  GamiTitle(id: 'moneymagnet', emoji: '💰', name: 'Money Magnet', kind: TitleKind.savings, threshold: 0.35, target: 6, blurb: 'Have 6 months with a savings rate of 35%+.'),
  GamiTitle(id: 'frugal', emoji: '🪙', name: 'Frugal Master', kind: TitleKind.savings, threshold: 0.60, target: 6, blurb: 'Have 6 months with a savings rate of 60%+.'),
  GamiTitle(id: 'broke', emoji: '😅', name: 'Broke Spender', kind: TitleKind.nospend, target: 90, blurb: 'Rack up 90 total no-spend days (they need not be in a row).'),
  // The final boss. [target] is a placeholder — evaluateTitleProgress derives
  // the real target from the catalog (every badge + every title above).
  GamiTitle(id: kMasterTitleId, emoji: '👑', name: 'Master Budgeter', kind: TitleKind.master, target: 1, blurb: 'Unlock every medal and every other title to claim the final crown.'),
];

/// Lookup a title by id (for the persisted "primary title" choice).
GamiTitle? titleById(String? id) {
  if (id == null) return null;
  for (final t in kTitles) {
    if (t.id == id) return t;
  }
  return null;
}

/// Lookup a (group, tierIndex) for a badge id like "amount.3".
({AchievementGroup group, int tierIndex})? badgeById(String id) {
  final dot = id.lastIndexOf('.');
  if (dot < 0) return null;
  final gid = id.substring(0, dot);
  final idx = int.tryParse(id.substring(dot + 1));
  if (idx == null) return null;
  for (final g in kAchievementGroups) {
    if (g.id == gid && idx >= 0 && idx < g.tiers.length) {
      return (group: g, tierIndex: idx);
    }
  }
  return null;
}
