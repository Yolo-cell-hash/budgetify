import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:budget_tracker/screens/main_shell.dart';
import 'package:budget_tracker/screens/lock_screen.dart';
import 'package:budget_tracker/screens/onboarding_screen.dart';
import 'package:budget_tracker/screens/splash_screen.dart';
import 'package:budget_tracker/services/app_icon_service.dart';
import 'package:budget_tracker/services/app_lock_service.dart';
import 'package:budget_tracker/services/notification_service.dart';
import 'package:budget_tracker/services/background_service.dart';
import 'package:budget_tracker/services/bank_alias_service.dart';
import 'package:budget_tracker/services/custom_tag_service.dart';
import 'package:budget_tracker/services/dev_mode.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/services/entitlement_service.dart';
import 'package:budget_tracker/services/royal_notification_skin.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart' show courtDressFor;
import 'package:budget_tracker/widgets/royal_reactions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw behind the status and navigation bars — the Flutter equivalent of
  // Android's `enableEdgeToEdge()`. Android 15 (SDK 35) forces this on every
  // app that targets it, so on new phones the app already ran this way; asking
  // for it explicitly is what extends the same look back to Android 14 and
  // below, which is exactly what Play Console's "Edge-to-edge may not display
  // for all users" is about. Safe here because the chrome that meets the
  // system bars — AppBar, BottomNavigationBar, and the SafeArea every screen
  // wraps its body in — already pads itself by the window insets.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Only first-frame-critical state is awaited before runApp. The three
  // providers and the custom-tag cache are each just a few SharedPreferences
  // reads (sharing one cached instance), and they decide what the very first
  // frame *is*: the theme, the onboarding-vs-home route, the locale and the
  // tag icons. Keeping the pre-runApp path this thin is what lets the first
  // frame paint in tens of milliseconds.
  //
  // Everything heavier — WorkManager scheduling, notification channels, the
  // trial clock, the gamification profile — used to be awaited here too. On a
  // cold first launch that blocked the first frame for many seconds (measured
  // ~7.5s of pre-runApp work, 15s to first frame on a fresh install), leaving
  // the user staring at the bare Android system launch screen and reporting
  // the app as "broken on first open." A warm relaunch — already AOT-compiled,
  // caches hot — hid it, which is why a force-kill+reopen "fixed" it. That work
  // now runs after the first frame in [_initDeferredServices].
  final themeProvider = ThemeProvider();
  final appPreferences = AppPreferences();
  final localeProvider = LocaleProvider();

  await themeProvider.initialize();
  await appPreferences.initialize();
  await localeProvider.initialize();
  // Custom tags feed transaction icons synchronously during build, so the
  // cache is warmed before the first frame (a cheap cached-prefs read).
  await CustomTagService().initialize();
  // Before anything renders: bank names resolve synchronously everywhere
  // (including deep inside the export builders), so the user's own names
  // have to be in memory first or the first frame shows the detected ones.
  await BankAliasService().initialize();

  // Which royal launcher-icon is active (if any), so the very first splash
  // frame can wear the matching gem skin instead of flashing the default.
  await AppIconService.loadActiveVariant();

  // Restore the persisted developer-mode flag (stays on across restarts until
  // the user turns it off). While on, this also re-applies the persisted
  // preview overlay: the previewed theme (via themeProvider) and the equipped
  // royal (via the session avatar override, read by the deferred loadProfile in
  // _initDeferredServices). Kept in the pre-runApp path because it can change
  // the previewed theme, which the very first frame must reflect.
  await DevMode.initialize(themeProvider);

  // Which over-budget breach the court has already reacted to. Must be in
  // memory before the first health snapshot lands, or a session that opens
  // over budget would re-scold for a breach the user has already been told
  // about (see RoyalMood).
  await RoyalMood.loadBreach();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: appPreferences),
        ChangeNotifierProvider.value(value: localeProvider),
      ],
      child: const MyApp(),
    ),
  );

  // Kick off the heavy, non-first-frame work once the first frame is on
  // screen. Fire-and-forget so it never blocks or bricks startup.
  unawaited(_initDeferredServices(themeProvider));
}

/// Startup work the first frame does not depend on, run after [runApp] so a
/// slow step (WorkManager) or a throwing one (notification-channel setup) can
/// neither delay the first frame nor strand the app on the launch screen. Each
/// step is isolated in its own try/catch so one failure never blocks the rest.
Future<void> _initDeferredServices(ThemeProvider themeProvider) async {
  // Trial anchor (first-use timestamp). Silent — nothing is gated on it yet —
  // so stamping it just after first paint is fine. The install-record floor
  // follows it here, and only here: it crosses a platform channel, so it must
  // stay off the gate path (allowsAsync runs in the background isolate, which
  // has no channel bound). It only ever pulls the anchor back, so no one needs
  // to wait on it before reading the trial.
  // The portable anchor follows both: it is the one witness that outlives an
  // uninstall, since Android's automatic backup restores it — and only it —
  // from the user's own Drive. Runs last so it writes back whatever the
  // install-record floor may have just pulled the anchor to.
  try {
    await EntitlementService().initialize();
    await EntitlementService().applyInstallRecordFloor();
    await EntitlementService().syncPortableAnchor();
  } catch (e) {
    debugPrint('EntitlementService.initialize failed: $e');
  }

  // An equipped ROYALTY avatar (with its app-wide theme toggle on) dresses
  // both primary themes everywhere: the gold slots take the court shade —
  // its bright accent on dark, its deep one on light. Canvases and reward
  // themes stay untouched. Sync from the saved profile now, and again on
  // every avatar save. (After a backup restore the dress refreshes on next
  // launch.) Applied a beat after the first frame rather than before it — the
  // splash covers the swap, so an equipped royal sees no flash.
  //
  // The same profile read also mirrors the equipped royal for NOTIFICATIONS
  // (see RoyalSkinService), which paints its alerts in that royal's gem. It
  // has to be mirrored here, from the UI isolate: the background isolate that
  // posts transaction alerts can't load the profile itself, so what it reads
  // is what this leaves behind in SharedPreferences.
  try {
    final profile = await GamificationService().loadProfile();
    themeProvider.setThemeDress(
      profile.applyRoyalTheme
          ? courtDressFor(profile.avatarKind, profile.avatarValue)
          : null,
    );
    await RoyalSkinService.sync(int.tryParse(profile.avatarValue) ?? -1);
  } catch (e) {
    debugPrint('GamificationService.loadProfile failed: $e');
  }
  GamificationService.onProfileSaved = (p) {
    themeProvider.setThemeDress(
      p.applyRoyalTheme ? courtDressFor(p.avatarKind, p.avatarValue) : null,
    );
    // Unlike the theme dress, the notification skin is NOT tied to the
    // applyRoyalTheme toggle: that switch is about the app's own surfaces,
    // and a user who keeps the app in its default colours still equipped a
    // royal and should still see it on their alerts.
    unawaited(RoyalSkinService.sync(int.tryParse(p.avatarValue) ?? -1));
  };

  // Notification channels. HomeScreen also (re)initializes this before it posts
  // anything, so here it is just an early warm-up.
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService.initialize failed: $e');
  }

  // If a tapped notification cold-started the app, route now that the navigator
  // exists (the first frame is up).
  try {
    await NotificationService().handleLaunchPayload();
  } catch (e) {
    debugPrint('NotificationService.handleLaunchPayload failed: $e');
  }

  // Background service for scheduled SMS scans and reminders (WorkManager) —
  // the slowest step, and needed only for future background runs, so it goes
  // last.
  try {
    await BackgroundService.initialize();
  } catch (e) {
    debugPrint('BackgroundService.initialize failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, AppPreferences, LocaleProvider>(
      builder: (context, themeProvider, appPreferences, localeProvider, child) {
        return MaterialApp(
          title: 'Budget Tracker',
          debugShowCheckedModeBanner: false,
          navigatorKey: NotificationService.navigatorKey,
          // Lets the royal-reaction host know when a modal popup (dialog, sheet,
          // menu) is on top, so its cosmetic overlay never paints over one.
          navigatorObservers: [RoyalOverlayRouteObserver.instance],
          locale: localeProvider.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
            Locale('mr'),
            Locale('bn'),
            Locale('te'),
            Locale('ta'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // The active variant's ThemeData carries its own brightness, so it
          // always lives in the `theme` slot (light/dark/streak themes alike).
          theme: themeProvider.activeTheme,
          themeMode: ThemeMode.light,
          // The lock gate wraps the Navigator itself so the lock screen
          // covers every route, not just the home screen. The royal-reaction
          // host sits inside it (below the lock overlay) so a royal avatar's
          // cosmetic flourishes float above the app — but never over the lock.
          builder: (context, child) =>
              AppLockGate(child: RoyalReactionHost(child: child!)),
          home: appPreferences.isOnboardingComplete
              ? const MainShell()
              : const OnboardingScreen(),
        );
      },
    );
  }
}

/// Orchestrates the cold-start sequence: animated splash first, then (if
/// app lock is enabled) the biometric lock screen, then the app. Also
/// re-locks after the app has been in the background for over a minute.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  static const _relockAfter = Duration(seconds: 60);

  bool _splashing = true;
  bool _locked = false;
  DateTime? _pausedAt;

  /// When the app last entered the foreground, for the time-in-app tally that
  /// feeds the consistency heatmap and usage title.
  DateTime? _fgSince = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialLock() async {
    // Determined during the splash so the lock screen can take over the
    // moment the splash animation finishes.
    final enabled = await AppLockService().isEnabled();
    if (!mounted) return;
    setState(() => _locked = enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      // Bank this foreground session's length for the consistency heatmap
      // (capped so an app left open doesn't inflate the tally).
      final since = _fgSince;
      _fgSince = null;
      if (since != null) {
        final secs = DateTime.now().difference(since).inSeconds.clamp(0, 7200);
        if (secs > 0) GamificationService().recordAppTime(secs.toInt());
      }
    } else if (state == AppLifecycleState.resumed) {
      _fgSince = DateTime.now();
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (_splashing || _locked || pausedAt == null) return;
      if (DateTime.now().difference(pausedAt) >= _relockAfter &&
          await AppLockService().isEnabled()) {
        if (mounted) setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the app subtree mounted underneath so Navigator state survives
    // lock/unlock; splash and lock are opaque overlays above it. The splash
    // sits on top so the lock prompt only appears once it finishes.
    return Stack(
      children: [
        widget.child,
        if (_locked && !_splashing)
          Positioned.fill(
            child: LockScreen(
              onUnlocked: () => setState(() => _locked = false),
            ),
          ),
        if (_splashing)
          Positioned.fill(
            child: SplashScreen(
              onComplete: () {
                if (mounted) setState(() => _splashing = false);
              },
            ),
          ),
      ],
    );
  }
}
