import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:budget_tracker/screens/main_shell.dart';
import 'package:budget_tracker/screens/lock_screen.dart';
import 'package:budget_tracker/screens/onboarding_screen.dart';
import 'package:budget_tracker/screens/splash_screen.dart';
import 'package:budget_tracker/services/app_lock_service.dart';
import 'package:budget_tracker/services/notification_service.dart';
import 'package:budget_tracker/services/background_service.dart';
import 'package:budget_tracker/services/custom_tag_service.dart';
import 'package:budget_tracker/services/gamification_service.dart';
import 'package:budget_tracker/services/entitlement_service.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Record the trial anchor (first-use timestamp) as the very first thing, so
  // it survives even if a later startup step fails. Silent: nothing reads it
  // yet and no feature is gated on it.
  await EntitlementService().initialize();

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize background service for scheduled SMS scans
  await BackgroundService.initialize();

  // Initialize custom tags (must be before UI builds)
  await CustomTagService().initialize();

  // Create providers
  final themeProvider = ThemeProvider();
  final appPreferences = AppPreferences();
  final localeProvider = LocaleProvider();

  // Initialize providers
  await themeProvider.initialize();
  await appPreferences.initialize();
  await localeProvider.initialize();

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

  // If a tapped notification cold-started the app, route after first frame.
  await NotificationService().handleLaunchPayload();
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
          locale: localeProvider.locale,
          supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr'), Locale('bn'), Locale('te'), Locale('ta')],
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
          // covers every route, not just the home screen.
          builder: (context, child) => AppLockGate(child: child!),
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

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
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
