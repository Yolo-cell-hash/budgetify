import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/models/bank_summary.dart';
import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/services/bank_directory.dart';
import 'package:budget_tracker/widgets/bank_chips.dart';

// A typical phone: the strip's own 16px padding leaves 361 for the cards.
const _phone = Size(393, 850);

BankActivity _bank(String id, String name, double spent) => BankActivity(
      bank: BankIdentity(id, name, BankKind.bank),
      spent: spent,
      expenseCount: 1,
    );

Future<void> _pump(WidgetTester tester, List<BankActivity> banks) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final prefs = AppPreferences();
  await prefs.initialize();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BankChips(
                breakdown: BankBreakdown(banks),
                style: BankChipStyle.card,
                onSelect: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The cards themselves, in row order.
List<Rect> _cardRects(WidgetTester tester) => tester
    .widgetList<InkWell>(find.byType(InkWell))
    .map((w) => tester.getRect(find.byWidget(w)))
    .toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('BankChips card strip', () {
    testWidgets('two banks share the row evenly and reach both edges',
        (tester) async {
      await _pump(tester, [
        _bank('hdfc', 'HDFC Bank', 19856),
        _bank('boi', 'Bank of India', 16646),
      ]);

      final rects = _cardRects(tester);
      expect(rects, hasLength(2));

      // Equal width, to the pixel.
      expect(rects[0].width, moreOrLessEquals(rects[1].width, epsilon: 0.01));

      // Flush with the 16px margin on both sides — the strip lines up with
      // the balance card above it instead of stopping short.
      expect(rects.first.left, moreOrLessEquals(16, epsilon: 0.01));
      expect(rects.last.right, moreOrLessEquals(_phone.width - 16,
          epsilon: 0.01));

      // The gap between them is the 10px the strip asks for, not whatever
      // was left over.
      expect(rects[1].left - rects[0].right, moreOrLessEquals(10,
          epsilon: 0.01));
    });

    testWidgets('a single bank fills the row', (tester) async {
      await _pump(tester, [_bank('hdfc', 'HDFC Bank', 19856)]);

      final rects = _cardRects(tester);
      expect(rects, hasLength(1));
      expect(rects.single.left, moreOrLessEquals(16, epsilon: 0.01));
      expect(rects.single.right,
          moreOrLessEquals(_phone.width - 16, epsilon: 0.01));
    });

    testWidgets('more banks than fit stay equal, and the next one peeks in',
        (tester) async {
      await _pump(tester, [
        _bank('hdfc', 'HDFC Bank', 19856),
        _bank('boi', 'Bank of India', 16646),
        _bank('sbi', 'State Bank of India', 8200),
        _bank('icici', 'ICICI Bank', 4100),
      ]);

      final rects = _cardRects(tester);
      expect(rects, hasLength(4));

      // Still all the same width.
      for (final r in rects.skip(1)) {
        expect(r.width, moreOrLessEquals(rects.first.width, epsilon: 0.01));
      }

      // Two full cards, then part of a third showing past the right edge —
      // the only thing telling you the strip scrolls.
      expect(rects[1].right, lessThan(_phone.width));
      expect(rects[2].left, lessThan(_phone.width));
      expect(rects[2].right, greaterThan(_phone.width));
    });
  });
}
