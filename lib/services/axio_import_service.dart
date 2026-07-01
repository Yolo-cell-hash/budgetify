import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/transaction_model.dart';
import '../models/transaction_rule_model.dart';
import 'app_events.dart';
import 'database_service.dart';

/// Import sources the app can bring tags in from. Kept as an enum so the
/// picker can grow ("import based on apps") without reworking the flow.
enum ImportSource { axio }

extension ImportSourceInfo on ImportSource {
  String get displayName => switch (this) {
    ImportSource.axio => 'axio',
  };
}

/// A single merchant's tag decision derived from an Axio export: which
/// [category] to apply, how many times Axio tagged it that way ([count]), and
/// — via the parent list it lands in — whether it becomes a forever-rule.
class AxioMerchantTag {
  final String merchant; // display/stored name (title-cased)
  final TransactionType type;
  final String category; // mapped Budgetify category
  final int count;

  const AxioMerchantTag({
    required this.merchant,
    required this.type,
    required this.category,
    required this.count,
  });
}

/// The plan produced by reading an Axio CSV, shown to the user before anything
/// is written. [recurring] merchants become auto-tag rules ("Apply to All");
/// [oneOff] merchants only tag matching existing transactions ("Apply to this
/// one").
class AxioImportPreview {
  final List<AxioMerchantTag> recurring;
  final List<AxioMerchantTag> oneOff;
  final int rowsParsed; // data rows read from the file
  final int taggedRows; // rows that carried a usable (mappable) tag

  const AxioImportPreview({
    required this.recurring,
    required this.oneOff,
    required this.rowsParsed,
    required this.taggedRows,
  });

  bool get isEmpty => recurring.isEmpty && oneOff.isEmpty;
  int get merchantCount => recurring.length + oneOff.length;
}

/// What actually happened when a preview was applied.
class AxioImportResult {
  final int rulesCreated;
  final int rulesUpdated;
  final int transactionsTagged;

  const AxioImportResult({
    this.rulesCreated = 0,
    this.rulesUpdated = 0,
    this.transactionsTagged = 0,
  });

  bool get didNothing =>
      rulesCreated == 0 && rulesUpdated == 0 && transactionsTagged == 0;
}

/// Imports the *tags* (not the messages) from an Axio "Expense Report" CSV.
///
/// Re-tagging every merchant by hand is the tedious part of switching apps, so
/// this reads how Axio categorised each merchant and reproduces that knowledge
/// as Budgetify auto-tag rules + tags on the user's existing transactions. No
/// Axio transaction rows are inserted — the app still reconstructs spending
/// from the device's own SMS, preserving the offline/privacy model.
///
/// Recurring rule: a merchant that Axio tagged with one consistent category
/// **more than [recurringThreshold] times, and nothing else,** earns an
/// "Apply to All" rule. Any other tagged merchant is "Apply to this one" —
/// applied to matching existing transactions but not persisted as a rule.
class AxioImportService {
  final DatabaseService _db;

  AxioImportService([DatabaseService? db]) : _db = db ?? DatabaseService();

  /// "more than 5 times" → a category must be seen at least 6 times to become
  /// a rule.
  static const int recurringThreshold = 5;

  /// Axio category label → Budgetify category. Only genuine spending buckets
  /// are mapped; structural rows (UNKNOWN, CREDIT, TRANSFER, ACCOUNT TRANSFER
  /// and blanks) carry no reliable tag and are skipped.
  static const Map<String, String> categoryMap = {
    'FOOD & DRINKS': 'Food & Dining',
    'FOOD & DRINK': 'Food & Dining',
    'FOOD': 'Food & Dining',
    'GROCERIES': 'Groceries',
    'SHOPPING': 'Shopping',
    'TRAVEL': 'Travel',
    'TRANSPORT': 'Transportation',
    'TRANSPORTATION': 'Transportation',
    'BILLS': 'Bills & Utilities',
    'BILLS & UTILITIES': 'Bills & Utilities',
    'ENTERTAINMENT': 'Entertainment',
    'HEALTH': 'Health & Medical',
    'HEALTH & MEDICAL': 'Health & Medical',
    'MEDICAL': 'Health & Medical',
    'EDUCATION': 'Education',
  };

  // ── Parsing ───────────────────────────────────────────────────────────

  /// Parse raw CSV [content] into a preview. Never throws on messy data — bad
  /// rows are skipped — but throws [FormatException] if the file has no
  /// recognisable Axio header row.
  AxioImportPreview parsePreview(String content) {
    // Drop a leading UTF-8 BOM if the exporter added one.
    if (content.startsWith('\u{FEFF}')) content = content.substring(1);
    final rows = _readTaggedRows(content);

    // Group by (merchant, type) → category → count.
    final groups = <String, _MerchantGroup>{};
    for (final row in rows) {
      final key = '${row.type.index}|${_normalize(row.merchant)}';
      final group = groups.putIfAbsent(
        key,
        () => _MerchantGroup(row.merchant, row.type),
      );
      group.add(row.category);
    }

    final recurring = <AxioMerchantTag>[];
    final oneOff = <AxioMerchantTag>[];
    for (final group in groups.values) {
      // "nothing else": exactly one category ever seen for this merchant.
      if (group.categoryCounts.length != 1) continue;
      final entry = group.categoryCounts.entries.first;
      final tag = AxioMerchantTag(
        merchant: group.displayName,
        type: group.type,
        category: entry.key,
        count: entry.value,
      );
      if (entry.value > recurringThreshold) {
        recurring.add(tag);
      } else {
        oneOff.add(tag);
      }
    }

    // Most-seen merchants first — the ones worth the user's attention.
    recurring.sort((a, b) => b.count.compareTo(a.count));
    oneOff.sort((a, b) => b.count.compareTo(a.count));

    return AxioImportPreview(
      recurring: recurring,
      oneOff: oneOff,
      rowsParsed: rows.length,
      taggedRows: rows.length,
    );
  }

  /// Read the file down to the tagged data rows, mapping Axio categories to
  /// Budgetify ones and dropping anything without a usable tag.
  List<_TagRow> _readTaggedRows(String content) {
    final lines = content.split(RegExp(r'\r\n|\r|\n'));

    // Locate the column header row (…,PLACE,…,DR/CR,…,CATEGORY,…).
    int headerIndex = -1;
    List<String> header = const [];
    for (var i = 0; i < lines.length; i++) {
      final fields = _parseCsvLine(lines[i]).map(_norm).toList();
      final upper = fields.map((f) => f.toUpperCase()).toList();
      if (upper.contains('PLACE') && upper.contains('CATEGORY')) {
        headerIndex = i;
        header = upper;
        break;
      }
    }
    if (headerIndex == -1) {
      throw const FormatException(
        'This does not look like an Axio export — no PLACE/CATEGORY header row '
        'was found.',
      );
    }

    final placeCol = header.indexOf('PLACE');
    final categoryCol = header.indexOf('CATEGORY');
    final drCrCol = header.indexOf('DR/CR');

    final result = <_TagRow>[];
    for (var i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      final fields = _parseCsvLine(line);
      // Footer row ("POWERED BY axio …") and any short/garbled row.
      if (fields.length <= categoryCol || fields.length <= placeCol) continue;

      final merchant = _norm(fields[placeCol]);
      final rawCategory = _norm(fields[categoryCol]).toUpperCase();
      final category = categoryMap[rawCategory];
      if (merchant.isEmpty || category == null) continue;

      final drcr = drCrCol >= 0 && drCrCol < fields.length
          ? _norm(fields[drCrCol]).toUpperCase()
          : 'DR';
      final type = drcr == 'CR'
          ? TransactionType.credit
          : TransactionType.debit;

      result.add(_TagRow(_titleCase(merchant), type, category));
    }
    return result;
  }

  // ── Applying ──────────────────────────────────────────────────────────

  /// Write [preview] into the database: create/refresh rules for the recurring
  /// merchants, apply those rules to existing untagged transactions, then tag
  /// existing untagged transactions for the one-off merchants. Fires
  /// [notifyAppDataChanged] so live screens refresh.
  Future<AxioImportResult> apply(AxioImportPreview preview) async {
    var rulesCreated = 0;
    var rulesUpdated = 0;

    // "Apply to All": persistent rules for the frequent, consistent merchants.
    for (final tag in preview.recurring) {
      final existing = await _db.findExistingRule(tag.merchant, tag.type);
      if (existing == null) {
        await _db.insertTransactionRule(
          TransactionRule(
            senderName: tag.merchant,
            transactionType: tag.type,
            category: tag.category,
            isActive: true,
          ),
        );
        rulesCreated++;
      } else if (existing.category != tag.category || !existing.isActive) {
        // Refresh a stale/disabled rule to match what Axio believes.
        await _db.updateTransactionRule(
          existing.copyWith(category: tag.category, isActive: true),
        );
        rulesUpdated++;
      }
    }

    // Make sure historical rows have merchant names, then let the freshly
    // created rules tag every matching untagged transaction (past + future).
    var tagged = 0;
    if (preview.recurring.isNotEmpty) {
      await _db.backfillMerchantNames();
      tagged += await _db.applyRulesToUntagged();
    }

    // "Apply to this one": tag matching untagged transactions for the
    // occasional merchants, without committing to a forever-rule.
    for (final tag in preview.oneOff) {
      tagged += await _db.tagUntaggedByMerchant(
        merchant: tag.merchant,
        type: tag.type,
        category: tag.category,
      );
    }

    final result = AxioImportResult(
      rulesCreated: rulesCreated,
      rulesUpdated: rulesUpdated,
      transactionsTagged: tagged,
    );
    if (!result.didNothing) notifyAppDataChanged();
    return result;
  }

  // ── CSV / text helpers ────────────────────────────────────────────────

  /// Split one CSV line into fields, honouring double-quoted values and
  /// escaped quotes (""). Axio wraps every field in quotes and comma-separates
  /// them; amounts like "5,000" therefore stay intact.
  @visibleForTesting
  static List<String> parseCsvLine(String line) => _parseCsvLine(line);

  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++; // skip the escaped quote
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }

  /// Trim a field and drop the leading apostrophe Excel/Axio use to force text
  /// (e.g. "'-", "'+9188…").
  static String _norm(String value) {
    var v = value.trim();
    if (v.startsWith("'")) v = v.substring(1).trim();
    return v;
  }

  /// Normalize a merchant name for grouping — mirrors [TransactionRule] so two
  /// spellings of the same payee collapse together.
  static String _normalize(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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
}

/// A single tagged observation read from the file.
class _TagRow {
  final String merchant;
  final TransactionType type;
  final String category;
  const _TagRow(this.merchant, this.type, this.category);
}

/// Accumulates the categories seen for one merchant+type while parsing.
class _MerchantGroup {
  final String displayName;
  final TransactionType type;
  final Map<String, int> categoryCounts = {};

  _MerchantGroup(this.displayName, this.type);

  void add(String category) {
    categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
  }
}
