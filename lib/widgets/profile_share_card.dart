import 'dart:math' as math;

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
import 'mythic.dart';
import 'royal_avatars.dart';

/// Max badges featured on the profile card.
const int kMaxShowcase = 4;

/// A resolved badge for the showcase row.
typedef ShowcaseBadge = ({
  BadgeRarity rarity,
  String emblem,
  String label,
  String group,
});

/// The premium, shareable profile card — avatar in a double ring, username,
/// the headline title on a banner, a stats strip and an honours section where
/// showcased medals and remaining titles sit side by side.
///
/// When [mythic] is set (the Master Budgeter crown is equipped) the card
/// transforms: void-violet canvas, breathing gold/starlight border, an aura of
/// rings and orbiting sparks, and a shimmering crown banner. Presentational so
/// it can be rendered to an image for sharing (set [animate] false when
/// capturing — the mythic frame then renders as a rich static frame).
class ProfileShareCard extends StatefulWidget {
  final GamiProfile profile;
  final int currentStreak;
  final List<GamiTitle> titles; // earned, primary first
  final List<ShowcaseBadge> showcased; // <= kMaxShowcase
  final int trophyCount;
  final bool animate;
  final bool mythic;

  const ProfileShareCard({
    super.key,
    required this.profile,
    required this.currentStreak,
    required this.titles,
    required this.showcased,
    required this.trophyCount,
    this.animate = true,
    this.mythic = false,
  });

  @override
  State<ProfileShareCard> createState() => _ProfileShareCardState();
}

class _ProfileShareCardState extends State<ProfileShareCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  /// The equipped royal character, when the avatar is a royal pixel sprite.
  /// Royals re-skin the whole card with their [RoyalTheme]; canvas
  /// precedence is royal > mythic (the mythic crown keeps its shimmering
  /// title treatment either way — the two compose).
  RoyalAvatar? get _royal => widget.profile.avatarKind == 'pixel'
      ? royalAvatarAt(int.tryParse(widget.profile.avatarValue) ?? 0)
      : null;

  bool get _live => widget.animate && (widget.mythic || _royal != null);

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(ProfileShareCard old) {
    super.didUpdateWidget(old);
    _syncController();
  }

  void _syncController() {
    if (_live && _c == null) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6),
      )..repeat();
    } else if (!_live && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      // Static frame: mid-sheen looks best in captures and previews.
      return _card(context, widget.mythic ? 0.35 : 0.5);
    }
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => _card(context, c.value),
    );
  }

  Widget _card(BuildContext context, double t) {
    final mythic = widget.mythic;
    final royal = _royal;
    final profile = widget.profile;
    // Pixel-only roster; a legacy emoji value maps to its migration sprite.
    final halo = pixelHaloOf(profile.avatarKind == 'pixel'
        ? (int.tryParse(profile.avatarValue) ?? 0)
        : legacyEmojiSeed(profile.avatarValue));
    final name = profile.username.trim().isEmpty
        ? context.l10n.defaultBudgeteer
        : profile.username.trim();
    final headline = widget.titles.isEmpty ? null : widget.titles.first;
    final extraTitles =
        widget.titles.length > 1 ? widget.titles.sublist(1) : const <GamiTitle>[];
    final breath = (math.sin(t * 2 * math.pi) + 1) / 2;
    // The card's name glow: the royal's accent outranks the mythic gold.
    final nameGlow = royal?.theme.accent ?? (mythic ? Mythic.gold : null);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _eyebrow(context, mythic),
        const SizedBox(height: 16),
        _avatarBlock(halo, t, mythic),
        const SizedBox(height: 12),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: Colors.white,
            shadows: nameGlow != null
                ? [
                    Shadow(
                      color: nameGlow.withValues(alpha: 0.35 + breath * 0.25),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 10),
        if (headline != null) ...[
          _headlineBanner(context, headline, t),
          if (extraTitles.isNotEmpty) ...[
            const SizedBox(height: 10),
            _titleChips(context, extraTitles),
          ],
        ] else
          Text(
            context.l10n.trackingWithBudgetify,
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
          ),
        const SizedBox(height: 18),
        _statsStrip(context.l10n, mythic),
        if (widget.showcased.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionRule(context.l10n.trophyCase, mythic),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final b in widget.showcased) _trophy(b)],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandLogo(size: 15),
            const SizedBox(width: 7),
            Text(
              'Budgetify',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
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
    );

    return Container(
      width: 340,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // Canvas precedence: royal court > mythic void > hero.
          colors: royal?.theme.cardGradient ??
              (mythic ? Mythic.cardGradient : AppColors.heroGradient),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: royal?.theme.borderAt(t) ??
              (mythic
                  ? Mythic.borderAt(t)
                  : AppColors.gold.withValues(alpha: 0.4)),
          width: (mythic || royal != null) ? 1.4 : 1,
        ),
        boxShadow: royal != null
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 34,
                    offset: const Offset(0, 16)),
                BoxShadow(
                    color: royal.theme.accent
                        .withValues(alpha: 0.08 + breath * 0.12),
                    blurRadius: 30),
              ]
            : mythic
                ? [
                    BoxShadow(
                        color: Mythic.deepViolet.withValues(alpha: 0.55),
                        blurRadius: 34,
                        offset: const Offset(0, 16)),
                    BoxShadow(
                        color:
                            Mythic.gold.withValues(alpha: 0.08 + breath * 0.10),
                        blurRadius: 30),
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 28,
                        offset: const Offset(0, 14)),
                  ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            if (royal != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: RoyalAuraPainter(theme: royal.theme, t: t),
                ),
              )
            else if (mythic)
              Positioned.fill(
                child: CustomPaint(painter: MythicAuraPainter(t: t)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  /// Tiny letter-spaced masthead between two hairlines.
  Widget _eyebrow(BuildContext context, bool mythic) {
    final label = context.l10n.profileCardEyebrow.toUpperCase();
    final color =
        _royal?.theme.accentSoft ?? (mythic ? Mythic.cyan : AppColors.gold);
    return Row(
      children: [
        Expanded(child: _hairline(color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ),
        Expanded(child: _hairline(color)),
      ],
    );
  }

  Widget _hairline(Color color) => Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.45),
          ]),
        ),
      );

  /// Avatar in a double ring: a coordinating (mythic/royal: slowly
  /// revolving) gradient ring, a dark gap, then the avatar itself. An
  /// equipped royal supplies its own ring colours and glow — and already
  /// wears a crown, so the mythic crown emoji stays off.
  Widget _avatarBlock(List<Color> halo, double t, bool mythic) {
    final royal = _royal;
    final ringColors = royal?.theme.ringColors ??
        (mythic
            ? const [Mythic.gold, Mythic.cyan, Mythic.deepViolet, Mythic.gold]
            : halo);
    final glow = royal?.theme.accent ?? (mythic ? Mythic.gold : halo.first);
    final revolving = mythic || royal != null;
    final ring = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [...ringColors, ringColors.first]),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.45),
            blurRadius: 24,
          ),
        ],
      ),
    );
    return SizedBox(
      width: 106,
      height: 106,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (revolving)
            Transform.rotate(angle: t * 2 * math.pi, child: ring)
          else
            ring,
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mythic ? Mythic.abyss : const Color(0xFF131520),
            ),
          ),
          AvatarView(
            kind: widget.profile.avatarKind,
            value: widget.profile.avatarValue,
            size: 84,
            ring: false,
            animateRoyals: widget.animate,
          ),
          if (mythic && royal == null)
            const Positioned(
              top: 0,
              child: Text('👑', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }

  /// The headline title, displayed proudly under the name. The Master
  /// Budgeter crown gets its own animated treatment; other titles get a
  /// gilded banner between hairlines.
  Widget _headlineBanner(BuildContext context, GamiTitle title, double t) {
    if (title.id == kMasterTitleId) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MythicShimmerText(
            '👑 ${context.l10n.titleName(title.id).toUpperCase()}',
            t: t,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '✦ ${context.l10n.mythicTag.toUpperCase()} ✦',
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 3.5,
              fontWeight: FontWeight.w700,
              color: Mythic.cyan,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bannerRule(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${title.emoji}  ${context.l10n.titleName(title.id).toUpperCase()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.gold,
            ),
          ),
        ),
        _bannerRule(),
      ],
    );
  }

  Widget _bannerRule() => Container(
        width: 26,
        height: 1,
        color: AppColors.gold.withValues(alpha: 0.5),
      );

  Widget _titleChips(BuildContext context, List<GamiTitle> titles) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in titles.take(2)) _titleChip(context, t),
        if (titles.length > 2) _plainChip('+${titles.length - 2}'),
      ],
    );
  }

  Widget _titleChip(BuildContext context, GamiTitle t) {
    final master = t.id == kMasterTitleId;
    final text = '${t.emoji} ${context.l10n.titleName(t.id)}';
    if (master) {
      // The crown among ordinary chips: gilded violet, always distinctive.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF3A2470), Color(0xFF1E1240)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Mythic.gold.withValues(alpha: 0.7)),
        ),
        child: MythicShimmerText(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }
    return _plainChip(text);
  }

  Widget _plainChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gold)),
    );
  }

  Widget _sectionRule(String label, bool mythic) {
    final color = _royal?.theme.accent ?? AppColors.gold;
    return Row(
      children: [
        Expanded(child: _hairline(color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ),
        Expanded(child: _hairline(color)),
      ],
    );
  }

  Widget _statsStrip(AppStrings l10n, bool mythic) {
    final royalAccent = _royal?.theme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: (mythic || royalAccent != null) ? 0.07 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: royalAccent?.withValues(alpha: 0.30) ??
              (mythic
                  ? Mythic.gold.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          _stat('🔥', '${widget.currentStreak}', l10n.dayStreakLabel),
          _divider(),
          _stat('🏆', '${widget.trophyCount}', l10n.trophyWord(widget.trophyCount)),
          _divider(),
          _stat('🎖️', '${widget.titles.length}', l10n.titleWord(widget.titles.length)),
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
          BadgeMedallion(
              rarity: b.rarity,
              emblem: b.emblem,
              earned: true,
              size: 54,
              animate: widget.animate),
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
}
