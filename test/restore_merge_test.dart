import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/restore_merge.dart';

/// A `transactions` row as the database stores it, with only the columns a
/// restore reasons about spelled out per test.
Map<String, Object?> row({
  String? category,
  int? isClassified,
  String? notes,
  String? reviewReasons,
  String? taxBucket,
  num? splitShare,
  String? merchantName,
}) =>
    {
      'amount': 1200.0,
      'type': 0,
      'sender': 'VM-HDFCBK-S',
      'message': 'Rs 1200 debited',
      'detected_at': 1754380800000,
      'category': category,
      'is_classified': isClassified ?? (category == null ? 0 : 1),
      'notes': notes,
      'review_reasons': reviewReasons,
      'tax_bucket': taxBucket,
      'split_share': splitShare,
      'merchant_name': merchantName,
    };

void main() {
  group('the reported bug: Needs Review comes back after a restore', () {
    // Reinstall → onboarding scans the inbox → the same SMS is re-parsed and
    // re-flagged → the backup lands on top. The user already answered these
    // in Tidy up; the queue must not reappear.
    test('a confirmed row clears the fresh scan\'s review flags', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(category: 'Food & Dining', reviewReasons: null),
        local: row(reviewReasons: 'payee_unknown,direction_uncertain'),
      );

      expect(updates.containsKey('review_reasons'), isTrue);
      expect(updates['review_reasons'], isNull);
    });

    // The common Tidy up case: "Looks right" confirms the parse without
    // tagging anything. The old merge gated the entire update on the backup
    // having a category, so exactly these rows kept their flags.
    test('confirmed but untagged still clears — no category required', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(category: null, reviewReasons: null),
        local: row(reviewReasons: 'amount_uncertain'),
      );

      expect(updates['review_reasons'], isNull);
      expect(updates.containsKey('category'), isFalse,
          reason: 'a blank backup category must not wipe anything');
    });

    test('a still-flagged backup never re-flags a locally confirmed row', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(reviewReasons: 'payee_unknown'),
        local: row(reviewReasons: null),
      );

      expect(updates.containsKey('review_reasons'), isFalse);
    });

    test('an empty-string review_reasons counts as confirmed', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(reviewReasons: '   '),
        local: row(reviewReasons: 'payee_unknown'),
      );

      expect(updates['review_reasons'], isNull);
    });
  });

  group('the other decisions the merge was dropping', () {
    test('the tax section is restored', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(taxBucket: '80C'),
        local: row(),
      );
      expect(updates['tax_bucket'], '80C');
    });

    // Without this a restored split bill counts its full amount as spend
    // again — split_share is what every total coalesces to.
    test('the split share is restored', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(splitShare: 400),
        local: row(),
      );
      expect(updates['split_share'], 400.0);
      expect(updates['split_share'], isA<double>());
    });

    test('a note is restored even when the row carries no category', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(category: null, notes: 'annual premium'),
        local: row(),
      );
      expect(updates['notes'], 'annual premium');
    });

    test('a payee fills a gap but never overwrites a named one', () {
      expect(
        RestoreMerge.updatesFor(
          backup: row(merchantName: 'Sharma Kirana'),
          local: row(merchantName: null),
        )['merchant_name'],
        'Sharma Kirana',
      );
      expect(
        RestoreMerge.updatesFor(
          backup: row(merchantName: 'paytm.s21upj5@pty'),
          local: row(merchantName: 'Sharma Kirana'),
        ).containsKey('merchant_name'),
        isFalse,
      );
    });

    test('the tag still wins, and brings is_classified with it', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(category: 'Groceries'),
        local: row(category: null),
      );
      expect(updates['category'], 'Groceries');
      expect(updates['is_classified'], 1);
    });
  });

  group('one-directional: a restore never undoes local work', () {
    // The whole safety property, stated once. Anything the backup left blank
    // must be absent from the update map, so the local value stands.
    test('a blank backup wipes nothing the local row has', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(), // nothing decided
        local: row(
          category: 'Travel',
          notes: 'work trip',
          taxBucket: '80D',
          splitShare: 250,
          merchantName: 'IndiGo',
          reviewReasons: null,
        ),
      );

      for (final column in [
        'category',
        'is_classified',
        'notes',
        'tax_bucket',
        'split_share',
        'merchant_name',
      ]) {
        expect(updates.containsKey(column), isFalse,
            reason: '$column must be left alone when the backup has none');
      }
    });

    // The caller counts a non-empty map as "one transaction restored", so a
    // merge that restates what the row already holds would report a
    // five-figure restore on a backup that changed nothing.
    test('nothing to change means nothing to write', () {
      expect(RestoreMerge.updatesFor(backup: row(), local: row()), isEmpty);

      final identical = row(
        category: 'Travel',
        notes: 'work trip',
        taxBucket: '80D',
        splitShare: 250,
        merchantName: 'IndiGo',
      );
      expect(
        RestoreMerge.updatesFor(backup: identical, local: identical),
        isEmpty,
        reason: 'restoring the same backup twice must be a no-op',
      );
    });

    test('an already-confirmed local row is not rewritten', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(reviewReasons: null),
        local: row(reviewReasons: null),
      );
      expect(updates, isEmpty);
    });

    test('a full restore onto a bare rescanned row carries everything', () {
      final updates = RestoreMerge.updatesFor(
        backup: row(
          category: 'Health & Medical',
          notes: 'annual premium',
          taxBucket: '80C',
          splitShare: 6000,
          merchantName: 'LIC',
          reviewReasons: null,
        ),
        local: row(reviewReasons: 'payee_unknown'),
      );

      expect(updates, {
        'category': 'Health & Medical',
        'is_classified': 1,
        'notes': 'annual premium',
        'review_reasons': null,
        'tax_bucket': '80C',
        'split_share': 6000.0,
        'merchant_name': 'LIC',
      });
    });
  });

  group('A muted shape never comes back', () {
    // "Not a transaction" is an answer, and a restore may not re-open one.
    // Before this check the answer only held until the next restore: the row
    // was deleted and the mute stored, then the backup — written while the
    // row still existed — put it straight back into Needs review. Reported
    // 2026-08-10 against an ignored BOI mandate revocation that returned
    // after every restore.
    const key = 'BOIIND|BOI UPI-MANDATE REVOKED FOR COURSERA RS.#.#';

    test('a backed-up row whose shape is muted is skipped', () {
      expect(
        RestoreMerge.isMutedShape(
          backup: row(),
          shapeKey: key,
          mutedShapeKeys: {key},
        ),
        isTrue,
      );
    });

    test('an unmuted row still restores', () {
      expect(
        RestoreMerge.isMutedShape(
          backup: row(),
          shapeKey: 'HDFCBK|RS.# DEBITED',
          mutedShapeKeys: {key},
        ),
        isFalse,
      );
    });

    test('nothing is skipped when the device knows no mutes', () {
      expect(
        RestoreMerge.isMutedShape(
          backup: row(),
          shapeKey: key,
          mutedShapeKeys: const {},
        ),
        isFalse,
      );
    });

    test('a manual row is never muted, however its shape reads', () {
      // Mirrors RemovalService.canMute: a mute keys off a message shape, and
      // a row typed in by hand has no message to key off. Restoring someone's
      // hand-entered cash entry because it collided with a mute would be the
      // worse bug of the two.
      expect(
        RestoreMerge.isMutedShape(
          backup: {...row(), 'is_manual': 1},
          shapeKey: key,
          mutedShapeKeys: {key},
        ),
        isFalse,
      );
    });

    test('a row with no message cannot be matched', () {
      expect(
        RestoreMerge.isMutedShape(
          backup: {...row(), 'message': ''},
          shapeKey: key,
          mutedShapeKeys: {key},
        ),
        isFalse,
      );
    });

    test('a row the caller could not key is left alone', () {
      expect(
        RestoreMerge.isMutedShape(
          backup: row(),
          shapeKey: null,
          mutedShapeKeys: {key},
        ),
        isFalse,
      );
    });
  });
}
