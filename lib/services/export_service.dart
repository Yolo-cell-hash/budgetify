import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';

/// Service for exporting transaction data to CSV and TXT files.
///
/// CSV files are openable natively in Excel.
/// TXT files provide a richly formatted, human-readable summary.
class ExportService {
  final DatabaseService _db = DatabaseService();

  // ── Formatters ──────────────────────────────────────────────────────

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('HH:mm');
  static final _dayFmt = DateFormat('dd MMM');
  static final _monthYearFmt = DateFormat('MMMM yyyy');
  static final _fileDateFmt = DateFormat('yyyyMMdd');
  static final _headerDateFmt = DateFormat('dd MMM yyyy');
  static final _currencyFmt = NumberFormat('#,##0.00', 'en_IN');

  // ── Public API ──────────────────────────────────────────────────────

  /// Export all transactions to a CSV file (sorted by date descending,
  /// separated by month headers). Returns the saved file path.
  Future<String> exportToExcel() async {
    final transactions = await _db.getAllTransactions();
    final buffer = StringBuffer();

    // CSV header row
    buffer.writeln('Date,Time,Type,Amount,Category,Merchant,Notes,Sender');

    // Group by month (year-month key)
    final grouped = _groupByMonth(transactions);
    bool isFirst = true;

    for (final entry in grouped.entries) {
      if (!isFirst) {
        // Blank row + month header between groups
        buffer.writeln();
      }
      buffer.writeln('--- ${_monthYearFmt.format(entry.key)} ---');
      isFirst = false;

      for (final txn in entry.value) {
        buffer.writeln(_transactionToCsvRow(txn));
      }
    }

    final dir = await _getExportDirectory();
    final fileName =
        'budget_tracker_export_${_fileDateFmt.format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file.path;
  }

  /// Export all transactions to a neatly formatted TXT file with tree-style
  /// category grouping. Returns the saved file path.
  Future<String> exportToTxt() async {
    final transactions = await _db.getAllTransactions();
    final buffer = StringBuffer();

    // ── Header box ────────────────────────────────────────────────────
    final generatedDate = _headerDateFmt.format(DateTime.now());
    buffer.writeln('╔══════════════════════════════════════╗');
    buffer.writeln('║      BUDGET TRACKER EXPORT          ║');
    buffer.writeln('║      Generated: ${generatedDate.padRight(20)}║');
    buffer.writeln('╚══════════════════════════════════════╝');
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

    final net = totalIncome - totalExpenses;

    buffer.writeln('── Summary ──────────────────────────────');
    buffer.writeln(
      '  Total Transactions: ${transactions.length}',
    );
    buffer.writeln(
      '  Total Income:       ₹${_currencyFmt.format(totalIncome)}',
    );
    buffer.writeln(
      '  Total Expenses:     ₹${_currencyFmt.format(totalExpenses)}',
    );
    buffer.writeln(
      '  Net:                ₹${_currencyFmt.format(net)}',
    );
    buffer.writeln();

    // ── Monthly sections ──────────────────────────────────────────────
    final grouped = _groupByMonth(transactions);

    for (final entry in grouped.entries) {
      final monthLabel = _monthYearFmt.format(entry.key);
      buffer.writeln('── $monthLabel ${'─' * (40 - monthLabel.length - 4)}');
      buffer.writeln();

      final monthTxns = entry.value;

      // Split expenses vs income
      final expenses =
          monthTxns.where((t) => t.type == TransactionType.debit).toList();
      final income =
          monthTxns.where((t) => t.type == TransactionType.credit).toList();

      // ── Expenses by category ──────────────────────────────────────
      if (expenses.isNotEmpty) {
        buffer.writeln('  EXPENSES by Category:');

        // Group expenses by category
        final byCategory = <String, List<TransactionModel>>{};
        for (final txn in expenses) {
          final cat = txn.category ?? 'Uncategorized';
          byCategory.putIfAbsent(cat, () => []).add(txn);
        }

        // Sort categories by total amount descending
        final sortedCategories = byCategory.entries.toList()
          ..sort((a, b) {
            final totalA = a.value.fold<double>(0, (s, t) => s + t.amount);
            final totalB = b.value.fold<double>(0, (s, t) => s + t.amount);
            return totalB.compareTo(totalA);
          });

        double totalMonthExpenses = 0;
        for (var i = 0; i < sortedCategories.length; i++) {
          final catEntry = sortedCategories[i];
          final isLast = i == sortedCategories.length - 1;
          final connector = isLast ? '└─' : '├─';
          final childPrefix = isLast ? '    ' : '│   ';

          final catTotal =
              catEntry.value.fold<double>(0, (s, t) => s + t.amount);
          totalMonthExpenses += catTotal;

          final icon = ExpenseCategories.getIcon(catEntry.key);
          final catLabel = '$icon ${catEntry.key}';
          final amountStr = '₹${_currencyFmt.format(catTotal)}';

          buffer.writeln(
            '  $connector ${catLabel.padRight(28)}$amountStr',
          );

          // Individual transactions within category
          for (var j = 0; j < catEntry.value.length; j++) {
            final txn = catEntry.value[j];
            final isLastTxn = j == catEntry.value.length - 1;
            final txnConnector = isLastTxn ? '└─' : '├─';
            final dateStr = _dayFmt.format(txn.detectedAt);
            final merchant = txn.merchantName ?? txn.sender;
            final txnAmountStr = '₹${_currencyFmt.format(txn.amount)}';

            buffer.writeln(
              '  $childPrefix$txnConnector $dateStr  ${merchant.padRight(20)}$txnAmountStr',
            );
          }
        }

        buffer.writeln(
          '  └─ Total Expenses${' ' * 13}₹${_currencyFmt.format(totalMonthExpenses)}',
        );
        buffer.writeln();
      }

      // ── Income ────────────────────────────────────────────────────
      if (income.isNotEmpty) {
        buffer.writeln('  INCOME:');

        double totalMonthIncome = 0;
        for (var i = 0; i < income.length; i++) {
          final txn = income[i];
          final isLast = i == income.length - 1;
          final connector = isLast ? '└─' : '├─';
          final dateStr = _dayFmt.format(txn.detectedAt);
          final merchant = txn.merchantName ?? txn.sender;
          final amountStr = '₹${_currencyFmt.format(txn.amount)}';
          totalMonthIncome += txn.amount;

          buffer.writeln(
            '  $connector $dateStr  ${merchant.padRight(20)}$amountStr',
          );
        }

        buffer.writeln(
          '  └─ Total Income${' ' * 14}₹${_currencyFmt.format(totalMonthIncome)}',
        );
        buffer.writeln();
      }
    }

    final dir = await _getExportDirectory();
    final fileName =
        'budget_tracker_export_${_fileDateFmt.format(DateTime.now())}.txt';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file.path;
  }

  // ── Helpers ─────────────────────────────────────────────────────────

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
  /// Values containing commas or quotes are properly escaped.
  String _transactionToCsvRow(TransactionModel txn) {
    final date = _dateFmt.format(txn.detectedAt);
    final time = _timeFmt.format(txn.detectedAt);
    final type = txn.type == TransactionType.credit ? 'Credit' : 'Debit';
    final amount = txn.amount.toStringAsFixed(2);
    final category = _escapeCsv(txn.category ?? '');
    final merchant = _escapeCsv(txn.merchantName ?? '');
    final notes = _escapeCsv(txn.notes ?? '');
    final sender = _escapeCsv(txn.sender);

    return '$date,$time,$type,$amount,$category,$merchant,$notes,$sender';
  }

  /// Escape a value for CSV: wrap in double quotes if it contains
  /// commas, double-quotes, or newlines.
  String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
