import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/plus_products.dart';
import 'package:budget_tracker/services/play_billing_gateway.dart';

/// Which Play entry the app buys — and quotes.
///
/// A subscription comes back as one entry per base plan and per eligible
/// offer, all sharing a product id, in no meaningful order. Before this,
/// `launchPurchase` took `.first`, so ₹49 and ₹29 were a coin toss and the
/// price shown could differ from the price charged. These cases pin the rule
/// that replaced it.
void main() {
  OfferCandidate base(double price) =>
      OfferCandidate(offerId: null, tags: const [], price: price);

  OfferCandidate ours(String id, double price) =>
      OfferCandidate(offerId: id, tags: const [kPlusOfferTag], price: price);

  OfferCandidate foreign(String id, double price) =>
      OfferCandidate(offerId: id, tags: const ['someone-elses'], price: price);

  group('outside a discount window', () {
    test('takes the base plan even when a cheaper offer is live', () {
      // The Console offer stays permanently active; out of season it must
      // simply go unused.
      final picked = selectEntry(
        [ours('plus-offer-monthly', 29), base(49)],
        preferOffer: false,
      );
      expect(picked, 1, reason: 'must charge the everyday price');
    });

    test('order cannot change the answer', () {
      for (final entries in [
        [base(49), ours('plus-offer-monthly', 29)],
        [ours('plus-offer-monthly', 29), base(49)],
      ]) {
        final i = selectEntry(entries, preferOffer: false);
        expect(entries[i!].offerId, isNull);
      }
    });
  });

  group('inside a discount window', () {
    test('takes the tagged offer', () {
      final picked = selectEntry(
        [base(49), ours('plus-offer-monthly', 29)],
        preferOffer: true,
      );
      expect(picked, 1);
    });

    test('order cannot change the answer', () {
      for (final entries in [
        [base(49), ours('plus-offer-monthly', 29)],
        [ours('plus-offer-monthly', 29), base(49)],
      ]) {
        final i = selectEntry(entries, preferOffer: true);
        expect(entries[i!].price, 29);
      }
    });

    test('ignores an offer that is not ours, however cheap', () {
      // Play can return offers we never configured. Selecting on price alone
      // would hand the buyer someone else's discount.
      final entries = [base(49), foreign('mystery-1', 5)];
      final i = selectEntry(entries, preferOffer: true);
      expect(entries[i!].offerId, isNull,
          reason: 'an untagged offer is not ours to apply');
    });

    test('cheapest wins among several of ours', () {
      final entries = [
        base(49),
        ours('plus-offer-monthly', 39),
        ours('diwali-29', 29),
      ];
      expect(selectEntry(entries, preferOffer: true), 2);
    });

    test('falls back to the base plan when no offer is live', () {
      // Our calendar says "discount", the Console disagrees. Charge the
      // everyday price rather than invent one.
      expect(selectEntry([base(49)], preferOffer: true), 0);
    });
  });

  group('degenerate catalogues', () {
    test('a lone one-time product is picked either way', () {
      for (final prefer in [true, false]) {
        expect(selectEntry([base(1499)], preferOffer: prefer), 0);
      }
    });

    test('nothing to pick returns null', () {
      expect(selectEntry([], preferOffer: true), isNull);
    });

    test('with no base plan and no offer of ours, fails CLOSED to the dearest',
        () {
      // Never quietly undercharge on a catalogue we do not recognise.
      final entries = [foreign('a', 19), foreign('b', 49)];
      final i = selectEntry(entries, preferOffer: true);
      expect(entries[i!].price, 49);
    });
  });
}
