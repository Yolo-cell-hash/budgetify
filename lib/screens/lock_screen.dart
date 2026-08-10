import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import '../services/app_lock_service.dart';

/// Full-screen gate shown while the app is locked. Triggers the system
/// biometric prompt automatically and offers a retry button.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  bool _authenticating = false;

  /// Monotonic token per authentication attempt. A cancelled/hung attempt that
  /// completes late is ignored when its token no longer matches, so it can't
  /// flip the button state or race a newer prompt.
  int _session = 0;

  /// True while the app is genuinely backgrounded (paused/hidden) — as opposed
  /// to merely losing focus to the biometric sheet itself (inactive).
  bool _wentToBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fire the prompt once the first frame is up
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wentToBackground = true;
    } else if (state == AppLifecycleState.resumed && _wentToBackground) {
      // Swiping the app away (or switching apps) while the system sheet was
      // up dismisses the sheet, and on some devices the pending
      // authenticate() call never completes — which used to leave this
      // screen stuck on "Waiting" with no way to bring the prompt back.
      // Cancel whatever is left and prompt again now that we're visible.
      _wentToBackground = false;
      _repromptAfterResume();
    }
  }

  Future<void> _repromptAfterResume() async {
    // Give a result that was completing right as we resumed (e.g. the
    // device-credential fallback on older Android) a moment to land before
    // tearing the session down. If it unlocked, this screen is already gone.
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _tryUnlock(force: true);
  }

  /// Show the system prompt. With [force], any in-flight attempt is cancelled
  /// first so a fresh prompt can always be brought up.
  Future<void> _tryUnlock({bool force = false}) async {
    if (_authenticating && !force) return;
    final session = ++_session;
    if (_authenticating) {
      await AppLockService().cancelPendingAuth();
      if (!mounted || session != _session) return;
    }
    setState(() => _authenticating = true);
    final ok = await AppLockService().authenticate();
    if (!mounted || session != _session) return;
    setState(() => _authenticating = false);
    if (ok) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    // The lock screen is the app's front door, so it wears the same hero
    // surface as the marquee cards rather than a hardcoded midnight gradient —
    // that stayed dark-and-gold under every light theme, every reward theme,
    // and every royal court dress (which re-skins the hero through the
    // AppPalette extension this reads).
    final hero = HeroStyle.of(context);
    // On-accent ink: reward accents range from near-black indigo to pale rose,
    // so pick by the accent's own luminance instead of by theme brightness.
    final onAccent = hero.accent.computeLuminance() > 0.5
        ? const Color(0xFF15110A)
        : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // No AppBar here to publish an overlay style, and a light hero would
      // otherwise keep the white status-bar icons it inherited from the screen
      // underneath. Icon brightness only — colours stay null so the engine
      // never touches the setters Android 15 deprecated (see AppTheme).
      value: SystemUiOverlayStyle(
        statusBarIconBrightness:
            hero.onDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness:
            hero.onDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: hero.onDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: hero.gradient),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: hero.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: hero.accent.withValues(alpha: 0.35)),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 44,
                      color: hero.accent,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.l10n.appLockedTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: hero.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.appLockOnDesc,
                    style: TextStyle(
                      fontSize: 14,
                      color: hero.foregroundAlpha(0.6),
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Always tappable: if an attempt is (or appears) in flight it
                  // is cancelled and re-issued, so a dismissed/hung prompt can
                  // never lock the user out of retrying.
                  ElevatedButton.icon(
                    onPressed: () => _tryUnlock(force: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hero.accent,
                      foregroundColor: onAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(_authenticating
                        ? context.l10n.waiting
                        : context.l10n.unlock),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
