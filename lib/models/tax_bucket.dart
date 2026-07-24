/// Tax deduction "buckets" — a second, orthogonal label on a transaction, next
/// to its spending category. One ₹12,000 LIC payment is category *Insurance*
/// AND tax bucket *80D*.
///
/// PLAN: `docs/tax-buckets-plan.md`. This is a record-keeping aid, NOT tax
/// advice — the app tags and totals what the user marks; it never computes tax
/// liability or asserts an amount is deductible.
library;

/// Which regime the user files under. The new regime (default since FY23-24)
/// disallows almost all of these deductions, so the whole feature is gated on
/// this: new-regime users are shown an honest explainer, not buckets that
/// imply savings they can't claim.
enum TaxRegime {
  /// Old regime — deductions apply. Full feature.
  old,

  /// New regime — most Chapter VI-A deductions don't apply. Feature suppressed.
  newRegime,

  /// Not stated yet (the default). Treated as "show the feature" so a user who
  /// never sets it still gets value, with a gentle prompt to confirm.
  unsure;

  String get storageKey => switch (this) {
        TaxRegime.old => 'old',
        TaxRegime.newRegime => 'new',
        TaxRegime.unsure => 'unsure',
      };

  static TaxRegime fromStorage(String? v) => switch (v) {
        'old' => TaxRegime.old,
        'new' => TaxRegime.newRegime,
        _ => TaxRegime.unsure,
      };

  /// Whether the deduction buckets should be shown at all.
  bool get showsBuckets => this != TaxRegime.newRegime;
}

/// Two kinds, because honesty requires the distinction:
enum TaxBucketKind {
  /// A flat statutory ceiling the app can legitimately sum against and show a
  /// filled-vs-cap bar (80C, 80D, 80CCD(1B), 24b).
  cappedDeduction,

  /// The deductible figure is NOT the sum of payments — it depends on inputs
  /// the app doesn't hold (HRA needs salary; 80G varies 50%/100% per donee).
  /// The app organises evidence and shows the total, but must NEVER present
  /// that total as "the deduction".
  evidenceOnly,
}

/// One deduction section. [id] is stable and persisted in
/// `transactions.tax_bucket`; the English [section]/[shortLabel] are the
/// fallback/export text (per-bucket localization can follow — the screen
/// chrome and disclaimer are already localized in all six languages).
class TaxBucket {
  final String id;
  final String section;
  final String shortLabel;
  final TaxBucketKind kind;

  /// Statutory ceiling in whole rupees for [TaxBucketKind.cappedDeduction];
  /// null for evidence-only buckets. The *effective* cap can be overridden by
  /// the user (limits change most budgets) — see TaxService.
  final int? defaultCapInr;

  const TaxBucket({
    required this.id,
    required this.section,
    required this.shortLabel,
    required this.kind,
    this.defaultCapInr,
  });

  bool get isCapped => kind == TaxBucketKind.cappedDeduction;
}

/// The Phase-1 catalog: the six most-used deductions (owner decision). 80E
/// (education-loan interest) and 80TTA/80TTB/80CCD(2) are deliberately out —
/// each is a one-row add later, no schema change.
///
/// Order is display order on the Tax screen: capped first (they have the
/// satisfying fill bars), evidence-only last.
const List<TaxBucket> kTaxBuckets = [
  TaxBucket(
    id: '80C',
    section: 'Section 80C',
    shortLabel: 'Investments & insurance',
    kind: TaxBucketKind.cappedDeduction,
    defaultCapInr: 150000,
  ),
  TaxBucket(
    id: '80CCD1B',
    section: 'Section 80CCD(1B)',
    shortLabel: 'NPS (over 80C)',
    kind: TaxBucketKind.cappedDeduction,
    defaultCapInr: 50000,
  ),
  TaxBucket(
    id: '80D',
    section: 'Section 80D',
    shortLabel: 'Health insurance',
    kind: TaxBucketKind.cappedDeduction,
    defaultCapInr: 25000,
  ),
  TaxBucket(
    id: '24B',
    section: 'Section 24(b)',
    shortLabel: 'Home-loan interest',
    kind: TaxBucketKind.cappedDeduction,
    defaultCapInr: 200000,
  ),
  TaxBucket(
    id: 'HRA',
    section: 'HRA / 80GG',
    shortLabel: 'Rent paid',
    kind: TaxBucketKind.evidenceOnly,
  ),
  TaxBucket(
    id: '80G',
    section: 'Section 80G',
    shortLabel: 'Donations',
    kind: TaxBucketKind.evidenceOnly,
  ),
];

/// Bucket for [id], or null if it isn't one we know (e.g. a row tagged by a
/// future version and then opened in an older one — fail safe, don't guess).
TaxBucket? taxBucketById(String? id) {
  if (id == null) return null;
  for (final b in kTaxBuckets) {
    if (b.id == id) return b;
  }
  return null;
}

/// Valid bucket ids, for validation at the tagging boundary.
final Set<String> kTaxBucketIds = {for (final b in kTaxBuckets) b.id};
