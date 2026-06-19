import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../providers/theme_provider.dart';
import '../services/gamification_service.dart';
import 'avatars.dart';
import 'badge_medallion.dart';

/// A resolved badge for the showcase row.
typedef ShowcaseBadge = ({BadgeRarity rarity, String emblem, String label});

/// The premium, shareable profile card — avatar, username, primary title,
/// streak and up to five showcased badges, on the app's ink+gold hero surface.
/// Presentational so it can be both displayed and rendered to an image for
/// sharing (set [animate] false when capturing). Sized for social (portrait).
class ProfileShareCard extends StatelessWidget {
  final GamiProfile profile;
  final int currentStreak;
  final GamiTitle? primaryTitle;
  final List<ShowcaseBadge> showcased;
  final bool animate;

  const ProfileShareCard({
    super.key,
    required this.profile,
    required this.currentStreak,
    required this.primaryTitle,
    required this.showcased,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(profile.avatarAccent);
    final name = profile.username.trim().isEmpty ? 'Budgeteer' : profile.username.trim();

    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accent halo behind the avatar.
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: accent),
              boxShadow: [
                BoxShadow(
                  color: accent.first.withValues(alpha: 0.5),
                  blurRadius: 22,
                ),
              ],
            ),
            child: AvatarView(
              kind: profile.avatarKind,
              value: profile.avatarValue,
              accent: profile.avatarAccent,
              size: 86,
              ring: false,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (primaryTitle != null)
            _chip('${primaryTitle!.emoji}  ${primaryTitle!.name}', AppColors.gold)
          else
            _chip('Rising Budgeteer', Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          _chip(
            '🔥  ${currentStreak > 0 ? '$currentStreak-day streak' : 'New streak'}',
            const Color(0xFFFF8A5B),
          ),
          if (showcased.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'TROPHY CASE',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: AppColors.gold.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final b in showcased)
                  BadgeMedallion(
                    rarity: b.rarity,
                    emblem: b.emblem,
                    earned: true,
                    size: 54,
                    animate: animate,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('✨', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                'Budgetify',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color == AppColors.gold ? AppColors.gold : Colors.white,
        ),
      ),
    );
  }
}
