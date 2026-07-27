import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/models/plus_products.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/screens/plus_screen.dart';
import 'package:budget_tracker/services/entitlement_service.dart';

/// The paywall is dormant (no menu reaches it), but it must render correctly
/// the day a trial expires: three plans at the agreed prices, lifetime
/// pre-selected, and the restore affordance — the reinstall lifeline for an
/// app with no accounts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EntitlementService().resetForTest();
  });

  Widget host() => ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: const MaterialApp(home: PlusScreen()),
      );

  testWidgets('shows the three plans, prices and restore button',
      (tester) async {
    await tester.pumpWidget(host());
    // Entrance animation is ~950ms; the shimmer repeats forever, so pump a
    // fixed span instead of pumpAndSettle.
    await tester.pump(const Duration(seconds: 1));

    final en = AppStrings(AppLanguage.english);
    expect(find.text(en.plusTitle), findsOneWidget);
    expect(find.text(en.plusPlanMonthly), findsOneWidget);
    expect(find.text(en.plusPlanYearly), findsOneWidget);
    expect(find.text(en.plusPlanLifetime), findsOneWidget);
    expect(find.text('₹29'), findsOneWidget);
    expect(find.text('₹299'), findsOneWidget);
    expect(find.text('₹699'), findsOneWidget);
    expect(find.text(en.plusRestore), findsOneWidget);
    // Lifetime leads: the CTA starts on the one-time price.
    expect(find.text(en.plusContinueCta('₹699')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a plan retargets the CTA', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(seconds: 1));

    final en = AppStrings(AppLanguage.english);
    await tester.ensureVisible(find.text(en.plusPlanYearly));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(en.plusPlanYearly));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(en.plusContinueCta('₹299')), findsOneWidget);
  });

  testWidgets('buying with the shipped stub shows the calm store-closed toast',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(seconds: 1));

    final en = AppStrings(AppLanguage.english);
    await tester.tap(find.text(en.plusContinueCta('₹699')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(en.plusStoreUnavailable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('maybePush is a no-op while the free window runs',
      (tester) async {
    // A fresh install (trial just started) must never see the paywall.
    late Future<bool> allowed;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                allowed =
                    PlusScreen.maybePush(context, PlusFeature.categoryBudgets);
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(await allowed, isTrue);
    expect(find.byType(PlusScreen), findsNothing);
  });

  testWidgets('the paywall lists the AI prediction and tax export gates',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(seconds: 1));

    final en = AppStrings(AppLanguage.english);
    expect(find.text(en.plusFeatAiPredictions), findsOneWidget);
    expect(find.text(en.plusFeatTaxExport), findsOneWidget);
  });

  /// The two newest gates are the only ones attached to a feature that was
  /// free-and-visible before the wall existed, so prove the whole chain —
  /// enum entry → gate → paywall — actually bites once the window closes.
  for (final feature in [
    PlusFeature.aiPredictionMode,
    PlusFeature.taxDeductionsExport,
  ]) {
    testWidgets('maybePush opens the paywall for ${feature.name} once the '
        'free window closed', (tester) async {
      // Seed through the live instance (not setMockInitialValues) — the
      // prefs singleton is already resolved by this point in the run.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'entitlement_first_launch_at',
          DateTime.now()
              .subtract(const Duration(days: 200))
              .millisecondsSinceEpoch);
      await prefs.setInt(
          'entitlement_last_seen_at', DateTime.now().millisecondsSinceEpoch);
      EntitlementService().resetForTest();

      late Future<bool> allowed;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    allowed = PlusScreen.maybePush(context, feature),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      // The gate resolves across real async gaps (prefs read) before the route
      // is pushed, so step the loop a few times — pumpAndSettle would hang on
      // the paywall's forever-repeating shimmer.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // The wall is up, and the caller is told the feature stayed locked.
      expect(find.byType(PlusScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(PlusScreen))).pop();
      await tester.pump(const Duration(milliseconds: 400));
      expect(await allowed, isFalse);
    });
  }
}
