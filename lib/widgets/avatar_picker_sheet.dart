import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';

import '../providers/theme_provider.dart';
import '../services/gamification_service.dart';
import 'app_toast.dart';
import 'avatars.dart';
import 'royal_avatars.dart';

/// Edit the profile's avatar (emoji or procedural pixel) + accent + username.
/// Returns the edited [GamiProfile], or null if cancelled.
///
/// Royal avatars are gated: [unlockedRoyals] are the ids the user has already
/// unlocked (via streak picks), and [royalPicksAvailable] is how many
/// still-locked royals they may unlock right now. Spending a pick calls
/// [onUnlockRoyal] so the host can persist it. The currently-equipped royal
/// (if any) is always treated as unlocked, so nobody loses their face.
Future<GamiProfile?> showAvatarPicker(
  BuildContext context,
  GamiProfile initial, {
  Set<String> unlockedRoyals = const {},
  int royalPicksAvailable = 0,
  Future<void> Function(String royalId)? onUnlockRoyal,
  bool scrollToRoyalty = false,
}) {
  return showModalBottomSheet<GamiProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AvatarPickerSheet(
      initial: initial,
      unlockedRoyals: unlockedRoyals,
      royalPicksAvailable: royalPicksAvailable,
      onUnlockRoyal: onUnlockRoyal,
      scrollToRoyalty: scrollToRoyalty,
    ),
  );
}

class _AvatarPickerSheet extends StatefulWidget {
  final GamiProfile initial;
  final Set<String> unlockedRoyals;
  final int royalPicksAvailable;
  final Future<void> Function(String royalId)? onUnlockRoyal;
  final bool scrollToRoyalty;
  const _AvatarPickerSheet({
    required this.initial,
    this.unlockedRoyals = const {},
    this.royalPicksAvailable = 0,
    this.onUnlockRoyal,
    this.scrollToRoyalty = false,
  });

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  // Royals the user may equip — only those unlocked with a streak pick.
  late final Set<String> _unlocked = {...widget.unlockedRoyals};

  // The roster is pixel-only; a legacy emoji profile opens on its migration
  // sprite. A royal that isn't unlocked (e.g. one restored from a pre-gating
  // backup) can never be the equipped value — fall back to a basic avatar.
  late String _value = _sanitizedInitialValue();
  late bool _applyRoyalTheme = widget.initial.applyRoyalTheme;
  late final TextEditingController _name =
      TextEditingController(text: widget.initial.username);

  // Picks left to spend on still-locked royals this session.
  late int _picks = widget.royalPicksAvailable;

  String _sanitizedInitialValue() {
    final v = widget.initial.avatarKind == 'pixel'
        ? widget.initial.avatarValue
        : '${legacyEmojiSeed(widget.initial.avatarValue)}';
    final royal = royalAvatarAt(int.tryParse(v) ?? -1);
    if (royal != null && !_unlocked.contains(royal.id)) return '0';
    return v;
  }

  // Anchors the ROYALTY section so an "Unlock Now" deep-link can scroll to it.
  final GlobalKey _royaltyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToRoyalty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Let the sheet finish presenting, then bring ROYALTY into view.
        await Future.delayed(const Duration(milliseconds: 320));
        final ctx = _royaltyKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          alignment: 0.05,
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  bool _isRoyalUnlocked(RoyalAvatar r) => _unlocked.contains(r.id);

  /// Spend a pick to unlock [r], then equip it. Persists via [onUnlockRoyal].
  Future<void> _unlockRoyal(RoyalAvatar r) async {
    if (_picks <= 0 || _isRoyalUnlocked(r)) return;
    setState(() {
      _unlocked.add(r.id);
      _picks -= 1;
      _value = '${r.spriteIndex}';
    });
    await widget.onUnlockRoyal?.call(r.id);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      widget.initial.copyWith(
        username: _name.text.trim(),
        avatarKind: 'pixel',
        avatarValue: _value,
        applyRoyalTheme: _applyRoyalTheme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              // Keyed by the selection so equipping a royal replays its
              // spawn flourish in the preview.
              child: AvatarView(
                key: ValueKey(_value),
                kind: 'pixel',
                value: _value,
                size: 88,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: context.l10n.usernameLabel,
                hintText: context.l10n.pickAName,
              ),
            ),
            const SizedBox(height: 8),
            _sectionLabel(colors, context.l10n.pixelAvatarLabel),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final seed in kFreePixelSeeds)
                  _option(colors, '$seed', '$seed' == _value),
              ],
            ),
            // Elite characters: the showpiece art, in its own category.
            const SizedBox(height: 16),
            Row(
              children: [
                _sectionLabel(colors, context.l10n.eliteAvatarsLabel),
                const SizedBox(width: 6),
                Icon(Icons.workspace_premium_rounded,
                    size: 14, color: colors.brandAccent),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.eliteAvatarsDesc,
              style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final e in kEliteAvatars) _eliteOption(colors, e),
              ],
            ),
            // Royalty: the court above elite — living avatars with their
            // own aura, backdrop and profile-card theme.
            const SizedBox(height: 18),
            Row(
              key: _royaltyKey,
              children: [
                _sectionLabel(colors, context.l10n.royalAvatarsLabel),
                const SizedBox(width: 6),
                const Text('👑', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.royalAvatarsDesc,
              style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
            ),
            const SizedBox(height: 10),
            _royalStatusLine(colors),
            const SizedBox(height: 12),
            // Two showpiece tiles per row — the court is too large for one.
            LayoutBuilder(
              builder: (ctx, constraints) {
                final tileWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final r in kRoyalAvatars)
                      SizedBox(
                        width: tileWidth,
                        child: _royalOption(colors, r),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _save, child: Text(context.l10n.commonSave)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(AppColors colors, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: colors.textSecondary,
        ),
      );

  /// The ROYALTY unlock status: a gold call-to-action when picks are waiting,
  /// a calm "coming soon" hint otherwise. Hidden once the whole court is
  /// unlocked (nothing left to say).
  Widget _royalStatusLine(AppColors colors) {
    final allUnlocked = kRoyalAvatars.every(_isRoyalUnlocked);
    if (allUnlocked) return const SizedBox.shrink();
    if (_picks > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.brandAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.brandAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_open_rounded, size: 15, color: colors.brandAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.royalPicksAvailable(_picks),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: colors.brandAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      context.l10n.royalLockedHint,
      style: TextStyle(fontSize: 11.5, height: 1.35, color: colors.textTertiary),
    );
  }

  Widget _option(AppColors colors, String value, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _value = value),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.brandAccent : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: AvatarView(kind: 'pixel', value: value, size: 46, ring: false),
      ),
    );
  }

  /// A one-tap row inside the royal sheet: if the user isn't on the royal's
  /// home primary theme, offer to switch to it so the dress goes live; if
  /// they already are, a calm confirmation instead.
  Widget _modeSwitchRow(BuildContext ctx, RoyalAvatar r, Color accent) {
    final theme = ctx.watch<ThemeProvider>();
    final wantsLight = r.theme.homeBrightness == Brightness.light;
    final onHome = (theme.variant == AppThemeVariant.light) == wantsLight &&
        (theme.variant == AppThemeVariant.light ||
            theme.variant == AppThemeVariant.dark);
    if (onHome) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 15, color: accent),
            const SizedBox(width: 6),
            Text(
              ctx.l10n.royalOnHomeTheme,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.of(ctx).textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => theme.setVariant(wantsLight
              ? AppThemeVariant.light
              : AppThemeVariant.dark),
          style: TextButton.styleFrom(
            foregroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          ),
          icon: Icon(
              wantsLight ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 16),
          label: Text(ctx.l10n.royalSwitchMode(wantsLight),
              style: const TextStyle(fontSize: 12.5)),
        ),
      ),
    );
  }

  /// The royal's court sheet: living avatar, lore, which primary theme it
  /// dresses, the per-royal app-wide theme toggle, and the Equip action.
  Future<void> _showRoyalSheet(RoyalAvatar r) async {
    final colors = AppColors.of(context);
    // A royal's bright accent (gold / lavender) is legible on a dark
    // surface but washes out on the light picker; use the deep, ink-legible
    // shade whenever the surface is light so names/borders stay readable.
    final accent = Theme.of(context).brightness == Brightness.light
        ? r.theme.accentDeep
        : r.theme.accent;
    final value = '${r.spriteIndex}';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final equipped = _value == value;
          final unlocked = _isRoyalUnlocked(r);
          final unlockable = !unlocked && _picks > 0;
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            // Scrolls on short screens — the lore + note + toggle stack can
            // outgrow a small viewport (or a large text scale).
            child: SingleChildScrollView(
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
                // The royal presents itself — spawn flourish included.
                AvatarView(kind: 'pixel', value: value, size: 92, ring: false),
                const SizedBox(height: 10),
                Text(
                  ctx.l10n.royalAvatarName(r.id),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ctx.l10n.royalAvatarLore(r.id),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                // Home-court note: which primary theme the effects live in.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        r.theme.homeBrightness == Brightness.light
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 14,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          ctx.l10n.royalHomeNote(
                              r.theme.homeBrightness == Brightness.light),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Unlocked royals get the app-wide theme toggle + Equip. A
                // still-locked royal shows either an Unlock action (a pick is
                // waiting) or a calm "coming soon" note.
                if (unlocked) ...[
                  // "Apply app-wide <court> theme" — the royal's own wording.
                  SwitchListTile(
                    value: _applyRoyalTheme,
                    onChanged: (v) {
                      setState(() => _applyRoyalTheme = v);
                      setSheetState(() {});
                    },
                    activeThumbColor: accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      ctx.l10n.royalThemeToggle(r.id),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                  // The court's effects only show on its home primary theme;
                  // offer a one-tap switch when the user isn't there yet.
                  _modeSwitchRow(ctx, r, accent),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: equipped
                          ? null
                          : () {
                              setState(() => _value = value);
                              Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: r.theme.homeBrightness ==
                                Brightness.light
                            ? Colors.white
                            : const Color(0xFF15171E),
                        disabledBackgroundColor:
                            accent.withValues(alpha: 0.35),
                      ),
                      icon: Icon(
                          equipped
                              ? Icons.check_rounded
                              : Icons.workspace_premium_rounded,
                          size: 18),
                      label: Text(equipped
                          ? ctx.l10n.equippedRoyal
                          : ctx.l10n.equipRoyal),
                    ),
                  ),
                ] else if (unlockable) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _unlockRoyal(r);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          showAppToast(
                            context,
                            message: context.l10nRead.royalUnlockedToast(
                                context.l10nRead.royalAvatarName(r.id)),
                            type: AppToastType.success,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: r.theme.homeBrightness ==
                                Brightness.light
                            ? Colors.white
                            : const Color(0xFF15171E),
                      ),
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: Text(ctx.l10n.unlockRoyalCta),
                    ),
                  ),
                ] else ...[
                  // Locked with no pick to spend: a calm coming-soon note.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.cardAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 16, color: colors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ctx.l10n.royalLockedSheetNote,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// A royal character tile — a living avatar with its court name and a status
  /// pill beneath. Every tile is the SAME height (avatar + name + pill), so the
  /// grid stays even regardless of lock state. The art is always fully visible;
  /// a locked royal is dimmed a touch and carries a small lock badge in the
  /// corner (never over the face). Tapping opens the royal's court sheet.
  Widget _royalOption(AppColors colors, RoyalAvatar r) {
    final value = '${r.spriteIndex}';
    final unlocked = _isRoyalUnlocked(r);
    final equipped = unlocked && _value == value;
    final unlockable = !unlocked && _picks > 0;
    final lockedSoon = !unlocked && !unlockable;
    // The bright accent tints the tile fill; text + border use the deep
    // shade on a light surface so the selected name never sits gold-on-
    // yellow (illegible in light mode; fine on the dark tile).
    final accent = r.theme.accent;
    final ink = Theme.of(context).brightness == Brightness.light
        ? r.theme.accentDeep
        : r.theme.accent;
    final borderColor = equipped
        ? ink
        : unlockable
            ? colors.brandAccent.withValues(alpha: 0.6)
            : lockedSoon
                ? colors.border
                : ink.withValues(alpha: 0.35);
    return GestureDetector(
      onTap: () => _showRoyalSheet(r),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              (lockedSoon ? colors.textTertiary : accent)
                  .withValues(alpha: equipped ? 0.16 : 0.07),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: borderColor, width: equipped ? 2 : 1),
          boxShadow: equipped
              ? [BoxShadow(color: accent.withValues(alpha: 0.30), blurRadius: 14)]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The living royal, always visible — locked ones just dimmed.
                  Opacity(
                    opacity: lockedSoon ? 0.82 : 1,
                    child: ClipOval(
                      child: AvatarView(
                        kind: 'pixel',
                        value: value,
                        size: 60,
                        ring: false,
                        spawnRoyals: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.royalAvatarName(r.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: equipped
                          ? ink
                          : lockedSoon
                              ? colors.textTertiary
                              : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _royalTilePill(
                    colors: colors,
                    equipped: equipped,
                    unlocked: unlocked,
                    unlockable: unlockable,
                    accent: ink,
                  ),
                ],
              ),
            ),
            // A subtle corner lock — signals "locked" without hiding the face.
            if (lockedSoon)
              Positioned(top: 8, right: 8, child: _cornerLock(colors)),
          ],
        ),
      ),
    );
  }

  /// A small lock badge for the top-right corner of a locked royal tile.
  Widget _cornerLock(AppColors colors) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
        child: Icon(Icons.lock_rounded, size: 11, color: colors.textSecondary),
      );

  /// The status pill under every royal tile — present in all states so the
  /// tiles share one height: Equipped / Tap to equip / Unlock / Coming soon.
  Widget _royalTilePill({
    required AppColors colors,
    required bool equipped,
    required bool unlocked,
    required bool unlockable,
    required Color accent,
  }) {
    final (IconData? icon, String label, Color fg) = equipped
        ? (Icons.check_circle_rounded, context.l10n.equippedRoyal, accent)
        : unlocked
            ? (null, context.l10n.royalTapToEquip, colors.textSecondary)
            : unlockable
                ? (
                    Icons.lock_open_rounded,
                    context.l10n.royalUnlockable,
                    colors.brandAccent
                  )
                : (null, context.l10n.royalComingSoon, colors.textTertiary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// An elite character tile — always selectable, named under the art.
  Widget _eliteOption(AppColors colors, EliteAvatar e) {
    final value = '${e.spriteIndex}';
    final selected = _value == value;
    return GestureDetector(
      onTap: () => setState(() => _value = value),
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.brandAccent : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: AvatarView(
                  kind: 'pixel', value: value, size: 46, ring: false),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.eliteAvatarName(e.id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
