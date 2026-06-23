import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/achievement.dart';
import '../providers/theme_provider.dart';
import '../widgets/badge_medallion.dart';

String gamiFormat(num v, GamiUnit unit) {
  switch (unit) {
    case GamiUnit.rupees:
      if (v >= 10000000) {
        final cr = v / 10000000;
        return '₹${cr.toStringAsFixed(cr % 1 == 0 ? 0 : 1)}Cr';
      }
      if (v >= 100000) {
        final l = v / 100000;
        return '₹${l.toStringAsFixed(l % 1 == 0 ? 0 : 1)}L';
      }
      return '₹${NumberFormat.decimalPattern('en_IN').format(v.round())}';
    case GamiUnit.count:
      return NumberFormat.decimalPattern('en_IN').format(v.round());
    case GamiUnit.days:
      return '${v.round()}';
    case GamiUnit.months:
      return v >= 10 ? '${v.round()}' : v.toStringAsFixed(1);
  }
}

/// The Trophy Room: every badge group with earned/locked medallions and
/// progress toward the next tier.
class TrophyRoomView extends StatelessWidget {
  final List<GroupProgress> groups;
  final Map<String, DateTime> unlockDates;

  const TrophyRoomView({
    super.key,
    required this.groups,
    required this.unlockDates,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _GroupCard(progress: groups[i], unlockDates: unlockDates),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupProgress progress;
  final Map<String, DateTime> unlockDates;

  const _GroupCard({required this.progress, required this.unlockDates});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final g = progress.group;

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
              Text(g.emblem, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  g.name,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: colors.text,
                  ),
                ),
              ),
              Text(
                '${progress.earnedCount}/${g.tiers.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: progress.isComplete ? colors.success : colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var i = 0; i < g.tiers.length; i++)
                _tile(context, colors, i),
            ],
          ),
          if (!progress.isComplete) ...[
            const SizedBox(height: 16),
            _nextProgress(colors),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, AppColors colors, int i) {
    final tier = progress.group.tiers[i];
    final earned = progress.earned[i];
    return GestureDetector(
      onTap: () => _showDetail(context, i),
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            BadgeMedallion(
              rarity: tier.rarity,
              emblem: progress.group.emblem,
              earned: earned,
              size: 62,
              animate: earned,
            ),
            const SizedBox(height: 6),
            Text(
              tier.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: earned ? colors.text : colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nextProgress(AppColors colors) {
    final next = progress.nextTier!;
    final g = progress.group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Next: ${next.label}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${gamiFormat(progress.value, g.unit)} / ${gamiFormat(next.threshold, g.unit)}',
              style: TextStyle(fontSize: 12, color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 6, color: colors.border),
              FractionallySizedBox(
                widthFactor: progress.nextProgress.clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.goldDeep],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, int i) {
    final colors = AppColors.of(context);
    final g = progress.group;
    final tier = g.tiers[i];
    final earned = progress.earned[i];
    final date = unlockDates[g.badgeId(i)];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeMedallion(
              rarity: tier.rarity,
              emblem: g.emblem,
              earned: earned,
              size: 110,
            ),
            const SizedBox(height: 16),
            Text(
              '${g.name} · ${tier.label}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.tierLabel(context.l10n.tierName(rarityName(tier.rarity))),
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              g.blurb,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (earned ? colors.success : colors.textTertiary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                earned
                    ? (date != null
                        ? context.l10n.earnedOn(context.l10n.mediumDate(date))
                        : context.l10n.earned)
                    : context.l10n.lockedProgress(
                        gamiFormat(progress.value, g.unit),
                        gamiFormat(tier.threshold, g.unit)),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: earned ? colors.success : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
