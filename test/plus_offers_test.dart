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

    test('Diwali runs for exactly one week around the anchor', () {
      // Diwali 2026 falls on 8 Nov: four days of run-up, the day itself, two
      // days after — 4–10 Nov inclusive.
      expect(activeFestiveOffer(DateTime(2026, 11, 8))?.id, 'diwali');
      expect(activeFestiveOffer(DateTime(2026, 11, 4))?.id, 'diwali');
      expect(activeFestiveOffer(DateTime(2026, 11, 10))?.id, 'diwali');
      // …and stays shut outside it.
      expect(activeFestiveOffer(DateTime(2026, 11, 3)), isNull);
      expect(activeFestiveOffer(DateTime(2026, 11, 11)), isNull);
    });

    test('festivals run a week, national holidays a long weekend', () {
      // The whole point of the shape: a festival sale that outlasts the
      // festival stops reading as one, and stops making the base price real.
      const national = {'republic', 'independence'};
      for (var year = 2026; year <= 2032; year++) {
        for (final offer in festiveOffersAnchoredIn(year)) {
          expect(
            offer.endsAt.difference(offer.startsAt),
            national.contains(offer.id)
                ? kNationalOfferDuration
                : kFestiveOfferDuration,
            reason: '${offer.id} $year',
          );
        }
      }
    });

    test('Republic Day and Independence Day are three fixed days', () {
      // No almanac, no drift — the eve, the day, the day after.
      for (final (id, month, day) in [
        ('republic', 1, 26),
        ('independence', 8, 15),
      ]) {
        expect(activeFestiveOffer(DateTime(2028, month, day - 1))?.id, id);
        expect(activeFestiveOffer(DateTime(2028, month, day))?.id, id);
        expect(activeFestiveOffer(DateTime(2028, month, day + 1))?.id, id);
        expect(activeFestiveOffer(DateTime(2028, month, day - 2)), isNull);
        expect(activeFestiveOffer(DateTime(2028, month, day + 2)), isNull);
      }
    });

    test('Dussehra opens three weeks before Diwali, and the two never touch',
        () {
      // Both hang off the same lunar month, so the gap is fixed at ~20 days —
      // comfortably more than the fourteen their two windows occupy.
      expect(activeFestiveOffer(DateTime(2026, 10, 20))?.id, 'dussehra');
      expect(activeFestiveOffer(DateTime(2027, 10, 9))?.id, 'dussehra');
      for (var year = 2026; year <= 2032; year++) {
        final windows = {
          for (final o in festiveOffersAnchoredIn(year)) o.id: o,
        };
        expect(windows['dussehra']!.endsAt.isBefore(windows['diwali']!.startsAt),
            isTrue,
            reason: 'Dussehra and Diwali windows collide in $year');
      }
    });

    test('Eid al-Fitr walks backwards through the calendar, and is tabled for '
        'it', () {
      // Purely lunar: ~11 days earlier each year, March in 2027 → January by
      // 2031. A rule cannot express that, which is why the table exists.
      expect(activeFestiveOffer(DateTime(2027, 3, 10))?.id, 'eid');
      expect(activeFestiveOffer(DateTime(2029, 2, 15))?.id, 'eid');
      expect(activeFestiveOffer(DateTime(2032, 1, 15))?.id, 'eid');
      // A moon sighting that lands a day either side is still inside.
      expect(activeFestiveOffer(DateTime(2027, 3, 9))?.id, 'eid');
      expect(activeFestiveOffer(DateTime(2027, 3, 11))?.id, 'eid');
      // 2031 is the year Eid falls on Republic Day. The festival wins the
      // label; either way the user sees one offer, not two.
      expect(activeFestiveOffer(DateTime(2031, 1, 26))?.id, 'eid');
    });

    test('the window still contains a panchang date that shifts by a day', () {
      // The anchors are approximate by design. Whether Diwali 2027 lands on
      // 28, 29 or 30 October, the window is open.
      for (final day in [28, 29, 30]) {
        expect(activeFestiveOffer(DateTime(2027, 10, day))?.id, 'diwali');
      }
    });

    test('the New Year week runs Boxing Day to New Year\'s Day, across the '
        'year boundary', () {
      expect(activeFestiveOffer(DateTime(2026, 12, 26))?.id, 'newyear');
      expect(activeFestiveOffer(DateTime(2026, 12, 31))?.id, 'newyear');
      expect(activeFestiveOffer(DateTime(2027, 1, 1))?.id, 'newyear');
      // Closes on 2 Jan; Christmas Day itself is still the everyday price.
      expect(activeFestiveOffer(DateTime(2027, 1, 2)), isNull);
      expect(activeFestiveOffer(DateTime(2026, 12, 25)), isNull);
    });

    test('Holi opens a window too', () {
      expect(activeFestiveOffer(DateTime(2027, 3, 22))?.id, 'holi');
      expect(activeFestiveOffer(DateTime(2028, 3, 11))?.id, 'holi');
    });

    test('every festival is preloaded for the next five years', () {
      // A missing year fails CLOSED — no window at all — so the depth of the
      // table IS the feature. The app ships knowing its own sale calendar,
      // with no network call, no update and no almanac at runtime.
      for (var year = 2027; year <= 2031; year++) {
        expect(
          festiveOffersAnchoredIn(year).map((o) => o.id).toSet(),
          containsAll(<String>[
            'holi',
            'eid',
            'dussehra',
            'diwali',
            'republic',
            'independence',
            'newyear',
          ]),
          reason: 'festival anchors missing for $year',
        );
      }
      // 2026 carries no Holi and no Eid on purpose: both fell in March 2026,
      // before any of this shipped.
      expect(festiveOffersAnchoredIn(2026).map((o) => o.id),
          isNot(contains('holi')));
      expect(festiveOffersAnchoredIn(2026).map((o) => o.id),
          isNot(contains('eid')));
    });

    test('a year with no anchor falls back to the base price, not a discount',
        () {
      // The lunar tables stop after 2032. Running past them must fail CLOSED —
      // showing full price is recoverable, advertising a discount Play is not
      // running is not.
      expect(activeFestiveOffer(DateTime(2040, 10, 25)), isNull);
      expect(activeFestiveOffer(DateTime(2040, 3, 15)), isNull);
      // The fixed-date windows still work, since none of them needs a table.
      expect(activeFestiveOffer(DateTime(2040, 12, 26))?.id, 'newyear');
      expect(activeFestiveOffer(DateTime(2040, 1, 26))?.id, 'republic');
      expect(activeFestiveOffer(DateTime(2040, 8, 15))?.id, 'independence');
    });

    test('offers cover only a small slice of the year', () {
      // The strikethrough is only honest while the base price is what
      // normally applies. Sample every day of 2027 and 2031 — the second
      // being the year Eid collides with Republic Day, so it can only ever
      // come in lower.
      int discountedDaysIn(int year) {
        var days = 0;
        for (var d = DateTime(year, 1, 1);
            d.year == year;
            d = d.add(const Duration(days: 1))) {
          if (activeFestiveOffer(d) != null) days++;
        }
        return days;
      }

      // Holi + Eid + Dussehra + Diwali + New Year at seven days apiece, plus
      // Republic Day and Independence Day at three. Not one day more.
      expect(discountedDaysIn(2027), 41);
      expect(discountedDaysIn(2031), lessThanOrEqualTo(41));
      // A budget, not a coincidence: past ~50 days a year the base price
      // stops being the price and the strikethrough stops being true.
      for (var year = 2027; year <= 2032; year++) {
        expect(discountedDaysIn(year), lessThan(50), reason: '$year');
      }
    });
  });

  group('welcome week', () {
    final svc = EntitlementService();

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      svc.resetForTest();
      // The production restart is dated in the future, which would put every
      // seeded install back inside its free window. Neutralised here so the
      // suite can exercise expired trials; trial_notice_test.dart drives the
      // restart itself.
      EntitlementService.debugTrialRestartAt = DateTime.utc(2000);
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
      // Seven days from the day the free window closed — no more.
      expect(offer.endsAt.difference(offer.startsAt),
          EntitlementService.welcomeOfferDuration);
      expect(offer.daysLeftFrom(DateTime.now()), lessThanOrEqualTo(7));
    });

    test('is anchored on the moment access stopped, never on a trial end that '
        'is still ahead', () async {
      // Regression: the welcome week used to be anchored on trialEndsAt
      // outright. Ask about a clock that predates that end — which is what an
      // expiry forced by anything other than the calendar looks like — and it
      // advertised an offer "ending in 114 days", counting down to a date the
      // user had not reached. The window is seven days from when free access
      // actually stopped, and nothing else.
      SharedPreferences.setMockInitialValues({
        'entitlement_first_launch_at': daysAgo(91),
      });
      await svc.initialize();
      expect(svc.trialActive, isFalse);

      final wellBeforeTheEnd =
          svc.trialEndsAt!.subtract(const Duration(days: 100));
      final offer = svc.offerAt(wellBeforeTheEnd);
      expect(offer?.id, 'welcome');
      expect(offer!.daysLeftFrom(wellBeforeTheEnd), 7);
      expect(offer.endsAt.difference(offer.startsAt),
          EntitlementService.welcomeOfferDuration);
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
