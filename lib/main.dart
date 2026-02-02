import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget_tracker/screens/home_screen.dart';
import 'package:budget_tracker/screens/onboarding_screen.dart';
import 'package:budget_tracker/services/notification_service.dart';
import 'package:budget_tracker/services/background_service.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/providers/app_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize background service for scheduled SMS scans
  await BackgroundService.initialize();

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
          home: appPreferences.isOnboardingComplete
              ? const HomeScreen()
              : const OnboardingScreen(),
        );
      },
    );
  }
}
