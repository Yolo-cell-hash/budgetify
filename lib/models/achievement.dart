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

  // Titles — category spend as a share of income over each title's window,
  // plus the windowed savings rate. Null/empty when there isn't enough
  // income/history to judge.
  final Map<String, double> categoryIncomeShare;
  final double? savingsRate; // trailing-window savings rate (fraction)
  final bool hasIncomeForTitles;

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
    this.categoryIncomeShare = const {},
    this.savingsRate,
    this.hasIncomeForTitles = false,
  });
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

/// An earnable title shown on the profile. Predicate is pure over [GamiStats].
class GamiTitle {
  final String id;
  final String emoji;
  final String name;
  final String blurb;
  final bool Function(GamiStats) earned;

  const GamiTitle({
    required this.id,
    required this.emoji,
    required this.name,
    required this.blurb,
    required this.earned,
  });
}

/// All titles the user currently qualifies for (may be empty — titles are
/// earned, there is no default).
List<GamiTitle> evaluateTitles(GamiStats stats) =>
    [for (final t in kTitles) if (t.earned(stats)) t];

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

bool _share(GamiStats s, String category, double min) =>
    s.hasIncomeForTitles && (s.categoryIncomeShare[category] ?? 0) >= min;

/// Tag-based titles. Category titles use a share of income over a trailing
/// window (computed by the service); savings titles use the windowed rate.
final List<GamiTitle> kTitles = [
  GamiTitle(id: 'foodie', emoji: '🍔', name: 'Foodie', blurb: 'Spend 35%+ of your income on Food & Dining, averaged over the last 6 months.', earned: (s) => _share(s, 'Food & Dining', 0.35)),
  GamiTitle(id: 'homechef', emoji: '🍳', name: 'Home Chef', blurb: 'Spend 25%+ of your income on Groceries, averaged over the last 6 months.', earned: (s) => _share(s, 'Groceries', 0.25)),
  GamiTitle(id: 'shopaholic', emoji: '🛍️', name: 'Shopaholic', blurb: 'Spend 25%+ of your income on Shopping, averaged over the last 6 months.', earned: (s) => _share(s, 'Shopping', 0.25)),
  GamiTitle(id: 'roadwarrior', emoji: '🚗', name: 'Road Warrior', blurb: 'Spend 20%+ of your income on Transportation, averaged over the last 6 months.', earned: (s) => _share(s, 'Transportation', 0.20)),
  GamiTitle(id: 'billmaster', emoji: '🧾', name: 'Bill Master', blurb: 'Spend 25%+ of your income on Bills & Utilities, averaged over the last 6 months.', earned: (s) => _share(s, 'Bills & Utilities', 0.25)),
  GamiTitle(id: 'showstopper', emoji: '🎬', name: 'Showstopper', blurb: 'Spend 20%+ of your income on Entertainment, averaged over the last 6 months.', earned: (s) => _share(s, 'Entertainment', 0.20)),
  GamiTitle(id: 'wellness', emoji: '🩺', name: 'Wellness Warrior', blurb: 'Spend 15%+ of your income on Health & Medical, averaged over the last 6 months.', earned: (s) => _share(s, 'Health & Medical', 0.15)),
  GamiTitle(id: 'globetrotter', emoji: '✈️', name: 'Globetrotter', blurb: 'Spend 25%+ of your income on Travel, averaged over the last 3 months.', earned: (s) => _share(s, 'Travel', 0.25)),
  GamiTitle(id: 'scholar', emoji: '🎓', name: 'Scholar', blurb: 'Spend 15%+ of your income on Education, averaged over the last 6 months.', earned: (s) => _share(s, 'Education', 0.15)),
  GamiTitle(id: 'investor', emoji: '📈', name: 'Investor', blurb: 'Invest 20%+ of your income, averaged over the last 6 months.', earned: (s) => _share(s, 'Investments', 0.20)),
  GamiTitle(id: 'moneymagnet', emoji: '💰', name: 'Money Magnet', blurb: 'Keep a savings rate of 35%+ over the last 6 months.', earned: (s) => s.hasIncomeForTitles && (s.savingsRate ?? 0) >= 0.35),
  GamiTitle(id: 'frugal', emoji: '🪙', name: 'Frugal Master', blurb: 'Keep a savings rate of 60%+ over the last 6 months.', earned: (s) => s.hasIncomeForTitles && (s.savingsRate ?? 0) >= 0.60),
  GamiTitle(id: 'broke', emoji: '😅', name: 'Broke Spender', blurb: 'Rack up 60 total no-spend days (they need not be in a row).', earned: (s) => s.noSpendDays >= 60),
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
