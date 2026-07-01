import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/axio_import_service.dart';

void main() {
  // A trimmed axio "Expense Report" with the same preamble + header the real
  // export uses, followed by a mix of rows that exercise every branch.
  const csv = '''
"","axio","EXPENSE","REPORT","","","","","","",""
"Name","Jay","","","","","","","","",""
"FROM","2026-06-01","TO","2026-06-30"

"DATE","TIME","PLACE","AMOUNT","DR/CR","ACCOUNT","EXPENSE","INCOME","CATEGORY","TAGS","NOTE"
"2026-06-01","07:00 PM","SWIGGY","140","DR","BOI 7848","Yes","'-","FOOD & DRINKS","#Online",""
"2026-06-02","07:00 PM","SWIGGY","141","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-03","07:00 PM","SWIGGY","142","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-04","07:00 PM","SWIGGY","143","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-05","07:00 PM","SWIGGY","144","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-06","07:00 PM","SWIGGY","145","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-01","05:00 PM","IRCTC","19.4","DR","BOI 7848","Yes","'-","TRAVEL","#Online",""
"2026-06-02","05:00 PM","IRCTC","19.4","DR","BOI 7848","Yes","'-","TRAVEL","#Online",""
"2026-06-03","05:00 PM","IRCTC","19.4","DR","BOI 7848","Yes","'-","TRAVEL","#Online",""
"2026-06-04","05:00 PM","IRCTC","19.4","DR","BOI 7848","Yes","'-","TRAVEL","#Online",""
"2026-06-05","05:00 PM","IRCTC","19.4","DR","BOI 7848","Yes","'-","TRAVEL","#Online",""
"2026-06-06","05:00 PM","IRCTC","19.4","DR","BOI 7848","Yes","'-","TRAVEL","#Online",""
"2026-06-01","06:00 PM","EATCLUB","135","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-02","06:00 PM","EATCLUB","136","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-03","06:00 PM","EATCLUB","137","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-04","06:00 PM","EATCLUB","138","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-05","06:00 PM","EATCLUB","139","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-01","06:39 PM","MCDONALD'S","5,000","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-01","09:00 AM","CONFUSED SHOP","10","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-02","09:00 AM","CONFUSED SHOP","10","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-03","09:00 AM","CONFUSED SHOP","10","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-04","09:00 AM","CONFUSED SHOP","10","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-05","09:00 AM","CONFUSED SHOP","10","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-06","09:00 AM","CONFUSED SHOP","10","DR","BOI 7848","Yes","'-","FOOD & DRINKS","",""
"2026-06-07","09:00 AM","CONFUSED SHOP","10","DR","BOI 7848","Yes","'-","SHOPPING","",""
"2026-06-01","07:49 AM","JAMES CHETTIYAR","30","DR","BOI 7848","Yes","'-","UNKNOWN","",""
"2026-06-02","08:58 AM","CREDIT","202","CR","BOI 7848","'-","No","CREDIT","",""
"2026-06-04","10:52 PM","A/C TRANSFER","101","CR","BOI 7848","'-","No","ACCOUNT TRANSFER","",""
"","","","","","","POWERED","BY","axio","","https://axio.co.in"
''';

  final service = AxioImportService();

  AxioMerchantTag? find(List<AxioMerchantTag> list, String merchant) {
    for (final t in list) {
      if (t.merchant == merchant) return t;
    }
    return null;
  }

  group('AxioImportService.parsePreview', () {
    final preview = service.parsePreview(csv);

    test('frequent, consistent merchants (>5) become auto-tag rules', () {
      final swiggy = find(preview.recurring, 'Swiggy');
      final irctc = find(preview.recurring, 'Irctc');
      expect(swiggy, isNotNull);
      expect(swiggy!.category, 'Food & Dining');
      expect(swiggy.count, 6);
      expect(swiggy.type, TransactionType.debit);
      expect(irctc, isNotNull);
      expect(irctc!.category, 'Travel');
    });

    test('exactly 5 is NOT recurring (threshold is "more than 5")', () {
      expect(find(preview.recurring, 'Eatclub'), isNull);
      final eatclub = find(preview.oneOff, 'Eatclub');
      expect(eatclub, isNotNull);
      expect(eatclub!.count, 5);
      expect(eatclub.category, 'Food & Dining');
    });

    test('a single occurrence is a one-off tag, not a rule', () {
      expect(find(preview.recurring, "Mcdonald's"), isNull);
      final mcd = find(preview.oneOff, "Mcdonald's");
      expect(mcd, isNotNull);
      expect(mcd!.category, 'Food & Dining');
      expect(mcd.count, 1);
    });

    test('a merchant with conflicting tags is excluded entirely', () {
      // "nothing else" is violated (6× Food, 1× Shopping) → no confident tag.
      expect(find(preview.recurring, 'Confused Shop'), isNull);
      expect(find(preview.oneOff, 'Confused Shop'), isNull);
    });

    test('UNKNOWN / CREDIT / ACCOUNT TRANSFER rows carry no tag', () {
      expect(find(preview.recurring, 'James Chettiyar'), isNull);
      expect(find(preview.oneOff, 'James Chettiyar'), isNull);
      for (final t in [...preview.recurring, ...preview.oneOff]) {
        expect(t.merchant, isNot('Credit'));
        expect(t.merchant, isNot('A/c Transfer'));
      }
    });

    test('preview is non-empty and counts the usable tagged rows', () {
      expect(preview.isEmpty, isFalse);
      // 6 Swiggy + 6 IRCTC + 5 EatClub + 1 McDonald's + 7 Confused = 25 mapped.
      expect(preview.taggedRows, 25);
    });

    test('rejects a file with no axio header', () {
      expect(
        () => service.parsePreview('some,random,csv\n1,2,3'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AxioImportService.parseCsvLine', () {
    test('keeps a comma inside a quoted amount intact', () {
      expect(
        AxioImportService.parseCsvLine('"MCDONALD","5,000","DR"'),
        ['MCDONALD', '5,000', 'DR'],
      );
    });

    test('unescapes doubled quotes', () {
      expect(
        AxioImportService.parseCsvLine('"he said ""hi""","x"'),
        ['he said "hi"', 'x'],
      );
    });

    test('handles empty trailing fields', () {
      expect(
        AxioImportService.parseCsvLine('"a","",""'),
        ['a', '', ''],
      );
    });
  });
}
