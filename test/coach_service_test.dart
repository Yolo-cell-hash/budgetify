import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/coach_service.dart';

void main() {
  group('CoachStats.median / mad (robust estimators)', () {
    test('median handles odd and even lengths', () {
      expect(CoachStats.median([3, 1, 2]), 2);
      expect(CoachStats.median([1, 2, 3, 4]), 2.5);
      expect(CoachStats.median([]), 0);
    });

    test('median is unmoved by a single extreme value (unlike the mean)', () {
      final base = [100.0, 110.0, 105.0, 95.0, 100.0];
      final withOutlier = [...base, 100000.0];
      // The mean would explode; the median barely moves.
      expect(CoachStats.median(withOutlier), closeTo(102.5, 0.01));
    });

    test('mad measures spread around the median', () {
      // deviations from median(=3) are [2,1,0,1,2] → median 1
      expect(CoachStats.mad([1, 2, 3, 4, 5], 3), 1);
      // identical values → zero spread
      expect(CoachStats.mad([199, 199, 199], 199), 0);
    });
  });

  group('CoachStats.spikeUp (upward category spike)', () {
    test('fires on a genuine +40% material rise', () {
      expect(CoachStats.spikeUp(current: 4200, baseline: 3000), isTrue);
    });

    test('does NOT fire on a large % but tiny rupee change (₹20 → ₹80)', () {
      // +300% but only ₹60, and the baseline is below the category floor.
      expect(CoachStats.spikeUp(current: 80, baseline: 20), isFalse);
    });

    test('does NOT fire when the rupee change is below the floor', () {
      // +41% on a ₹1000 baseline = ₹410 < ₹750 floor.
      expect(CoachStats.spikeUp(current: 1410, baseline: 1000), isFalse);
    });

    test('does NOT fire when the baseline category is too small', () {
      // 2× rise but the baseline (₹600) is under catFloor (₹1000).
      expect(CoachStats.spikeUp(current: 1200, baseline: 600), isFalse);
    });

    test('does NOT fire on a modest +20% rise', () {
      expect(CoachStats.spikeUp(current: 3600, baseline: 3000), isFalse);
    });
  });

  group('CoachStats.spikeDown (encouraging drop)', () {
    test('fires on a genuine 40%+ drop in a material category', () {
      expect(CoachStats.spikeDown(current: 1500, baseline: 3000), isTrue);
    });

    test('does NOT fire on a small drop', () {
      expect(CoachStats.spikeDown(current: 2700, baseline: 3000), isFalse);
    });
  });

  group('CoachStats.isLargeOutlier (robust single-transaction outlier)', () {
    // A typical "Shopping" history clustered around ₹800.
    final shopping = [700.0, 850.0, 800.0, 900.0, 750.0, 820.0, 780.0, 810.0];

    test('flags a clear 6× outlier', () {
      expect(
        CoachStats.isLargeOutlier(amount: 5000, history: shopping),
        isTrue,
      );
    });

    test('does not flag an ordinary transaction within the usual range', () {
      expect(
        CoachStats.isLargeOutlier(amount: 900, history: shopping),
        isFalse,
      );
    });

    test('stays silent without enough history (< 8 samples)', () {
      expect(
        CoachStats.isLargeOutlier(amount: 9000, history: [800, 750, 820]),
        isFalse,
      );
    });

    test('never flags below the absolute rupee floor, even if proportionally big', () {
      // 10× the usual but only ₹1500 — under the ₹2000 floor.
      final tiny = [150.0, 160.0, 140.0, 155.0, 145.0, 150.0, 158.0, 142.0];
      expect(
        CoachStats.isLargeOutlier(amount: 1500, history: tiny),
        isFalse,
      );
    });

    test('fixed-price subscription (MAD = 0): the ratio guard prevents a false alarm', () {
      // Always ₹199 → MAD 0. A ₹250 charge must NOT flag (ratio < 2.5×)…
      final sub = List<double>.filled(10, 199);
      expect(CoachStats.isLargeOutlier(amount: 250, history: sub), isFalse);
      // …but a genuine ₹2500 charge (12.5×, over the floor) should.
      expect(CoachStats.isLargeOutlier(amount: 2500, history: sub), isTrue);
    });
  });

  group('CoachStats.pacesOver / pacesUnder', () {
    test('over fires only with both a ratio and a rupee gap', () {
      expect(CoachStats.pacesOver(projected: 60000, typical: 50000), isTrue);
      // +12% is under the 15% ratio.
      expect(CoachStats.pacesOver(projected: 56000, typical: 50000), isFalse);
      // big ratio but tiny absolute gap.
      expect(CoachStats.pacesOver(projected: 1300, typical: 1000), isFalse);
    });

    test('under fires on a meaningfully lighter month', () {
      expect(CoachStats.pacesUnder(projected: 40000, typical: 50000), isTrue);
      expect(CoachStats.pacesUnder(projected: 49000, typical: 50000), isFalse);
    });

    test('no baseline (typical 0) never paces', () {
      expect(CoachStats.pacesOver(projected: 5000, typical: 0), isFalse);
      expect(CoachStats.pacesUnder(projected: 0, typical: 0), isFalse);
    });
  });
}
