import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';

import '../providers/app_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/app_icon_service.dart';
import '../services/gamification_service.dart';
import 'app_dialog.dart';
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

/// After an avatar is saved, bring the Android launcher icon in step with the
/// equipped royal — only when the "match app icon" opt-in is on and the swap
/// would actually change the icon. Android applies alternate icons by toggling
/// launcher components, and launchers only pick the new artwork up reliably
/// once the app has been through a fresh start; so we ask first and, on
/// confirm, apply and RESTART. A no-op off-Android or when unchanged.
///
/// The restart used to be a plain close, leaving the user on their home screen
/// to reopen the app themselves — an errand handed out for a cosmetic change
/// they made two taps ago. [AppIconService.relaunch] brings it straight back
/// up instead; closing is only the fallback for when the platform can't.
///
/// Call this *after* the profile is persisted, so the restart can never lose
/// the equip.
Future<void> confirmRoyalAppIcon(
  BuildContext context,
  GamiProfile profile,
) async {
  if (!Platform.isAndroid) return;
  final enabled = context.read<AppPreferences>().royalAppIcon;
  final seed = int.tryParse(profile.avatarValue) ?? -1;
  if (!await AppIconService.willChange(equippedSeed: seed, enabled: enabled)) {
    return; // icon already matches — nothing to apply, no need to disturb.
  }
  if (!context.mounted) return;
  final confirmed = await showAppDialog<bool>(
    context,
    builder: (ctx) => AppDialog(
      icon: Icons.restart_alt_rounded,
      title: ctx.l10nRead.royalAppIconRestartTitle,
      subtitle: ctx.l10nRead.royalAppIconRestartBody,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10nRead.notNow),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10nRead.royalAppIconRestartConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await AppIconService.sync(equippedSeed: seed, enabled: enabled);
  // Icon swapped — take the fresh start that makes launchers show it, by
  // relaunching rather than closing. The user agreed and the profile is
  // already saved, so either path is safe.
  if (await AppIconService.relaunch()) return;
  await SystemNavigator.pop(); // platform couldn't relaunch — close instead
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
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.username,
  );

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
    // Just hand the edited profile back; the caller persists it and then — if
    // the "match app icon" opt-in wants a different launcher icon — asks before
    // applying it (the swap closes the app). See [confirmRoyalAppIcon].
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
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 14,
                  color: colors.brandAccent,
                ),
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
                onPressed: _save,
                child: Text(context.l10n.commonSave),
              ),
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
            Icon(Icons.lock_open_rounded, size: 14, color: colors.brandAccent),
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
      style: TextStyle(
        fontSize: 11.5,
        height: 1.35,
        color: colors.textTertiary,
      ),
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

  /// Where the court stands on the theme the user is actually in.
  ///
  /// This used to be a correction — every royal dressed one mode only, so the
  /// row's job was to tell you that you were in the wrong one. Now that the
  /// court follows both primaries it confirms the dress is live and offers
  /// the *other* mode, so trying a royal both ways is one tap either
  /// direction. A reward theme is the one place the dress still stands
  /// aside (each is hand-tuned), so there the row keeps its original job and
  /// offers the primary nearest the brightness the user already reads in.
  Widget _modeSwitchRow(BuildContext ctx, RoyalAvatar r, Color accent) {
    final theme = ctx.watch<ThemeProvider>();
    final onLight = theme.variant == AppThemeVariant.light;
    final onPrimary = onLight || theme.variant == AppThemeVariant.dark;

    Widget switchButton(bool toLight) => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => theme.setVariant(
          toLight ? AppThemeVariant.light : AppThemeVariant.dark,
        ),
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(
          toLight ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 16,
        ),
        label: Text(
          ctx.l10n.royalSwitchMode(toLight),
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
    );

    if (!onPrimary) {
      // A reward theme: the court steps aside here. Offer the primary that
      // matches the brightness they're already reading in.
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: switchButton(Theme.of(ctx).brightness == Brightness.light),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ctx.l10n.royalCourtLive(onLight),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.of(ctx).textSecondary,
                  ),
                ),
              ),
            ],
          ),
          switchButton(!onLight),
        ],
      ),
    );
  }

  /// The royal's court sheet: living avatar, lore, the both-modes promise,
  /// the per-royal app-wide theme toggle, and the Equip action.
  Future<void> _showRoyalSheet(RoyalAvatar r) async {
    final value = '${r.spriteIndex}';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // A modal CAPTURES its Theme at push time (InheritedTheme.capture), so
      // the sheet would keep painting in whichever mode it opened in while
      // the app behind it changed — and the row inside it exists precisely to
      // change that mode. ThemeProvider is not captured: it resolves live
      // through the tree, so watching it and re-installing the active theme
      // over the sheet is what lets "See it in the Dark theme" actually show
      // you the sheet in dark.
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Theme(
          data: ctx.watch<ThemeProvider>().activeTheme,
          // Nested Builder so AppColors.of / Theme.of below resolve through
          // the theme just installed, not the captured one above it.
          child: Builder(
            builder: (ctx) => _royalSheetBody(ctx, r, value, setSheetState),
          ),
        ),
      ),
    );
  }

  /// The court sheet's contents, under the live app theme (see the Theme wrap
  /// in [_showRoyalSheet]). [setSheetState] rebuilds the sheet for the toggles
  /// that live on it.
  Widget _royalSheetBody(
    BuildContext ctx,
    RoyalAvatar r,
    String value,
    StateSetter setSheetState,
  ) {
    final colors = AppColors.of(ctx);
    // A royal's bright accent (gold / lavender) is legible on a dark
    // surface but washes out on the light picker; use the deep,
    // ink-legible shade whenever the surface is light so names and
    // borders stay readable.
    final onLightSurface = Theme.of(ctx).brightness == Brightness.light;
    final accent = onLightSurface ? r.theme.accentDeep : r.theme.accent;
    // Label ink for a filled button in [accent]: white on the deep
    // shade, near-black on the bright one. Keyed to the surface the
    // sheet is on, not to the royal — every court dresses both modes.
    final onAccent = onLightSurface ? Colors.white : const Color(0xFF15171E);
    final equipped = _value == value;
    final unlocked = _isRoyalUnlocked(r);
    final unlockable = !unlocked && _picks > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      // Flutter 3.44 asserts if a ListTile's nearest Material ancestor is
      // further away than a DecoratedBox with a background — the tile
      // would paint its ink splashes behind this sheet's own fill. A
      // transparent Material INSIDE the decoration gives the two
      // SwitchListTiles below somewhere to splash without changing how
      // anything looks.
      child: Material(
        type: MaterialType.transparency,
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
              // Court note: the dress follows BOTH primary themes, so
              // this pill promises reach rather than naming one mode.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Half-lit disc — the one icon that reads as "both".
                    Icon(Icons.brightness_6_rounded, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        ctx.l10n.royalDualModeNote,
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
                // Full-body theatrics (off by default): the royal roaming,
                // peeking and attacking the screen. Global and persisted
                // immediately via AppPreferences — not part of this
                // profile, so Save/Cancel doesn't touch it. The circle
                // avatar keeps blinking and waving either way.
                SwitchListTile(
                  value: ctx.watch<AppPreferences>().royalCustomAnimations,
                  onChanged: (v) {
                    ctx.read<AppPreferences>().setRoyalCustomAnimations(v);
                    setSheetState(() {});
                  },
                  activeThumbColor: accent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    ctx.l10n.royalCustomAnimationsTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      ctx.l10n.royalCustomAnimationsDesc,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ),
                // Opt-in: match the Android launcher icon to this royal's
                // gem. The switch only records the preference; the icon is
                // swapped (after a confirm, since it closes the app) when the
                // avatar is saved. Shown on every royal's sheet by design.
                if (Platform.isAndroid)
                  SwitchListTile(
                    value: ctx.watch<AppPreferences>().royalAppIcon,
                    // Records the preference and NOTHING else. Applying it
                    // waits for Save, which goes through
                    // [confirmRoyalAppIcon] and asks first.
                    //
                    // A previous pass reconciled the icon the moment the
                    // switch moved, on the theory that the swap is silent
                    // because the native side passes DONT_KILL_APP. It is not:
                    // disabling the launcher component the running task is
                    // attached to tears the task down anyway on real devices,
                    // so flicking the switch force-closed the app — before any
                    // confirmation, and for an avatar the user had not chosen
                    // to keep yet. There is no such thing as a quiet icon
                    // swap, which is why every one of them now sits behind the
                    // confirm-and-relaunch path.
                    onChanged: (v) {
                      ctx.read<AppPreferences>().setRoyalAppIcon(v);
                      setSheetState(() {});
                    },
                    activeThumbColor: accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      ctx.l10n.royalAppIconTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        ctx.l10n.royalAppIconDesc,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                // Where the court stands on the active theme, and a
                // one-tap hop to see it in the other mode.
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
                      foregroundColor: onAccent,
                      disabledBackgroundColor: accent.withValues(alpha: 0.35),
                    ),
                    icon: Icon(
                      equipped
                          ? Icons.check_rounded
                          : Icons.workspace_premium_rounded,
                      size: 18,
                    ),
                    label: Text(
                      equipped ? ctx.l10n.equippedRoyal : ctx.l10n.equipRoyal,
                    ),
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
                            context.l10nRead.royalAvatarName(r.id),
                          ),
                          type: AppToastType.success,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: onAccent,
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: Text(ctx.l10n.unlockRoyalCta),
                  ),
                ),
              ] else ...[
                // Locked with no pick to spend: a calm coming-soon note.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
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
              (lockedSoon ? colors.textTertiary : accent).withValues(
                alpha: equipped ? 0.16 : 0.07,
              ),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: borderColor, width: equipped ? 2 : 1),
          boxShadow: equipped
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
                    blurRadius: 14,
                  ),
                ]
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
    child: Icon(Icons.lock_rounded, size: 10, color: colors.textSecondary),
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
            colors.brandAccent,
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
                kind: 'pixel',
                value: value,
                size: 46,
                ring: false,
              ),
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
