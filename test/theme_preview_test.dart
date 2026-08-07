import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/theme_preview_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [child] with the providers the still needs (l10n, and privacy mode
/// for the amounts inside SavingsRateBar), under [ambient] — deliberately a
/// *different* theme from the one being previewed in most tests.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  AppThemeVariant ambient = AppThemeVariant.light,
}) async {
  SharedPreferences.setMockInitialValues({});
  final lp = LocaleProvider();
  await lp.initialize();
  final prefs = AppPreferences();
  await prefs.initialize();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: lp),
        ChangeNotifierProvider.value(value: prefs),
      ],
      child: MaterialApp(
        theme: AppTheme.of(ambient),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ThemeStill', () {
    testWidgets('renders every variant without throwing or overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final v in AppThemeVariant.values) {
        await _pump(tester, ThemeStill(variant: v));
        expect(tester.takeException(), isNull, reason: 'threw on ${v.name}');
      }
    });

    testWidgets('inks itself for the PREVIEWED variant, not the ambient one',
        (tester) async {
      // The whole mechanism is the Theme wrap: AppColors.of / HeroStyle.of
      // resolve through the AppPalette extension, so a still shown inside a
      // light app must still paint Vellum's parchment-on-near-black. If this
      // regresses, every preview silently shows the user's current theme.
      await _pump(
        tester,
        const ThemeStill(variant: AppThemeVariant.vellum),
        ambient: AppThemeVariant.light,
      );

      final wordmark = tester.widget<Text>(find.text('Budgetify'));
      expect(wordmark.style!.color, AppColors.vellum.text);
      expect(wordmark.style!.color, isNot(AppColors.light.text));
    });

    testWidgets('shows the hero and the canvas together', (tester) async {
      // Pairing them is the point: a theme whose card runs lighter than the
      // screen (Vellum) is only legible as such when both are on screen. The
      // canvas rows are the "screen" half of that pair.
      await _pump(
        tester,
        const ThemeStill(variant: AppThemeVariant.vellum),
        ambient: AppThemeVariant.dark,
      );

      expect(find.text('Budgetify'), findsOneWidget); // canvas
      expect(find.text('₹42,318.60'), findsOneWidget); // hero
      expect(find.text('HDFC Bank'), findsOneWidget); // canvas rows
      expect(find.textContaining('SAVINGS RATE'), findsOneWidget);
    });
  });

  group('showThemePreviewSheet', () {
    testWidgets('a locked theme states the requirement and cannot be applied',
        (tester) async {
      var applied = 0;
      await _pump(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showThemePreviewSheet(
              ctx,
              variant: AppThemeVariant.vellum,
              name: 'Vellum',
              unlockDays: 60,
              onApply: null,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Vellum'), findsOneWidget);
      expect(find.textContaining('60-day streak'), findsOneWidget);
      // No way to wear it from here — the still is the reward preview, not the
      // reward.
      expect(find.text(AppStrings(AppLanguage.english).applyTheme), findsNothing);
      expect(find.text(AppStrings(AppLanguage.english).gotIt), findsOneWidget);
      expect(applied, 0);
    });

    testWidgets('an unlocked theme can be applied from the sheet',
        (tester) async {
      var applied = 0;
      await _pump(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showThemePreviewSheet(
              ctx,
              variant: AppThemeVariant.onyxAmber,
              name: 'Onyx & Amber',
              onApply: () => applied++,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final apply = find.text(AppStrings(AppLanguage.english).applyTheme);
      expect(apply, findsOneWidget);
      await tester.tap(apply);
      await tester.pumpAndSettle();

      expect(applied, 1);
      // Applying closes the sheet — the user sees the real thing behind it.
      expect(apply, findsNothing);
    });

    testWidgets('the active theme offers nothing to apply', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showThemePreviewSheet(
              ctx,
              variant: AppThemeVariant.light,
              name: 'Light',
              active: true,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings(AppLanguage.english).currentlyApplied),
          findsOneWidget);
      expect(find.text(AppStrings(AppLanguage.english).applyTheme), findsNothing);
    });
  });
}
