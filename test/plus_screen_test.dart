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
}
