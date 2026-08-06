import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/month_totals.dart';
import 'package:budget_tracker/models/transaction_model.dart';

TransactionModel _txn({
  required double amount,
  TransactionType type = TransactionType.debit,
  String? category,
  String? reviewReasons,
  double? splitShare,
}) {
  return TransactionModel(
    amount: amount,
    type: type,
    sender: 'VM-HDFCBK-S',
    message: 'test',
    detectedAt: DateTime(2026, 8, 6),
    category: category,
    reviewReasons: reviewReasons,
    splitShare: splitShare,
  );
}

void main() {
  group('MonthTotals', () {
    test('splits income from expenses', () {
      final t = MonthTotals.fromTransactions([
        _txn(amount: 500, category: 'Food & Dining'),
        _txn(amount: 300, category: 'Shopping'),
        _txn(amount: 5000, type: TransactionType.credit, category: 'Salary'),
      ]);
      expect(t.expenses, 800);
      expect(t.income, 5000);
      expect(t.unconfirmedExpenses, 0);
    });

    test('flagged debits are counted into unconfirmedExpenses', () {
      final t = MonthTotals.fromTransactions([
        _txn(amount: 500, category: 'Food & Dining'),
        _txn(
          amount: 10000,
          category: 'Shopping',
          reviewReasons: 'direction_uncertain,payee_unknown',
        ),
      ]);
      expect(t.expenses, 10500);
      expect(t.unconfirmedExpenses, 10000);
    });

    // The invariant the hero card leans on: the caveat sits *under* the total
    // and describes part of it, so it can never exceed it. Computing the two
    // from separate queries is exactly how that breaks.
    test('unconfirmedExpenses never exceeds expenses', () {
      final cases = [
        <TransactionModel>[],
        [_txn(amount: 100, category: 'Food & Dining')],
        [_txn(amount: 100, category: 'Food & Dining', reviewReasons: 'x')],
        [
          // A flagged self-transfer: excluded from expenses, so it must be
          // excluded from the caveat too, or the card claims more is
          // unconfirmed than was spent.
          _txn(amount: 50000, category: 'Self Transfer', reviewReasons: 'x'),
          _txn(amount: 200, category: 'Shopping'),
        ],
        [
          // A flagged credit belongs to income, never to the expense caveat.
          _txn(
            amount: 9000,
            type: TransactionType.credit,
            category: 'Salary',
            reviewReasons: 'x',
          ),
          _txn(amount: 200, category: 'Shopping'),
        ],
      ];
      for (final c in cases) {
        final t = MonthTotals.fromTransactions(c);
        expect(
          t.unconfirmedExpenses,
          lessThanOrEqualTo(t.expenses),
          reason: 'caveat must be a subset of the total it qualifies',
        );
      }
    });

    test('a flagged self-transfer contributes to neither figure', () {
      final t = MonthTotals.fromTransactions([
        _txn(amount: 50000, category: 'Self Transfer', reviewReasons: 'x'),
      ]);
      expect(t.expenses, 0);
      expect(t.unconfirmedExpenses, 0);
    });

    test('a flagged credit lands in income, not the expense caveat', () {
      final t = MonthTotals.fromTransactions([
        _txn(
          amount: 9000,
          type: TransactionType.credit,
          category: 'Salary',
          reviewReasons: 'x',
        ),
      ]);
      expect(t.income, 9000);
      expect(t.unconfirmedExpenses, 0);
    });

    test('a split transaction contributes only the user\'s share', () {
      final t = MonthTotals.fromTransactions([
        _txn(
          amount: 1200,
          category: 'Food & Dining',
          splitShare: 400,
          reviewReasons: 'x',
        ),
      ]);
      expect(t.expenses, 400);
      expect(t.unconfirmedExpenses, 400);
    });

    test('an empty month is all zeroes', () {
      final t = MonthTotals.fromTransactions(const []);
      expect(t.income, 0);
      expect(t.expenses, 0);
      expect(t.unconfirmedExpenses, 0);
    });
  });
}
