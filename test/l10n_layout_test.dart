import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/screens/onboarding_screen.dart';
import 'package:budget_tracker/widgets/language_picker_sheet.dart';
import 'package:budget_tracker/widgets/transaction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression net for two localization layout bugs:
///  1. Onboarding soft-lock — long-script languages overflowed the fixed
///     columns on small phones and pushed the Continue button off-screen.
///  2. The Settings language sheet clipped its last option (the modal sheet
///     caps at ~9/16 of screen height and the list couldn't scroll).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(LocaleProvider, AppPreferences)> providers() async {
    final lp = LocaleProvider();
    await lp.initialize();
    final prefs = AppPreferences();
    await prefs.initialize();
    return (lp, prefs);
  }

  void useSmallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  bool onScreen(WidgetTester tester, Finder f) {
    final rect = tester.getRect(f);
    final screen = Offset.zero & const Size(360, 640);
    return screen.contains(rect.topLeft) && screen.contains(rect.bottomRight);
  }

  group('Onboarding fits every language on a small phone', () {
    testWidgets('the action button is always on-screen and tappable',
        (tester) async {
      useSmallPhone(tester);
      for (final lang in AppLanguage.values) {
        final (lp, prefs) = await providers();
        await lp.setLanguage(lang);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: lp),
              ChangeNotifierProvider.value(value: prefs),
            ],
            // Keyed per language so each iteration starts fresh on page 1
            // (identical trees would otherwise keep the PageView state).
            child: MaterialApp(
                key: ValueKey(lang), home: const OnboardingScreen()),
          ),
        );
        await tester.pumpAndSettle();
        final strings = AppStrings(lang);

        // Page 1 — language choice. The old fixed column overflowed here and
        // buried Continue below the fold: the soft-lock.
        expect(tester.takeException(), isNull, reason: '$lang page 1');
        final cont =
            find.widgetWithText(ElevatedButton, strings.commonContinue);
        expect(cont, findsOneWidget, reason: '$lang');
        expect(onScreen(tester, cont), isTrue,
            reason: '$lang: Continue must be pinned on-screen');
        await tester.tap(cont);
        await tester.pumpAndSettle();

        // Page 2 — welcome.
        expect(tester.takeException(), isNull, reason: '$lang page 2');
        final start =
            find.widgetWithText(ElevatedButton, strings.getStarted);
        expect(start, findsOneWidget, reason: '$lang');
        expect(onScreen(tester, start), isTrue, reason: '$lang: Get started');
        await tester.tap(start);
        await tester.pumpAndSettle();

        // Page 3 — permissions. The grant button must be visible (we don't
        // tap it — that would hit the real permission plugin).
        expect(tester.takeException(), isNull, reason: '$lang page 3');
        final grant = find.widgetWithText(
            ElevatedButton, strings.grantPermissionAndStart);
        expect(grant, findsOneWidget, reason: '$lang');
        expect(onScreen(tester, grant), isTrue, reason: '$lang: grant');
      }
    });
  });

  group('Language picker sheet', () {
    testWidgets('every language, including the last, is reachable on a small '
        'phone', (tester) async {
      useSmallPhone(tester);
      final (lp, _) = await providers();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: lp,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showLanguagePickerSheet(context, lp),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The last language used to be clipped half out of the sheet. Now the
      // list scrolls: bring Tamil into view and select it. (The finder only
      // matches once the lazy list builds the row, so scroll first.)
      final tamil = find.text('Tamil');
      await tester.scrollUntilVisible(tamil, 60,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      expect(tamil, findsOneWidget);
      final rect = tester.getRect(find.ancestor(
          of: tamil, matching: find.byType(ListTile)));
      expect(rect.bottom, lessThanOrEqualTo(640),
          reason: 'the Tamil row must sit fully inside the screen');

      await tester.tap(tamil);
      await tester.pumpAndSettle();
      expect(lp.language, AppLanguage.tamil);
      expect(find.byType(ListTile), findsNothing,
          reason: 'selection closes the sheet');
    });
  });

  group('Transaction card state badges', () {
    // The badge strip was a plain Row of intrinsic-width children inside a
    // bounded parent, so a row that was both unclassified and flagged for
    // review overflowed and clipped its LAST badge — "Check", the only on-card
    // pointer into the parser-correction flow. Release builds clip silently,
    // so on narrow phones that badge was simply never seen.
    TransactionModel txn({required bool classified, required bool review}) =>
        TransactionModel(
          id: 1,
          amount: 12345.00,
          type: TransactionType.debit,
          sender: 'HDFCBK',
          message: 'Rs.12345.00 debited from a/c XX1234 to VPA foo@ybl',
          detectedAt: DateTime(2026, 7, 1, 14, 30),
          isClassified: classified,
          category: classified ? 'Food' : null,
          reviewReasons: review ? 'direction,payee_unknown' : null,
          accountInfo: 'XX1234',
        );

    testWidgets('no badge is clipped in any language, in either theme '
        'brightness, on a small phone at large text scale', (tester) async {
      for (final lang in AppLanguage.values) {
        for (final variant in [AppThemeVariant.light, AppThemeVariant.dark]) {
          useSmallPhone(tester); // 360x640 @ textScale 1.2
          final (lp, prefs) = await providers();
          await lp.setLanguage(lang);
          final strings = AppStrings(lang);

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: lp),
                ChangeNotifierProvider.value(value: prefs),
              ],
              child: MaterialApp(
                key: ValueKey('$lang-$variant'),
                theme: AppTheme.of(variant),
                home: Scaffold(
                  body: ListView(
                    children: [
                      TransactionCard(
                        transaction: txn(classified: false, review: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final where = '$lang/$variant';
          expect(tester.takeException(), isNull,
              reason: '$where: badge strip must not overflow');

          // Both badges present *and* fully inside the viewport — the point of
          // the fix is that neither is silently cut off the right edge.
          for (final label in [strings.unclassified, strings.needsReviewBadge]) {
            final badge = find.text(label);
            expect(badge, findsOneWidget, reason: '$where: "$label" missing');
            expect(tester.getRect(badge).right, lessThanOrEqualTo(360.0),
                reason: '$where: "$label" is clipped off the right edge');
          }
        }
      }
    });

    testWidgets('a long localised category name ellipsizes instead of '
        'overflowing', (tester) async {
      for (final lang in AppLanguage.values) {
        useSmallPhone(tester);
        final (lp, prefs) = await providers();
        await lp.setLanguage(lang);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: lp),
              ChangeNotifierProvider.value(value: prefs),
            ],
            child: MaterialApp(
              key: ValueKey(lang),
              theme: AppTheme.of(AppThemeVariant.light),
              home: Scaffold(
                body: ListView(
                  children: [
                    TransactionCard(
                      transaction: txn(classified: true, review: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: '$lang: category chip must not overflow');
      }
    });
  });
}
