import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';
import 'achievement.dart';

/// What a streak milestone grants. Only [theme] exists today, but the model is
/// deliberately open so future streak rewards (avatars, titles, …) slot in.
enum StreakRewardKind { theme }

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
];

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
