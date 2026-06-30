import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'sms_parser_service.dart';

/// Output formats for an export.
enum ExportFormat { excel, csv, text, pdf }

/// User-chosen filters applied before an export. Empty/null fields mean
/// "no restriction on this dimension".
class ExportFilter {
  final DateTimeRange? dateRange;
  final Set<TransactionType> types; // empty = both credit and debit
  final Set<String> categories; // empty = all; 'Uncategorized' matches null
  final String merchantQuery; // case-insensitive substring on merchant/sender

  const ExportFilter({
    this.dateRange,
    this.types = const {},
    this.categories = const {},
    this.merchantQuery = '',
  });

  bool get isUnfiltered =>
      dateRange == null &&
      types.isEmpty &&
      categories.isEmpty &&
      merchantQuery.trim().isEmpty;

  bool matches(TransactionModel t) {
    if (types.isNotEmpty && !types.contains(t.type)) return false;

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

  static const int _reportWidth = 64;
  static const List<String> _columns = [
    'Month', 'Date', 'Time', 'Type', 'Amount',
    'Category', 'Merchant', 'Account', 'Bank', 'Notes',
  ];

  // ── Public API ──────────────────────────────────────────────────────

  /// Export in [format] honoring [filter]. Returns the saved file path,
  /// or null when the filter matched no transactions.
  Future<String?> export({
    required ExportFormat format,
    ExportFilter filter = const ExportFilter(),
  }) async {
    final all = await _db.getAllTransactions();
    final txns = all.where(filter.matches).toList();
    if (txns.isEmpty) return null;

    switch (format) {
      case ExportFormat.excel:
        return _writeBytes('xlsx', _buildWorkbook(txns));
      case ExportFormat.csv:
        return _writeBytes('csv', _buildCsvBytes(txns));
      case ExportFormat.text:
        return _writeString('txt', _buildTxt(txns));
      case ExportFormat.pdf:
        return _writeBytes('pdf', await _buildPdfBytes(txns));
    }
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
          TextCellValue(t.isManual
              ? 'Manual'
              : SmsParserService.normalizeSender(t.sender)),
          TextCellValue(t.notes ?? ''),
        ]);
      }
    }

    // Reasonable column widths
    const widths = [14.0, 13.0, 7.0, 8.0, 12.0, 16.0, 22.0, 10.0, 12.0, 24.0];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    // ── Summary sheet ──
    _buildSummarySheet(excel['Summary'], txns);

    // Drop the auto-created default sheet so the file opens on Transactions
    if (defaultSheet != 'Transactions' && defaultSheet != 'Summary') {
      excel.delete(defaultSheet);
    }
    excel.setDefaultSheet('Transactions');

    return excel.save()!;
  }

  void _buildSummarySheet(Sheet sheet, List<TransactionModel> txns) {
    double income = 0, expenses = 0;
    final byCategory = <String, double>{};
    for (final t in txns) {
      if (t.type == TransactionType.credit) {
        income += t.amount;
      } else {
        expenses += t.amount;
        final c = t.category ?? 'Uncategorized';
        byCategory[c] = (byCategory[c] ?? 0) + t.amount;
      }
    }

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
    row(2, 'Total Transactions', IntCellValue(txns.length));
    row(3, 'Total Income', DoubleCellValue(income));
    row(4, 'Total Expenses', DoubleCellValue(expenses));
    row(5, 'Net', DoubleCellValue(income - expenses));

    row(7, 'Expenses by Category', TextCellValue(''), style: titleStyle);
    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var r = 8;
    for (final e in sortedCats) {
      row(r++, e.key, DoubleCellValue(e.value));
    }

    sheet.setColumnWidth(0, 24.0);
    sheet.setColumnWidth(1, 16.0);
  }

  // ── PDF ─────────────────────────────────────────────────────────────

  /// A paginated report: a summary block (totals + expenses by category)
  /// followed by a per-month transaction table. Uses the built-in Helvetica
  /// font (ASCII), so amounts are prefixed "Rs." rather than the ₹ glyph.
  Future<List<int>> _buildPdfBytes(List<TransactionModel> txns) async {
    double income = 0, expenses = 0;
    final byCategory = <String, double>{};
    for (final t in txns) {
      if (t.type == TransactionType.credit) {
        income += t.amount;
      } else {
        expenses += t.amount;
        final c = t.category ?? 'Uncategorized';
        byCategory[c] = (byCategory[c] ?? 0) + t.amount;
      }
    }
    final sortedCats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const headerColor = PdfColor.fromInt(0xFF1B1E28);

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
        build: (context) => [
          pw.Text('Budgetify Export',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('Generated: ${_dateFmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 14),
          pw.Text('Summary',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 0.5),
          summaryRow('Total Transactions', '${txns.length}'),
          summaryRow('Total Income', _rs(income)),
          summaryRow('Total Expenses', _rs(expenses)),
          summaryRow('Net', _rs(income - expenses), bold: true),
          if (sortedCats.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Expenses by Category',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 0.5),
            for (final e in sortedCats) summaryRow(e.key, _rs(e.value)),
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
                    t.merchantName ??
                        (t.isManual
                            ? 'Manual'
                            : SmsParserService.normalizeSender(t.sender)),
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
      t.isManual ? 'Manual' : SmsParserService.normalizeSender(t.sender),
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
    buffer.writeln('  Generated: ${_dateFmt.format(DateTime.now())}');
    buffer.writeln('=' * _reportWidth);
    buffer.writeln();

    double totalIncome = 0, totalExpenses = 0;
    for (final t in txns) {
      if (t.type == TransactionType.credit) {
        totalIncome += t.amount;
      } else {
        totalExpenses += t.amount;
      }
    }

    buffer.writeln('SUMMARY');
    buffer.writeln('-' * _reportWidth);
    buffer.writeln(_summaryLine('Total Transactions', '${txns.length}'));
    buffer.writeln(_summaryLine('Total Income', _rs(totalIncome)));
    buffer.writeln(_summaryLine('Total Expenses', _rs(totalExpenses)));
    buffer.writeln(_summaryLine('Net', _rs(totalIncome - totalExpenses)));
    buffer.writeln();

    final grouped = _groupByMonth(txns);
    for (final entry in grouped.entries) {
      buffer.writeln(_monthYearFmt.format(entry.key).toUpperCase());
      buffer.writeln('-' * _reportWidth);

      final expenses =
          entry.value.where((t) => t.type == TransactionType.debit).toList();
      final income =
          entry.value.where((t) => t.type == TransactionType.credit).toList();

      if (expenses.isNotEmpty) {
        buffer.writeln('EXPENSES BY CATEGORY');
        final byCategory = <String, List<TransactionModel>>{};
        for (final t in expenses) {
          byCategory.putIfAbsent(t.category ?? 'Uncategorized', () => []).add(t);
        }
        final sorted = byCategory.entries.toList()
          ..sort((a, b) {
            final ta = a.value.fold<double>(0, (s, t) => s + t.amount);
            final tb = b.value.fold<double>(0, (s, t) => s + t.amount);
            return tb.compareTo(ta);
          });
        double monthTotal = 0;
        for (final cat in sorted) {
          final catTotal = cat.value.fold<double>(0, (s, t) => s + t.amount);
          monthTotal += catTotal;
          buffer.writeln(_row(cat.key, _rs(catTotal), indent: 2));
          for (final t in cat.value) {
            buffer.writeln(_row(
              '${_dayFmt.format(t.detectedAt)}  ${t.merchantName ?? t.sender}',
              _currencyFmt.format(t.amount),
              indent: 4,
            ));
          }
        }
        buffer.writeln(_row('TOTAL EXPENSES', _rs(monthTotal), indent: 2));
        buffer.writeln();
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
    }
    return buffer.toString();
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

  Future<String> _writeBytes(String ext, List<int> bytes) async {
    final dir = await _getExportDirectory();
    final file = File('${dir.path}/budgetify_export_'
        '${_fileDateFmt.format(DateTime.now())}.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> _writeString(String ext, String content) async {
    final dir = await _getExportDirectory();
    final file = File('${dir.path}/budgetify_export_'
        '${_fileDateFmt.format(DateTime.now())}.$ext');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  Future<Directory> _getExportDirectory() async {
    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (await downloadsDir.exists()) return downloadsDir;
    return await getApplicationDocumentsDirectory();
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
