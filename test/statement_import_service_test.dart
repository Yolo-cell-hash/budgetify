import 'dart:convert';
import 'dart:typed_data';

import 'package:budget_tracker/models/statement_import_models.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/csv_reader.dart';
import 'package:budget_tracker/services/statement_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures mimic real bank exports: preamble junk before the header,
/// footer/total rows after the data, quoted fields, Indian number formats.
const hdfcCsv = '''
HDFC BANK Ltd.
Statement of account
MR TEST USER,,,,,,
Account No :XXXXXXXX1234,,,,,,
Date,Narration,Chq./Ref.No.,Value Dt,Withdrawal Amt.,Deposit Amt.,Closing Balance
01/04/26,UPI-SWIGGY LIMITED-swiggy@axis-UTIB0000248-1041234567-Payment,0000104123456789,01/04/26,449.00,,"1,23,551.00"
03/04/26,UPI-RAMESH KUMAR-q123@ybl-SBIN0001234-1042345678-Sent,0000104234567890,03/04/26,"5,000.00",,"1,18,551.00"
05/04/26,ACME CORP-SALARY-APR,SAL0426,05/04/26,,"85,000.00","2,03,551.00"
,,,,,,
STATEMENT SUMMARY :-,,,,,,
''';

const sbiCsv = '''
Account Name,MR TEST USER
Address,MUMBAI
Txn Date,Value Date,Description,Ref No./Cheque No.,Debit,Credit,Balance
02 Apr 2026,02 Apr 2026,TO TRANSFER-UPI/DR/510123456789/RAMESH KUMAR/SBIN/q1@ybl/Sent-,TRANSFER TO 4897691234567,120.00,,"45,880.00"
04 Apr 2026,04 Apr 2026,BY TRANSFER-NEFT*ACME CORP*SALARY,TRANSFER FROM 4897,, "85,000.00","1,30,880.00"
''';

const kotakStyleCsv = '''
Sl. No.,Transaction Date,Description,Chq / Ref No.,Amount,Dr / Cr,Balance
1,05-04-2026,UPI/ZOMATO/505123/pay,UPI-505123,349.50,DR,"22,650.50"
2,06-04-2026,IMPS-RENT REFUND-LANDLORD,IMPS-1234,"2,000.00",CR,"24,650.50"
''';

const signedAmountCsv = '''
Date,Description,Amount
01/05/2026,Coffee shop,-180.00
02/05/2026,Salary credit,50000.00
''';

const signlessAmountCsv = '''
Date,Description,Amount
01/05/2026,Lunch,250.00
02/05/2026,Auto fare,80.00
''';

void main() {
  group('detectHeader + guessMapping', () {
    test('finds the HDFC header under preamble junk', () {
      final grid = CsvReader.parse(hdfcCsv);
      final detected = StatementImportService.detectHeader(grid);
      expect(detected, isNotNull);
      final roles = detected!.mapping.roles;
      expect(grid[detected.rowIndex].first, 'Date');
      expect(roles.containsValue(StatementColumnRole.date), isTrue);
      expect(roles.containsValue(StatementColumnRole.description), isTrue);
      expect(roles.containsValue(StatementColumnRole.debit), isTrue);
      expect(roles.containsValue(StatementColumnRole.credit), isTrue);
      expect(roles.containsValue(StatementColumnRole.refNo), isTrue);
      expect(roles.containsValue(StatementColumnRole.balance), isTrue);
      // "Date" (leftmost) wins the date role; "Value Dt" must not steal it.
      expect(detected.mapping.columnFor(StatementColumnRole.date), 0);
    });

    test('maps bare DR/CR headers (Axis style)', () {
      final mapping = StatementImportService.guessMapping(
        ['Tran Date', 'PARTICULARS', 'DR', 'CR', 'BAL'],
      );
      expect(mapping.columnFor(StatementColumnRole.date), 0);
      expect(mapping.columnFor(StatementColumnRole.description), 1);
      expect(mapping.columnFor(StatementColumnRole.debit), 2);
      expect(mapping.columnFor(StatementColumnRole.credit), 3);
      expect(mapping.columnFor(StatementColumnRole.balance), 4);
    });

    test('returns null when no table exists', () {
      final grid = CsvReader.parse('hello\nthis is prose\nnot,a,statement');
      expect(StatementImportService.detectHeader(grid), isNull);
    });
  });

  group('parseAmount', () {
    test('parses lakh grouping, symbols and markers', () {
      expect(StatementImportService.parseAmount('1,23,456.78'), 123456.78);
      expect(StatementImportService.parseAmount('₹ 5,000'), 5000);
      expect(StatementImportService.parseAmount('INR 250.50'), 250.50);
      expect(StatementImportService.parseAmount('Rs. 99'), 99);
      expect(StatementImportService.parseAmount('1,499.00 Dr'), 1499.00);
    });

    test('parses negatives in every dialect', () {
      expect(StatementImportService.parseAmount('(500.00)'), -500.00);
      expect(StatementImportService.parseAmount('500.00-'), -500.00);
      expect(StatementImportService.parseAmount('-42'), -42);
    });

    test('rejects blanks and non-numbers', () {
      expect(StatementImportService.parseAmount(''), isNull);
      expect(StatementImportService.parseAmount('-'), isNull);
      expect(StatementImportService.parseAmount('N/A'), isNull);
    });
  });

  group('date handling', () {
    test('infers dd/MM/yy and windows two-digit years', () {
      final format = StatementImportService.inferDateFormat(
        ['01/04/26', '03/04/26', '05/04/26'],
      );
      expect(format, isNotNull);
      final d = StatementImportService.tryParseDate('01/04/26', format!);
      expect(d, DateTime(2026, 4, 1));
    });

    test('prefers dd/MM over MM/dd for ambiguous dates', () {
      final format =
          StatementImportService.inferDateFormat(['05/04/2026', '06/04/2026']);
      final d = StatementImportService.tryParseDate('05/04/2026', format!);
      expect(d, DateTime(2026, 4, 5));
    });

    test('disambiguates via values that exceed 12', () {
      final format =
          StatementImportService.inferDateFormat(['13/04/2026', '01/04/2026']);
      expect(
        StatementImportService.tryParseDate('13/04/2026', format!),
        DateTime(2026, 4, 13),
      );
    });

    test('parses month-name and ISO dates, tolerates a time suffix', () {
      expect(
        StatementImportService.tryParseDate('02 Apr 2026', 'dd MMM yyyy'),
        DateTime(2026, 4, 2),
      );
      expect(
        StatementImportService.tryParseDate('2026-04-02', 'yyyy-MM-dd'),
        DateTime(2026, 4, 2),
      );
      expect(
        StatementImportService.tryParseDate('01/04/2026 14:23', 'dd/MM/yyyy'),
        DateTime(2026, 4, 1),
      );
    });
  });

  group('parseRows', () {
    test('parses the HDFC fixture: types, amounts, dates, footer skipped', () {
      final grid = CsvReader.parse(hdfcCsv);
      final detected = StatementImportService.detectHeader(grid)!;
      final parsed = StatementImportService.parseRows(
        grid,
        detected.rowIndex,
        detected.mapping,
      );

      final importable = parsed.rows.where((r) => r.isImportable).toList();
      expect(importable, hasLength(3));

      expect(importable[0].type, TransactionType.debit);
      expect(importable[0].amount, 449.00);
      expect(importable[0].date, DateTime(2026, 4, 1));
      expect(importable[0].merchant, 'Swiggy Limited');
      expect(importable[0].autoCategory, 'Food & Dining');

      expect(importable[1].amount, 5000.00);
      expect(importable[1].merchant, 'Ramesh Kumar');

      expect(importable[2].type, TransactionType.credit);
      expect(importable[2].amount, 85000.00);

      // The closing-balance column must never leak into any amount.
      expect(
        importable.map((r) => r.amount),
        isNot(contains(123551.00)),
      );
    });

    test('parses the SBI fixture with month-name dates', () {
      final grid = CsvReader.parse(sbiCsv);
      final detected = StatementImportService.detectHeader(grid)!;
      final parsed = StatementImportService.parseRows(
        grid,
        detected.rowIndex,
        detected.mapping,
      );
      final rows = parsed.rows.where((r) => r.isImportable).toList();
      expect(rows, hasLength(2));
      expect(rows[0].date, DateTime(2026, 4, 2));
      expect(rows[0].type, TransactionType.debit);
      expect(rows[0].merchant, 'Ramesh Kumar');
      expect(rows[1].type, TransactionType.credit);
      expect(rows[1].amount, 85000.00);
    });

    test('resolves a single Amount column via the Dr/Cr marker', () {
      final grid = CsvReader.parse(kotakStyleCsv);
      final detected = StatementImportService.detectHeader(grid)!;
      final rows = StatementImportService.parseRows(
        grid,
        detected.rowIndex,
        detected.mapping,
      ).rows.where((r) => r.isImportable).toList();
      expect(rows[0].type, TransactionType.debit);
      expect(rows[0].amount, 349.50);
      expect(rows[1].type, TransactionType.credit);
      expect(rows[1].amount, 2000.00);
    });

    test('signed single-amount file: negatives debit, positives credit', () {
      final grid = CsvReader.parse(signedAmountCsv);
      final detected = StatementImportService.detectHeader(grid)!;
      final rows = StatementImportService.parseRows(
        grid,
        detected.rowIndex,
        detected.mapping,
      ).rows.where((r) => r.isImportable).toList();
      expect(rows[0].type, TransactionType.debit);
      expect(rows[0].amount, 180.00);
      expect(rows[1].type, TransactionType.credit);
    });

    test('signless single-amount file reads as a spend list', () {
      final grid = CsvReader.parse(signlessAmountCsv);
      final detected = StatementImportService.detectHeader(grid)!;
      final rows = StatementImportService.parseRows(
        grid,
        detected.rowIndex,
        detected.mapping,
      ).rows.where((r) => r.isImportable).toList();
      expect(rows.map((r) => r.type), everyElement(TransactionType.debit));
    });

    test('rows with no readable date surface as invalid, not dropped', () {
      final grid = CsvReader.parse(
        'Date,Description,Amount\ngarbage,Something,500\n01/05/2026,Fine,100',
      );
      final detected = StatementImportService.detectHeader(grid)!;
      final parsed = StatementImportService.parseRows(
        grid,
        detected.rowIndex,
        detected.mapping,
      );
      expect(parsed.invalid, hasLength(1));
      expect(parsed.invalid.first.invalidReason, 'date');
      expect(parsed.rows.where((r) => r.isImportable), hasLength(1));
    });
  });

  group('merchantFromNarration', () {
    test('extracts payees from bank narration dialects', () {
      expect(
        StatementImportService.merchantFromNarration(
          'UPI-SWIGGY LIMITED-swiggy@axis-UTIB0000248-1041234567-Payment',
        ),
        'Swiggy Limited',
      );
      expect(
        StatementImportService.merchantFromNarration(
          'TO TRANSFER-UPI/DR/510123456789/RAMESH KUMAR/SBIN/q1@ybl/Sent-',
        ),
        'Ramesh Kumar',
      );
      expect(
        StatementImportService.merchantFromNarration(
          'POS 416021XXXXXX1234 AMAZON RETAIL',
        ),
        'Amazon Retail',
      );
      expect(
        StatementImportService.merchantFromNarration(
          'NEFT-CITIN26123456-ACME CORP-SALARY APR',
        ),
        'Acme Corp',
      );
    });

    test('returns null when nothing looks like a name', () {
      expect(
        StatementImportService.merchantFromNarration('ATW-512345-XX1234'),
        isNull,
      );
      expect(StatementImportService.merchantFromNarration(''), isNull);
    });
  });

  group('markDuplicates', () {
    StatementRow row(DateTime date, double amount, TransactionType type) =>
        StatementRow(
          sourceRow: 0,
          date: date,
          narration: 'x',
          amount: amount,
          type: type,
        );

    test('flags same type+amount within ±1 day and unticks it', () {
      final rows = [row(DateTime(2026, 4, 2), 449.0, TransactionType.debit)];
      StatementImportService.markDuplicates(rows, [
        ExistingTxnKey(
          type: TransactionType.debit,
          amountPaise: 44900,
          date: DateTime(2026, 4, 1, 18, 30),
        ),
      ]);
      expect(rows.single.status, StatementRowStatus.probableDuplicate);
      expect(rows.single.include, isFalse);
    });

    test('leaves different amounts, types and far dates alone', () {
      final rows = [
        row(DateTime(2026, 4, 2), 449.0, TransactionType.debit),
        row(DateTime(2026, 4, 2), 449.0, TransactionType.credit),
        row(DateTime(2026, 4, 10), 449.0, TransactionType.debit),
      ];
      StatementImportService.markDuplicates(rows, [
        ExistingTxnKey(
          type: TransactionType.debit,
          amountPaise: 45000,
          date: DateTime(2026, 4, 2),
        ),
        ExistingTxnKey(
          type: TransactionType.debit,
          amountPaise: 44900,
          date: DateTime(2026, 4, 20),
        ),
      ]);
      expect(
        rows.map((r) => r.status),
        everyElement(StatementRowStatus.ready),
      );
    });
  });

  group('decode + provenance', () {
    test('recognises PDF and legacy-XLS magic bytes', () {
      expect(
        () => StatementImportService.decodeBytes(
          Uint8List.fromList(utf8.encode('%PDF-1.7 whatever')),
        ),
        throwsA(
          isA<StatementFileException>()
              .having((e) => e.kind, 'kind', StatementFileKind.pdf),
        ),
      );
      expect(
        () => StatementImportService.decodeBytes(
          Uint8List.fromList(
            [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1],
          ),
        ),
        throwsA(
          isA<StatementFileException>()
              .having((e) => e.kind, 'kind', StatementFileKind.legacyXls),
        ),
      );
    });

    test('decodes plain text bytes as CSV', () {
      final grid = StatementImportService.decodeBytes(
        Uint8List.fromList(utf8.encode('Date,Amount\n01/05/2026,100')),
      );
      expect(grid, hasLength(2));
    });

    test('senderFor builds a stable IMPORT- sender', () {
      expect(
        StatementImportService.senderFor('HDFC Savings'),
        'IMPORT-HDFC SAVINGS',
      );
      expect(StatementImportService.senderFor('  '), 'IMPORT-STATEMENT');
      expect(
        StatementImportService.senderFor('Kotak (Salary) a/c'),
        'IMPORT-KOTAK SALARY AC',
      );
    });

    test('same statement line fingerprints identically across imports', () {
      TransactionModel build() => TransactionModel(
            amount: 449.0,
            type: TransactionType.debit,
            sender: StatementImportService.senderFor('HDFC'),
            message: 'UPI-SWIGGY-... (Ref 104123)',
            detectedAt: DateTime(2026, 4, 1),
            isManual: false,
          ).withFingerprint();
      expect(build().fingerprint, build().fingerprint);

      final differentRef = TransactionModel(
        amount: 449.0,
        type: TransactionType.debit,
        sender: StatementImportService.senderFor('HDFC'),
        message: 'UPI-SWIGGY-... (Ref 104999)',
        detectedAt: DateTime(2026, 4, 1),
        isManual: false,
      ).withFingerprint();
      expect(build().fingerprint, isNot(differentRef.fingerprint));
    });
  });

  group('mapping templates', () {
    test('headerSignature is stable across cosmetic differences', () {
      expect(
        StatementImportService.headerSignature(
          ['Date', 'Narration', 'Withdrawal Amt.'],
        ),
        StatementImportService.headerSignature(
          ['date', 'NARRATION', 'Withdrawal  Amt'],
        ),
      );
    });
  });
}
