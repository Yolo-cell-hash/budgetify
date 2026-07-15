import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import '../widgets/royal_avatars.dart';
import 'app_events.dart';
import 'gamification_service.dart';

/// Persistent developer mode.
///
/// Unlocked from a hidden gate on the Home title (five quick taps → password
/// prompt, password `budgetify.dev`). Once on, it STAYS on across app restarts
/// (the flag is persisted) until the user turns it off — either from the
/// hidden gate or the "Disable developer mode" toggle that appears in Settings
/// while it's active. Re-enabling is the same five-taps-plus-password gate.
///
/// While active, every theme and every ROYALTY avatar is equippable for
/// PREVIEW. Those previews now PERSIST across restarts too: the last look you
/// set in dev mode survives a relaunch (dev mode stays on and lands back on
/// exactly the avatar/theme you were previewing). The preview is stored in its
/// OWN keys ([_prefsAvatarKey] / [_prefsThemeKey]) as an OVERLAY — the user's
/// real, earned avatar (the gamification profile) and theme ([ThemeProvider]'s
/// `theme_variant`) are never overwritten. Turning dev mode off drops the
/// overlay and restores that untouched earned state, so prod always shows the
/// real themes, never the dev preview. No backup or snapshot of the earned
/// state is kept — it is simply never modified. The encrypted-data backup
/// stays disabled while dev mode is on so a dev preview can never leak into a
/// prod artefact.
///
/// NOT localized (it's a developer tool) and never part of core logic: the
/// only thing it persists is its own on/off flag plus the preview overlay.
class DevMode {
  DevMode._();

  static const String _password = 'budgetify.dev';
  static const String _prefsKey = 'dev_mode_active';

  /// Overlay keys for the persisted preview: the equipped royal avatar's sprite
  /// value and the previewed theme variant's name. Kept separate from the real
  /// earned state, and cleared the moment dev mode is turned off.
  static const String _prefsAvatarKey = 'dev_mode_avatar';
  static const String _prefsThemeKey = 'dev_mode_theme';

  /// Whether developer mode is on. Widgets that gate on it listen to this
  /// (it's a [ValueNotifier], so `ValueListenableBuilder` works). Persisted:
  /// call [initialize] once at startup to restore it.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  static bool get isActive => active.value;

  /// Restore the persisted on/off flag, and — while dev mode is on — re-apply
  /// the persisted preview overlay (previewed royal avatar + theme) so the last
  /// look set in dev mode survives the relaunch. Call once during app startup,
  /// before the first frame AND before the profile is loaded (the avatar
  /// override must be in place so `loadProfile` reports the previewed royal).
  /// Pass [themeProvider] in production so the previewed theme is restored too.
  /// Safe to call more than once.
  static Future<void> initialize([ThemeProvider? themeProvider]) async {
    final prefs = await SharedPreferences.getInstance();
    active.value = prefs.getBool(_prefsKey) ?? false;
    if (!active.value) return;

    // Re-apply the persisted avatar overlay (rides on top of storage via
    // GamificationService.loadProfile); null when nothing was previewed.
    GamificationService.sessionAvatarOverride = prefs.getString(_prefsAvatarKey);

    // Re-apply the persisted theme overlay over the real variant.
    final themeName = prefs.getString(_prefsThemeKey);
    if (themeProvider != null && themeName != null) {
      final match = AppThemeVariant.values.where((v) => v.name == themeName);
      if (match.isNotEmpty) themeProvider.setSessionVariant(match.first);
    }
  }

  /// Attempt to unlock with [input]; true on success. Persists the flag so
  /// dev mode survives the next launch.
  static bool tryUnlock(String input) {
    if (input.trim() == _password) {
      active.value = true;
      _persist(true);
      return true;
    }
    return false;
  }

  /// Developer-mode theme preview that SURVIVES a restart: apply [variant] for
  /// the session (never touching the real `theme_variant`) and persist it as
  /// the dev overlay, so the previewed theme comes back on the next launch
  /// while dev mode stays on.
  static Future<void> previewTheme(
      ThemeProvider themeProvider, AppThemeVariant variant) async {
    themeProvider.setSessionVariant(variant);
    await _persistTheme(variant);
  }

  /// Drop the persisted theme overlay — called when an EARNED theme is applied
  /// in dev mode (it persists as the real `theme_variant`, so the overlay must
  /// not shadow it on the next launch).
  static Future<void> clearThemePreview() => _persistTheme(null);

  /// Turn dev mode off, clear the persisted flag, and drop every preview: the
  /// persisted overlay (avatar + theme) is removed, the avatar override is
  /// cleared and the real theme variant is restored, so the app returns to
  /// exactly the user's earned state — now and on the next launch — without a
  /// restart.
  static Future<void> disable(ThemeProvider themeProvider) async {
    active.value = false;
    await _persist(false);
    await _persistAvatar(null);
    await _persistTheme(null);
    GamificationService.sessionAvatarOverride = null;
    await themeProvider.restorePersistedVariant();
    // Re-sync the royal dress and every profile-driven surface.
    GamificationService.onProfileSaved
        ?.call(await GamificationService().loadProfile());
    notifyAppDataChanged();
  }

  static Future<void> _persist(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, on);
  }

  /// Persist (or clear, when null) the previewed royal avatar overlay.
  static Future<void> _persistAvatar(String? avatarValue) async {
    final prefs = await SharedPreferences.getInstance();
    if (avatarValue == null) {
      await prefs.remove(_prefsAvatarKey);
    } else {
      await prefs.setString(_prefsAvatarKey, avatarValue);
    }
  }

  /// Persist (or clear, when null) the previewed theme overlay.
  static Future<void> _persistTheme(AppThemeVariant? variant) async {
    final prefs = await SharedPreferences.getInstance();
    if (variant == null) {
      await prefs.remove(_prefsThemeKey);
    } else {
      await prefs.setString(_prefsThemeKey, variant.name);
    }
  }

  @visibleForTesting
  static void debugReset() {
    active.value = false;
    GamificationService.sessionAvatarOverride = null;
  }
}

/// Routes an avatar-picker result through the dev-mode preview when needed.
///
/// If dev mode is on and [edited] equips a royal the user hasn't actually
/// unlocked ([reallyUnlocked] is the persisted set), the equip becomes an
/// override that is ALSO persisted as the dev overlay (so it survives a
/// restart while dev mode stays on) and this returns true — the caller must
/// NOT persist the profile. Otherwise any stale overlay is dropped (a real
/// equip always wins) and the caller saves normally.
Future<bool> applyDevRoyalPreview(
    GamiProfile edited, Set<String> reallyUnlocked) async {
  final royal = royalAvatarAt(int.tryParse(edited.avatarValue) ?? -1);
  final preview = DevMode.isActive &&
      royal != null &&
      !reallyUnlocked.contains(royal.id);
  if (preview) {
    GamificationService.sessionAvatarOverride = edited.avatarValue;
    // Persist the overlay so the equipped royal comes back on the next launch.
    await DevMode._persistAvatar(edited.avatarValue);
    // Re-dress the app for the previewed royal and nudge every profile-driven
    // surface (profile card, reaction host) to reload.
    GamificationService.onProfileSaved?.call(edited);
    notifyAppDataChanged();
  } else {
    GamificationService.sessionAvatarOverride = null;
    // A real equip (earned royal or a plain avatar) saves to the profile —
    // drop any dev overlay so it can't shadow the real avatar next launch.
    if (DevMode.isActive) await DevMode._persistAvatar(null);
  }
  return preview;
}

/// The hidden entrance: wraps any widget (the Home "Budgetify" title) and
/// opens the developer-mode dialog after [tapsToOpen] quick taps.
class DevModeGate extends StatefulWidget {
  final Widget child;
  final int tapsToOpen;

  /// Injectable clock so tests can simulate slow taps (widget-test pumps
  /// advance the fake clock, not [DateTime.now]).
  final DateTime Function() nowSource;

  const DevModeGate({
    super.key,
    required this.child,
    this.tapsToOpen = 5,
    this.nowSource = DateTime.now,
  });

  @override
  State<DevModeGate> createState() => _DevModeGateState();
}

class _DevModeGateState extends State<DevModeGate> {
  int _taps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTap() {
    final now = widget.nowSource();
    _taps = now.difference(_lastTap) < const Duration(milliseconds: 700)
        ? _taps + 1
        : 1;
    _lastTap = now;
    if (_taps >= widget.tapsToOpen) {
      _taps = 0;
      HapticFeedback.mediumImpact();
      showDevModeDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}

/// The password prompt (or, when dev mode is already on, the status sheet
/// with the switch-off action). English-only by design: a developer tool,
/// not user-facing product surface.
Future<void> showDevModeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => DevMode.isActive
        ? AlertDialog(
            title: const Text('Developer mode'),
            content: const Text(
              'Developer mode is ON.\n\n'
              'All themes and royal characters are unlocked for preview, '
              'and backups are disabled. Your previewed look is kept while '
              'developer mode stays on — turn it off to return to your real, '
              'earned state.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Keep on'),
              ),
              FilledButton(
                onPressed: () async {
                  final themeProvider = dialogContext.read<ThemeProvider>();
                  Navigator.pop(dialogContext);
                  await DevMode.disable(themeProvider);
                },
                child: const Text('Turn off'),
              ),
            ],
          )
        : const _DevPasswordDialog(),
  );
}

class _DevPasswordDialog extends StatefulWidget {
  const _DevPasswordDialog();

  @override
  State<_DevPasswordDialog> createState() => _DevPasswordDialogState();
}

class _DevPasswordDialogState extends State<_DevPasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (DevMode.tryUnlock(_controller.text)) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
              'Developer mode on — all themes & royals unlocked. '
              'Backups disabled.'),
        ),
      );
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Developer mode'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          hintText: 'Password',
          errorText: _failed ? 'Incorrect password' : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Unlock')),
      ],
    );
  }
}
