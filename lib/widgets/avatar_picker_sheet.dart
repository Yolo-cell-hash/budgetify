import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../providers/theme_provider.dart';
import '../services/gamification_service.dart';
import 'avatars.dart';
import 'royal_avatars.dart';

/// Edit the profile's avatar (emoji or procedural pixel) + accent + username.
/// Returns the edited [GamiProfile], or null if cancelled.
Future<GamiProfile?> showAvatarPicker(
  BuildContext context,
  GamiProfile initial,
) {
  return showModalBottomSheet<GamiProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AvatarPickerSheet(initial: initial),
  );
}

class _AvatarPickerSheet extends StatefulWidget {
  final GamiProfile initial;
  const _AvatarPickerSheet({required this.initial});

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  // The roster is pixel-only; a legacy emoji profile opens on its
  // migration sprite.
  late String _value = widget.initial.avatarKind == 'pixel'
      ? widget.initial.avatarValue
      : '${legacyEmojiSeed(widget.initial.avatarValue)}';
  late bool _applyRoyalTheme = widget.initial.applyRoyalTheme;
  late final TextEditingController _name =
      TextEditingController(text: widget.initial.username);

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

  /// The royal's court sheet: living avatar, lore, which primary theme it
  /// dresses, the per-royal app-wide theme toggle, and the Equip action.
  Future<void> _showRoyalSheet(RoyalAvatar r) async {
    final colors = AppColors.of(context);
    final accent = r.theme.accent;
    final value = '${r.spriteIndex}';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final equipped = _value == value;
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
                    label: Text(
                        equipped ? ctx.l10n.equippedRoyal : ctx.l10n.equipRoyal),
                  ),
                ),
              ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// A royal character tile — a living avatar in a gilded aura ring with its
  /// court name beneath. Tiles stay calm (no spawn burst); tapping opens the
  /// royal's court sheet (lore + app-wide theme toggle + equip). Sized by
  /// the caller (two per row in the ROYALTY grid).
  Widget _royalOption(AppColors colors, RoyalAvatar r) {
    final value = '${r.spriteIndex}';
    final selected = _value == value;
    final accent = r.theme.accent;
    return GestureDetector(
        onTap: () => _showRoyalSheet(r),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: selected ? 0.16 : 0.07),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(
              color: selected ? accent : accent.withValues(alpha: 0.35),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: accent.withValues(alpha: 0.30), blurRadius: 14)]
                : null,
          ),
          child: Column(
            children: [
              ClipOval(
                child: AvatarView(
                  kind: 'pixel',
                  value: value,
                  size: 62,
                  ring: false,
                  spawnRoyals: false,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.royalAvatarName(r.id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: selected ? accent : colors.textSecondary,
                ),
              ),
            ],
          ),
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
