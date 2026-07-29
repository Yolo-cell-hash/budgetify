import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import '../app_info.dart';
import '../models/bank_summary.dart';
import '../models/tax_export.dart';
import '../models/transaction_model.dart';
import '../widgets/brand_logo.dart';
import 'bank_directory.dart';
import 'database_service.dart';

/// Output formats for an export.
enum ExportFormat { excel, csv, text, pdf }

/// User-chosen filters applied before an export. Empty/null fields mean
/// "no restriction on this dimension".
class ExportFilter {
  final DateTimeRange? dateRange;
  final Set<TransactionType> types; // empty = both credit and debit
  final Set<String> categories; // empty = all; 'Uncategorized' matches null
  final String merchantQuery; // case-insensitive substring on merchant/sender

  /// [BankIdentity.id]s to keep; empty = every bank. Lets a user with three
  /// accounts export just the one they care about.
  final Set<String> banks;

  const ExportFilter({
    this.dateRange,
    this.types = const {},
    this.categories = const {},
    this.merchantQuery = '',
    this.banks = const {},
  });

  bool get isUnfiltered =>
      dateRange == null &&
      types.isEmpty &&
      categories.isEmpty &&
      banks.isEmpty &&
      merchantQuery.trim().isEmpty;

  bool matches(TransactionModel t) {
    if (types.isNotEmpty && !types.contains(t.type)) return false;

    if (banks.isNotEmpty && !banks.contains(BankDirectory.resolve(t).id)) {
      return false;
    }

    if (dateRange != null) {
      final d = t.detectedAt;
      final start = DateTime(
        dateRange!.start.year,
        dateRange!.start.month,
        dateRange!.start.day,
      );
      final end = DateTime(
        dateRange!.end.year,
        dateRange!.end.month,
        dateRange!.end.day,
        23,
        59,
        59,
      );
      if (d.isBefore(start) || d.isAfter(end)) return false;
    }

    if (categories.isNotEmpty) {
      final cat = t.category ?? 'Uncategorized';
      if (!categories.contains(cat)) return false;
    }

    final q = merchantQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = '${t.merchantName ?? ''} ${t.sender}'.toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }
}

/// Period totals on the app's definition of money.
///
/// Self-transfers, investments and settlements are real transactions but
/// neither spending nor income (see [ExpenseCategories.nonExpense]), so they
/// are held in [moved] rather than silently inflating [expenses] — which is
/// what every other screen in the app already does. Debits use the split
/// share when there is one; credits are never split.
class _PeriodTotals {
  final double income;
  final double expenses;
  final double moved;

  /// Expense categories only, ranked by the caller.
  final Map<String, double> byCategory;

  const _PeriodTotals(
      this.income, this.expenses, this.moved, this.byCategory);

  factory _PeriodTotals.of(List<TransactionModel> txns) {
    double income = 0, expenses = 0, moved = 0;
    final byCategory = <String, double>{};
    for (final t in txns) {
      if (t.type == TransactionType.credit) {
        if (ExpenseCategories.isIncomeCategory(t.category)) {
          income += t.amount;
        } else {
          moved += t.amount;
        }
      } else if (ExpenseCategories.isExpenseCategory(t.category)) {
        expenses += t.effectiveAmount;
        final c = t.category ?? 'Uncategorized';
        byCategory[c] = (byCategory[c] ?? 0) + t.effectiveAmount;
      } else {
        moved += t.effectiveAmount;
      }
    }
    return _PeriodTotals(income, expenses, moved, byCategory);
  }
}

/// A ready-to-save export: the file [bytes] and a suggested [filename].
/// The caller decides where it lands (typically the system file picker), so
/// the app needs no broad storage permission to produce one.
class ExportBundle {
  final List<int> bytes;
  final String filename;
  const ExportBundle(this.bytes, this.filename);
}

/// Service for exporting transaction data to Excel (.xlsx), CSV, TXT, and PDF.
///
/// Excel output is a genuine .xlsx workbook (not CSV-with-an-xls-name, which
/// some Excel installs reject as corrupt) with a styled header, numeric
/// amount/date cells, and a summary sheet. PDF is a paginated report with a
/// summary block and per-month transaction tables, generated on device with
/// no platform channels.
class ExportService {
  final DatabaseService _db = DatabaseService();

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('HH:mm');
  static final _dayFmt = DateFormat('dd MMM');
  static final _monthYearFmt = DateFormat('MMMM yyyy');
  static final _fileDateFmt = DateFormat('yyyyMMdd_HHmm');
  static final _currencyFmt = NumberFormat('#,##0.00', 'en_IN');

  /// Carried on every bank breakdown, so a reader never has to guess why a
  /// bank's Spent is smaller than the money that passed through it.
  // Middot, not em-dash: the built-in Helvetica the PDF uses has no em-dash
  // glyph and renders it as a tofu box.
  static const String bankMovedNote =
      'Spent and Received count real spending and income only. "Moved" is '
      'self-transfers, investments and settlements · your money changing '
      'place, not leaving.';

  static const int _reportWidth = 64;
  static const List<String> _columns = [
    'Month', 'Date', 'Time', 'Type', 'Amount',
    'Category', 'Merchant', 'Account', 'Bank', 'Notes',
  ];

  // ── Public API ──────────────────────────────────────────────────────

  /// Build an export in [format] honoring [filter]. Returns the file bytes and
  /// a suggested filename, or null when the filter matched no transactions.
  /// The caller saves or shares the bytes (e.g. through the system file
  /// picker), so no storage permission is required.
  Future<ExportBundle?> buildExport({
    required ExportFormat format,
    ExportFilter filter = const ExportFilter(),
  }) async {
    final all = await _db.getAllTransactions();
    final txns = all.where(filter.matches).toList();
    if (txns.isEmpty) return null;

    final base = 'budgetify_export_${_fileDateFmt.format(DateTime.now())}';
    switch (format) {
      case ExportFormat.excel:
        return ExportBundle(_buildWorkbook(txns), '$base.xlsx');
      case ExportFormat.csv:
        return ExportBundle(_buildCsvBytes(txns), '$base.csv');
      case ExportFormat.text:
        return ExportBundle(utf8.encode(_buildTxt(txns)), '$base.txt');
      case ExportFormat.pdf:
        return ExportBundle(await _buildPdfBytes(txns), '$base.pdf');
    }
  }

  /// Every bank the stored transactions came from, ranked by spend. Feeds
  /// the export sheet's bank chips, so a user is only ever offered banks
  /// they actually have money moving through.
  Future<BankBreakdown> usedBanks() async =>
      BankBreakdown.fromTransactions(await _db.getAllTransactions());

  // ── Tax Summary export (Phase 3) ────────────────────────────────────

  /// The standing "organiser, not tax advice" line, carried on every tax
  /// export so the document can never be mistaken for a computed return.
  static const String taxExportDisclaimer =
      'This is an organiser, not tax advice. The amounts below are only those '
      'you tagged; your CA or the tax portal decides what is actually '
      'deductible. HRA and 80G show the total you paid as evidence, not the '
      'deductible amount.';

  /// Build a filing-season Tax Summary in [format] (PDF or Excel only) from a
  /// pre-assembled [input]. Returns null when nothing is tagged for the year.
  Future<ExportBundle?> buildTaxSummary({
    required ExportFormat format,
    required TaxSummaryInput input,
  }) async {
    if (!input.hasAnyEntries) return null;
    final base = 'budgetify_tax_summary_${input.fileSlug}';
    switch (format) {
      case ExportFormat.pdf:
        return ExportBundle(await _buildTaxPdf(input), '$base.pdf');
      case ExportFormat.excel:
        return ExportBundle(_buildTaxWorkbook(input), '$base.xlsx');
      case ExportFormat.csv:
      case ExportFormat.text:
        // The tax summary is a filing document — only the two formats a CA or
        // the portal actually consume.
        throw ArgumentError('Tax summary supports PDF and Excel only');
    }
  }

  @visibleForTesting
  Future<List<int>> buildTaxPdfForTest(TaxSummaryInput input) =>
      _buildTaxPdf(input);

  @visibleForTesting
  List<int> buildTaxWorkbookForTest(TaxSummaryInput input) =>
      _buildTaxWorkbook(input);

  Future<List<int>> _buildTaxPdf(TaxSummaryInput input) async {
    const headerColor = PdfColor.fromInt(0xFF1B1E28);
    const brandGold = PdfColor.fromInt(0xFFC8A75E);

    pw.MemoryImage? logo;
    try {
      logo = pw.MemoryImage(await loadBrandLogoBytes());
    } catch (_) {
      logo = null;
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 5),
          decoration: const pw.BoxDecoration(
            border:
                pw.Border(top: pw.BorderSide(color: brandGold, width: 0.6)),
          ),
          child: pw.Row(children: [
            // Middot, not em-dash: the built-in Helvetica lacks the em-dash
            // glyph and renders it as a tofu box.
            pw.Text('Budgetify · $kAppMotto',
                style:
                    const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
            pw.Spacer(),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style:
                    const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          ]),
        ),
        build: (context) => [
          // Brand header + report title.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.ClipRRect(
                  horizontalRadius: 7.5,
                  verticalRadius: 7.5,
                  child: pw.Image(logo, width: 34, height: 34),
                ),
                pw.SizedBox(width: 10),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Budgetify',
                      style: pw.TextStyle(
                          fontSize: 19,
                          fontWeight: pw.FontWeight.bold,
                          color: headerColor)),
                  pw.SizedBox(height: 1),
                  pw.Text('Tax Deductions Summary · ${input.fyLabel}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.Spacer(),
              pw.Text('Generated: ${_dateFmt.format(DateTime.now())}',
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(height: 1.6, color: brandGold),
          pw.SizedBox(height: 12),
          // Disclaimer — first thing on the page, boxed.
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF6F1E7),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(taxExportDisclaimer,
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
          ),
          pw.SizedBox(height: 14),
          // Totals overview.
          pw.Text('Sections',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 0.5),
          for (final s in input.sections)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${s.section} · ${s.shortLabel}',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(
                    s.isCapped && s.cap != null
                        ? '${_rs(s.total)} / ${_rs(s.cap!.toDouble())}'
                        : _rs(s.total),
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 6),
          // Per-section detail tables (skip empty sections).
          for (final s in input.sections)
            if (s.hasEntries) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                s.isCapped
                    ? '${s.section} · ${s.shortLabel}'
                    : '${s.section} · ${s.shortLabel} (evidence)',
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: headerColor),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignments: const {2: pw.Alignment.centerRight},
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.6),
                  1: pw.FlexColumnWidth(3.4),
                  2: pw.FlexColumnWidth(2.0),
                },
                headers: const ['Date', 'Payee', 'Amount'],
                data: [
                  for (final e in s.entries)
                    [
                      _dateFmt.format(e.date),
                      e.payee,
                      _currencyFmt.format(e.amount),
                    ],
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Subtotal: ${_rs(s.total)}',
                      style: pw.TextStyle(
                          fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
        ],
      ),
    );
    return doc.save();
  }

  List<int> _buildTaxWorkbook(TaxSummaryInput input) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet()!;
    final sheet = excel['Tax Summary'];

    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1B1E28'),
    );
    final sectionStyle = CellStyle(bold: true, fontSize: 12);

    sheet.appendRow(<CellValue?>[
      TextCellValue('Budgetify Tax Deductions Summary · ${input.fyLabel}'),
    ]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle = titleStyle;
    sheet.appendRow(<CellValue?>[TextCellValue(taxExportDisclaimer)]);
    sheet.appendRow(<CellValue?>[]);

    for (final s in input.sections) {
      if (!s.hasEntries) continue;
      final header = s.isCapped && s.cap != null
          ? '${s.section} — ${s.shortLabel}  (${_currencyFmt.format(s.total)} of ${_currencyFmt.format(s.cap!.toDouble())})'
          : '${s.section} — ${s.shortLabel}  (evidence: ${_currencyFmt.format(s.total)})';
      final sr = sheet.maxRows;
      sheet.appendRow(<CellValue?>[TextCellValue(header)]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sr))
          .cellStyle = sectionStyle;

      final hr = sheet.maxRows;
      sheet.appendRow(<CellValue?>[
        TextCellValue('Date'),
        TextCellValue('Payee'),
        TextCellValue('Amount'),
      ]);
      for (var c = 0; c < 3; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: hr))
            .cellStyle = headerStyle;
      }
      for (final e in s.entries) {
        sheet.appendRow(<CellValue?>[
          DateTimeCellValue(
              year: e.date.year,
              month: e.date.month,
              day: e.date.day,
              hour: 0,
              minute: 0),
          TextCellValue(e.payee),
          DoubleCellValue(e.amount),
        ]);
      }
      sheet.appendRow(<CellValue?>[
        TextCellValue('Subtotal'),
        TextCellValue(''),
        DoubleCellValue(s.total),
      ]);
      sheet.appendRow(<CellValue?>[]);
    }

    sheet.setColumnWidth(0, 16.0);
    sheet.setColumnWidth(1, 30.0);
    sheet.setColumnWidth(2, 14.0);

    if (defaultSheet != 'Tax Summary') excel.delete(defaultSheet);
    excel.setDefaultSheet('Tax Summary');
    return excel.save()!;
  }

  // ── Excel (.xlsx) ───────────────────────────────────────────────────

  @visibleForTesting
  List<int> buildWorkbookForTest(List<TransactionModel> txns) =>
      _buildWorkbook(txns);

  @visibleForTesting
  List<int> buildCsvForTest(List<TransactionModel> txns) =>
      _buildCsvBytes(txns);

  @visibleForTesting
  Future<List<int>> buildPdfForTest(List<TransactionModel> txns) =>
      _buildPdfBytes(txns);

  @visibleForTesting
  String buildTxtForTest(List<TransactionModel> txns) => _buildTxt(txns);

  List<int> _buildWorkbook(List<TransactionModel> txns) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet()!;

    // ── Transactions sheet ──
    final sheet = excel['Transactions'];

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1B1E28'),
      horizontalAlign: HorizontalAlign.Center,
    );
    sheet.appendRow(_columns.map((c) => TextCellValue(c) as CellValue).toList());
    for (var c = 0; c < _columns.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = headerStyle;
    }

    final grouped = _groupByMonth(txns);
    for (final entry in grouped.entries) {
      final month = _monthYearFmt.format(entry.key);
      for (final t in entry.value) {
        sheet.appendRow(<CellValue?>[
          TextCellValue(month),
          DateTimeCellValue(
            year: t.detectedAt.year,
            month: t.detectedAt.month,
            day: t.detectedAt.day,
            hour: t.detectedAt.hour,
            minute: t.detectedAt.minute,
          ),
          TextCellValue(_timeFmt.format(t.detectedAt)),
          TextCellValue(t.type == TransactionType.credit ? 'Credit' : 'Debit'),
          // Numeric so Excel can sum/sort/filter
          DoubleCellValue(t.amount),
          TextCellValue(t.category ?? ''),
          TextCellValue(t.merchantName ?? ''),
          TextCellValue(t.accountInfo ?? ''),
          TextCellValue(BankDirectory.resolve(t).name),
          TextCellValue(t.notes ?? ''),
        ]);
      }
    }

    // Reasonable column widths
    const widths = [14.0, 13.0, 7.0, 8.0, 12.0, 16.0, 22.0, 10.0, 12.0, 24.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    // ── Summary + By Bank sheets ──
    _buildSummarySheet(excel['Summary'], txns);
    _buildBankSheet(excel['By Bank'], txns);

    // Drop the auto-created default sheet so the file opens on Transactions
    if (defaultSheet != 'Transactions' &&
        defaultSheet != 'Summary' &&
        defaultSheet != 'By Bank') {
      excel.delete(defaultSheet);
    }
    excel.setDefaultSheet('Transactions');

    return excel.save()!;
  }

  void _buildSummarySheet(Sheet sheet, List<TransactionModel> txns) {
    final totals = _PeriodTotals.of(txns);
    final income = totals.income;
    final expenses = totals.expenses;
    final byCategory = totals.byCategory;

    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final labelStyle = CellStyle(bold: true);

    void row(int r, String label, CellValue value, {CellStyle? style}) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
        ..value = TextCellValue(label)
        ..cellStyle = style ?? labelStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).value =
          value;
    }

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Budgetify Summary')
      ..cellStyle = titleStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        TextCellValue(kAppMotto);
    row(2, 'Total Transactions', IntCellValue(txns.length));
    row(3, 'Total Income', DoubleCellValue(income));
    row(4, 'Total Expenses', DoubleCellValue(expenses));
    row(5, 'Net', DoubleCellValue(income - expenses));
    if (totals.moved > 0) {
      row(6, 'Moved (not counted)', DoubleCellValue(totals.moved));
    }

    row(8, 'Expenses by Category', TextCellValue(''), style: titleStyle);
    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var r = 9;
    for (final e in sortedCats) {
      row(r++, e.key, DoubleCellValue(e.value));
    }

    sheet.setColumnWidth(0, 24.0);
    sheet.setColumnWidth(1, 16.0);
  }

  /// Spending and income per bank, month by month, then a period total.
  ///
  /// Each month lists only the banks that saw activity in it, so a month
  /// spent entirely on one card is a one-row month. "Moved" holds
  /// self-transfers, investments and settlements: real transactions that are
  /// deliberately kept out of Spent and Received.
  void _buildBankSheet(Sheet sheet, List<TransactionModel> txns) {
    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final sectionStyle = CellStyle(bold: true, fontSize: 12);
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1B1E28'),
    );
    final totalStyle = CellStyle(bold: true);

    sheet.appendRow(<CellValue?>[TextCellValue('Spending by Bank')]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle = titleStyle;
    sheet.appendRow(<CellValue?>[TextCellValue(bankMovedNote)]);
    sheet.appendRow(<CellValue?>[]);

    void bankTable(String heading, BankBreakdown breakdown) {
      if (breakdown.isEmpty) return;
      final sr = sheet.maxRows;
      sheet.appendRow(<CellValue?>[TextCellValue(heading)]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sr))
          .cellStyle = sectionStyle;

      final hr = sheet.maxRows;
      sheet.appendRow(<CellValue?>[
        TextCellValue('Bank'),
        TextCellValue('Spent'),
        TextCellValue('Received'),
        TextCellValue('Moved'),
        TextCellValue('Transactions'),
        TextCellValue('% of spend'),
      ]);
      for (var c = 0; c < 6; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: hr))
            .cellStyle = headerStyle;
      }
      for (final b in breakdown.banks) {
        sheet.appendRow(<CellValue?>[
          TextCellValue(b.name),
          DoubleCellValue(b.spent),
          DoubleCellValue(b.received),
          DoubleCellValue(b.moved),
          IntCellValue(b.transactionCount),
          DoubleCellValue(
              double.parse((breakdown.share(b) * 100).toStringAsFixed(1))),
        ]);
      }
      final tr = sheet.maxRows;
      sheet.appendRow(<CellValue?>[
        TextCellValue('Total'),
        DoubleCellValue(breakdown.totalSpent),
        DoubleCellValue(breakdown.totalReceived),
        DoubleCellValue(breakdown.totalMoved),
        IntCellValue(breakdown.transactionCount),
        TextCellValue(''),
      ]);
      for (var c = 0; c < 6; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: tr))
            .cellStyle = totalStyle;
      }
      sheet.appendRow(<CellValue?>[]);
    }

    bankTable('All months', BankBreakdown.fromTransactions(txns));
    for (final entry in _groupByMonth(txns).entries) {
      bankTable(_monthYearFmt.format(entry.key),
          BankBreakdown.fromTransactions(entry.value));
    }

    sheet.setColumnWidth(0, 30.0);
    for (var c = 1; c < 6; c++) {
      sheet.setColumnWidth(c, 14.0);
    }
  }

  // ── PDF ─────────────────────────────────────────────────────────────

  /// A paginated report: a summary block (totals + expenses by category)
  /// followed by a per-month transaction table. Uses the built-in Helvetica
  /// font (ASCII), so amounts are prefixed "Rs." rather than the ₹ glyph.
  Future<List<int>> _buildPdfBytes(List<TransactionModel> txns) async {
    final totals = _PeriodTotals.of(txns);
    final income = totals.income;
    final expenses = totals.expenses;
    final sortedCats = totals.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final banks = BankBreakdown.fromTransactions(txns);

    const headerColor = PdfColor.fromInt(0xFF1B1E28);
    const brandGold = PdfColor.fromInt(0xFFC8A75E);

    // The bundled brand logo (the real artwork, not a redrawn mark). Guarded
    // so a load hiccup degrades the header to text-only rather than failing
    // the whole export.
    pw.MemoryImage? logo;
    try {
      logo = pw.MemoryImage(await loadBrandLogoBytes());
    } catch (_) {
      logo = null;
    }

    pw.Widget summaryRow(String label, String value, {bool bold = false}) {
      final style = pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text(label, style: style), pw.Text(value, style: style)],
        ),
      );
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        // Brand footer on every page: motto on the left, page number right.
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 5),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: brandGold, width: 0.6),
            ),
          ),
          child: pw.Row(
            children: [
              // Middot, not em-dash — Helvetica has no em-dash glyph and
              // renders a tofu box, as the tax PDF footer already accounts for.
              pw.Text('Budgetify · $kAppMotto',
                  style:
                      const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              pw.Spacer(),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                  style:
                      const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (context) => [
          // Brand header: mark + wordmark + motto, generated date on the right.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.ClipRRect(
                  horizontalRadius: 7.5,
                  verticalRadius: 7.5,
                  child: pw.Image(logo, width: 34, height: 34),
                ),
                pw.SizedBox(width: 10),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Budgetify',
                      style: pw.TextStyle(
                          fontSize: 19,
                          fontWeight: pw.FontWeight.bold,
                          color: headerColor)),
                  pw.SizedBox(height: 1),
                  pw.Text(kAppMotto,
                      style: const pw.TextStyle(
                          fontSize: 8.5, color: PdfColors.grey700)),
                ],
              ),
              pw.Spacer(),
              pw.Text('Generated: ${_dateFmt.format(DateTime.now())}',
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(height: 1.6, color: brandGold),
          pw.SizedBox(height: 14),
          pw.Text('Summary',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 0.5),
          summaryRow('Total Transactions', '${txns.length}'),
          summaryRow('Total Income', _rs(income)),
          summaryRow('Total Expenses', _rs(expenses)),
          summaryRow('Net', _rs(income - expenses), bold: true),
          if (totals.moved > 0)
            summaryRow('Moved (not counted)', _rs(totals.moved)),
          if (sortedCats.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Expenses by Category',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 0.5),
            for (final e in sortedCats) summaryRow(e.key, _rs(e.value)),
          ],
          if (banks.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('By Bank',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: headerColor),
              headerAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: const {
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              columnWidths: const {
                0: pw.FlexColumnWidth(3.4),
                1: pw.FlexColumnWidth(2.0),
                2: pw.FlexColumnWidth(2.0),
                3: pw.FlexColumnWidth(2.0),
                4: pw.FlexColumnWidth(1.4),
              },
              headers: const ['Bank', 'Spent', 'Received', 'Moved', 'Txns'],
              data: [
                for (final b in banks.banks)
                  [
                    b.name,
                    _currencyFmt.format(b.spent),
                    _currencyFmt.format(b.received),
                    _currencyFmt.format(b.moved),
                    '${b.transactionCount}',
                  ],
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(bankMovedNote,
                style:
                    const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          ],
          pw.SizedBox(height: 18),
          for (final entry in _groupByMonth(txns).entries) ...[
            pw.SizedBox(height: 10),
            pw.Text(_monthYearFmt.format(entry.key),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: headerColor),
              headerAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: const {4: pw.Alignment.centerRight},
              columnWidths: const {
                0: pw.FlexColumnWidth(2.2),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(2.4),
                3: pw.FlexColumnWidth(3.0),
                4: pw.FlexColumnWidth(2.0),
              },
              headers: const ['Date', 'Type', 'Category', 'Merchant', 'Amount'],
              data: [
                for (final t in entry.value)
                  [
                    _dateFmt.format(t.detectedAt),
                    t.type == TransactionType.credit ? 'Credit' : 'Debit',
                    t.category ?? '',
                    t.merchantName ?? BankDirectory.resolve(t).name,
                    _currencyFmt.format(t.amount),
                  ],
              ],
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ── CSV ─────────────────────────────────────────────────────────────

  List<int> _buildCsvBytes(List<TransactionModel> txns) {
    final buffer = StringBuffer()..writeln(_columns.join(','));
    final grouped = _groupByMonth(txns);
    for (final entry in grouped.entries) {
      final month = _monthYearFmt.format(entry.key);
      for (final t in entry.value) {
        buffer.writeln(_csvRow(month, t));
      }
    }
    // UTF-8 BOM so Excel decodes as UTF-8 (ANSI default mangled non-ASCII)
    return [0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())];
  }

  String _csvRow(String month, TransactionModel t) {
    final fields = [
      month,
      _dateFmt.format(t.detectedAt),
      _timeFmt.format(t.detectedAt),
      t.type == TransactionType.credit ? 'Credit' : 'Debit',
      t.amount.toStringAsFixed(2),
      t.category ?? '',
      t.merchantName ?? '',
      t.accountInfo ?? '',
      BankDirectory.resolve(t).name,
      t.notes ?? '',
    ];
    return fields.map(_escapeCsv).join(',');
  }

  String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── Text report ─────────────────────────────────────────────────────

  String _buildTxt(List<TransactionModel> txns) {
    final buffer = StringBuffer();
    buffer.writeln('=' * _reportWidth);
    buffer.writeln('  BUDGETIFY EXPORT');
    buffer.writeln('  $kAppMotto');
    buffer.writeln('  Generated: ${_dateFmt.format(DateTime.now())}');
    buffer.writeln('=' * _reportWidth);
    buffer.writeln();

    final totals = _PeriodTotals.of(txns);

    buffer.writeln('SUMMARY');
    buffer.writeln('-' * _reportWidth);
    buffer.writeln(_summaryLine('Total Transactions', '${txns.length}'));
    buffer.writeln(_summaryLine('Total Income', _rs(totals.income)));
    buffer.writeln(_summaryLine('Total Expenses', _rs(totals.expenses)));
    buffer.writeln(
        _summaryLine('Net', _rs(totals.income - totals.expenses)));
    if (totals.moved > 0) {
      buffer.writeln(_summaryLine('Moved (not counted)', _rs(totals.moved)));
    }
    buffer.writeln();

    _writeBankBlock(buffer, 'BY BANK', BankBreakdown.fromTransactions(txns));

    final grouped = _groupByMonth(txns);
    for (final entry in grouped.entries) {
      buffer.writeln(_monthYearFmt.format(entry.key).toUpperCase());
      buffer.writeln('-' * _reportWidth);

      // Only the banks this month actually saw — a one-card month reads as
      // one line, and a dormant account waking up is visible on sight.
      _writeBankBlock(
        buffer,
        'BANKS USED',
        BankBreakdown.fromTransactions(entry.value),
        indent: 2,
      );

      // Self-transfers, investments and settlements are listed, but under
      // their own heading — they are not spending and must not inflate the
      // month's expense total.
      final expenses = <TransactionModel>[];
      final moved = <TransactionModel>[];
      final income = <TransactionModel>[];
      for (final t in entry.value) {
        if (t.type == TransactionType.debit) {
          (ExpenseCategories.isExpenseCategory(t.category) ? expenses : moved)
              .add(t);
        } else {
          (ExpenseCategories.isIncomeCategory(t.category) ? income : moved)
              .add(t);
        }
      }

      if (expenses.isNotEmpty) {
        _writeCategoryBlock(buffer, 'EXPENSES BY CATEGORY', expenses,
            totalLabel: 'TOTAL EXPENSES');
      }

      if (income.isNotEmpty) {
        buffer.writeln('INCOME');
        double monthIncome = 0;
        for (final t in income) {
          monthIncome += t.amount;
          buffer.writeln(_row(
            '${_dayFmt.format(t.detectedAt)}  ${t.merchantName ?? t.sender}',
            _currencyFmt.format(t.amount),
            indent: 2,
          ));
        }
        buffer.writeln(_row('TOTAL INCOME', _rs(monthIncome), indent: 2));
        buffer.writeln();
      }

      if (moved.isNotEmpty) {
        _writeCategoryBlock(buffer, 'MOVED, NOT COUNTED', moved,
            totalLabel: 'TOTAL MOVED');
      }
    }
    return buffer.toString();
  }

  /// A category-grouped listing with a total line: each category ranked by
  /// size, every transaction under it, then [totalLabel].
  void _writeCategoryBlock(
    StringBuffer buffer,
    String heading,
    List<TransactionModel> txns, {
    required String totalLabel,
  }) {
    buffer.writeln(heading);
    final byCategory = <String, List<TransactionModel>>{};
    for (final t in txns) {
      byCategory.putIfAbsent(t.category ?? 'Uncategorized', () => []).add(t);
    }
    double blockTotal(List<TransactionModel> list) =>
        list.fold<double>(0, (s, t) => s + t.effectiveAmount);
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => blockTotal(b.value).compareTo(blockTotal(a.value)));
    double total = 0;
    for (final cat in sorted) {
      final catTotal = blockTotal(cat.value);
      total += catTotal;
      buffer.writeln(_row(cat.key, _rs(catTotal), indent: 2));
      for (final t in cat.value) {
        buffer.writeln(_row(
          '${_dayFmt.format(t.detectedAt)}  ${t.merchantName ?? t.sender}',
          _currencyFmt.format(t.amount),
          indent: 4,
        ));
      }
    }
    buffer.writeln(_row(totalLabel, _rs(total), indent: 2));
    buffer.writeln();
  }

  /// One "who did the spending" block: a line per bank, then the total.
  /// Silent when there is nothing to report.
  void _writeBankBlock(
    StringBuffer buffer,
    String heading,
    BankBreakdown breakdown, {
    int indent = 0,
  }) {
    if (breakdown.isEmpty) return;
    buffer.writeln('${' ' * indent}$heading');
    for (final b in breakdown.banks) {
      final detail = StringBuffer(b.name)
        ..write('  (${b.transactionCount} txn');
      if (b.transactionCount != 1) detail.write('s');
      if (b.received > 0) detail.write(', +${_currencyFmt.format(b.received)}');
      if (b.moved > 0) detail.write(', moved ${_currencyFmt.format(b.moved)}');
      detail.write(')');
      buffer.writeln(_row(
        detail.toString(),
        _currencyFmt.format(b.spent),
        indent: indent + 2,
      ));
    }
    buffer.writeln(_row('TOTAL SPENT', _rs(breakdown.totalSpent),
        indent: indent + 2));
    buffer.writeln();
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static String _rs(double amount) => 'Rs. ${_currencyFmt.format(amount)}';

  static String _summaryLine(String label, String value) =>
      '${label.padRight(20)}: $value';

  static String _row(String left, String right, {int indent = 0}) {
    final leftWidth = _reportWidth - right.length - indent - 1;
    var text = left;
    if (text.length > leftWidth) {
      text = '${text.substring(0, leftWidth - 3)}...';
    }
    return '${' ' * indent}${text.padRight(leftWidth)} $right';
  }

  Map<DateTime, List<TransactionModel>> _groupByMonth(
    List<TransactionModel> transactions,
  ) {
    final Map<DateTime, List<TransactionModel>> grouped = {};
    for (final t in transactions) {
      final key = DateTime(t.detectedAt.year, t.detectedAt.month);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final key in sortedKeys) key: grouped[key]!};
  }
}
