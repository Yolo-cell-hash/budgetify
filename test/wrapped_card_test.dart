import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/models/monthly_recap.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/wrapped_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The redesigned Wrapped poster is a fixed 360×640 composition that must
/// hold together — no overflows, key content present — across every app
/// theme (the reward themes restyle it via HeroStyle), in privacy and
/// reveal-amounts modes, with and without a royal seal, and in long-script
/// languages.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MonthlyRecap demoRecap({int appTimeSeconds = 4 * 3600 + 23 * 60}) {
    final daily = List<double>.generate(
        30, (i) => i == 13 ? 9400.0 : (i % 4 == 0 ? 0.0 : 800.0 + i * 37));
    return MonthlyRecap(
      month: DateTime(2026, 6, 1),
      availableDays: 30,
      hasData: true,
      savingsRatePct: 18,
      spendVsLastMonthPct: -12,
      topCategories: const [
        RecapHighlight(label: 'Rent', icon: '🏠', sharePct: 48, amount: 40000),
        RecapHighlight(
            label: 'Food & Dining', icon: '🍔', sharePct: 21, amount: 17400),
        RecapHighlight(
            label: 'Groceries', icon: '🛒', sharePct: 9, amount: 7500),
      ],
      topMerchant: const RecapHighlight(
          label: 'Malandkar Santosh Ramchandra',
          icon: '🏪',
          sharePct: 48,
          amount: 40000),
      categoryMover: const RecapMover(label: 'Travel', icon: '✈️', changePct: 35),
      netWorthChangePct: 4,
      investedPct: 62,
      transactionCount: 266,
      merchantCount: 102,
      trends: RecapTrends(
        dailySpend: daily,
        peakDay: DateTime(2026, 6, 14),
        peakDayAmount: 9400,
        busiestDay: DateTime(2026, 6, 27),
        busiestDayTxns: 21,
        trackedDays: 30,
        noSpendDays: 8,
      ),
      appTimeSeconds: appTimeSeconds,
      totalSpent: 82932,
      totalIncome: 101000,
      avgPerDay: 2764,
      biggestTxnAmount: 35000,
      biggestTxnLabel: 'Malandkar Santosh Ramchandra',
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required AppThemeVariant variant,
    AppLanguage language = AppLanguage.english,
    bool showAmounts = false,
    RoyalAvatar? royal,
    MonthlyRecap? recap,
  }) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final lp = LocaleProvider();
    await lp.initialize();
    await lp.setLanguage(language);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: lp,
        child: MaterialApp(
          theme: AppTheme.of(variant),
          home: Scaffold(
            body: Center(
              child: WrappedCard(
                recap: recap ?? demoRecap(),
                showAmounts: showAmounts,
                royal: royal,
                animate: false,
              ),
            ),
          ),
        ),
      ),
    );
    // Settle AnimatedTheme so assertions run against this variant's palette,
    // not a lerp from the previous pump.
    await tester.pumpAndSettle();
  }

  testWidgets('renders without overflow on every theme variant',
      (tester) async {
    for (final variant in AppThemeVariant.values) {
      await pumpCard(tester, variant: variant);
      expect(tester.takeException(), isNull,
          reason: 'overflow/exception on $variant');
      expect(find.text('BUDGETIFY'), findsOneWidget);
      expect(find.text('budgetify.app'), findsOneWidget);
      // Privacy mode: the hero is the savings rate (the shimmer paints the
      // glyphs twice), and no ₹ leaks anywhere.
      expect(find.text('18%'), findsAtLeastNWidgets(1));
      expect(find.textContaining('₹'), findsNothing,
          reason: 'privacy mode must never show amounts on $variant');
    }
  });

  testWidgets('reveal-amounts mode swaps in real figures', (tester) async {
    await pumpCard(tester,
        variant: AppThemeVariant.dark, showAmounts: true);
    expect(tester.takeException(), isNull);
    // Hero total + at least the top-category amount render as rupees.
    expect(find.textContaining('₹'), findsWidgets);
    expect(find.textContaining('82,932'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows the daily rhythm, top categories and insight grid',
      (tester) async {
    await pumpCard(tester, variant: AppThemeVariant.dark);
    final l10n = const AppStrings(AppLanguage.english);
    expect(find.text(l10n.wDailyRhythm.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.wTopCategories.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.wBusiestDay.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.wNoSpendDays.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.wTimeInApp.toUpperCase()), findsOneWidget);
    expect(find.text('4h 23m'), findsOneWidget);
    expect(find.text(l10n.nTxns(266)), findsOneWidget);
    expect(find.text(l10n.nMerchants(102)), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('falls back gracefully when time-in-app is unrecorded',
      (tester) async {
    await pumpCard(tester,
        variant: AppThemeVariant.light,
        recap: demoRecap(appTimeSeconds: 0));
    expect(tester.takeException(), isNull);
    final l10n = const AppStrings(AppLanguage.english);
    expect(find.text(l10n.wTimeInApp.toUpperCase()), findsNothing);
    // The mover tile takes the slot instead.
    expect(find.text('↑ 35%'), findsOneWidget);
  });

  testWidgets('equipped royals sign the card with their seal', (tester) async {
    await pumpCard(tester,
        variant: AppThemeVariant.dark, royal: kRoyalAvatars.first);
    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate((w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_RoyalSealPainter'),
      findsOneWidget,
    );
  });

  testWidgets('holds together in long-script languages', (tester) async {
    for (final lang in [AppLanguage.tamil, AppLanguage.telugu]) {
      await pumpCard(tester,
          variant: AppThemeVariant.midnightIndigo, language: lang);
      expect(tester.takeException(), isNull,
          reason: 'overflow/exception in $lang');
    }
  });
}
