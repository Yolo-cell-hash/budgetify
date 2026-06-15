import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/sms_parser_service.dart';

void main() {
  group('Bank of Maharashtra merchant extraction', () {
    test('debit: extracts the payee after "UPI payment to", not the A/c', () {
      const body =
          'A/c X7763 debited by Rs. 20.00 for UPI payment to SANTOSH ANANT G '
          'on 10-Jun-26. RRN: 616189591413 if not you, call 18002334526 '
          '-Bank of Maharashtra';
      final txn = SmsParserService.parseTransaction(
          'AD-MAHABK-S', body, DateTime(2026, 6, 10));

      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.debit);
      expect(txn.amount, 20.0);
      expect(txn.merchantName, 'Santosh Anant G');
      // The bug was payee == account; guard against regressing.
      expect(txn.merchantName, isNot('XX7763'));
      expect(txn.accountInfo, 'XX7763');
    });

    test('credit: extracts the payer after "UPI payment from"', () {
      const body =
          'A/c X7763 credited by Rs. 500.00 for UPI payment from RAHUL SHARMA '
          'on 10-Jun-26. RRN: 111222333 -Bank of Maharashtra';
      final txn = SmsParserService.parseTransaction(
          'AD-MAHABK-T', body, DateTime(2026, 6, 10));

      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.credit);
      expect(txn.merchantName, 'Rahul Sharma');
    });

    test('plain credit to own account does NOT use "your A/c" as the payee',
        () {
      const body =
          'Rs.5000.00 credited to your A/c XX7763 on 01-Jun-26. '
          'Avl Bal Rs.12000.00 -Bank of Maharashtra';
      final txn = SmsParserService.parseTransaction(
          'AD-MAHABK-S', body, DateTime(2026, 6, 1));

      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.credit);
      // Falls back to the account number rather than "Your A/c Xx7763".
      expect(txn.merchantName, 'XX7763');
    });
  });

  group('Merchant extraction regressions (other banks unaffected)', () {
    test('BOI "credited to {NAME} via UPI" still works', () {
      const body =
          'Your A/c XX1234 is debited by Rs.500.00 and credited to '
          'KIRTI PRAHALAD PANCHAL via UPI Ref 123456.';
      final txn = SmsParserService.parseTransaction(
          'VK-BOIIND-S', body, DateTime(2026, 6, 1));

      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.debit);
      expect(txn.merchantName, 'Kirti Prahalad Panchal');
    });

    test('HDFC "To {NAME}" (multi-line) still works', () {
      const body =
          'Sent Rs.30.00\nFrom HDFC Bank A/C *9463\n'
          'To Mumbai Metro Ghatkopar\nOn 01-06-26';
      final txn = SmsParserService.parseTransaction(
          'VM-HDFCBK-S', body, DateTime(2026, 6, 1));

      expect(txn, isNotNull);
      expect(txn!.merchantName, 'Mumbai Metro Ghatkopar');
    });
  });

  group('parseDetailed reason codes', () {
    const bomDebit =
        'A/c X7763 debited by Rs. 20.00 for UPI payment to SANTOSH ANANT G '
        'on 10-Jun-26. -Bank of Maharashtra';

    test('parsed for a real BOM debit (all sender variants)', () {
      for (final sender in const [
        'AD-MAHABK-S',
        'AD-MAHABK-T',
        'MAHABK',
        'Bank of Maharashtra',
      ]) {
        final r = SmsParserService.parseDetailed(
            sender, bomDebit, DateTime(2026, 6, 10));
        expect(r.reason, SmsParseReason.parsed, reason: 'sender=$sender');
        expect(r.transaction, isNotNull, reason: 'sender=$sender');
      }
    });

    test('promo route (-P) is rejected even with a real transaction body', () {
      final r = SmsParserService.parseDetailed(
          'AD-MAHABK-P', bomDebit, DateTime(2026, 6, 10));
      expect(r.reason, SmsParseReason.promo);
      expect(r.transaction, isNull);
    });

    test('unknown sender -> notBank', () {
      final r = SmsParserService.parseDetailed(
          'XY-ABCXYZ-S', bomDebit, DateTime(2026, 6, 10));
      expect(r.reason, SmsParseReason.notBank);
    });

    test('bank OTP -> nonTransaction', () {
      final r = SmsParserService.parseDetailed(
        'AD-MAHABK-S',
        '123456 is your OTP for a transaction of Rs.500. Do not share it.',
        DateTime(2026, 6, 10),
      );
      expect(r.reason, SmsParseReason.nonTransaction);
    });

    test('bank debit with no amount -> noAmount', () {
      final r = SmsParserService.parseDetailed(
        'AD-MAHABK-S',
        'Your a/c is debited for a UPI payment to SOME SHOP. -Bank of Maharashtra',
        DateTime(2026, 6, 10),
      );
      expect(r.reason, SmsParseReason.noAmount);
    });
  });
}
