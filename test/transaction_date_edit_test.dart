import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/sms_parser_service.dart';

/// A transaction's date used to be whatever moment its SMS happened to
/// arrive, and final. Bank alerts land late, an imported statement carries a
/// posting date rather than a spend date, and a manual entry gets typed days
/// after the money moved — so a transaction sat in the wrong month and bent
/// every figure derived from it, with deleting and re-entering it the only
/// way out (user report, Sep '26).
///
/// These pin the rules the edit follows. The move itself is one column, and
/// every dated figure in the app is derived from that column at read time,
/// so what needs guarding is which moment the edit resolves to.
void main() {
  final now = DateTime(2026, 9, 1, 14, 30);

  group('Resolving an edited date', () {
    test('a clock left as the picker opened it rides across whole', () {
      // The time picker opens on the transaction's own time, so handing back
      // that same hour and minute is what "I only wanted the day" looks like.
      final original = DateTime(2026, 8, 20, 9, 41, 17, 456);
      final moved = TransactionModel.resolveEditedDate(
        original: original,
        pickedDay: DateTime(2026, 8, 18),
        now: now,
        hour: original.hour,
        minute: original.minute,
      );
      expect(moved, DateTime(2026, 8, 18, 9, 41, 17, 456));
      expect(moved.second, 17);
      expect(moved.millisecond, 456);
    });

    test('a clock the user set lands on the second', () {
      final moved = TransactionModel.resolveEditedDate(
        original: DateTime(2026, 8, 20, 9, 41, 17, 456),
        pickedDay: DateTime(2026, 8, 18),
        now: now,
        hour: 19,
        minute: 5,
      );
      expect(moved, DateTime(2026, 8, 18, 19, 5));
    });

    test('two transactions a minute apart keep their order after a move', () {
      final earlier = DateTime(2026, 8, 20, 9, 41, 10);
      final later = DateTime(2026, 8, 20, 9, 41, 55);
      final day = DateTime(2026, 8, 18);
      final a = TransactionModel.resolveEditedDate(
          original: earlier,
          pickedDay: day,
          now: now,
          hour: earlier.hour,
          minute: earlier.minute);
      final b = TransactionModel.resolveEditedDate(
          original: later,
          pickedDay: day,
          now: now,
          hour: later.hour,
          minute: later.minute);
      expect(a.isBefore(b), isTrue);
    });

    test('today plus a later hour is clamped to now, not left in the future',
        () {
      // The picker's own ceiling stops at the day; it cannot stop 11pm today.
      final moved = TransactionModel.resolveEditedDate(
        original: DateTime(2026, 8, 20, 9, 0),
        pickedDay: DateTime(2026, 9, 1),
        now: now,
        hour: 23,
        minute: 0,
      );
      expect(moved, now);
      expect(moved.isAfter(now), isFalse);
    });

    test('a past day with a late hour is left alone', () {
      final moved = TransactionModel.resolveEditedDate(
        original: DateTime(2026, 8, 20, 9, 0),
        pickedDay: DateTime(2026, 8, 31),
        now: now,
        hour: 23,
        minute: 0,
      );
      expect(moved, DateTime(2026, 8, 31, 23, 0));
    });

    test('picking the same day and clock resolves to no change at all', () {
      // What "Next" then "Save" without touching anything must produce, so
      // the caller can bail before writing and never leaves a no-op toast.
      final original = DateTime(2026, 8, 20, 9, 41, 17, 456);
      final moved = TransactionModel.resolveEditedDate(
        original: original,
        pickedDay: DateTime(2026, 8, 20),
        now: now,
        hour: original.hour,
        minute: original.minute,
      );
      expect(moved, original);
    });
  });

  group('A moved transaction keeps its identity', () {
    test('the fingerprint is not derived from the corrected date', () {
      // The fingerprint is what an SMS rescan matches a stored row against.
      // Recomputing it from a corrected date would make the row stop matching
      // its own message, and the next scan would import it a second time.
      final txn = TransactionModel(
        amount: 250,
        type: TransactionType.debit,
        sender: 'AD-UNIONB-S',
        message: 'A/c *1234 Debited for Rs:250.00 on 20-08-2026',
        detectedAt: DateTime(2026, 8, 20, 9, 41),
      ).withFingerprint();

      final moved = txn.copyWith(detectedAt: DateTime(2026, 8, 18, 9, 41));

      expect(moved.fingerprint, txn.fingerprint);
      expect(moved.fingerprint, isNotNull);
      // And the move changed only the date.
      expect(moved.amount, txn.amount);
      expect(moved.message, txn.message);
      expect(moved.detectedAt, DateTime(2026, 8, 18, 9, 41));
    });

    test('a rescan of the same SMS still recognises a moved row', () {
      // The end-to-end reason the fingerprint must not be recomputed. An
      // inbox scan re-parses the message at the timestamp it arrived with,
      // and matches the result against stored rows by fingerprint. If moving
      // a transaction changed its fingerprint, two things break at once:
      // transactionExists stops finding the row and imports the message a
      // second time, and the tombstone left by a DELETED row stops matching
      // too — so a transaction the user threw away comes back on every scan.
      const sender = 'AD-UNIONB-S';
      const body = 'A/c *1234 Debited for Rs:250.00 on 20-08-2026 by UPI '
          'ref no 123456789012. Bal:Rs 4500.00 -Union Bank of India';
      final arrivedAt = DateTime(2026, 8, 20, 9, 41);

      final asScanned =
          SmsParserService.parseTransaction(sender, body, arrivedAt)!
              .withFingerprint();
      final moved =
          asScanned.copyWith(detectedAt: DateTime(2026, 8, 18, 9, 41));

      // What a later scan of the very same message would compute.
      final rescanned =
          SmsParserService.parseTransaction(sender, body, arrivedAt)!
              .withFingerprint();

      expect(rescanned.fingerprint, moved.fingerprint);
      expect(moved.fingerprint, isNotNull);
    });
  });
}
