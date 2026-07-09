import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/screens/transactions_screen.dart';

TransactionModel _txn({
  double amount = 100.0,
  String? merchant,
  String? category,
  DateTime? detectedAt,
}) {
  return TransactionModel(
    amount: amount,
    type: TransactionType.debit,
    sender: 'AD-HDFCBK-S',
    message: 'test message',
    detectedAt: detectedAt ?? DateTime(2026, 7, 9, 18, 30),
    merchantName: merchant,
    category: category,
  );
}

void main() {
  group('amount queries are strict', () {
    // Real user report: searching "50" returned ₹500, ₹5000, even ₹250.
    test('searching 50 matches only exactly ₹50', () {
      expect(transactionMatchesQuery(_txn(amount: 50.0), '50'), isTrue);
      expect(transactionMatchesQuery(_txn(amount: 50.0), '50.00'), isTrue);
      expect(transactionMatchesQuery(_txn(amount: 500.0), '50'), isFalse);
      expect(transactionMatchesQuery(_txn(amount: 5000.0), '50'), isFalse);
      expect(transactionMatchesQuery(_txn(amount: 250.0), '50'), isFalse);
      expect(transactionMatchesQuery(_txn(amount: 1150.50), '50'), isFalse);
      expect(transactionMatchesQuery(_txn(amount: 50.50), '50'), isFalse);
    });

    test('paise-precise queries match to the paisa', () {
      expect(
          transactionMatchesQuery(_txn(amount: 457.42), '457.42'), isTrue);
      expect(
          transactionMatchesQuery(_txn(amount: 457.42), '457.41'), isFalse);
      expect(transactionMatchesQuery(_txn(amount: 457.42), '457'), isFalse);
    });

    test('currency prefixes and commas are tolerated', () {
      expect(transactionMatchesQuery(_txn(amount: 1200.0), '₹1,200'), isTrue);
      expect(transactionMatchesQuery(_txn(amount: 1200.0), 'rs 1200'), isTrue);
      expect(
          transactionMatchesQuery(_txn(amount: 1200.0), 'Rs. 1,200'), isTrue);
      expect(transactionMatchesQuery(_txn(amount: 1200.0), 'inr 1200'),
          isTrue);
      expect(transactionMatchesQuery(_txn(amount: 120.0), '₹1,200'), isFalse);
    });

    test('numeric query does not loosely match digits in text fields', () {
      // Merchant contains "50" but the amount is ₹99 — an amount query
      // must not fall back to substring matching.
      final t = _txn(amount: 99.0, merchant: 'Store 50');
      expect(transactionMatchesQuery(t, '50'), isFalse);
    });
  });

  group('text queries stay loose', () {
    test('payee substring, case-insensitive', () {
      final t = _txn(merchant: 'Sharma Kirana');
      expect(transactionMatchesQuery(t, 'sharma'), isTrue);
      expect(transactionMatchesQuery(t, 'KIRA'), isTrue);
      expect(transactionMatchesQuery(t, 'patel'), isFalse);
    });

    test('category and sender substrings match', () {
      final t = _txn(category: 'Food & Dining');
      expect(transactionMatchesQuery(t, 'food'), isTrue);
      expect(transactionMatchesQuery(t, 'hdfcbk'), isTrue);
    });

    test('formatted dates match', () {
      final t = _txn(detectedAt: DateTime(2026, 7, 9));
      expect(transactionMatchesQuery(t, '9 jul'), isTrue);
      expect(transactionMatchesQuery(t, '09/07/2026'), isTrue);
      expect(transactionMatchesQuery(t, '10 aug'), isFalse);
    });

    test('empty query matches everything', () {
      expect(transactionMatchesQuery(_txn(), ''), isTrue);
      expect(transactionMatchesQuery(_txn(), '   '), isTrue);
    });
  });
}
