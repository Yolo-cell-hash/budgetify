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
/// PREVIEW. Those previews stay SESSION-only — the equipped-royal override
/// ([GamificationService.sessionAvatarOverride]) and previewed theme variant
/// ([ThemeProvider.setSessionVariant]) are never written to storage, so a
/// restart keeps dev mode ON but lands back on the user's real, earned avatar
/// and theme (which are one tap away again in the unlocked pickers). Backups
/// cannot be created while dev mode is on — a dev-session backup would freeze
/// preview state into a prod artefact.
///
/// NOT localized (it's a developer tool) and never part of core logic: the
/// only thing it persists is its own on/off flag.
class DevMode {
  DevMode._();

  static const String _password = 'budgetify.dev';
  static const String _prefsKey = 'dev_mode_active';

  /// Whether developer mode is on. Widgets that gate on it listen to this
  /// (it's a [ValueNotifier], so `ValueListenableBuilder` works). Persisted:
  /// call [initialize] once at startup to restore it.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  static bool get isActive => active.value;

  /// Restore the persisted on/off flag. Call once during app startup, before
  /// the first frame. Safe to call more than once.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    active.value = prefs.getBool(_prefsKey) ?? false;
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

  /// Turn dev mode off, clear the persisted flag, and drop every session-only
  /// preview: the avatar override is cleared and the persisted theme variant
  /// is restored, so the app returns to exactly the user's earned state
  /// without a restart.
  static Future<void> disable(ThemeProvider themeProvider) async {
    active.value = false;
    await _persist(false);
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

  @visibleForTesting
  static void debugReset() {
    active.value = false;
    GamificationService.sessionAvatarOverride = null;
  }
}

/// Routes an avatar-picker result through the dev-mode preview when needed.
///
/// If dev mode is on and [edited] equips a royal the user hasn't actually
/// unlocked ([reallyUnlocked] is the persisted set), the equip becomes a
/// session-only override and this returns true — the caller must NOT persist
/// the profile. Otherwise any stale preview is dropped (a real equip always
/// wins) and the caller saves normally.
bool applyDevRoyalPreview(GamiProfile edited, Set<String> reallyUnlocked) {
  final royal = royalAvatarAt(int.tryParse(edited.avatarValue) ?? -1);
  final preview = DevMode.isActive &&
      royal != null &&
      !reallyUnlocked.contains(royal.id);
  if (preview) {
    GamificationService.sessionAvatarOverride = edited.avatarValue;
    // Re-dress the app for the previewed royal and nudge every profile-driven
    // surface (profile card, reaction host) to reload.
    GamificationService.onProfileSaved?.call(edited);
    notifyAppDataChanged();
  } else {
    GamificationService.sessionAvatarOverride = null;
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
              'Developer mode is ON for this session.\n\n'
              'All themes and royal characters are unlocked for preview, '
              'and backups are disabled. Everything resets when the app '
              'is closed.',
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
              'Developer mode on — all themes & royals unlocked for this '
              'session. Backups disabled.'),
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
