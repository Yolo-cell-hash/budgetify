import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/notification_service.dart';

void main() {
  TransactionModel txn({
    required double amount,
    required TransactionType type,
    bool isClassified = false,
    String? category,
  }) =>
      TransactionModel(
        amount: amount,
        type: type,
        sender: 'JM-BOIIND-S',
        message: 'test body',
        detectedAt: DateTime(2026, 6, 25),
        isClassified: isClassified,
        category: category,
      );

  group('NotificationService.buildTransactionBody', () {
    test('untagged debit stays plain', () {
      final body = NotificationService.buildTransactionBody(
        txn(amount: 500, type: TransactionType.debit),
      );
      expect(body, '₹500.00 debited');
    });

    test('untagged credit stays plain', () {
      final body = NotificationService.buildTransactionBody(
        txn(amount: 150, type: TransactionType.credit),
      );
      expect(body, '₹150.00 credited');
    });

    test('tagged debit names the category', () {
      final body = NotificationService.buildTransactionBody(
        txn(
          amount: 500,
          type: TransactionType.debit,
          isClassified: true,
          category: 'Food & Dining',
        ),
      );
      expect(body, '₹500.00 debited towards Food & Dining');
    });

    test('tagged credit names the category', () {
      final body = NotificationService.buildTransactionBody(
        txn(
          amount: 50000,
          type: TransactionType.credit,
          isClassified: true,
          category: 'Salary',
        ),
      );
      expect(body, '₹50,000.00 credited towards Salary');
    });

    test('a non-expense tag is still shown (whatever it is tagged against)', () {
      final body = NotificationService.buildTransactionBody(
        txn(
          amount: 2000,
          type: TransactionType.debit,
          isClassified: true,
          category: 'Investments',
        ),
      );
      expect(body, '₹2,000.00 debited towards Investments');
    });

    test('a guessed category that is NOT classified stays plain', () {
      // The parser may detect a category from the merchant but leave the txn
      // unclassified (needs a tag). The notification must agree with the app's
      // "Unclassified" status and stay plain.
      final body = NotificationService.buildTransactionBody(
        txn(
          amount: 500,
          type: TransactionType.debit,
          isClassified: false,
          category: 'Shopping',
        ),
      );
      expect(body, '₹500.00 debited');
    });

    test('classified with a blank category stays plain', () {
      final body = NotificationService.buildTransactionBody(
        txn(
          amount: 500,
          type: TransactionType.debit,
          isClassified: true,
          category: '   ',
        ),
      );
      expect(body, '₹500.00 debited');
    });
  });

  group('NotificationService.transactionNotificationId', () {
    test('two transactions in the same second get distinct ids', () {
      // Same detectedAt second, different amounts. The old `detectedAt ~/ 1000`
      // id collided and one alert silently replaced the other; the seeded id
      // must keep them in separate slots.
      final a = NotificationService.transactionNotificationId(
        txn(amount: 500, type: TransactionType.debit),
      );
      final b = NotificationService.transactionNotificationId(
        txn(amount: 250, type: TransactionType.debit),
      );
      expect(a, isNot(b));
    });

    test('a debit and a credit of the same amount differ', () {
      expect(
        NotificationService.transactionNotificationId(
            txn(amount: 500, type: TransactionType.debit)),
        isNot(NotificationService.transactionNotificationId(
            txn(amount: 500, type: TransactionType.credit))),
      );
    });

    test('is stable for the same transaction (idempotent re-show)', () {
      final t = txn(amount: 500, type: TransactionType.debit);
      expect(
        NotificationService.transactionNotificationId(t),
        NotificationService.transactionNotificationId(t),
      );
    });

    test('is always a positive 31-bit int (valid Android notification id)', () {
      final id = NotificationService.transactionNotificationId(
        txn(amount: 500, type: TransactionType.debit),
      );
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7fffffff));
    });
  });
}
