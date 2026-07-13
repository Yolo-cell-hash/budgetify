import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../models/streak_reward.dart';
import '../providers/theme_provider.dart';
import 'badge_medallion.dart';
import 'streak_flame.dart';

/// The Streak Reward Road: a vertical timeline of streak milestones. Each node
/// shows a tiered medallion (earned/locked), the reward, and — for unlocked
/// theme rewards — an Apply/Active control wired to [ThemeProvider]. Built to
/// grow: new milestones come from [kStreakRewards].
class StreakRewardRoad extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;

  /// Outer padding; defaults suit a scrollable page.
  final EdgeInsets padding;

  const StreakRewardRoad({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 32),
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StreakHeader(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < kStreakRewards.length; i++)
            _MilestoneTile(
              reward: kStreakRewards[i],
              longestStreak: longestStreak,
              currentStreak: currentStreak,
              isFirst: i == 0,
              nextUnlocked: i + 1 < kStreakRewards.length
                  ? kStreakRewards[i + 1].isUnlocked(longestStreak)
                  : false,
            ),
          // Trailing "more on the way" node keeps the road open-ended.
          _ComingSoonTile(colors: colors),
        ],
      ),
    );
  }
}

class _StreakHeader extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;

  const _StreakHeader({
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final next = kStreakRewards
        .where((r) => !r.isUnlocked(longestStreak))
        .fold<StreakReward?>(null, (a, b) => a ?? b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StreakFlame(streak: currentStreak, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currentStreak-day streak',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      context.l10n.bestStreak(longestStreak),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            next == null
                ? context.l10n.allStreakRewardsUnlocked
                : context.l10n.openToUnlock(_daysAway(context, next),
                    context.l10n.streakRewardName(next.id)),
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _daysAway(BuildContext context, StreakReward next) {
    final remaining = (next.days - longestStreak).clamp(0, next.days);
    if (remaining <= 0) return context.l10n.todayWord;
    return context.l10n.daysMore(remaining);
  }
}

class _MilestoneTile extends StatelessWidget {
  final StreakReward reward;
  final int longestStreak;
  final int currentStreak;
  final bool isFirst;
  final bool nextUnlocked;

  const _MilestoneTile({
    required this.reward,
    required this.longestStreak,
    required this.currentStreak,
    required this.isFirst,
    required this.nextUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final unlocked = reward.isUnlocked(longestStreak);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Rail(
            colors: colors,
            topFilled: !isFirst && unlocked,
            bottomFilled: nextUnlocked,
            node: BadgeMedallion(
              rarity: reward.rarity,
              emblem: reward.emblem,
              earned: unlocked,
              size: 52,
              animate: unlocked,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _RewardCard(
                reward: reward,
                unlocked: unlocked,
                currentStreak: currentStreak,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The vertical "road" rail: a node with connector segments above/below that
/// fill in (accent) once reached, or stay muted while locked.
class _Rail extends StatelessWidget {
  final AppColors colors;
  final bool topFilled;
  final bool bottomFilled;
  final Widget node;

  const _Rail({
    required this.colors,
    required this.topFilled,
    required this.bottomFilled,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    Color seg(bool filled) => filled ? colors.accent : colors.border;
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          Expanded(child: Container(width: 2.5, color: seg(topFilled))),
          node,
          Expanded(child: Container(width: 2.5, color: seg(bottomFilled))),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final StreakReward reward;
  final bool unlocked;
  final int currentStreak;

  const _RewardCard({
    required this.reward,
    required this.unlocked,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final variant = reward.themeVariant;
    final active = variant != null &&
        context.watch<ThemeProvider>().variant == variant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? colors.accent : colors.border,
          width: active ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SwatchPreview(colors: reward.swatch),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.l10n.tierBadgeLabel('${reward.days}-Day'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: unlocked
                                ? colors.accent
                                : colors.textTertiary,
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          _ActivePill(colors: colors),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.streakRewardName(reward.id),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: unlocked ? colors.text : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.streakRewardBlurb(reward.id),
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _action(context, colors, active),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, AppColors colors, bool active) {
    if (!unlocked) {
      final remaining = (reward.days - currentStreak).clamp(0, reward.days);
      return Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 15, color: colors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              remaining > 0
                  ? context.l10n.reachStreakStatus(reward.days, currentStreak)
                  : context.l10n.unlockingSoon,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
          ),
        ],
      );
    }

    if (reward.kind == StreakRewardKind.royalPick) {
      return Row(
        children: [
          Text('👑', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.l10n.royalPickRoadUnlocked,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: colors.accent,
              ),
            ),
          ),
        ],
      );
    }

    if (reward.themeVariant == null) {
      return _earnedPill(context, colors);
    }

    if (active) {
      return Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 6),
          Text(
            context.l10n.currentlyApplied,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: colors.accent,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            context.read<ThemeProvider>().setVariant(reward.themeVariant!),
        icon: const Icon(Icons.palette_outlined, size: 17),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.accent,
          side: BorderSide(color: colors.accent.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 11),
        ),
        label: Text(context.l10n.applyTheme),
      ),
    );
  }

  Widget _earnedPill(BuildContext context, AppColors colors) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          context.l10n.unlockedLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.success,
          ),
        ),
      );
}

class _ActivePill extends StatelessWidget {
  final AppColors colors;
  const _ActivePill({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        context.l10n.activeBadge,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: colors.accent,
        ),
      ),
    );
  }
}

/// A two-tone preview chip echoing the reference palette cards: accent over
/// canvas, the same two colours the theme uses.
class _SwatchPreview extends StatelessWidget {
  final List<Color> colors;
  const _SwatchPreview({required this.colors});

  @override
  Widget build(BuildContext context) {
    final border = AppColors.of(context).border;
    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Expanded(child: Container(color: colors.first)),
          Expanded(child: Container(color: colors.last)),
        ],
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  final AppColors colors;
  const _ComingSoonTile({required this.colors});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Expanded(child: Container(width: 2.5, color: colors.border)),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.more_horiz_rounded,
                      size: 18, color: colors.textTertiary),
                ),
                const SizedBox(height: 0),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                context.l10n.moreStreakRewards,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
