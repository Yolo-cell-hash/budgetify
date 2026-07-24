import 'package:shared_preferences/shared_preferences.dart';

import '../models/financial_year.dart';
import '../models/tax_bucket.dart';
import '../models/tax_export.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';

/// One bucket's standing for a financial year: how much is tagged, and — for
/// capped buckets only — the cap and headroom. Evidence-only buckets carry a
/// total but no cap, and the UI must present that total as *organised
/// evidence*, never as "the deduction".
class TaxBucketSummary {
  final TaxBucket bucket;

  /// Sum of tagged transactions in the FY (whole-rupee-agnostic; rupees).
  final double total;

  /// Effective cap (default or user-overridden) for capped buckets; null for
  /// evidence-only.
  final int? cap;

  const TaxBucketSummary({
    required this.bucket,
    required this.total,
    required this.cap,
  });

  bool get isCapped => bucket.isCapped && cap != null;

  /// Remaining headroom under the cap, floored at zero. Null when uncapped.
  double? get headroom => isCapped ? (cap! - total).clamp(0, cap!.toDouble()) : null;

  /// Fill fraction 0..1 for the progress bar. Null when uncapped.
  double? get fillFraction {
    if (!isCapped || cap! <= 0) return null;
    return (total / cap!).clamp(0.0, 1.0);
  }

  /// Whether tagged spend has met or exceeded the cap.
  bool get isFull => isCapped && total >= cap!;
}

/// The Tax screen's whole view-model for a financial year.
class TaxYearSummary {
  final FinancialYear year;
  final TaxRegime regime;
  final List<TaxBucketSummary> buckets;

  const TaxYearSummary({
    required this.year,
    required this.regime,
    required this.buckets,
  });

  /// Whether anything is tagged at all this year (drives empty states and
  /// whether the seasonal Home card has something to say).
  bool get hasAnyTagged => buckets.any((b) => b.total > 0);
}

/// Tax buckets' state and math. Deliberately separate from AppPreferences so
/// it stays off the first-frame-critical init path and keeps all tax logic in
/// one isolated place. Everything is lazy: nothing is read until the Tax
/// screen (or the seasonal card) asks.
///
/// This is a record-keeper, not a tax advisor: it sums what the user tagged
/// and compares to statutory caps. It never computes tax liability or advises
/// which regime to choose.
class TaxService {
  static final TaxService _instance = TaxService._internal();
  factory TaxService() => _instance;
  TaxService._internal();

  final DatabaseService _db = DatabaseService();

  static const String _regimeKey = 'tax_regime';
  static const String _capPrefix = 'tax_cap_'; // + bucket id

  // ── Regime ────────────────────────────────────────────────────────────────

  Future<TaxRegime> getRegime() async {
    final prefs = await SharedPreferences.getInstance();
    return TaxRegime.fromStorage(prefs.getString(_regimeKey));
  }

  Future<void> setRegime(TaxRegime regime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regimeKey, regime.storageKey);
  }

  // ── Cap overrides ───────────────────────────────────────────────────────────

  /// The effective cap for a capped bucket: the user's override if set,
  /// otherwise the statutory default. Null for evidence-only buckets.
  Future<int?> effectiveCap(TaxBucket bucket) async {
    if (!bucket.isCapped) return null;
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getInt('$_capPrefix${bucket.id}');
    return override ?? bucket.defaultCapInr;
  }

  /// Override a bucket's cap (limits change most budgets). Passing null clears
  /// the override, reverting to the statutory default.
  Future<void> setCapOverride(String bucketId, int? cap) async {
    final prefs = await SharedPreferences.getInstance();
    if (cap == null) {
      await prefs.remove('$_capPrefix$bucketId');
    } else {
      await prefs.setInt('$_capPrefix$bucketId', cap);
    }
  }

  // ── Summary ─────────────────────────────────────────────────────────────────

  /// The full view-model for [year]: regime plus every bucket's total and cap.
  Future<TaxYearSummary> summaryForYear(FinancialYear year) async {
    final regime = await getRegime();
    final totals = await _db.sumByTaxBucket(
      start: year.start,
      endExclusive: year.endExclusive,
    );

    final summaries = <TaxBucketSummary>[];
    for (final bucket in kTaxBuckets) {
      summaries.add(TaxBucketSummary(
        bucket: bucket,
        total: totals[bucket.id] ?? 0,
        cap: await effectiveCap(bucket),
      ));
    }
    return TaxYearSummary(year: year, regime: regime, buckets: summaries);
  }

  // ── Auto-suggest (Phase 2) ──────────────────────────────────────────────────

  /// The bucket to suggest for [payee], or null. A user-taught rule wins (it's
  /// an explicit choice); otherwise the built-in keyword map. Suggestion only —
  /// the caller confirms before tagging.
  Future<String?> suggestionFor(String? payee) async {
    if (payee == null || payee.isEmpty) return null;
    final rule = await _db.findMatchingTaxRule(payee);
    if (rule != null && taxBucketById(rule) != null) return rule;
    return suggestTaxBucketFromPayee(payee);
  }

  /// "Apply to all from [payee] → [bucket]": remember the rule and tag every
  /// existing untagged transaction from that payee. Returns how many rows were
  /// bulk-tagged (excluding the one the user just tagged, which is already
  /// set). Only call for an identifying payee ([isIdentifyingTaxPayee]).
  Future<int> saveRuleAndApply(String payee, String bucket) async {
    await _db.upsertTaxRule(payee, bucket);
    return _db.bulkSetTaxBucketByPayee(payee, bucket);
  }

  /// The lazy "forever" sweep: apply user rules to any transaction that has no
  /// bucket yet. Run when the Tax screen opens, so a rule taught once keeps
  /// catching future transactions without touching the SMS insert path.
  Future<int> applyRulesToUntagged() => _db.applyTaxRulesToUntagged();

  // ── Backup ──────────────────────────────────────────────────────────────────

  /// Regime + cap overrides for the encrypted backup payload. (Transaction
  /// tax tags ride the transactions table dump automatically.)
  Future<Map<String, dynamic>> exportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final caps = <String, int>{};
    for (final b in kTaxBuckets) {
      final c = prefs.getInt('$_capPrefix${b.id}');
      if (c != null) caps[b.id] = c;
    }
    return {'regime': prefs.getString(_regimeKey), 'caps': caps};
  }

  /// Restore regime + cap overrides from a backup. Null/absent is a no-op, so
  /// restoring an older backup that predates this feature changes nothing.
  Future<void> importSettings(Map<String, dynamic>? data) async {
    if (data == null) return;
    final prefs = await SharedPreferences.getInstance();
    final regime = data['regime'] as String?;
    if (regime != null) await prefs.setString(_regimeKey, regime);
    final caps = (data['caps'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final entry in caps.entries) {
      final v = entry.value;
      if (v is int) await prefs.setInt('$_capPrefix${entry.key}', v);
    }
  }

  /// Contributing transactions for one bucket in [year] (newest first).
  Future<List<TransactionModel>> transactionsFor(
    String bucketId,
    FinancialYear year,
  ) =>
      _db.transactionsForTaxBucket(
        bucketId: bucketId,
        start: year.start,
        endExclusive: year.endExclusive,
      );

  /// Assemble the self-contained payload the Tax Summary export renders — every
  /// bucket with its total, cap and contributing rows for [year]. Sections with
  /// no tagged transactions are still included (as empty) so the export shows
  /// the full picture; the caller checks [TaxSummaryInput.hasAnyEntries].
  Future<TaxSummaryInput> buildTaxSummaryInput(FinancialYear year) async {
    final summary = await summaryForYear(year);
    final sections = <TaxSummarySection>[];
    for (final s in summary.buckets) {
      final txns = await transactionsFor(s.bucket.id, year);
      sections.add(TaxSummarySection(
        id: s.bucket.id,
        section: s.bucket.section,
        shortLabel: s.bucket.shortLabel,
        isCapped: s.bucket.isCapped,
        total: s.total,
        cap: s.cap,
        entries: [
          for (final t in txns)
            TaxSummaryEntry(
              date: t.detectedAt,
              payee: t.merchantName ?? t.sender,
              amount: t.amount,
            ),
        ],
      ));
    }
    return TaxSummaryInput(fyLabel: year.label, sections: sections);
  }
}
