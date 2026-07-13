import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';
import 'achievement.dart';

/// What a streak milestone grants. [theme] applies a colour variant;
/// [royalPick] grants one "royal pick" — a choice to unlock any one of the
/// royal avatars from the ROYALTY section of the avatar picker.
enum StreakRewardKind { theme, royalPick }

/// One milestone on the Streak Reward Road: reach [days] consecutive days to
/// unlock it. Unlock is evaluated against the user's *longest* streak, so it is
/// permanent — a broken streak never re-locks an already-earned reward.
class StreakReward {
  final String id; // stable id, used for "newly unlocked" tracking
  final int days; // streak threshold in days
  final String name;
  final String blurb;
  final StreakRewardKind kind;
  final AppThemeVariant? themeVariant; // set when kind == theme
  final BadgeRarity rarity; // medallion treatment on the road
  final String emblem; // emoji at the medallion's centre
  final List<Color> swatch; // preview colours: [accent, canvas]

  const StreakReward({
    required this.id,
    required this.days,
    required this.name,
    required this.blurb,
    required this.kind,
    required this.rarity,
    required this.emblem,
    required this.swatch,
    this.themeVariant,
  });

  bool isUnlocked(int longestStreak) => longestStreak >= days;
}

/// The Streak Reward Road, ascending by [StreakReward.days]. Add new milestones
/// here as the streak system grows.
const List<StreakReward> kStreakRewards = [
  StreakReward(
    id: 'theme_smoky_ivory',
    days: 3,
    name: 'Smoky Blue & Warm Ivory',
    blurb:
        'A calm smoky-blue accent on a warm ivory canvas. Unlocked at a 3-day streak.',
    kind: StreakRewardKind.theme,
    themeVariant: AppThemeVariant.smokyIvory,
    rarity: BadgeRarity.bronze,
    emblem: '🎨',
    swatch: [Color(0xFF70798A), Color(0xFFEDDECB)],
  ),
  StreakReward(
    id: 'theme_seashell_mauve',
    days: 7,
    name: 'Soft Seashell & Dusty Mauve',
    blurb:
        'Blush seashell with a dusty-mauve accent. Unlocked at a 7-day streak.',
    kind: StreakRewardKind.theme,
    themeVariant: AppThemeVariant.seashellMauve,
    rarity: BadgeRarity.silver,
    emblem: '🌸',
    swatch: [Color(0xFF9E756F), Color(0xFFD7C4BE)],
  ),
  // First royal pick: choose any one of the six royals to unlock.
  StreakReward(
    id: 'royal_pick_1',
    days: 10,
    name: 'Royal Unlock',
    blurb:
        'Choose any one of the six royal avatars to unlock. Unlocked at a 10-day streak.',
    kind: StreakRewardKind.royalPick,
    rarity: BadgeRarity.gold,
    emblem: '👑',
    swatch: [Color(0xFFF2C14E), Color(0xFF4A121A)],
  ),
  StreakReward(
    id: 'theme_onyx_amber',
    days: 14,
    name: 'Onyx & Amber',
    blurb:
        'A vivid amber accent on a deep onyx canvas. Unlocked at a 14-day streak.',
    kind: StreakRewardKind.theme,
    themeVariant: AppThemeVariant.onyxAmber,
    rarity: BadgeRarity.gold,
    emblem: '⚡',
    swatch: [Color(0xFFFF8C00), Color(0xFF202427)],
  ),
  // Second royal pick: choose another royal from the remaining five.
  StreakReward(
    id: 'royal_pick_2',
    days: 24,
    name: 'Royal Unlock',
    blurb:
        'Choose another royal avatar to unlock, from the remaining five. Unlocked at a 24-day streak.',
    kind: StreakRewardKind.royalPick,
    rarity: BadgeRarity.platinum,
    emblem: '👑',
    swatch: [Color(0xFFB18CFF), Color(0xFF32175E)],
  ),
  StreakReward(
    id: 'theme_royal_indigo',
    days: 30,
    name: 'Royal Indigo',
    blurb:
        'The crown jewel — a deep-indigo accent with an electric-cyan hero on a '
        'frosted-lavender canvas. Unlocked at a 30-day streak.',
    kind: StreakRewardKind.theme,
    themeVariant: AppThemeVariant.royalIndigo,
    rarity: BadgeRarity.platinum,
    emblem: '👑',
    swatch: [Color(0xFF4530B3), Color(0xFFDDEAF6)],
  ),
  StreakReward(
    id: 'theme_midnight_indigo',
    days: 45,
    name: 'Midnight Indigo',
    blurb:
        'Royal Indigo after dark — an electric-cyan accent on a deep '
        'indigo-navy canvas. Unlocked at a 45-day streak.',
    kind: StreakRewardKind.theme,
    themeVariant: AppThemeVariant.midnightIndigo,
    rarity: BadgeRarity.ruby,
    emblem: '🌌',
    swatch: [Color(0xFF27C0F5), Color(0xFF0D1430)],
  ),
];

/// Streak lengths (in days) that each grant one royal-avatar pick. Kept in
/// sync with the [StreakRewardKind.royalPick] entries in [kStreakRewards].
const List<int> kRoyalPickStreaks = [10, 24];

/// How many royal picks a [longestStreak] has earned (0, 1 or 2).
int royalPicksEarned(int longestStreak) =>
    kRoyalPickStreaks.where((d) => longestStreak >= d).length;

/// All rewards unlocked at [longestStreak], in road order.
List<StreakReward> unlockedStreakRewards(int longestStreak) =>
    [for (final r in kStreakRewards) if (r.isUnlocked(longestStreak)) r];

/// The ids unlocked at [longestStreak] (for celebration / "seen" tracking).
Set<String> unlockedStreakRewardIds(int longestStreak) =>
    {for (final r in kStreakRewards) if (r.isUnlocked(longestStreak)) r.id};

/// Lookup a reward by id.
StreakReward? streakRewardById(String id) {
  for (final r in kStreakRewards) {
    if (r.id == id) return r;
  }
  return null;
}

/// The reward that grants [variant], if any.
StreakReward? streakRewardForVariant(AppThemeVariant variant) {
  for (final r in kStreakRewards) {
    if (r.themeVariant == variant) return r;
  }
  return null;
}
