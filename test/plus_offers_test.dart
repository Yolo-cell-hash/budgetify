import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/models/plus_offers.dart';
import 'package:budget_tracker/models/plus_products.dart';
import 'package:budget_tracker/services/entitlement_service.dart';

/// Offer windows decide when the paywall may show a struck-through price, so
/// the thing under test is really a claim about honesty: the base price has to
/// be what applies on an ordinary day, and a discount may only be advertised
/// inside a window that a real Play offer is expected to mirror.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int daysAgo(int n) => DateTime.now()
      .subtract(Duration(days: n))
      .millisecondsSinceEpoch;

  group('festive windows', () {
    test('an ordinary day carries no offer', () {
      // Mid-July, mid-February, mid-June: nowhere near a festival.
      expect(activeFestiveOffer(DateTime(2026, 7, 15)), isNull);
      expect(activeFestiveOffer(DateTime(2027, 2, 10)), isNull);
      expect(activeFestiveOffer(DateTime(2028, 6, 1)), isNull);
    });

    test('Diwali opens a week either side of the anchor', () {
      // Diwali 2026 falls on 8 Nov, so ±7 days spans 1–15 Nov.
      expect(activeFestiveOffer(DateTime(2026, 11, 8))?.id, 'diwali');
      expect(activeFestiveOffer(DateTime(2026, 11, 1))?.id, 'diwali');
      expect(activeFestiveOffer(DateTime(2026, 11, 15))?.id, 'diwali');
      // …and stays shut outside it.
      expect(activeFestiveOffer(DateTime(2026, 10, 31)), isNull);
      expect(activeFestiveOffer(DateTime(2026, 11, 16)), isNull);
    });

    test('the buffer absorbs a panchang date that shifts by a day or two', () {
      // The anchors are approximate by design. Whether Diwali 2027 lands on
      // 28, 29 or 30 October, the window is open.
      for (final day in [28, 29, 30]) {
        expect(activeFestiveOffer(DateTime(2027, 10, day))?.id, 'diwali');
      }
    });

    test('Christmas runs through to New Year, across the year boundary', () {
      expect(activeFestiveOffer(DateTime(2026, 12, 24))?.id, 'newyear');
      expect(activeFestiveOffer(DateTime(2026, 12, 31))?.id, 'newyear');
      expect(activeFestiveOffer(DateTime(2027, 1, 1))?.id, 'newyear');
      // Closes on 2 Jan; 23 Dec is still the everyday price.
      expect(activeFestiveOffer(DateTime(2027, 1, 2)), isNull);
      expect(activeFestiveOffer(DateTime(2026, 12, 23)), isNull);
    });

    test('Holi opens a window too', () {
      expect(activeFestiveOffer(DateTime(2027, 3, 23))?.id, 'holi');
      expect(activeFestiveOffer(DateTime(2028, 3, 11))?.id, 'holi');
    });

    test('a year with no anchor falls back to the base price, not a discount',
        () {
      // The tables stop after 2030/2031. Running past them must fail CLOSED —
      // showing full price is recoverable, advertising a discount Play is not
      // running is not.
      expect(activeFestiveOffer(DateTime(2040, 10, 25)), isNull);
      expect(activeFestiveOffer(DateTime(2040, 3, 15)), isNull);
      // The fixed New Year window still works, since it needs no table.
      expect(activeFestiveOffer(DateTime(2040, 12, 26))?.id, 'newyear');
    });

    test('offers cover only a small slice of the year', () {
      // The strikethrough is only honest while the base price is what
      // normally applies. Sample every day of 2027 and assert the discount
      // runs well under a fifth of it.
      var discounted = 0;
      for (var d = DateTime(2027, 1, 1);
          d.year == 2027;
          d = d.add(const Duration(days: 1))) {
        if (activeFestiveOffer(d) != null) discounted++;
      }
      expect(discounted, lessThan(60)); // ~40 days: Diwali + Holi + New Year
      expect(discounted, greaterThan(20)); // …but the campaigns do run
    });
  });

  group('welcome week', () {
    final svc = EntitlementService();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      svc.resetForTest();
    });

    test('runs for seven days once the free window closes', () async {
      // First launch 91 days ago: the 90-day trial closed yesterday.
      SharedPreferences.setMockInitialValues({
        'entitlement_first_launch_at': daysAgo(91),
      });
      await svc.initialize();

      expect(svc.trialActive, isFalse);
      final offer = svc.activeOffer;
      expect(offer, isNotNull);
      expect(offer!.id, 'welcome');
      expect(offer.kind, PlusOfferKind.welcome);
    });

    test('has closed by the time the trial is long over', () async {
      SharedPreferences.setMockInitialValues({
        'entitlement_first_launch_at': daysAgo(200),
      });
      await svc.initialize();

      expect(svc.trialActive, isFalse);
      // 200 days in, the welcome week is 103 days gone. Only a festival could
      // reopen a discount, and offerAt() is pinned here to an ordinary day.
      expect(svc.offerAt(DateTime(2026, 7, 15)), isNull);
    });

    test('does not run while the free window is still open', () async {
      SharedPreferences.setMockInitialValues({
        'entitlement_first_launch_at': daysAgo(10),
      });
      await svc.initialize();

      expect(svc.trialActive, isTrue);
      expect(svc.offerAt(DateTime(2026, 7, 15)), isNull);
    });
  });

  group('offer prices', () {
    test('every plan discounts to the agreed offer price', () {
      expect(PlusPlan.monthly.priceInr, 49);
      expect(PlusPlan.monthly.offerPriceInr, 29);
      expect(PlusPlan.yearly.priceInr, 499);
      expect(PlusPlan.yearly.offerPriceInr, 299);
      expect(PlusPlan.lifetime.priceInr, 1499);
      expect(PlusPlan.lifetime.offerPriceInr, 999);
    });

    test('priceFor picks the right side of the window', () {
      for (final plan in PlusPlan.values) {
        expect(plan.priceFor(onOffer: false), plan.priceInr);
        expect(plan.priceFor(onOffer: true), plan.offerPriceInr);
        // An offer that isn't cheaper isn't an offer.
        expect(plan.offerPriceInr, lessThan(plan.priceInr));
      }
    });

    test('the saving percentages are what the chip will claim', () {
      expect(PlusPlan.monthly.offerSavingPercent, 41);
      expect(PlusPlan.yearly.offerSavingPercent, 40);
      expect(PlusPlan.lifetime.offerSavingPercent, 33);
    });
  });
}
