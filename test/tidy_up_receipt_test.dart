import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/widgets/tidy_up_receipt.dart';

/// Tidy up's acknowledgement strip. Before it existed, answering an entry
/// swapped one card for another and nothing else moved — with two ₹100 credits
/// back to back there was no way to tell a registered answer from an ignored
/// tap, or which of the two had been answered.
///
/// It sits in a Row with a translated label, a data line and an Undo button,
/// which is the classic overflow shape, so it is exercised in all six
/// languages at a narrow width.
void main() {
  Widget host(Widget child, {double width = 360}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      );

  testWidgets('names the answer and the entry it was given to',
      (tester) async {
    final en = AppStrings(AppLanguage.english);
    await tester.pumpWidget(host(TidyUpReceipt(
      accent: const Color(0xFF178A5B),
      icon: Icons.check_rounded,
      label: en.tidyUpDidConfirm,
      detail: '+₹100 · KOTAKB · 5 Aug, 4:41 PM',
      undoLabel: en.commonUndo,
      onUndo: () {},
    )));

    expect(find.text(en.tidyUpDidConfirm), findsOneWidget);
    // The identity line is the point: it is what separates this ₹100 credit
    // from the next one.
    expect(find.text('+₹100 · KOTAKB · 5 Aug, 4:41 PM'), findsOneWidget);
    expect(find.text(en.commonUndo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('undo reports the tap', (tester) async {
    final en = AppStrings(AppLanguage.english);
    var undone = 0;
    await tester.pumpWidget(host(TidyUpReceipt(
      accent: const Color(0xFFC05621),
      icon: Icons.playlist_remove_rounded,
      label: en.tidyUpDidRemove,
      detail: '-₹450 · SWIGGY · 5 Aug, 1:02 PM',
      undoLabel: en.commonUndo,
      onUndo: () => undone++,
    )));

    await tester.tap(find.text(en.commonUndo));
    await tester.pump();
    expect(undone, 1);
  });

  testWidgets('an unrestorable removal offers no Undo', (tester) async {
    final en = AppStrings(AppLanguage.english);
    await tester.pumpWidget(host(TidyUpReceipt(
      accent: const Color(0xFFC05621),
      icon: Icons.playlist_remove_rounded,
      label: en.tidyUpDidRemove,
      undoLabel: en.commonUndo,
    )));

    expect(find.text(en.tidyUpDidRemove), findsOneWidget);
    expect(find.text(en.commonUndo), findsNothing);
  });

  testWidgets('every language fits a 360px strip', (tester) async {
    for (final language in AppLanguage.values) {
      final s = AppStrings(language);
      for (final label in [
        s.tidyUpDidConfirm,
        s.tidyUpDidFlip,
        s.tidyUpDidRemove,
        s.tidyUpUndone,
      ]) {
        await tester.pumpWidget(host(TidyUpReceipt(
          accent: const Color(0xFF178A5B),
          icon: Icons.check_rounded,
          label: label,
          detail: '+₹1,00,000 · A VERY LONG PAYEE NAME PVT LTD · 5 Aug, '
              '4:41 PM',
          undoLabel: s.commonUndo,
          onUndo: () {},
        )));
        expect(
          tester.takeException(),
          isNull,
          reason: '${language.code}: "$label" overflowed the strip',
        );
      }
    }
  });

  testWidgets('survives a cramped 280px width', (tester) async {
    final ta = AppStrings(AppLanguage.tamil);
    await tester.pumpWidget(host(
      TidyUpReceipt(
        accent: const Color(0xFF178A5B),
        icon: Icons.check_rounded,
        label: ta.tidyUpDidFlip,
        detail: '+₹1,00,000 · SOME PAYEE · 5 Aug, 4:41 PM',
        undoLabel: ta.commonUndo,
        onUndo: () {},
      ),
      width: 280,
    ));
    expect(tester.takeException(), isNull);
  });
}
