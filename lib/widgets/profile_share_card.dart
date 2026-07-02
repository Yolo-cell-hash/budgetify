import 'package:flutter/material.dart';

import '../app_info.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/achievement.dart';
import '../providers/theme_provider.dart';
import '../services/gamification_service.dart';
import 'avatars.dart';
import 'badge_medallion.dart';
import 'brand_logo.dart';

/// Max badges featured on the profile card.
const int kMaxShowcase = 4;

/// A resolved badge for the showcase row.
typedef ShowcaseBadge = ({
  BadgeRarity rarity,
  String emblem,
  String label,
  String group,
});

/// The premium, shareable profile card — avatar, username, earned titles, a
/// stats strip and up to four showcased badges, on the app's ink+gold hero
/// surface. Presentational so it can be displayed and rendered to an image for
/// sharing (set [animate] false when capturing).
class ProfileShareCard extends StatelessWidget {
  final GamiProfile profile;
  final int currentStreak;
  final List<GamiTitle> titles; // earned, primary first
  final List<ShowcaseBadge> showcased; // <= kMaxShowcase
  final int trophyCount;
  final bool animate;

  const ProfileShareCard({
    super.key,
    required this.profile,
    required this.currentStreak,
    required this.titles,
    required this.showcased,
    required this.trophyCount,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final accent = profile.avatarKind == 'pixel'
        ? pixelHaloOf(int.tryParse(profile.avatarValue) ?? 0)
        : accentOf(profile.avatarAccent);
    final name = profile.username.trim().isEmpty
        ? context.l10n.defaultBudgeteer
        : profile.username.trim();

    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 28, offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: accent),
              boxShadow: [BoxShadow(color: accent.first.withValues(alpha: 0.5), blurRadius: 22)],
            ),
            child: AvatarView(
              kind: profile.avatarKind,
              value: profile.avatarValue,
              accent: profile.avatarAccent,
              size: 82,
              ring: false,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: Colors.white),
          ),
          const SizedBox(height: 10),
          // Titles if earned; otherwise a neutral tagline (default theme).
          if (titles.isNotEmpty)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in titles.take(3))
                  _titleChip('${t.emoji} ${context.l10n.titleName(t.id)}'),
                if (titles.length > 3) _titleChip('+${titles.length - 3}'),
              ],
            )
          else
            Text(
              context.l10n.trackingWithBudgetify,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
            ),
          const SizedBox(height: 18),
          _statsStrip(context.l10n),
          if (showcased.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.trophyCase,
                style: TextStyle(
                  fontSize: 10.5, letterSpacing: 2, fontWeight: FontWeight.w700,
                  color: AppColors.gold.withValues(alpha: 0.85)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final b in showcased) _trophy(b)],
            ),
          ],
          const SizedBox(height: 20),
          // Brand footer: the mark + wordmark, motto beneath.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandLogo(size: 15),
              const SizedBox(width: 7),
              Text(
                'Budgetify',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3,
                  color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              kAppMotto,
              maxLines: 1,
              style: TextStyle(
                fontSize: 8.5,
                letterSpacing: 0.2,
                color: Colors.white.withValues(alpha: 0.40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsStrip(AppStrings l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _stat('🔥', '$currentStreak', l10n.dayStreakLabel),
          _divider(),
          _stat('🏆', '$trophyCount', l10n.trophyWord(trophyCount)),
          _divider(),
          _stat('🎖️', '${titles.length}', l10n.titleWord(titles.length)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.10));

  Widget _stat(String icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: Colors.white)),
          Text(label,
              style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.55))),
        ],
      ),
    );
  }

  Widget _trophy(ShowcaseBadge b) {
    return SizedBox(
      width: 66,
      child: Column(
        children: [
          BadgeMedallion(rarity: b.rarity, emblem: b.emblem, earned: true, size: 54, animate: animate),
          const SizedBox(height: 6),
          Text(b.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(b.group,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8.5, color: Colors.white.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _titleChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gold)),
    );
  }
}
