import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/tax_bucket.dart';
import 'package:budget_tracker/services/tax_service.dart';

void main() {
  group('catalog', () {
    test('exactly the six Phase-1 buckets, 80E deliberately absent', () {
      expect(kTaxBuckets.length, 6);
      expect(kTaxBucketIds, {'80C', '80CCD1B', '80D', '24B', 'HRA', '80G'});
      expect(kTaxBucketIds.contains('80E'), isFalse);
    });

    test('capped buckets carry a cap, evidence-only ones do not', () {
      for (final b in kTaxBuckets) {
        if (b.kind == TaxBucketKind.cappedDeduction) {
          expect(b.defaultCapInr, isNotNull, reason: '${b.id} needs a cap');
        } else {
          expect(b.defaultCapInr, isNull, reason: '${b.id} must not imply a cap');
        }
      }
    });

    test('HRA and 80G are evidence-only — never presented as a capped deduction', () {
      expect(taxBucketById('HRA')!.kind, TaxBucketKind.evidenceOnly);
      expect(taxBucketById('80G')!.kind, TaxBucketKind.evidenceOnly);
      expect(taxBucketById('80C')!.isCapped, isTrue);
    });

    test('lookup by id fails safe on unknown ids', () {
      expect(taxBucketById('80EEE'), isNull);
      expect(taxBucketById(null), isNull);
      expect(taxBucketById('80C')!.section, 'Section 80C');
    });
  });

  group('regime', () {
    test('new regime suppresses buckets; old and unsure show them', () {
      expect(TaxRegime.newRegime.showsBuckets, isFalse);
      expect(TaxRegime.old.showsBuckets, isTrue);
      expect(TaxRegime.unsure.showsBuckets, isTrue);
    });

    test('storage round-trips, unknown decodes to unsure', () {
      for (final r in TaxRegime.values) {
        expect(TaxRegime.fromStorage(r.storageKey), r);
      }
      expect(TaxRegime.fromStorage(null), TaxRegime.unsure);
      expect(TaxRegime.fromStorage('garbage'), TaxRegime.unsure);
    });
  });

  group('TaxBucketSummary math', () {
    TaxBucketSummary capped(double total, int cap) => TaxBucketSummary(
          bucket: taxBucketById('80C')!,
          total: total,
          cap: cap,
        );

    test('headroom and fill for a partially used cap', () {
      final s = capped(90000, 150000);
      expect(s.isCapped, isTrue);
      expect(s.headroom, 60000);
      expect(s.fillFraction, closeTo(0.6, 1e-9));
      expect(s.isFull, isFalse);
    });

    test('over-cap clamps: headroom floors at 0, fill caps at 1', () {
      final s = capped(200000, 150000);
      expect(s.headroom, 0);
      expect(s.fillFraction, 1.0);
      expect(s.isFull, isTrue);
    });

    test('evidence-only bucket exposes no cap, headroom, or fill', () {
      final s = TaxBucketSummary(
        bucket: taxBucketById('HRA')!,
        total: 120000,
        cap: null,
      );
      expect(s.isCapped, isFalse);
      expect(s.headroom, isNull);
      expect(s.fillFraction, isNull);
      expect(s.total, 120000);
    });
  });

  group('keyword suggestions (Phase 2)', () {
    test('life insurers suggest 80C', () {
      expect(suggestTaxBucketFromPayee('LIC of India'), '80C');
      expect(suggestTaxBucketFromPayee('HDFC Life'), '80C');
      expect(suggestTaxBucketFromPayee('SBI Life Insurance'), '80C');
    });

    test('health insurers suggest 80D', () {
      expect(suggestTaxBucketFromPayee('Star Health'), '80D');
      expect(suggestTaxBucketFromPayee('Niva Bupa'), '80D');
      expect(suggestTaxBucketFromPayee('HDFC Ergo'), '80D');
    });

    test('NPS suggests 80CCD1B', () {
      expect(suggestTaxBucketFromPayee('National Pension System'), '80CCD1B');
      expect(suggestTaxBucketFromPayee('Protean NPS'), '80CCD1B');
    });

    test('matching is punctuation/spacing-insensitive', () {
      expect(suggestTaxBucketFromPayee('h.d.f.c-life'), '80C');
    });

    test('unknown payee and non-identifying input suggest nothing', () {
      expect(suggestTaxBucketFromPayee('Swiggy'), isNull);
      expect(suggestTaxBucketFromPayee('UPI Transfer'), isNull);
      expect(suggestTaxBucketFromPayee(''), isNull);
      expect(suggestTaxBucketFromPayee(null), isNull);
    });

    test('every suggested bucket id is a real bucket', () {
      for (final id in kTaxSuggestionKeywords.values) {
        expect(kTaxBucketIds.contains(id), isTrue, reason: '$id must exist');
      }
    });
  });

  group('isIdentifyingTaxPayee (apply-to-all guard)', () {
    test('real names qualify', () {
      expect(isIdentifyingTaxPayee('LIC of India'), isTrue);
      expect(isIdentifyingTaxPayee('Star Health'), isTrue);
    });

    test('placeholders and masked accounts do not', () {
      expect(isIdentifyingTaxPayee('UPI Transfer'), isFalse);
      expect(isIdentifyingTaxPayee('ATM'), isFalse);
      expect(isIdentifyingTaxPayee('Bank Charges'), isFalse);
      expect(isIdentifyingTaxPayee('XX7848'), isFalse);
      expect(isIdentifyingTaxPayee('**1234'), isFalse);
      expect(isIdentifyingTaxPayee(null), isFalse);
      expect(isIdentifyingTaxPayee(''), isFalse);
    });
  });
}
