import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../widgets/royal_avatars.dart';
import 'app_events.dart';
import 'gamification_service.dart';

/// Session-only developer mode.
///
/// Unlocked from a hidden gate on the Home title (five quick taps → password
/// prompt, password `budgetify.dev`). While active, every theme and every
/// ROYALTY avatar is equippable for PREVIEW: the choices live in memory only
/// (see [GamificationService.sessionAvatarOverride] and
/// [ThemeProvider.setSessionVariant]) so a normal app restart lands back on
/// the user's real, earned state. Backups cannot be created while dev mode is
/// on — a dev-session backup would freeze preview state into a prod artefact.
///
/// Deliberately NOT persisted, NOT localized (it's a developer tool) and never
/// part of core logic: nothing here writes to the database or SharedPreferences.
class DevMode {
  DevMode._();

  static const String _password = 'budgetify.dev';

  /// Whether developer mode is on for this session. Widgets that gate on it
  /// listen to this (it's a [ValueNotifier], so `ValueListenableBuilder`
  /// works) — there is no persistence to invalidate.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  static bool get isActive => active.value;

  /// Attempt to unlock with [input]; true on success.
  static bool tryUnlock(String input) {
    if (input.trim() == _password) {
      active.value = true;
      return true;
    }
    return false;
  }

  /// Turn dev mode off and drop every session-only preview: the avatar
  /// override is cleared and the persisted theme variant is restored, so the
  /// app returns to exactly the user's earned state without a restart.
  static Future<void> disable(ThemeProvider themeProvider) async {
    active.value = false;
    GamificationService.sessionAvatarOverride = null;
    await themeProvider.restorePersistedVariant();
    // Re-sync the royal dress and every profile-driven surface.
    GamificationService.onProfileSaved
        ?.call(await GamificationService().loadProfile());
    notifyAppDataChanged();
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
