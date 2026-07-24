import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/tax_export.dart';
import 'package:budget_tracker/services/export_service.dart';

TaxSummaryInput _input({bool tagged = true}) => TaxSummaryInput(
      fyLabel: 'FY 2025-26',
      sections: [
        TaxSummarySection(
          id: '80C',
          section: 'Section 80C',
          shortLabel: 'Investments & insurance',
          isCapped: true,
          total: tagged ? 90000 : 0,
          cap: 150000,
          entries: tagged
              ? [
                  TaxSummaryEntry(
                      date: DateTime(2025, 6, 1),
                      payee: 'LIC of India',
                      amount: 90000),
                ]
              : const [],
        ),
        TaxSummarySection(
          id: 'HRA',
          section: 'HRA / 80GG',
          shortLabel: 'Rent paid',
          isCapped: false,
          total: tagged ? 240000 : 0,
          cap: null,
          entries: tagged
              ? [
                  TaxSummaryEntry(
                      date: DateTime(2025, 5, 5),
                      payee: 'Landlord',
                      amount: 20000),
                ]
              : const [],
        ),
      ],
    );

void main() {
  final svc = ExportService();

  group('TaxSummaryInput', () {
    test('hasAnyEntries reflects whether anything is tagged', () {
      expect(_input().hasAnyEntries, isTrue);
      expect(_input(tagged: false).hasAnyEntries, isFalse);
    });

    test('fileSlug is filename-safe', () {
      expect(_input().fileSlug, '2025_26');
    });
  });

  group('buildTaxSummary', () {
    test('refuses PDF/Excel when nothing is tagged (returns null)', () async {
      final input = _input(tagged: false);
      expect(
        await svc.buildTaxSummary(format: ExportFormat.pdf, input: input),
        isNull,
      );
      expect(
        await svc.buildTaxSummary(format: ExportFormat.excel, input: input),
        isNull,
      );
    });

    test('PDF is produced with the FY in the filename', () async {
      final bundle =
          await svc.buildTaxSummary(format: ExportFormat.pdf, input: _input());
      expect(bundle, isNotNull);
      expect(bundle!.filename, endsWith('.pdf'));
      expect(bundle.filename, contains('2025_26'));
      // %PDF- magic header — proves a real PDF, not empty bytes.
      expect(String.fromCharCodes(bundle.bytes.take(5)), '%PDF-');
    });

    test('Excel is produced as a real .xlsx (PK zip header)', () async {
      final bundle = await svc.buildTaxSummary(
          format: ExportFormat.excel, input: _input());
      expect(bundle, isNotNull);
      expect(bundle!.filename, endsWith('.xlsx'));
      expect(bundle.bytes.length, greaterThan(0));
      expect(bundle.bytes[0], 0x50); // 'P'
      expect(bundle.bytes[1], 0x4B); // 'K'
    });

    test('CSV and text are rejected — filing formats only', () async {
      expect(
        () => svc.buildTaxSummary(format: ExportFormat.csv, input: _input()),
        throwsArgumentError,
      );
      expect(
        () => svc.buildTaxSummary(format: ExportFormat.text, input: _input()),
        throwsArgumentError,
      );
    });

    test('disclaimer text is present and names the evidence caveat', () {
      expect(ExportService.taxExportDisclaimer, contains('not tax advice'));
      expect(ExportService.taxExportDisclaimer, contains('HRA'));
    });
  });

  group('renderers do not throw on realistic input', () {
    test('PDF renders both capped and evidence-only sections', () async {
      final bytes = await svc.buildTaxPdfForTest(_input());
      expect(bytes, isNotEmpty);
    });

    test('Excel renders both section kinds', () {
      final bytes = svc.buildTaxWorkbookForTest(_input());
      expect(bytes, isNotEmpty);
    });
  });
}
