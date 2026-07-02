import 'transaction_model.dart';

/// What a column in a bank-statement file means.
///
/// [balance] exists so a "Closing Balance" column can be *recognised* (it
/// helps header detection) — its values are deliberately never read or
/// stored: Budgetify does not track bank balances by product decision.
enum StatementColumnRole {
  date,
  description,
  debit,
  credit,
  amount,
  drCr,
  refNo,
  balance,
  ignore,
}

/// How each column index of a statement grid maps to a [StatementColumnRole],
/// plus the inferred date format for the date column.
class StatementMapping {
  /// Column index → role. Unmapped columns are treated as [StatementColumnRole.ignore].
  final Map<int, StatementColumnRole> roles;

  /// `intl` pattern for the date column (e.g. `dd/MM/yy`), null until inferred.
  final String? dateFormat;

  const StatementMapping({required this.roles, this.dateFormat});

  int? columnFor(StatementColumnRole role) {
    for (final e in roles.entries) {
      if (e.value == role) return e.key;
    }
    return null;
  }

  bool get hasDate => columnFor(StatementColumnRole.date) != null;

  bool get hasMoney =>
      columnFor(StatementColumnRole.debit) != null ||
      columnFor(StatementColumnRole.credit) != null ||
      columnFor(StatementColumnRole.amount) != null;

  /// A usable mapping needs a date and at least one money column.
  bool get isValid => hasDate && hasMoney;

  StatementMapping copyWith({
    Map<int, StatementColumnRole>? roles,
    String? dateFormat,
  }) =>
      StatementMapping(
        roles: roles ?? this.roles,
        dateFormat: dateFormat ?? this.dateFormat,
      );
}

/// Outcome of parsing one data row of the statement.
enum StatementRowStatus {
  /// Parses cleanly and doesn't match anything already in the database.
  ready,

  /// Same type + amount within ±1 day of an existing transaction — most
  /// likely the SMS pipeline already captured it. Excluded by default,
  /// user-overridable per row.
  probableDuplicate,

  /// Couldn't be read (bad date, no amount, both debit and credit, …).
  invalid,
}

/// One parsed statement line, carrying everything needed to build a
/// [TransactionModel] plus review-screen state.
class StatementRow {
  /// 0-based index into the raw grid, for stable identity in the UI.
  final int sourceRow;

  final DateTime? date;

  /// Mutable: statements sometimes wrap a long narration onto continuation
  /// lines, which the parser folds back into the row above.
  String narration;

  /// Bank reference / cheque / UTR number; empty when the file has none.
  /// Included in the stored message so two same-day, same-amount payments to
  /// the same payee still fingerprint differently.
  final String refNo;

  /// Positive rupee amount. Null only for invalid rows.
  final double? amount;

  final TransactionType? type;

  /// Payee extracted from the narration, when one could be found.
  final String? merchant;

  /// Category from the shared merchant-keyword table, when one matched.
  final String? autoCategory;

  StatementRowStatus status;

  /// Whether this row will be imported. Ready rows default to true,
  /// probable duplicates to false, invalid rows are never importable.
  bool include;

  /// Human-readable reason when [status] is [StatementRowStatus.invalid].
  final String? invalidReason;

  StatementRow({
    required this.sourceRow,
    required this.date,
    required this.narration,
    this.refNo = '',
    this.amount,
    this.type,
    this.merchant,
    this.autoCategory,
    this.status = StatementRowStatus.ready,
    bool? include,
    this.invalidReason,
  }) : include = include ?? (status == StatementRowStatus.ready);

  bool get isImportable =>
      status != StatementRowStatus.invalid &&
      date != null &&
      amount != null &&
      type != null;
}

/// Everything the review step needs: the parsed rows plus context about the
/// device's own transaction history.
class StatementParseResult {
  final List<StatementRow> rows;
  final StatementMapping mapping;
  final int headerRowIndex;

  StatementParseResult({
    required this.rows,
    required this.mapping,
    required this.headerRowIndex,
  });

  Iterable<StatementRow> get ready =>
      rows.where((r) => r.status == StatementRowStatus.ready);
  Iterable<StatementRow> get duplicates =>
      rows.where((r) => r.status == StatementRowStatus.probableDuplicate);
  Iterable<StatementRow> get invalid =>
      rows.where((r) => r.status == StatementRowStatus.invalid);
}

/// What actually happened when the rows were written.
class StatementImportResult {
  /// Rows inserted as new transactions.
  final int inserted;

  /// Rows skipped because an identical import already exists (re-imported
  /// file) or the user previously deleted the same row (tombstone).
  final int skippedExisting;

  /// Transactions tagged by the user's saved rules right after the insert.
  final int autoTagged;

  const StatementImportResult({
    this.inserted = 0,
    this.skippedExisting = 0,
    this.autoTagged = 0,
  });
}

/// A key describing an existing on-device transaction, used to flag probable
/// duplicates between statement rows and SMS-captured history without keeping
/// full models in memory.
class ExistingTxnKey {
  final TransactionType type;

  /// Amount in paise so equality is exact.
  final int amountPaise;
  final DateTime date;

  const ExistingTxnKey({
    required this.type,
    required this.amountPaise,
    required this.date,
  });

  factory ExistingTxnKey.fromTransaction(TransactionModel t) => ExistingTxnKey(
        type: t.type,
        amountPaise: (t.amount * 100).round(),
        date: t.detectedAt,
      );
}
