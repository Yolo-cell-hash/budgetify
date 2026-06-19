import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/achievement.dart';
import '../providers/theme_provider.dart';
import '../services/gamification_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/badge_medallion.dart';
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
  final List<GamiTitle> earnedTitles;
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
    required this.earnedTitles,
    required this.primaryTitle,
    required this.showcased,
    required this.allEarned,
    required this.onEdit,
    required this.onUpdateShowcase,
    required this.onUpdatePrimaryTitle,
  });

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
        text: 'My Budgetify rewards 🏆',
      );
    } catch (_) {
      if (mounted) {
        showAppToast(context,
            message: "Couldn't create the share image just now",
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
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _share,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(_sharing ? 'Sharing…' : 'Share'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionHeader(colors, 'Showcase', '${widget.showcased.length}/$kMaxShowcase'),
        const SizedBox(height: 8),
        _card(
          colors,
          widget.allEarned.isEmpty
              ? Text(
                  'Earn badges in the Trophies tab to feature them here.',
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
                                ? 'Choose up to 5 badges to feature'
                                : 'Tap to change your featured badges',
                            style: TextStyle(fontSize: 13.5, color: colors.text),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(colors, 'Titles', ''),
        const SizedBox(height: 8),
        _card(colors, _titles(colors)),
      ],
    );
  }

  /// A gallery of every title — earned ones are colourful and tappable to set
  /// your headline; locked ones are muted and show how to earn them. Mirrors
  /// the Trophies tab so titles are just as visible.
  Widget _titles(AppColors colors) {
    final earnedIds = widget.earnedTitles.map((t) => t.id).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          earnedIds.isEmpty
              ? 'Titles reflect where your money goes — none earned yet.'
              : 'Tap an earned title to feature it on your profile.',
          style: TextStyle(fontSize: 12, color: colors.textTertiary, height: 1.4),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < kTitles.length; i++) ...[
          if (i > 0) Divider(height: 18, color: colors.border),
          _titleRow(colors, kTitles[i], earnedIds.contains(kTitles[i].id)),
        ],
      ],
    );
  }

  Widget _titleRow(AppColors colors, GamiTitle t, bool earned) {
    final primary = earned && t.id == widget.primaryTitle?.id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showTitleSheet(t, earned),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned ? AppColors.gold.withValues(alpha: 0.16) : colors.cardAlt,
                border: Border.all(
                    color: earned ? AppColors.gold.withValues(alpha: 0.5) : colors.border),
              ),
              child: Opacity(
                opacity: earned ? 1 : 0.4,
                child: Text(t.emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: earned ? colors.text : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    t.blurb,
                    style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!earned)
              Icon(Icons.lock_rounded, size: 16, color: colors.textTertiary)
            else if (primary)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 13, color: AppColors.goldDeep),
                    SizedBox(width: 3),
                    Text('Featured',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.goldDeep)),
                  ],
                ),
              )
            else
              Icon(Icons.radio_button_unchecked_rounded,
                  size: 18, color: AppColors.gold.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet describing a title in full (with its window) + earn status.
  /// Earned titles can be featured on the profile from here.
  void _showTitleSheet(GamiTitle t, bool earned) {
    final colors = AppColors.of(context);
    final primary = earned && t.id == widget.primaryTitle?.id;
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
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned ? AppColors.gold.withValues(alpha: 0.16) : colors.cardAlt,
                border: Border.all(
                    color: earned ? AppColors.gold.withValues(alpha: 0.5) : colors.border,
                    width: 2),
              ),
              child: Opacity(
                opacity: earned ? 1 : 0.4,
                child: Text(t.emoji, style: const TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 14),
            Text(t.name,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: colors.text)),
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
                  Text(earned ? 'Earned' : 'Locked',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: earned ? colors.success : colors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t.blurb,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: colors.textSecondary),
            ),
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
                  label: Text(primary ? 'Remove from profile' : 'Feature on profile'),
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
                'Featured badges',
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
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
