/// Self-contained snapshot for the filing-season Tax Summary export, so the
/// renderer (ExportService) needs neither the DB nor the tax prefs — it just
/// lays out what it's handed. Assembled by TaxService.buildTaxSummaryInput.
library;

/// One contributing transaction under a bucket.
class TaxSummaryEntry {
  final DateTime date;
  final String payee;
  final double amount;
  const TaxSummaryEntry(
      {required this.date, required this.payee, required this.amount});
}

/// One deduction section with its total and contributing rows.
class TaxSummarySection {
  final String id; // '80C'
  final String section; // 'Section 80C'
  final String shortLabel; // 'Investments & insurance'
  final bool isCapped;
  final double total;

  /// Statutory cap for capped sections; null for evidence-only.
  final int? cap;

  final List<TaxSummaryEntry> entries;

  const TaxSummarySection({
    required this.id,
    required this.section,
    required this.shortLabel,
    required this.isCapped,
    required this.total,
    required this.cap,
    required this.entries,
  });

  bool get hasEntries => entries.isNotEmpty;
}

/// The whole export payload for one financial year.
class TaxSummaryInput {
  final String fyLabel; // 'FY 2025-26'
  final List<TaxSummarySection> sections;

  const TaxSummaryInput({required this.fyLabel, required this.sections});

  /// Whether anything is tagged at all — the export is refused when false.
  bool get hasAnyEntries => sections.any((s) => s.hasEntries);

  /// A short slug for the filename, e.g. '2025_26'.
  String get fileSlug =>
      fyLabel.replaceAll('FY ', '').replaceAll('-', '_').replaceAll(' ', '');
}
