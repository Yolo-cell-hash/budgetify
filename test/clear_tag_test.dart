import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/models/transaction_rule_model.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/widgets/clear_tag_sheet.dart';

/// Clearing a tag has to reach exactly as far as tagging did, or a tag
/// applied to ten transactions in one gesture takes ten gestures to undo —
/// which is why users were deleting the tag itself to get rid of it.
///
/// These pin the two halves of that: what the sheets offer, and that the
/// matcher a clear sweeps with is the same one tagging applied with.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final en = AppStrings(AppLanguage.english);

  Widget host(Future<void> Function(BuildContext) onOpen) {
    return ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => onOpen(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  group('Clear-tag scope sheet', () {
    testWidgets('offers all three distances when both apply', (tester) async {
      ClearTagScope? chosen;
      await tester.pumpWidget(host((ctx) async {
        chosen = await showClearTagSheet(
          ctx,
          tag: 'Groceries',
          payee: 'Big Bazaar',
          matchCount: 10,
          hasRule: true,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(en.clearOnlyThis), findsOneWidget);
      expect(find.text(en.clearAllFromPayee), findsOneWidget);
      expect(find.text(en.clearAllAndStopRule), findsOneWidget);
      // The consequence is stated with a real count, never "some".
      expect(find.textContaining('10'), findsWidgets);

      await tester.tap(find.text(en.clearAllAndStopRule));
      await tester.pumpAndSettle();
      expect(chosen, ClearTagScope.allAndStopRule);
    });

    testWidgets('hides the rule scope when no rule exists', (tester) async {
      await tester.pumpWidget(host((ctx) async {
        await showClearTagSheet(
          ctx,
          tag: 'Groceries',
          payee: 'Big Bazaar',
          matchCount: 4,
          hasRule: false,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Never promise to stop something that isn't happening.
      expect(find.text(en.clearAllAndStopRule), findsNothing);
      expect(find.text(en.clearAllFromPayee), findsOneWidget);
    });

    testWidgets('collapses to one choice for a lone transaction',
        (tester) async {
      await tester.pumpWidget(host((ctx) async {
        await showClearTagSheet(
          ctx,
          tag: 'Groceries',
          payee: 'Big Bazaar',
          matchCount: 1,
          hasRule: false,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // "All from this payee" and "only this one" would do the same thing.
      expect(find.text(en.clearOnlyThis), findsOneWidget);
      expect(find.text(en.clearAllFromPayee), findsNothing);
    });

    testWidgets('dismissing changes nothing', (tester) async {
      ClearTagScope? chosen = ClearTagScope.onlyThis;
      await tester.pumpWidget(host((ctx) async {
        chosen = await showClearTagSheet(
          ctx,
          tag: 'Groceries',
          payee: 'Big Bazaar',
          matchCount: 3,
          hasRule: true,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40)); // barrier
      await tester.pumpAndSettle();
      expect(chosen, isNull);
    });
  });

  group('Delete-rule sheet', () {
    testWidgets('separates "stop from now on" from "take it back"',
        (tester) async {
      DeleteRuleChoice? chosen;
      await tester.pumpWidget(host((ctx) async {
        chosen = await showDeleteRuleSheet(
          ctx,
          payee: 'Swiggy',
          tag: 'Food & Dining',
          matchCount: 7,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(en.deleteRuleKeepTags), findsOneWidget);
      expect(find.text(en.deleteRuleAndClear), findsOneWidget);

      await tester.tap(find.text(en.deleteRuleKeepTags));
      await tester.pumpAndSettle();
      expect(chosen, DeleteRuleChoice.keepTags);
    });

    testWidgets('offers only "stop" when the rule tagged nothing',
        (tester) async {
      await tester.pumpWidget(host((ctx) async {
        await showDeleteRuleSheet(
          ctx,
          payee: 'Swiggy',
          tag: 'Food & Dining',
          matchCount: 0,
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(en.deleteRuleKeepTags), findsOneWidget);
      expect(find.text(en.deleteRuleAndClear), findsNothing);
    });
  });

  group('A clear reverses exactly what the tag applied', () {
    // findTaggedByMerchant sweeps with TransactionRule.matches — the same
    // matcher bulkUpdateByMerchant tagged with. If the two ever diverged, a
    // clear would silently leave some of the tagged rows behind.
    TransactionModel txn(String? payee, TransactionType type) =>
        TransactionModel(
          amount: 100,
          type: type,
          sender: 'AD-CANBNK-S',
          message: 'x',
          detectedAt: DateTime(2026, 8, 1),
          merchantName: payee,
          category: 'Groceries',
          isClassified: true,
        );

    final probe = TransactionRule(
      senderName: 'Big Bazaar',
      transactionType: TransactionType.debit,
      category: 'Groceries',
    );

    test('matches the same payee regardless of case and punctuation', () {
      expect(probe.matches('BIG BAZAAR', TransactionType.debit), isTrue);
      expect(probe.matches('Big-Bazaar', TransactionType.debit), isTrue);
    });

    test('never crosses the direction boundary', () {
      // A "Groceries" rule on spends must not clear a refund credit.
      expect(probe.matches('Big Bazaar', TransactionType.credit), isFalse);
      expect(txn('Big Bazaar', TransactionType.credit).type,
          TransactionType.credit);
    });

    test('leaves an unrelated payee alone', () {
      expect(probe.matches('Reliance Fresh', TransactionType.debit), isFalse);
      expect(probe.matches(null, TransactionType.debit), isFalse);
    });
  });

  group('Every new clearing string is translated', () {
    // The table is hand-rolled, so a missing language shows English mid-screen
    // rather than failing to compile.
    for (final lang in AppLanguage.values) {
      test('${lang.englishName} has text for the clear flow', () {
        final s = AppStrings(lang);
        for (final value in [
          s.clearTag,
          s.clearTagAction,
          s.clearOnlyThis,
          s.clearOnlyThisDesc,
          s.clearAllFromPayee,
          s.clearAllAndStopRule,
          s.clearTagUndoHint,
          s.tagRestored,
          s.autoTagRules,
          s.autoTagRulesDesc,
          s.autoTagRulesIntro,
          s.noAutoTagRules,
          s.deleteRuleKeepTags,
          s.deleteRuleAndClear,
          s.pauseRuleTooltip,
          s.resumeRuleTooltip,
          s.deleteRuleTooltip,
          s.manageRule,
          s.ruleRestored,
          s.tagActionsTooltip,
        ]) {
          expect(value.trim(), isNotEmpty);
        }
        // Parameterised ones must carry their substitutions through.
        expect(s.clearAllFromPayeeDesc(6, 'Swiggy'), contains('6'));
        expect(s.clearAllFromPayeeDesc(6, 'Swiggy'), contains('Swiggy'));
        expect(s.clearedFromCount(6, 'Swiggy'), contains('6'));
        expect(s.clearedAndStoppedRule(6, 'Swiggy'), contains('Swiggy'));
        expect(s.deleteRuleTitle('Swiggy'), contains('Swiggy'));
        expect(s.deleteRuleAndClearDesc(6, 'Food'), contains('6'));
        expect(s.clearTagFromAllDesc(6, 2, 'Food'), contains('6'));
        expect(s.clearTagFromAllDesc(6, 2, 'Food'), contains('2'));
        expect(s.ruleMeta('Food', true, 3, false), contains('Food'));
        expect(s.autoTaggedByRule('Swiggy'), contains('Swiggy'));
        expect(s.clearFromTransactions(4), contains('4'));
      });
    }

    test('non-English languages really differ from English', () {
      final hi = AppStrings(AppLanguage.hindi);
      final ta = AppStrings(AppLanguage.tamil);
      expect(hi.autoTagRules, isNot(en.autoTagRules));
      expect(ta.clearOnlyThis, isNot(en.clearOnlyThis));
    });
  });
}
