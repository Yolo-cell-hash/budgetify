import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../models/achievement.dart';
import '../providers/theme_provider.dart';
import '../services/gamification_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/badge_medallion.dart';
import '../widgets/mythic.dart';
import '../widgets/profile_share_card.dart';

/// A badge the user has earned, resolved for the showcase picker.
typedef EarnedBadge = ({
  String id,
  String group,
  String emblem,
  BadgeRarity rarity,
  String label,
});

/// The Profile tab: the shareable card, edit/share actions, showcase picker and
/// earned titles. Pure props + callbacks; the hub owns the data + persistence.
class ProfileView extends StatefulWidget {
  final GamiProfile profile;
  final int currentStreak;
  final int trophyCount;
  final List<TitleProgress> titleProgress;
  final GamiTitle? primaryTitle;
  final List<ShowcaseBadge> showcased;
  final List<EarnedBadge> allEarned;
  final VoidCallback onEdit;
  final ValueChanged<List<String>> onUpdateShowcase;
  final ValueChanged<String?> onUpdatePrimaryTitle;

  const ProfileView({
    super.key,
    required this.profile,
    required this.currentStreak,
    required this.trophyCount,
    required this.titleProgress,
    required this.primaryTitle,
    required this.showcased,
    required this.allEarned,
    required this.onEdit,
    required this.onUpdateShowcase,
    required this.onUpdatePrimaryTitle,
  });

  List<GamiTitle> get earnedTitles =>
      [for (final p in titleProgress) if (p.earned) p.title];

  /// Earned titles with the chosen headline first (for the card + chips).
  List<GamiTitle> get orderedTitles {
    final p = primaryTitle;
    if (p == null) return earnedTitles;
    return [p, ...earnedTitles.where((t) => t.id != p.id)];
  }

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final l10n = context.l10nRead;
    try {
      // Let any in-flight layout settle before capturing.
      await Future.delayed(const Duration(milliseconds: 60));
      final boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/budgetify-profile.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: l10n.profileShareText,
      );
    } catch (_) {
      if (mounted) {
        showAppToast(context,
            message: l10n.couldntCreateShareImage,
            type: AppToastType.warning);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Center(
          child: RepaintBoundary(
            key: _shareKey,
            child: ProfileShareCard(
              profile: widget.profile,
              currentStreak: widget.currentStreak,
              titles: widget.orderedTitles,
              showcased: widget.showcased,
              trophyCount: widget.trophyCount,
              // Equipping the Master Budgeter crown transforms the card.
              mythic: widget.primaryTitle?.id == kMasterTitleId,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(context.l10n.commonEdit),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _share,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(
                    _sharing ? context.l10n.sharingProgress : context.l10n.shareLabel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionHeader(colors, context.l10n.showcase, '${widget.showcased.length}/$kMaxShowcase'),
        const SizedBox(height: 8),
        _card(
          colors,
          widget.allEarned.isEmpty
              ? Text(
                  context.l10n.earnBadgesDesc,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                )
              : InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickShowcase,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.showcased.isEmpty
                                ? context.l10n.chooseBadgesToFeature
                                : context.l10n.tapToChangeBadges,
                            style: TextStyle(fontSize: 13.5, color: colors.text),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                      ],
                    ),
                  ),
                ),
        ),
        // The mythic crown lives outside the regular gallery — a one-of-a-kind
        // rarity slot with its own banner and animation.
        if (_masterProgress != null) ...[
          const SizedBox(height: 24),
          _MythicTitleBanner(
            progress: _masterProgress!,
            isPrimary: widget.primaryTitle?.id == kMasterTitleId,
            onTap: () => _showTitleSheet(_masterProgress!),
          ),
        ],
        const SizedBox(height: 24),
        _sectionHeader(colors, context.l10n.titlesLabel, ''),
        const SizedBox(height: 8),
        _card(colors, _titles(colors)),
      ],
    );
  }

  /// Progress of the Master Budgeter crown (rendered apart from the gallery).
  TitleProgress? get _masterProgress {
    for (final p in widget.titleProgress) {
      if (p.title.kind == TitleKind.master) return p;
    }
    return null;
  }

  /// A gallery of every regular title — earned ones are colourful and tappable
  /// to set your headline; locked ones are muted and show how to earn them.
  /// The Master Budgeter crown is NOT here: as the one mythic-rarity title it
  /// gets its own banner above the gallery.
  Widget _titles(AppColors colors) {
    final tp = [
      for (final p in widget.titleProgress)
        if (p.title.kind != TitleKind.master) p
    ];
    final earnedCount = tp.where((p) => p.earned).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          earnedCount == 0
              ? context.l10n.titlesIntro
              : context.l10n.tapTitleDesc,
          style: TextStyle(fontSize: 12, color: colors.textTertiary, height: 1.4),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < tp.length; i++) ...[
          if (i > 0) Divider(height: 18, color: colors.border),
          _titleRow(colors, tp[i]),
        ],
      ],
    );
  }

  Widget _titleEmoji(AppColors colors, String emoji, bool earned, double size,
      {bool master = false}) {
    if (master && earned) {
      // The crown's emblem: gilded violet orb with a soft golden halo.
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [Color(0xFF3A2470), Color(0xFF1E1240)]),
          border: Border.all(color: Mythic.gold, width: size > 50 ? 2 : 1.4),
          boxShadow: [
            BoxShadow(
                color: Mythic.gold.withValues(alpha: 0.35),
                blurRadius: size > 50 ? 18 : 10),
          ],
        ),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.47)),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? AppColors.gold.withValues(alpha: 0.16) : colors.cardAlt,
        border: Border.all(
            color: earned ? AppColors.gold.withValues(alpha: 0.5) : colors.border,
            width: size > 50 ? 2 : 1),
      ),
      child: Opacity(
        opacity: earned ? 1 : 0.4,
        child: Text(emoji, style: TextStyle(fontSize: size * 0.47)),
      ),
    );
  }

  Widget _progressBar(AppColors colors, double fraction, bool earned,
      {double height = 6}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(height: height, color: colors.border),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: earned
                      ? [AppColors.successLight, AppColors.successDark]
                      : [AppColors.gold, AppColors.goldDeep],
                ),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleRow(AppColors colors, TitleProgress p) {
    final t = p.title;
    final earned = p.earned;
    final master = t.id == kMasterTitleId;
    final primary = earned && t.id == widget.primaryTitle?.id;
    final shown = p.current > p.target ? p.target : p.current;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showTitleSheet(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _titleEmoji(colors, t.emoji, earned, 38, master: master),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: master && earned
                            // The crown shimmers wherever it is displayed.
                            ? AnimatedMythicText(
                                context.l10n.titleName(t.id),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : Text(
                                context.l10n.titleName(t.id),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: earned
                                      ? colors.text
                                      : colors.textSecondary,
                                ),
                              ),
                      ),
                      if (primary)
                        const Icon(Icons.star_rounded, size: 16, color: AppColors.goldDeep)
                      else if (earned)
                        Icon(Icons.check_circle_rounded, size: 16, color: colors.success)
                      else
                        Icon(Icons.lock_rounded, size: 14, color: colors.textTertiary),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _progressBar(colors, p.fraction, earned)),
                      const SizedBox(width: 8),
                      Text('$shown/${p.target} ${context.l10n.gamiUnit(t.unit)}',
                          style: TextStyle(fontSize: 11, color: colors.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet with the title's full requirement, live progress, and (when
  /// earned) the option to feature it on the profile.
  void _showTitleSheet(TitleProgress p) {
    final colors = AppColors.of(context);
    final t = p.title;
    final earned = p.earned;
    final master = t.id == kMasterTitleId;
    final primary = earned && t.id == widget.primaryTitle?.id;
    final shown = p.current > p.target ? p.target : p.current;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _titleEmoji(colors, t.emoji, earned, 72, master: master),
            const SizedBox(height: 14),
            if (master && earned)
              AnimatedMythicText(context.l10nRead.titleName(t.id),
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800))
            else
              Text(context.l10nRead.titleName(t.id),
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: colors.text)),
            if (master) ...[
              const SizedBox(height: 5),
              // The one mythic-rarity title wears its rarity tag everywhere.
              Text(
                '✦ ${context.l10nRead.mythicTag.toUpperCase()} ✦',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  color: earned ? Mythic.ember : colors.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (earned ? colors.success : colors.textTertiary).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(earned ? Icons.check_circle_rounded : Icons.lock_rounded,
                      size: 14, color: earned ? colors.success : colors.textSecondary),
                  const SizedBox(width: 5),
                  Text(earned ? context.l10nRead.earned : context.l10nRead.inProgress,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: earned ? colors.success : colors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.l10nRead.titleBlurb(t.id),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: colors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(context.l10nRead.progressLabel,
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                const Spacer(),
                Text('$shown / ${p.target} ${context.l10nRead.gamiUnit(t.unit)}',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.text)),
              ],
            ),
            const SizedBox(height: 8),
            _progressBar(colors, p.fraction, earned, height: 8),
            if (earned) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onUpdatePrimaryTitle(primary ? null : t.id);
                    Navigator.pop(ctx);
                  },
                  icon: Icon(primary ? Icons.star_rounded : Icons.star_outline_rounded, size: 18),
                  label: Text(primary
                      ? context.l10nRead.removeFromProfile
                      : context.l10nRead.featureOnProfile),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(AppColors colors, String title, String trailing) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: colors.text,
          ),
        ),
        const Spacer(),
        if (trailing.isNotEmpty)
          Text(trailing, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
      ],
    );
  }

  Widget _card(AppColors colors, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: child,
      );

  Future<void> _pickShowcase() async {
    final selected = List<String>.from(widget.profile.showcasedBadgeIds);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShowcasePicker(
        all: widget.allEarned,
        initial: selected,
      ),
    );
    if (result != null) widget.onUpdateShowcase(result);
  }
}

/// The Master Budgeter banner — the app's only mythic-rarity title, displayed
/// apart from the regular title gallery like a mythic-rare drop: void-violet
/// canvas, breathing gold/cyan border, a live aura of halo rings and orbiting
/// sparks, and a shimmering crown name once earned. While locked it stays
/// dark and aspirational — dimmed aura, lock badge, live progress bar.
class _MythicTitleBanner extends StatefulWidget {
  final TitleProgress progress;
  final bool isPrimary;
  final VoidCallback onTap;

  const _MythicTitleBanner({
    required this.progress,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_MythicTitleBanner> createState() => _MythicTitleBannerState();
}

class _MythicTitleBannerState extends State<_MythicTitleBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final earned = p.earned;
    final shown = p.current > p.target ? p.target : p.current;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final breath = (math.sin(t * 2 * math.pi) + 1) / 2;
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: Mythic.cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: earned
                    ? Mythic.borderAt(t)
                    : Mythic.gold.withValues(alpha: 0.35),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Mythic.deepViolet.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                if (earned)
                  BoxShadow(
                    color: Mythic.gold.withValues(alpha: 0.10 + breath * 0.12),
                    blurRadius: 26,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: earned ? 1 : 0.45,
                      child: CustomPaint(
                        painter: MythicAuraPainter(
                          t: t,
                          focus: const Alignment(-0.68, -1),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        _crown(earned, breath),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '✦ ${context.l10n.mythicTag.toUpperCase()} ✦',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 3,
                                        color: Mythic.cyan,
                                      ),
                                    ),
                                  ),
                                  if (widget.isPrimary)
                                    const Icon(Icons.star_rounded,
                                        size: 16, color: Mythic.gold)
                                  else if (earned)
                                    const Icon(Icons.check_circle_rounded,
                                        size: 15, color: Mythic.cyan)
                                  else
                                    Icon(Icons.lock_rounded,
                                        size: 14,
                                        color:
                                            Colors.white.withValues(alpha: 0.45)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (earned)
                                MythicShimmerText(
                                  context.l10n.titleName(p.title.id),
                                  t: t,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                )
                              else
                                Text(
                                  context.l10n.titleName(p.title.id),
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                    color: Color(0xFFB9AEDB),
                                  ),
                                ),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: Stack(
                                        children: [
                                          Container(
                                            height: 6,
                                            color: Colors.white
                                                .withValues(alpha: 0.10),
                                          ),
                                          FractionallySizedBox(
                                            widthFactor:
                                                p.fraction.clamp(0.0, 1.0),
                                            child: Container(
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: Mythic.crownGradient,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$shown/${p.target} ${context.l10n.gamiUnit(p.title.unit)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Mythic.paleGold
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The gilded crown orb — glowing when earned, padlocked while not.
  Widget _crown(bool earned, double breath) {
    const size = 54.0;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [Color(0xFF3A2470), Color(0xFF1E1240)]),
            border: Border.all(
              color: earned
                  ? Mythic.gold
                  : Mythic.gold.withValues(alpha: 0.45),
              width: 1.8,
            ),
            boxShadow: [
              if (earned)
                BoxShadow(
                  color: Mythic.gold.withValues(alpha: 0.30 + breath * 0.25),
                  blurRadius: 14 + breath * 6,
                ),
            ],
          ),
          child: Opacity(
            opacity: earned ? 1 : 0.55,
            child: Text(widget.progress.title.emoji,
                style: const TextStyle(fontSize: 25)),
          ),
        ),
        if (!earned)
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Mythic.abyss,
              border: Border.all(color: Mythic.ember),
            ),
            child:
                const Icon(Icons.lock_rounded, size: 10, color: Mythic.paleGold),
          ),
      ],
    );
  }
}

class _ShowcasePicker extends StatefulWidget {
  final List<EarnedBadge> all;
  final List<String> initial;
  const _ShowcasePicker({required this.all, required this.initial});

  @override
  State<_ShowcasePicker> createState() => _ShowcasePickerState();
}

class _ShowcasePickerState extends State<_ShowcasePicker> {
  late final List<String> _sel = List.from(widget.initial);

  void _toggle(String id) {
    setState(() {
      if (_sel.contains(id)) {
        _sel.remove(id);
      } else if (_sel.length < kMaxShowcase) {
        _sel.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.l10n.featuredBadges,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              Text('${_sel.length}/$kMaxShowcase',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 14,
                runSpacing: 16,
                children: [
                  for (final b in widget.all)
                    GestureDetector(
                      onTap: () => _toggle(b.id),
                      child: SizedBox(
                        width: 70,
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Opacity(
                                  opacity: _sel.contains(b.id) ? 1 : 0.5,
                                  child: BadgeMedallion(
                                    rarity: b.rarity,
                                    emblem: b.emblem,
                                    earned: true,
                                    size: 58,
                                    animate: false,
                                  ),
                                ),
                                if (_sel.contains(b.id))
                                  const Icon(Icons.check_circle_rounded,
                                      size: 18, color: AppColors.gold),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _sel),
              child: Text(context.l10n.commonDone),
            ),
          ),
        ],
      ),
    );
  }
}
