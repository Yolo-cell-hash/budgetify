import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';
import 'sms_parser_service.dart';

/// Service for exporting transaction data to CSV and TXT files.
///
/// CSV is a single clean table (no decorative rows) with a UTF-8 BOM so
/// Excel parses it correctly. TXT is a plain-ASCII aligned report that
/// renders the same in every viewer — no emoji or box-drawing characters,
/// which showed up as mojibake in non-UTF8 apps.
class ExportService {
  final DatabaseService _db = DatabaseService();

  // ── Formatters ──────────────────────────────────────────────────────

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('HH:mm');
  static final _dayFmt = DateFormat('dd MMM');
  static final _monthYearFmt = DateFormat('MMMM yyyy');
  static final _fileDateFmt = DateFormat('yyyyMMdd_HHmm');
  static final _currencyFmt = NumberFormat('#,##0.00', 'en_IN');

  static const int _reportWidth = 64;

  // ── Public API ──────────────────────────────────────────────────────

  /// Export all transactions to a CSV file. One clean header row and one
  /// row per transaction — month lives in its own column so the file is
  /// sortable/filterable in Excel and Sheets. Returns the saved file path.
  Future<String> exportToExcel() async {
    final transactions = await _db.getAllTransactions();
    final buffer = StringBuffer();

    buffer.writeln(
      'Month,Date,Time,Type,Amount,Category,Merchant,Account,Bank,Notes',
    );

    final grouped = _groupByMonth(transactions);
    for (final entry in grouped.entries) {
      final month = _monthYearFmt.format(entry.key);
      for (final txn in entry.value) {
        buffer.writeln(_transactionToCsvRow(month, txn));
      }
    }

    final dir = await _getExportDirectory();
    final fileName =
        'budgetify_export_${_fileDateFmt.format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    // UTF-8 BOM so Excel on Windows decodes the file as UTF-8 instead of
    // ANSI (which turned any non-ASCII character into gibberish)
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);

    return file.path;
  }

  /// Export all transactions to a plain-text report. Fixed-width ASCII
  /// columns, amounts right-aligned. Returns the saved file path.
  Future<String> exportToTxt() async {
    final transactions = await _db.getAllTransactions();
    final buffer = StringBuffer();

    // ── Header ────────────────────────────────────────────────────────
    buffer.writeln('=' * _reportWidth);
    buffer.writeln('  BUDGETIFY EXPORT');
    buffer.writeln('  Generated: ${_dateFmt.format(DateTime.now())}');
    buffer.writeln('=' * _reportWidth);
    buffer.writeln();

    // ── Overall summary ───────────────────────────────────────────────
    double totalIncome = 0;
    double totalExpenses = 0;
    for (final txn in transactions) {
      if (txn.type == TransactionType.credit) {
        totalIncome += txn.amount;
      } else {
        totalExpenses += txn.amount;
      }
    }

    buffer.writeln('SUMMARY');
    buffer.writeln('-' * _reportWidth);
    buffer.writeln(_summaryLine('Total Transactions', '${transactions.length}'));
    buffer.writeln(_summaryLine('Total Income', _rs(totalIncome)));
    buffer.writeln(_summaryLine('Total Expenses', _rs(totalExpenses)));
    buffer.writeln(_summaryLine('Net', _rs(totalIncome - totalExpenses)));
    buffer.writeln();

    // ── Monthly sections ──────────────────────────────────────────────
    final grouped = _groupByMonth(transactions);

    for (final entry in grouped.entries) {
      buffer.writeln(_monthYearFmt.format(entry.key).toUpperCase());
      buffer.writeln('-' * _reportWidth);

      final monthTxns = entry.value;
      final expenses =
          monthTxns.where((t) => t.type == TransactionType.debit).toList();
      final income =
          monthTxns.where((t) => t.type == TransactionType.credit).toList();

      if (expenses.isNotEmpty) {
        buffer.writeln('EXPENSES BY CATEGORY');

        final byCategory = <String, List<TransactionModel>>{};
        for (final txn in expenses) {
          byCategory
              .putIfAbsent(txn.category ?? 'Uncategorized', () => [])
              .add(txn);
        }
        final sortedCategories = byCategory.entries.toList()
          ..sort((a, b) {
            final totalA = a.value.fold<double>(0, (s, t) => s + t.amount);
            final totalB = b.value.fold<double>(0, (s, t) => s + t.amount);
            return totalB.compareTo(totalA);
          });

        double totalMonthExpenses = 0;
        for (final catEntry in sortedCategories) {
          final catTotal =
              catEntry.value.fold<double>(0, (s, t) => s + t.amount);
          totalMonthExpenses += catTotal;

          buffer.writeln(_row(catEntry.key, _rs(catTotal), indent: 2));
          for (final txn in catEntry.value) {
            buffer.writeln(
              _row(
                '${_dayFmt.format(txn.detectedAt)}  '
                '${txn.merchantName ?? txn.sender}',
                _currencyFmt.format(txn.amount),
                indent: 4,
              ),
            );
          }
        }
        buffer.writeln(_row('TOTAL EXPENSES', _rs(totalMonthExpenses), indent: 2));
        buffer.writeln();
      }

      if (income.isNotEmpty) {
        buffer.writeln('INCOME');

        double totalMonthIncome = 0;
        for (final txn in income) {
          totalMonthIncome += txn.amount;
          buffer.writeln(
            _row(
              '${_dayFmt.format(txn.detectedAt)}  '
              '${txn.merchantName ?? txn.sender}',
              _currencyFmt.format(txn.amount),
              indent: 2,
            ),
          );
        }
        buffer.writeln(_row('TOTAL INCOME', _rs(totalMonthIncome), indent: 2));
        buffer.writeln();
      }
    }

    final dir = await _getExportDirectory();
    final fileName =
        'budgetify_export_${_fileDateFmt.format(DateTime.now())}.txt';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file.path;
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static String _rs(double amount) => 'Rs. ${_currencyFmt.format(amount)}';

  /// "Label              : value" summary line.
  static String _summaryLine(String label, String value) {
    return '${label.padRight(20)}: $value';
  }

  /// One report row: left text (truncated with "..." if too long) and a
  /// right-aligned amount, always exactly [_reportWidth] wide.
  static String _row(String left, String right, {int indent = 0}) {
    final leftWidth = _reportWidth - right.length - indent - 1;
    var text = left;
    if (text.length > leftWidth) {
      text = '${text.substring(0, leftWidth - 3)}...';
    }
    return '${' ' * indent}${text.padRight(leftWidth)} $right';
  }

  /// Get the directory for saving exports.
  /// Saves to the public Downloads folder so users can find files easily.
  Future<Directory> _getExportDirectory() async {
    // Use public Downloads directory on Android
    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (await downloadsDir.exists()) {
      return downloadsDir;
    }
    // Fallback to app documents directory
    return await getApplicationDocumentsDirectory();
  }

  /// Group transactions by month (descending order).
  /// Returns a [LinkedHashMap] keyed by the first day of each month.
  Map<DateTime, List<TransactionModel>> _groupByMonth(
    List<TransactionModel> transactions,
  ) {
    final Map<DateTime, List<TransactionModel>> grouped = {};

    for (final txn in transactions) {
      final key = DateTime(txn.detectedAt.year, txn.detectedAt.month);
      grouped.putIfAbsent(key, () => []).add(txn);
    }

    // Sort keys descending (most recent month first)
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  /// Convert a single transaction to a CSV row string.
  String _transactionToCsvRow(String month, TransactionModel txn) {
    final fields = [
      month,
      _dateFmt.format(txn.detectedAt),
      _timeFmt.format(txn.detectedAt),
      txn.type == TransactionType.credit ? 'Credit' : 'Debit',
      txn.amount.toStringAsFixed(2),
      txn.category ?? '',
      txn.merchantName ?? '',
      txn.accountInfo ?? '',
      txn.isManual ? 'Manual' : SmsParserService.normalizeSender(txn.sender),
      txn.notes ?? '',
    ];
    return fields.map(_escapeCsv).join(',');
  }

  /// Escape a value for CSV: wrap in double quotes if it contains
  /// commas, double-quotes, or newlines.
  String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
