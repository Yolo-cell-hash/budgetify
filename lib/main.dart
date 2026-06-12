import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget_tracker/screens/home_screen.dart';
import 'package:budget_tracker/screens/lock_screen.dart';
import 'package:budget_tracker/screens/onboarding_screen.dart';
import 'package:budget_tracker/services/app_lock_service.dart';
import 'package:budget_tracker/services/notification_service.dart';
import 'package:budget_tracker/services/background_service.dart';
import 'package:budget_tracker/services/custom_tag_service.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/providers/app_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize background service for scheduled SMS scans
  await BackgroundService.initialize();

  // Initialize custom tags (must be before UI builds)
  await CustomTagService().initialize();

  // Create providers
  final themeProvider = ThemeProvider();
  final appPreferences = AppPreferences();

  // Initialize providers
  await themeProvider.initialize();
  await appPreferences.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: appPreferences),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AppPreferences>(
      builder: (context, themeProvider, appPreferences, child) {
        return MaterialApp(
          title: 'Budget Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          // The lock gate wraps the Navigator itself so the lock screen
          // covers every route, not just the home screen.
          builder: (context, child) => AppLockGate(child: child!),
          home: appPreferences.isOnboardingComplete
              ? const HomeScreen()
              : const OnboardingScreen(),
        );
      },
    );
  }
}

/// Gates the app behind the biometric lock screen when app lock is enabled.
/// Re-locks after the app has been in the background for over a minute.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  static const _relockAfter = Duration(seconds: 60);

  bool _locked = false;
  bool _checked = false;
  DateTime? _pausedAt;

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
    final enabled = await AppLockService().isEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _checked = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (_locked || pausedAt == null) return;
      if (DateTime.now().difference(pausedAt) >= _relockAfter &&
          await AppLockService().isEnabled()) {
        if (mounted) setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the app subtree mounted underneath so Navigator state survives
    // lock/unlock; the lock screen is an opaque overlay above it.
    return Stack(
      children: [
        widget.child,
        if (!_checked)
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFF131520)),
          )
        else if (_locked)
          Positioned.fill(
            child: LockScreen(
              onUnlocked: () => setState(() => _locked = false),
            ),
          ),
      ],
    );
  }
}
