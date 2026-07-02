import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/statement_import_models.dart';
import '../models/transaction_model.dart';
import 'app_events.dart';
import 'csv_reader.dart';
import 'database_service.dart';
import 'sms_parser_service.dart';

/// Why a picked file couldn't be turned into a statement grid.
enum StatementFileKind { pdf, legacyXls, unreadable }

class StatementFileException implements Exception {
  final StatementFileKind kind;
  const StatementFileException(this.kind);
}

/// Imports transactions from any bank's CSV/XLSX statement export.
///
/// Unlike the Axio importer (which only brings over *tags* because SMS
/// re-creates those transactions), this inserts real transaction rows — the
/// history the SMS pipeline cannot see: months before the app was installed,
/// accounts whose alerts land on another phone, or exports from other apps.
///
/// Everything is parsed on-device from a file the user picked; nothing new is
/// requested or sent. The statement's balance column is recognised so header
/// detection works, but its values are never read or stored (tracking bank
/// balances is an explicit product no-go).
///
/// Provenance and safety model:
/// - Imported rows carry `sender = 'IMPORT-<label>'` and `isManual = false`,
///   so deleting one writes a tombstone — re-importing the same file will
///   not resurrect it.
/// - The stored message is `narration (Ref <refNo>)`, which makes the
///   fingerprint deterministic per statement line: re-imports dedupe via the
///   existing UNIQUE fingerprint index.
/// - Rows that match an existing transaction's type + amount within ±1 day
///   (usually SMS-captured history) are flagged as probable duplicates and
///   excluded unless the user opts them in.
class StatementImportService {
  final DatabaseService _db;

  StatementImportService([DatabaseService? db]) : _db = db ?? DatabaseService();

  static const String _templatePrefsKey = 'statement_import_templates';

  /// Sender prefix marking imported rows; also used to exclude them when
  /// computing when SMS tracking began.
  static const String senderPrefix = 'IMPORT-';

  // ── 1. Decode the file into a grid ────────────────────────────────────

  /// Turn picked-file [bytes] into a text grid. Detects the real content by
  /// magic bytes, not extension — banks routinely serve ".xls" files that are
  /// actually CSV/TSV text (handled) or real legacy BIFF (rejected).
  static List<List<String>> decodeBytes(Uint8List bytes) {
    if (bytes.length < 8) throw const StatementFileException(StatementFileKind.unreadable);
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
      throw const StatementFileException(StatementFileKind.pdf); // %PDF
    }
    if (bytes[0] == 0xD0 && bytes[1] == 0xCF) {
      throw const StatementFileException(StatementFileKind.legacyXls); // OLE2
    }
    if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return _decodeXlsx(bytes); // zip container
    }
    final content = utf8.decode(bytes, allowMalformed: true);
    return CsvReader.parse(content);
  }

  static List<List<String>> _decodeXlsx(Uint8List bytes) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const StatementFileException(StatementFileKind.unreadable);
    }
    // Statements sometimes ship with an account-info sheet first; take the
    // sheet with the most rows.
    Sheet? best;
    for (final table in excel.tables.values) {
      if (best == null || table.maxRows > best.maxRows) best = table;
    }
    if (best == null) throw const StatementFileException(StatementFileKind.unreadable);
    return [
      for (final row in best.rows)
        [for (final cell in row) _cellToString(cell?.value)],
    ];
  }

  static String _cellToString(CellValue? value) {
    if (value == null) return '';
    if (value is DateCellValue) {
      return _isoDate(value.year, value.month, value.day);
    }
    if (value is DateTimeCellValue) {
      return _isoDate(value.year, value.month, value.day);
    }
    // TextCellValue/IntCellValue/DoubleCellValue/BoolCellValue all stringify
    // to their plain content.
    return value.toString();
  }

  static String _isoDate(int y, int m, int d) =>
      '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  // ── 2. Find the header row and guess the mapping ──────────────────────

  /// Header spellings actually used by Indian banks (HDFC, ICICI, SBI, Axis,
  /// Kotak, …) and common expense-tracker exports, normalized (lowercase,
  /// punctuation collapsed to spaces).
  static const Map<StatementColumnRole, List<String>> headerVocabulary = {
    StatementColumnRole.date: [
      'date', 'txn date', 'transaction date', 'tran date', 'trans date',
      'value date', 'value dt', 'post date', 'posting date', 'book date',
    ],
    StatementColumnRole.description: [
      'narration', 'naration', 'description', 'particulars', 'remarks',
      'transaction details', 'details', 'transaction remarks',
      'transaction description', 'transaction particulars',
    ],
    StatementColumnRole.debit: [
      'withdrawal amt', 'withdrawal amount', 'debit', 'debit amount',
      'debit amt', 'withdrawal', 'withdrawals', 'dr amount', 'dr amt',
      'paid out', 'money out', 'amount dr', 'withdrawal dr', 'expense',
      'dr', 'withdrawal inr',
    ],
    StatementColumnRole.credit: [
      'deposit amt', 'deposit amount', 'credit', 'credit amount',
      'credit amt', 'deposit', 'deposits', 'cr amount', 'cr amt',
      'paid in', 'money in', 'amount cr', 'deposit cr',
      'cr', 'deposit inr',
    ],
    StatementColumnRole.amount: [
      'amount', 'txn amount', 'transaction amount', 'amount inr', 'amt',
      'amount rs',
    ],
    StatementColumnRole.drCr: [
      'dr cr', 'cr dr', 'dr or cr', 'type', 'txn type', 'transaction type',
      'debit credit', 'credit debit', 'withdrawal deposit',
    ],
    StatementColumnRole.refNo: [
      'chq ref no', 'chq ref number', 'ref no', 'reference no',
      'reference number', 'ref number', 'cheque no', 'chq no',
      'cheque number', 'utr', 'utr no', 'utr number', 'tran id',
      'transaction id', 'txn id', 'reference', 'instrument id',
      'cheque ref no',
    ],
    StatementColumnRole.balance: [
      'closing balance', 'balance', 'available balance', 'running balance',
      'balance inr', 'available bal', 'balance amt', 'bal',
    ],
  };

  /// Normalize a header cell for vocabulary lookup.
  static String normalizeHeader(String cell) => cell
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  /// Guess a mapping from a candidate header row. Roles are assigned at most
  /// once, leftmost column wins — statements list "Txn Date" before
  /// "Value Date", so the transaction date is preferred naturally.
  static StatementMapping guessMapping(List<String> headerRow) {
    final exact = <String, StatementColumnRole>{};
    final contains = <MapEntry<String, StatementColumnRole>>[];
    for (final entry in headerVocabulary.entries) {
      for (final key in entry.value) {
        exact[key] = entry.key;
        contains.add(MapEntry(key, entry.key));
      }
    }
    // Longer keys first so "withdrawal amount" beats "amount".
    contains.sort((a, b) => b.key.length.compareTo(a.key.length));

    final roles = <int, StatementColumnRole>{};
    final taken = <StatementColumnRole>{};
    for (var i = 0; i < headerRow.length; i++) {
      final norm = normalizeHeader(headerRow[i]);
      if (norm.isEmpty) continue;
      StatementColumnRole? role = exact[norm];
      if (role == null) {
        for (final e in contains) {
          if (e.key.length >= 4 && norm.contains(e.key)) {
            role = e.value;
            break;
          }
        }
      }
      if (role == null) continue;
      if (taken.contains(role)) continue; // e.g. a second date-ish column
      roles[i] = role;
      taken.add(role);
    }
    return StatementMapping(roles: roles);
  }

  /// Scan the first rows of the grid for a header row whose names alone give
  /// a valid mapping (date + a money column). Statements carry preamble junk
  /// (account holder, address, "Statement of account…") before the header.
  static ({int rowIndex, StatementMapping mapping})? detectHeader(
    List<List<String>> grid,
  ) {
    final limit = grid.length < 40 ? grid.length : 40;
    for (var i = 0; i < limit; i++) {
      final row = grid[i];
      final nonEmpty = row.where((c) => c.trim().isNotEmpty).length;
      if (nonEmpty < 3) continue;
      final mapping = guessMapping(row);
      if (mapping.isValid) return (rowIndex: i, mapping: mapping);
    }
    return null;
  }

  // ── 3. Value parsing (Indian formats) ─────────────────────────────────

  /// Parse an Indian statement amount: lakh-style grouping ("1,23,456.78"),
  /// ₹/Rs/INR markers, trailing Dr/Cr, parenthesised or trailing-minus
  /// negatives. Returns null for blanks and non-numbers.
  static double? parseAmount(String raw) {
    var v = raw.trim();
    if (v.isEmpty) return null;
    var negative = false;
    if (v.startsWith('(') && v.endsWith(')')) {
      negative = true;
      v = v.substring(1, v.length - 1);
    }
    if (v.endsWith('-')) {
      negative = true;
      v = v.substring(0, v.length - 1);
    }
    v = v
        .replaceAll(RegExp(r'INR|Rs\.?|₹', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?:DR|CR)\.?\s*$', caseSensitive: false), '')
        .replaceAll(',', '')
        // \s in a Dart regex matches NBSP too, which exporters pad with.
        .replaceAll(RegExp(r'\s'), '');
    if (v.isEmpty || v == '-' || v == '.') return null;
    final parsed = double.tryParse(v);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }

  /// An explicit Dr/Cr suffix on a raw amount cell ("1,499.00 Dr").
  static TransactionType? amountSuffixMarker(String raw) {
    final m = RegExp(r'(DR|CR)\.?\s*$', caseSensitive: false)
        .firstMatch(raw.trim());
    if (m == null) return null;
    return m.group(1)!.toUpperCase() == 'DR'
        ? TransactionType.debit
        : TransactionType.credit;
  }

  /// Interpret a Dr/Cr marker column value.
  static TransactionType? drCrToType(String raw) {
    final v = raw.trim().toUpperCase();
    if (v.isEmpty) return null;
    const debitWords = [
      'DR', 'D', 'DEBIT', 'WITHDRAWAL', 'EXPENSE', 'PAID', 'OUT', 'SENT',
    ];
    const creditWords = [
      'CR', 'C', 'CREDIT', 'DEPOSIT', 'INCOME', 'RECEIVED', 'IN',
    ];
    if (debitWords.any((w) => v == w || v.startsWith('$w '))) {
      return TransactionType.debit;
    }
    if (creditWords.any((w) => v == w || v.startsWith('$w '))) {
      return TransactionType.credit;
    }
    return null;
  }

  /// Date patterns seen across Indian statement exports, dd-first so an
  /// ambiguous "05/04/2026" reads as 5 April (Indian convention). `dd`/`MM`
  /// also match single-digit values when parsing, so d/M variants are covered.
  static const List<String> dateFormatCandidates = [
    'dd/MM/yyyy', 'dd/MM/yy', 'dd-MM-yyyy', 'dd-MM-yy', 'dd.MM.yyyy',
    'dd MMM yyyy', 'dd-MMM-yyyy', 'dd-MMM-yy', 'dd MMM yy', 'MMM dd, yyyy',
    'yyyy-MM-dd', 'yyyy/MM/dd', 'MM/dd/yyyy', 'MM-dd-yyyy',
  ];

  /// Try one date value against one pattern; tolerates a trailing time part
  /// ("01/04/2026 14:23") and two-digit years, and rejects nonsense years.
  static DateTime? tryParseDate(String raw, String format) {
    final v = raw.trim().replaceFirst(RegExp(r"^'"), '');
    if (v.isEmpty) return null;
    DateTime? attempt(String s) {
      try {
        var d = DateFormat(format, 'en_US').parseStrict(s);
        if (d.year < 100) d = DateTime(d.year + 2000, d.month, d.day);
        if (d.year < 2000 || d.year > 2100) return null;
        return DateTime(d.year, d.month, d.day);
      } catch (_) {
        return null;
      }
    }

    final full = attempt(v);
    if (full != null) return full;
    if (!format.contains(' ') && v.contains(' ')) {
      return attempt(v.split(RegExp(r'\s+')).first);
    }
    return null;
  }

  /// Pick the pattern that parses the *most* sample values. Footer/summary
  /// rows ("STATEMENT SUMMARY :-") never parse under any pattern, so they
  /// penalise every candidate equally instead of vetoing the right one; ties
  /// go to the earlier candidate, preserving the dd-first preference. Null
  /// only when nothing parses at all.
  static String? inferDateFormat(Iterable<String> samples) {
    final values = samples
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(40)
        .toList();
    if (values.isEmpty) return null;
    String? best;
    var bestCount = 0;
    for (final format in dateFormatCandidates) {
      final ok = values.where((v) => tryParseDate(v, format) != null).length;
      if (ok > bestCount) {
        best = format;
        bestCount = ok;
      }
    }
    return best;
  }

  // ── 4. Merchant extraction from narrations ────────────────────────────

  /// Segments of a narration that are plumbing, not a payee.
  static const Set<String> _stopSegments = {
    'UPI', 'NEFT', 'IMPS', 'RTGS', 'POS', 'ACH', 'ATM', 'ATW', 'NWD', 'EAW',
    'DR', 'CR', 'P2A', 'P2M', 'TPT', 'TRANSFER', 'PAYMENT', 'PAYMENTS',
    'FT', 'CHQ', 'CLG', 'MB', 'IB', 'BIL', 'ONL', 'PCD', 'VIN', 'SI',
    'ECS', 'NACH', 'INF', 'INFT', 'RRN', 'REF', 'UTR', 'COLLECT',
    'PAYMENT FROM PH', 'OTHERS', 'OTH', 'SBIN', 'HDFC', 'ICIC', 'UTIB',
    'KKBK', 'PUNB', 'BARB', 'IDIB', 'IOBA', 'CNRB', 'UBIN', 'YESB', 'INDB',
    'FDRL', 'MAHB', 'AUBL', 'PYTM', 'AIRP', 'JIOP',
  };

  /// Best-effort payee from a statement narration.
  ///
  /// Narrations are bank-structured strings like
  /// `UPI-SWIGGY LIMITED-swiggy@axis-UTIB0000248-1041…-Payment` (HDFC) or
  /// `TO TRANSFER-UPI/DR/5121…/RAMESH KUMAR/SBIN/…` (SBI). Splitting on the
  /// structural separators and scoring the segments finds the name without
  /// per-bank templates. Returns null when nothing looks like a name — the
  /// keyword categorizer still sees the full narration independently.
  static String? merchantFromNarration(String narration) {
    var n = narration.trim();
    if (n.isEmpty) return null;

    // POS rows: the merchant is whatever follows the masked card number.
    final pos = RegExp(
      r'^POS(?:\s+PRCH)?[\s/]+[X*\d]{6,}[\s/]+(.+)$',
      caseSensitive: false,
    ).firstMatch(n);
    if (pos != null) return _titleCase(pos.group(1)!.trim());

    n = n.replaceFirst(
      RegExp(r'^(?:TO|BY)\s+TRANSFER[- ]*', caseSensitive: false),
      '',
    );

    final segments = n.split(RegExp(r'[-/|*]'));
    String? best;
    var bestScore = 0;
    final limit = segments.length < 8 ? segments.length : 8;
    for (var i = 0; i < limit; i++) {
      final segment = segments[i].trim();
      final score = _segmentScore(segment, i);
      if (score > bestScore) {
        best = segment;
        bestScore = score;
      }
    }
    return best == null ? null : _titleCase(best);
  }

  static int _segmentScore(String s, int position) {
    if (s.length < 3 || s.length > 40) return 0;
    if (s.contains('@')) return 0; // a VPA, not a name
    final letters = s.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (letters < 3 || digits > letters) return 0;
    if (RegExp(r'\d{6,}').hasMatch(s)) return 0; // embedded ref number
    final upper = s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_stopSegments.contains(upper)) return 0;
    if (upper.startsWith('PAYMENT FROM')) return 0;
    var score = 10 - position; // earlier segments carry the payee more often
    if (s.contains(' ')) score += 3;
    if (digits == 0) score += 3;
    if (letters >= 5) score += 2;
    return score;
  }

  static String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(RegExp(r'\s+'))
        .map(
          (w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  // ── 5. Parse the grid into rows ───────────────────────────────────────

  /// Trim a cell and drop the leading apostrophe exporters use to force text.
  static String _norm(String value) {
    var v = value.trim();
    if (v.startsWith("'")) v = v.substring(1).trim();
    return v;
  }

  /// Parse data rows under [headerRowIndex] with [mapping]. If the mapping
  /// has no date format yet, it is inferred from the data and returned inside
  /// the result's mapping.
  static StatementParseResult parseRows(
    List<List<String>> grid,
    int headerRowIndex,
    StatementMapping mapping,
  ) {
    String cellOf(List<String> row, StatementColumnRole role) {
      final c = mapping.columnFor(role);
      if (c == null || c >= row.length) return '';
      return _norm(row[c]);
    }

    var effective = mapping;
    if (effective.dateFormat == null) {
      final samples = <String>[
        for (var i = headerRowIndex + 1; i < grid.length; i++)
          cellOf(grid[i], StatementColumnRole.date),
      ];
      effective = effective.copyWith(dateFormat: inferDateFormat(samples));
    }
    final dateFormat = effective.dateFormat;

    // Single-amount files come in two dialects: signed (withdrawals negative,
    // deposits positive) and signless spend lists. One pass over the column
    // tells them apart before any row's type is decided.
    var anyNegativeAmount = false;
    if (effective.columnFor(StatementColumnRole.amount) != null) {
      for (var i = headerRowIndex + 1; i < grid.length; i++) {
        final v = parseAmount(cellOf(grid[i], StatementColumnRole.amount));
        if (v != null && v < 0) {
          anyNegativeAmount = true;
          break;
        }
      }
    }

    final rows = <StatementRow>[];
    for (var i = headerRowIndex + 1; i < grid.length; i++) {
      final raw = grid[i];
      final rawDate = cellOf(raw, StatementColumnRole.date);
      final narration = cellOf(raw, StatementColumnRole.description);
      final rawDebit = cellOf(raw, StatementColumnRole.debit);
      final rawCredit = cellOf(raw, StatementColumnRole.credit);
      final rawAmount = cellOf(raw, StatementColumnRole.amount);
      final rawDrCr = cellOf(raw, StatementColumnRole.drCr);
      final refNo = cellOf(raw, StatementColumnRole.refNo);

      if (rawDate.isEmpty &&
          narration.isEmpty &&
          rawDebit.isEmpty &&
          rawCredit.isEmpty &&
          rawAmount.isEmpty) {
        continue; // separator row
      }

      final debitVal = parseAmount(rawDebit);
      final creditVal = parseAmount(rawCredit);
      final amountVal = parseAmount(rawAmount);
      final hasMoney = (debitVal ?? 0) != 0 ||
          (creditVal ?? 0) != 0 ||
          (amountVal ?? 0) != 0;
      final date =
          dateFormat == null ? null : tryParseDate(rawDate, dateFormat);

      if (date == null && !hasMoney) {
        // Footer/summary or a wrapped narration continued on its own line.
        if (narration.isNotEmpty && rows.isNotEmpty) {
          final last = rows.last;
          if (last.status != StatementRowStatus.invalid) {
            last.narration = '${last.narration} $narration'.trim();
          }
        }
        continue;
      }

      if (date == null) {
        rows.add(StatementRow(
          sourceRow: i,
          date: null,
          narration: narration.isEmpty ? rawDate : narration,
          status: StatementRowStatus.invalid,
          include: false,
          invalidReason: 'date',
        ));
        continue;
      }

      double? amount;
      TransactionType? type;
      String? invalidReason;
      final hasDebit = debitVal != null && debitVal != 0;
      final hasCredit = creditVal != null && creditVal != 0;
      if (hasDebit && hasCredit) {
        invalidReason = 'amount';
      } else if (hasDebit) {
        amount = debitVal.abs();
        type = TransactionType.debit;
      } else if (hasCredit) {
        amount = creditVal.abs();
        type = TransactionType.credit;
      } else if (amountVal != null && amountVal != 0) {
        amount = amountVal.abs();
        type = drCrToType(rawDrCr) ??
            amountSuffixMarker(rawAmount) ??
            (amountVal < 0
                ? TransactionType.debit
                : anyNegativeAmount
                    // Signed file: positives are deposits.
                    ? TransactionType.credit
                    // Signless single-amount file: almost always a spend list.
                    : TransactionType.debit);
      } else {
        invalidReason = 'amount';
      }

      if (invalidReason != null) {
        rows.add(StatementRow(
          sourceRow: i,
          date: date,
          narration: narration,
          refNo: refNo,
          status: StatementRowStatus.invalid,
          include: false,
          invalidReason: invalidReason,
        ));
        continue;
      }

      rows.add(StatementRow(
        sourceRow: i,
        date: date,
        narration: narration,
        refNo: refNo,
        amount: amount,
        type: type,
        merchant: merchantFromNarration(narration),
        autoCategory: SmsParserService.detectCategory(narration),
      ));
    }

    return StatementParseResult(
      rows: rows,
      mapping: effective,
      headerRowIndex: headerRowIndex,
    );
  }

  // ── 6. Duplicate detection against on-device history ──────────────────

  /// Flag rows whose type + exact amount lands within ±1 day of an existing
  /// transaction (statement value-date vs SMS timestamp skew). Flagged rows
  /// are excluded by default; the user can opt any back in.
  static void markDuplicates(
    List<StatementRow> rows,
    Iterable<ExistingTxnKey> existing,
  ) {
    final datesByKey = <String, List<DateTime>>{};
    for (final e in existing) {
      datesByKey
          .putIfAbsent('${e.type.index}|${e.amountPaise}', () => [])
          .add(DateTime(e.date.year, e.date.month, e.date.day));
    }
    for (final row in rows) {
      if (row.status != StatementRowStatus.ready || !row.isImportable) {
        continue;
      }
      final key = '${row.type!.index}|${(row.amount! * 100).round()}';
      final dates = datesByKey[key];
      if (dates == null) continue;
      final day = DateTime(row.date!.year, row.date!.month, row.date!.day);
      final isDup = dates.any((d) => d.difference(day).inDays.abs() <= 1);
      if (isDup) {
        row.status = StatementRowStatus.probableDuplicate;
        row.include = false;
      }
    }
  }

  /// Existing-transaction keys overlapping the statement's date span (with a
  /// day of slack each side), for [markDuplicates].
  Future<List<ExistingTxnKey>> loadExistingKeys(
    DateTime from,
    DateTime to,
  ) async {
    final txns = await _db.getTransactionsByDateRange(
      from.subtract(const Duration(days: 1)),
      to.add(const Duration(days: 2)),
    );
    return [for (final t in txns) ExistingTxnKey.fromTransaction(t)];
  }

  /// When SMS tracking began on this device (earliest non-manual,
  /// non-imported transaction). Null when there is no SMS history yet.
  Future<DateTime?> smsEraStart() => _db.earliestSmsTransactionDate();

  // ── 7. Apply ──────────────────────────────────────────────────────────

  /// Label → sender, e.g. "HDFC Savings" → "IMPORT-HDFC SAVINGS".
  static String senderFor(String sourceLabel) {
    final cleaned = sourceLabel
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    return '$senderPrefix${cleaned.isEmpty ? 'STATEMENT' : cleaned}';
  }

  /// Insert every included, importable row. Skips rows that already exist or
  /// that the user previously deleted (tombstones), then lets the saved rules
  /// tag the newcomers and refreshes live screens.
  Future<StatementImportResult> apply(
    List<StatementRow> rows, {
    required String sourceLabel,
  }) async {
    final sender = senderFor(sourceLabel);
    var inserted = 0;
    var skipped = 0;
    for (final row in rows) {
      if (!row.include || !row.isImportable) continue;
      final message = row.refNo.isEmpty
          ? row.narration
          : '${row.narration} (Ref ${row.refNo})';
      final txn = TransactionModel(
        amount: row.amount!,
        type: row.type!,
        sender: sender,
        message: message.isEmpty ? 'Imported transaction' : message,
        detectedAt: row.date!,
        merchantName: row.merchant,
        category: row.autoCategory,
        isClassified: row.autoCategory != null,
        isManual: false,
      ).withFingerprint();

      final exists = await _db.transactionExists(
        txn.message,
        txn.detectedAt,
        fingerprint: txn.fingerprint,
      );
      if (exists) {
        skipped++;
        continue;
      }
      final id = await _db.insertTransaction(txn);
      if (id > 0) {
        inserted++;
      } else {
        skipped++; // unique-index race safety
      }
    }

    var autoTagged = 0;
    if (inserted > 0) {
      await _db.backfillMerchantNames();
      autoTagged = await _db.applyRulesToUntagged();
      notifyAppDataChanged();
    }
    return StatementImportResult(
      inserted: inserted,
      skippedExisting: skipped,
      autoTagged: autoTagged,
    );
  }

  // ── 8. Mapping templates ──────────────────────────────────────────────
  // A confirmed mapping is remembered against the header row's signature, so
  // the next statement from the same bank needs no re-mapping.

  static String headerSignature(List<String> headerRow) =>
      headerRow.map(normalizeHeader).join('|');

  Future<({StatementMapping mapping, String label})?> loadTemplate(
    List<String> headerRow,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_templatePrefsKey);
    if (raw == null) return null;
    try {
      final all = json.decode(raw) as Map<String, dynamic>;
      final entry = all[headerSignature(headerRow)] as Map<String, dynamic>?;
      if (entry == null) return null;
      final roles = <int, StatementColumnRole>{};
      (entry['roles'] as Map<String, dynamic>).forEach((k, v) {
        StatementColumnRole? role;
        for (final r in StatementColumnRole.values) {
          if (r.name == v) {
            role = r;
            break;
          }
        }
        final index = int.tryParse(k);
        if (role != null && index != null) roles[index] = role;
      });
      return (
        mapping: StatementMapping(
          roles: roles,
          dateFormat: entry['dateFormat'] as String?,
        ),
        label: (entry['label'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTemplate(
    List<String> headerRow,
    StatementMapping mapping,
    String label,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> all = {};
    final raw = prefs.getString(_templatePrefsKey);
    if (raw != null) {
      try {
        all = json.decode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    all[headerSignature(headerRow)] = {
      'label': label,
      'dateFormat': mapping.dateFormat,
      'roles': {
        for (final e in mapping.roles.entries) '${e.key}': e.value.name,
      },
    };
    await prefs.setString(_templatePrefsKey, json.encode(all));
  }
}
