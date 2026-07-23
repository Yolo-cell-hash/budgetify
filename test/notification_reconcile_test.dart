import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/transaction_reconciler.dart';

/// The twin-picking rules that decide "same real payment, two captures" vs
/// "two real payments". Pure logic — the DB glue only feeds it candidates,
/// mirroring how the statement importer's dedup is tested.
void main() {
  final base = DateTime(2026, 7, 20, 14, 30);
  int ms(DateTime d) => d.millisecondsSinceEpoch;

  TwinCandidate cand(int id, DateTime at, {String? payee}) => TwinCandidate(
        id: id,
        detectedAtMs: ms(at),
        merchantName: payee,
      );

  group('pickTwin', () {
    test('notification + its SMS three minutes later are one payment', () {
      final twin = TransactionReconciler.pickTwin(
        detectedAtMs: ms(base.add(const Duration(minutes: 3))),
        merchantName: 'Swiggy Limited',
        candidates: [cand(1, base, payee: 'Swiggy')],
      );
      expect(twin?.id, 1);
    });

    test('outside the 30-minute window is a separate payment', () {
      final twin = TransactionReconciler.pickTwin(
        detectedAtMs: ms(base.add(const Duration(minutes: 31))),
        merchantName: 'Swiggy',
        candidates: [cand(1, base, payee: 'Swiggy')],
      );
      expect(twin, isNull);
    });

    test('same amount, clearly different payees → never merged '
        '(two ₹50 autos to different people)', () {
      final twin = TransactionReconciler.pickTwin(
        detectedAtMs: ms(base.add(const Duration(minutes: 10))),
        merchantName: 'Suresh',
        candidates: [cand(1, base, payee: 'Ramesh')],
      );
      expect(twin, isNull);
    });

    test('unknown payee on one side lets amount+time carry the match', () {
      final twin = TransactionReconciler.pickTwin(
        detectedAtMs: ms(base.add(const Duration(minutes: 2))),
        merchantName: null,
        candidates: [cand(1, base, payee: 'Swiggy')],
      );
      expect(twin?.id, 1);
    });

    test('nearest-in-time candidate wins when several qualify', () {
      final twin = TransactionReconciler.pickTwin(
        detectedAtMs: ms(base),
        merchantName: null,
        candidates: [
          cand(1, base.subtract(const Duration(minutes: 20))),
          cand(2, base.subtract(const Duration(minutes: 1))),
          cand(3, base.add(const Duration(minutes: 9))),
        ],
      );
      expect(twin?.id, 2);
    });

    test('no candidates → no twin', () {
      expect(
        TransactionReconciler.pickTwin(
          detectedAtMs: ms(base),
          merchantName: 'X',
          candidates: const [],
        ),
        isNull,
      );
    });
  });

  group('payeesCompatible', () {
    test('containment tolerates SMS-vs-notification naming', () {
      expect(
        TransactionReconciler.payeesCompatible('Swiggy', 'Swiggy Limited'),
        isTrue,
      );
      expect(
        TransactionReconciler.payeesCompatible('SWIGGY LIMITED', 'swiggy'),
        isTrue,
      );
    });

    test('punctuation and spacing are ignored', () {
      expect(
        TransactionReconciler.payeesCompatible("Domino's Pizza", 'dominos pizza'),
        isTrue,
      );
    });

    test('unrelated names veto', () {
      expect(TransactionReconciler.payeesCompatible('Ramesh', 'Suresh'), isFalse);
    });

    test('null or empty on either side allows', () {
      expect(TransactionReconciler.payeesCompatible(null, 'Swiggy'), isTrue);
      expect(TransactionReconciler.payeesCompatible('Swiggy', null), isTrue);
      expect(TransactionReconciler.payeesCompatible('₹₹', 'Swiggy'), isTrue);
    });
  });
}
