import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/services/removal_service.dart';
import 'package:budget_tracker/widgets/removal_choice_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The removal fork is the fix for the complaint that "Not a transaction" is
/// invisible: instead of living in an overflow menu two screens away, it is
/// offered at the moment the user has already decided to remove something.
/// These tests pin the contract that every removal entry point depends on.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  TransactionModel txn({bool manual = false, String message = 'Rs.99 spent'}) =>
      TransactionModel(
        id: 1,
        amount: 99,
        type: TransactionType.debit,
        sender: 'HDFCBK',
        message: message,
        detectedAt: DateTime(2026, 7, 1),
        isManual: manual,
      );

  Future<TransactionRemoval?> openFork(
    WidgetTester tester, {
    required bool canMute,
    AppLanguage lang = AppLanguage.english,
    int count = 1,
  }) async {
    final lp = LocaleProvider();
    await lp.initialize();
    await lp.setLanguage(lang);

    TransactionRemoval? result;
    var returned = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: lp,
        child: MaterialApp(
          // Keyed per language so each iteration starts from a fresh tree
          // instead of inheriting the previous language's open dialog.
          key: ValueKey('$lang-$canMute-$count'),
          theme: AppTheme.of(AppThemeVariant.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showRemovalChoiceDialog(
                    context,
                    sender: 'HDFCBK',
                    canMute: canMute,
                    count: count,
                  );
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(returned, isFalse, reason: 'dialog should still be open');
    return result;
  }

  group('canMute', () {
    test('manual rows cannot be muted — nothing re-creates them', () {
      expect(RemovalService.canMute(txn(manual: true)), isFalse);
    });

    test('a row with no message body cannot key a mute', () {
      expect(RemovalService.canMute(txn(message: '   ')), isFalse);
    });

    test('an ordinary SMS-derived row can be muted', () {
      expect(RemovalService.canMute(txn()), isTrue);
    });
  });

  group('Removal fork', () {
    testWidgets('offers both outcomes, and states what each one does',
        (tester) async {
      await openFork(tester, canMute: true);
      final s = AppStrings(AppLanguage.english);

      expect(find.text(s.notATransaction), findsOneWidget);
      expect(find.text(s.justRemoveThisOne), findsOneWidget);
      // The consequences are the entire point of the fork: without them the
      // user has no way to know that a plain delete lets the promo come back.
      expect(find.text(s.notATransactionOptionBody('HDFCBK')), findsOneWidget);
      expect(find.text(s.justRemoveThisOneBody), findsOneWidget);
    });

    testWidgets('choosing "Not a transaction" reports the muting outcome',
        (tester) async {
      TransactionRemoval? captured;
      final lp = LocaleProvider();
      await lp.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: lp,
          child: MaterialApp(
            theme: AppTheme.of(AppThemeVariant.light),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async => captured =
                      await showRemovalChoiceDialog(context,
                          sender: 'HDFCBK', canMute: true),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text(AppStrings(AppLanguage.english).notATransaction));
      await tester.pumpAndSettle();

      expect(captured, TransactionRemoval.notATransaction);
    });

    testWidgets('choosing "Just remove this one" keeps the old behaviour',
        (tester) async {
      TransactionRemoval? captured;
      final lp = LocaleProvider();
      await lp.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: lp,
          child: MaterialApp(
            theme: AppTheme.of(AppThemeVariant.light),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async => captured =
                      await showRemovalChoiceDialog(context,
                          sender: 'HDFCBK', canMute: true),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text(AppStrings(AppLanguage.english).justRemoveThisOne));
      await tester.pumpAndSettle();

      expect(captured, TransactionRemoval.deleteOnly);
    });

    testWidgets('a row that cannot be muted gets a plain confirm, not a fork '
        'promising something it would silently skip', (tester) async {
      await openFork(tester, canMute: false);
      final s = AppStrings(AppLanguage.english);

      expect(find.text(s.notATransaction), findsNothing);
      expect(find.text(s.justRemoveThisOne), findsNothing);
      expect(find.text(s.commonDelete), findsOneWidget);
    });

    testWidgets('bulk removal describes the whole selection', (tester) async {
      await openFork(tester, canMute: true, count: 7);
      final s = AppStrings(AppLanguage.english);

      expect(find.text(s.removeNEntriesTitle(7)), findsOneWidget);
      expect(find.text(s.notATransactionNBody(7)), findsOneWidget);
    });

    testWidgets('lays out without overflow in every language on a small phone',
        (tester) async {
      for (final lang in AppLanguage.values) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await openFork(tester, canMute: true, lang: lang);
        expect(tester.takeException(), isNull,
            reason: '$lang: the fork must fit a small phone');

        final s = AppStrings(lang);
        expect(find.text(s.notATransaction), findsOneWidget, reason: '$lang');
        expect(find.text(s.justRemoveThisOne), findsOneWidget, reason: '$lang');
      }
    });
  });
}
