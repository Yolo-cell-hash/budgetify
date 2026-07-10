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
  late String _kind = widget.initial.avatarKind;
  late String _value = widget.initial.avatarValue;
  late int _accent = widget.initial.avatarAccent;
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
        avatarKind: _kind,
        avatarValue: _value,
        avatarAccent: _accent,
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
                key: ValueKey('$_kind/$_value'),
                kind: _kind,
                value: _value,
                accent: _accent,
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
            _sectionLabel(colors, context.l10n.styleLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                _segment(context.l10n.emojiStyle, _kind == 'emoji', () {
                  setState(() {
                    _kind = 'emoji';
                    _value = kEmojiAvatars.contains(_value) ? _value : kEmojiAvatars.first;
                  });
                }),
                const SizedBox(width: 10),
                _segment(context.l10n.pixelStyle, _kind == 'pixel', () {
                  setState(() {
                    _kind = 'pixel';
                    _value = (int.tryParse(_value) ?? 0).toString();
                  });
                }),
              ],
            ),
            const SizedBox(height: 16),
            _sectionLabel(colors,
                _kind == 'emoji' ? context.l10n.avatarLabel : context.l10n.pixelAvatarLabel),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _kind == 'emoji'
                  ? [for (final e in kEmojiAvatars) _option(e, e == _value, kind: 'emoji', value: e)]
                  : [
                      for (var i = 0; i < kFreePixelAvatarCount; i++)
                        _option('$i', '$i' == _value, kind: 'pixel', value: '$i')
                    ],
            ),
            // Elite characters: the showpiece art, in its own category.
            if (_kind == 'pixel') ...[
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
            ],
            // Accent applies to emoji avatars only — pixel characters carry
            // their own colours.
            if (_kind == 'emoji') ...[
              const SizedBox(height: 16),
              _sectionLabel(colors, context.l10n.accentLabel),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < kAvatarAccents.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _accent = i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: accentOf(i)),
                          border: Border.all(
                            color: _accent == i
                                ? AppColors.of(context).brandAccent
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
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

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.brandAccent.withValues(alpha: 0.16) : colors.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.brandAccent : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? colors.brandAccent : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(String key, bool selected, {required String kind, required String value}) {
    return GestureDetector(
      onTap: () => setState(() => _value = value),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppColors.of(context).brandAccent
                : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: AvatarView(kind: kind, value: value, accent: _accent, size: 46, ring: false),
      ),
    );
  }

  /// A royal character tile — a living avatar in a gilded aura ring with its
  /// court name beneath. Tiles stay calm (no spawn burst); the preview above
  /// plays the flourish when one is equipped. Sized by the caller (two per
  /// row in the ROYALTY grid).
  Widget _royalOption(AppColors colors, RoyalAvatar r) {
    final value = '${r.spriteIndex}';
    final selected = _kind == 'pixel' && _value == value;
    final accent = r.theme.accent;
    return GestureDetector(
        onTap: () => setState(() => _value = value),
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
                  accent: _accent,
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
    final selected = _kind == 'pixel' && _value == value;
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
                  kind: 'pixel',
                  value: value,
                  accent: _accent,
                  size: 46,
                  ring: false),
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
