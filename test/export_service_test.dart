import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/export_service.dart';

void main() {
  final txns = [
    TransactionModel(
      amount: 1234.56,
      type: TransactionType.debit,
      sender: 'BV-SBIUPI-S',
      message: 'debited by 1234.56',
      detectedAt: DateTime(2026, 6, 1, 10, 30),
      category: 'Food & Dining',
      merchantName: 'Swiggy',
      accountInfo: 'XX4321',
    ),
    TransactionModel(
      amount: 50000,
      type: TransactionType.credit,
      sender: 'JD-MAHABK',
      message: 'credited by 50000',
      detectedAt: DateTime(2026, 5, 28, 9, 0),
      category: 'Salary',
      merchantName: 'ACME CORP',
    ),
  ];

  final service = ExportService();

  group('Excel export', () {
    test('produces a real .xlsx (ZIP) not CSV text', () {
      final bytes = service.buildWorkbookForTest(txns);
      // .xlsx is a ZIP archive — must start with the PK local-file header.
      expect(bytes.length, greaterThan(100));
      expect(bytes[0], 0x50); // 'P'
      expect(bytes[1], 0x4B); // 'K'
    });
  });

  group('CSV export', () {
    test('starts with UTF-8 BOM and a single clean header row', () {
      final bytes = service.buildCsvForTest(txns);
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final text = String.fromCharCodes(bytes.sublist(3));
      final firstLine = text.split('\n').first.trim();
      expect(firstLine,
          'Month,Date,Time,Type,Amount,Category,Merchant,Account,Bank,Notes');
      // No decorative separator rows inside the table
      expect(text.contains('---'), isFalse);
    });
  });

  group('PDF export', () {
    test('produces a real PDF (starts with the %PDF header)', () async {
      final bytes = await service.buildPdfForTest(txns);
      expect(bytes.length, greaterThan(100));
      // PDF magic number: "%PDF"
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });
  });

  group('ExportFilter', () {
    test('filters by type', () {
      const f = ExportFilter(types: {TransactionType.credit});
      expect(txns.where(f.matches).length, 1);
    });

    test('filters by category', () {
      const f = ExportFilter(categories: {'Food & Dining'});
      expect(txns.where(f.matches).single.merchantName, 'Swiggy');
    });

    test('filters by merchant query (case-insensitive)', () {
      const f = ExportFilter(merchantQuery: 'swig');
      expect(txns.where(f.matches).single.amount, 1234.56);
    });

    test('filters by date range', () {
      final f = ExportFilter(
        dateRange: DateTimeRange(
          start: DateTime(2026, 5, 1),
          end: DateTime(2026, 5, 31),
        ),
      );
      expect(txns.where(f.matches).single.category, 'Salary');
    });

    test('unfiltered matches everything', () {
      const f = ExportFilter();
      expect(f.isUnfiltered, isTrue);
      expect(txns.where(f.matches).length, 2);
    });
  });
}
