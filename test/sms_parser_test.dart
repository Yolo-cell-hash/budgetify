import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/sms_parser_service.dart';

void main() {
  final now = DateTime(2026, 6, 1, 10, 30);

  group('isBankSms — sender matching', () {
    test('matches bare bank headers', () {
      expect(SmsParserService.isBankSms('SBIUPI'), isTrue);
      expect(SmsParserService.isBankSms('MAHABK'), isTrue);
    });

    test('matches DLT senders with operator/circle prefix', () {
      expect(SmsParserService.isBankSms('VM-SBIINB'), isTrue);
      expect(SmsParserService.isBankSms('JD-MAHABK'), isTrue);
      expect(SmsParserService.isBankSms('bv-sbiupi'), isTrue);
    });

    test('matches post-2024 DLT senders with route suffix', () {
      expect(SmsParserService.isBankSms('BV-SBIUPI-S'), isTrue);
      expect(SmsParserService.isBankSms('AD-MAHABK-T'), isTrue);
      expect(SmsParserService.isBankSms('JM-BOIIND-S'), isTrue);
    });

    test('matches full bank names regardless of case', () {
      expect(SmsParserService.isBankSms('Bank of Maharashtra'), isTrue);
      expect(SmsParserService.isBankSms('BANK OF BARODA'), isTrue);
    });

    test('normalizeSender strips prefix and suffix only', () {
      expect(SmsParserService.normalizeSender('BV-SBIUPI-S'), 'SBIUPI');
      expect(SmsParserService.normalizeSender('JD-MAHABK'), 'MAHABK');
      expect(SmsParserService.normalizeSender('SBIUPI'), 'SBIUPI');
    });

    test('rejects unknown DLT senders (colleges, stores, OTTs)', () {
      expect(SmsParserService.isBankSms('VM-SRMCLG-S'), isFalse);
      expect(SmsParserService.isBankSms('JD-DMRTST'), isFalse);
      expect(SmsParserService.isBankSms('AX-NETFLX-T'), isFalse);
    });

    test('rejects promotional -P routes even from real bank headers', () {
      expect(SmsParserService.isBankSms('VM-HDFCBK-P'), isFalse);
      expect(SmsParserService.isBankSms('BV-SBIUPI-P'), isFalse);
      expect(SmsParserService.isBankSms('VM-HDFCBK-T'), isTrue);
      expect(SmsParserService.isBankSms('BOIIND-S'), isTrue);
    });

    test('does not log non-bank amounts as transactions', () {
      final txn = SmsParserService.parseTransaction(
        'VM-SRMCLG-S',
        'Congratulations! A scholarship of Rs.30,000 has been credited to '
        'your student ledger account for the academic year.',
        DateTime(2026, 6, 1),
      );
      expect(txn, isNull);
    });

    test('drops bank promo SMS sent on the -P route', () {
      final txn = SmsParserService.parseTransaction(
        'VM-HDFCBK-P',
        'Get a pre-approved personal loan of Rs.5,00,000 credited to your '
        'account in minutes! Apply now.',
        DateTime(2026, 6, 1),
      );
      expect(txn, isNull);
    });
  });

  group('SBI message formats', () {
    test('parses UPI debit with bare amount (no Rs/INR marker)', () {
      final txn = SmsParserService.parseTransaction(
        'BV-SBIUPI-S',
        'Dear UPI user A/C X4321 debited by 35.0 on date 01Jun26 trf to '
        'RAMESH KUMAR Refno 612345678901. If not u? call 1800111109. -SBI',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 35.0);
      expect(txn.type, TransactionType.debit);
    });

    test('parses UPI credit with bare amount', () {
      final txn = SmsParserService.parseTransaction(
        'AD-SBIUPI-S',
        'Dear SBI UPI User, ur A/cX4321 credited by Rs100 on 01Jun26 by '
        '(Ref no 612345678902)',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 100.0);
      expect(txn.type, TransactionType.credit);
    });

    test('keeps transaction despite YONO promo footer with OFFER keyword', () {
      final txn = SmsParserService.parseTransaction(
        'VM-SBIINB-S',
        'Your A/C XXXXX4321 has a debit by transfer of Rs 2,500.00 on '
        '01Jun26. Avl Bal Rs 18,450.50. Download YONO for exciting offers!',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 2500.0);
      expect(txn.type, TransactionType.debit);
    });

    test('does not pick the balance as the amount', () {
      final txn = SmsParserService.parseTransaction(
        'BV-SBIUPI-S',
        'Dear UPI user A/C X4321 credited by 250.0 on date 01Jun26. '
        'Avl Bal Rs 99,999.99 -SBI',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 250.0);
    });

    test('ATM withdrawal', () {
      final txn = SmsParserService.parseTransaction(
        'ATMSBI',
        'Dear Customer, Rs.2000 withdrawn at SBI ATM S1NW000123001 from '
        'A/cX4321 on 01Jun26. Avl Bal Rs 5,000.00',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 2000.0);
      expect(txn.type, TransactionType.debit);
    });
  });

  group('Bank of Maharashtra message formats', () {
    test('debit with Avl Bal footer and "registered" security note', () {
      final txn = SmsParserService.parseTransaction(
        'JD-MAHABK-S',
        'Your a/c no. XX1234 is debited for Rs.500.00 on 01-06-2026 by UPI '
        'Ref No 612345678903. Avl Bal Rs.12,345.67. If not done by you, '
        'call from registered mobile - Bank of Maharashtra',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 500.0);
      expect(txn.type, TransactionType.debit);
      expect(txn.accountInfo, 'XX1234');
    });

    test('credit alert', () {
      final txn = SmsParserService.parseTransaction(
        'BOMSMS',
        'A/c XX1234 Credited by Rs.15,000.00 on 01-06-2026 by Mob Banking. '
        'Avl Bal Rs.27,345.67 - Bank of Maharashtra',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 15000.0);
      expect(txn.type, TransactionType.credit);
    });

    test('all DLT header variants are recognised as bank senders', () {
      for (final sender in const [
        'MAHABK',
        'AD-MAHABK-S',
        'AX-MAHABK-S',
        'VK-MAHABK-S',
        'VA-MAHABK-S',
        'VM-MAHABK-S',
        'CP-MAHABK-T',
        'Bank of Maharashtra',
      ]) {
        expect(SmsParserService.isBankSms(sender), isTrue, reason: sender);
      }
    });

    test('"UPI payment to {NAME}" debit extracts the payee, not the a/c', () {
      final txn = SmsParserService.parseTransaction(
        'AD-MAHABK-S',
        'A/c X7763 debited by Rs. 20.00 for UPI payment to SANTOSH ANANT G '
        'on 10-Jun-26. RRN: 616189591413 if not you, call 18002334526 '
        '-Bank of Maharashtra',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 20.0);
      expect(txn.type, TransactionType.debit);
      expect(txn.accountInfo, 'XX7763');
      expect(txn.merchantName, 'Santosh Anant G');
    });
  });

  group('Non-transaction rejection', () {
    test('rejects OTP messages even when they mention an amount', () {
      final txn = SmsParserService.parseTransaction(
        'BV-SBIOTP-S',
        'OTP for txn of Rs.5,000.00 at AMAZON on your card XX1234 is '
        '482910. Valid for 10 mins. Do not share with anyone. -SBI',
        now,
      );
      expect(txn, isNull);
    });

    test('keeps real debit with "Never share OTP/PIN" footer', () {
      final txn = SmsParserService.parseTransaction(
        'JM-BOIIND-S',
        'Rs.750.00 debited from A/c XX5678 on 01Jun26 via UPI Ref '
        '612345678904. Never share OTP/PIN with anyone. -Bank of India',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 750.0);
    });

    test('rejects UPI collect requests (money not moved yet)', () {
      final txn = SmsParserService.parseTransaction(
        'VM-SBIUPI-S',
        'RAMESH KUMAR has requested money of Rs.1,200.00 from you on UPI. '
        'Approve before 02Jun26 -SBI',
        now,
      );
      expect(txn, isNull);
    });

    test('rejects autopay reminders for future debits', () {
      final txn = SmsParserService.parseTransaction(
        'HDFCBK',
        'Rs.199.00 will be debited from your A/c XX5678 on 05-06-2026 '
        'towards NETFLIX autopay mandate.',
        now,
      );
      expect(txn, isNull);
    });

    test('rejects failed transaction alerts', () {
      final txn = SmsParserService.parseTransaction(
        'BV-SBIUPI-S',
        'UPI txn of Rs.300.00 on 01Jun26 failed due to insufficient '
        'balance in A/c X4321. -SBI',
        now,
      );
      expect(txn, isNull);
    });

    test('rejects credit card statement messages', () {
      final txn = SmsParserService.parseTransaction(
        'HDFCBK',
        'Your HDFC Bank Credit Card statement is generated. Total due '
        'Rs.5,430.00, Minimum due Rs.270.00, Due date 15-06-2026.',
        now,
      );
      expect(txn, isNull);
    });

    test('keeps transaction at merchant containing PIN substring', () {
      final txn = SmsParserService.parseTransaction(
        'ICICIB',
        'INR 899.00 spent on ICICI Bank Card XX9012 on 01-Jun-26 at '
        'SHOPPING STOP. Avl Lmt: INR 45,000.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 899.0);
      expect(txn.type, TransactionType.debit);
    });
  });

  group('Other banks still parse', () {
    test('HDFC sent format', () {
      final txn = SmsParserService.parseTransaction(
        'HDFCBK',
        'Sent Rs.30.00\nFrom HDFC Bank A/C *9463\nTo Mumbai Metro '
        'Ghatkopar\nOn 01/06/26\nRef 612345678905',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 30.0);
      expect(txn.type, TransactionType.debit);
      expect(txn.merchantName, isNotNull);
    });

    test('ICICI Info format with merchant', () {
      final txn = SmsParserService.parseTransaction(
        'ICICIT',
        'ICICI Bank Acct XX012 debited for Rs 450.00 on 01-Jun-26; '
        'Info: UPI-612345678906-SWIGGY. Call 18002662 for dispute.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 450.0);
      expect(txn.merchantName, 'Swiggy');
      expect(txn.category, 'Food & Dining');
    });
  });

  group('ICICI UPI "debited for ...; PAYEE credited" (debit, not credit)', () {
    // Regression: a real ICICI UPI outflow was being shown as a credit
    // because "<payee> credited" + the weak "CREDIT" keyword out-scored the
    // "debited" signal. An account-debited marker must win.
    test('UPI payment is a debit despite the payee being "credited"', () {
      final txn = SmsParserService.parseTransaction(
        'AD-ICICIT-S',
        'ICICI Bank Acct XX197 debited for Rs 73.00 on 16-Jun-26; '
        'JAY RAJESH KEER credited. UPI:123834511400. Call 18002662 for '
        'dispute. SMS BLOCK 197 to 9215676766.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 73.0);
      expect(txn.type, TransactionType.debit);
    });

    test('genuine ICICI incoming credit is still a credit', () {
      final txn = SmsParserService.parseTransaction(
        'AD-ICICIT-S',
        'ICICI Bank Acct XX197 credited with Rs 73.00 on 16-Jun-26 from '
        'JAY RAJESH KEER. UPI:123834511400. Call 18002662 for dispute.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 73.0);
      expect(txn.type, TransactionType.credit);
    });
  });

  group('ICICI false-positive credits (offers & card bill payments)', () {
    // These arrive on the transactional -S route, so the -P promo filter
    // doesn't catch them; both were being logged as income.
    test('rejects a credit-limit-increase offer', () {
      final txn = SmsParserService.parseTransaction(
        'AX-ICICIT-S',
        'Manage spends effectively by increasing the limit on ICICI Bank '
        'Credit Card XX8018 from Rs50000 to Rs150000. SMS CRLIM 8018 to '
        '5676766 to raise the limit',
        now,
      );
      expect(txn, isNull);
    });

    test('rejects a credit-card bill payment confirmation (not income)', () {
      final txn = SmsParserService.parseTransaction(
        'AX-ICICIT-S',
        'Dear Customer, Payment of INR 11,942.20 has been received on your '
        'ICICI Bank Credit Card Account 6xxx8018 on 08-JUN-26. Thank you.',
        now,
      );
      expect(txn, isNull);
    });

    test('still keeps a genuine credit-card spend as a debit', () {
      final txn = SmsParserService.parseTransaction(
        'AX-ICICIT-S',
        'INR 1,250.00 spent on ICICI Bank Credit Card XX8018 on 08-Jun-26 '
        'at AMAZON. Avl Limit: INR 1,38,058.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 1250.0);
      expect(txn.type, TransactionType.debit);
    });

    test('still keeps a genuine salary credit to a bank account', () {
      final txn = SmsParserService.parseTransaction(
        'AX-ICICIT-S',
        'Your ICICI Bank Account XX197 has been credited with INR 50,000.00 '
        'on 01-Jun-26 towards SALARY. Avl Bal: INR 72,310.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 50000.0);
      expect(txn.type, TransactionType.credit);
    });
  });

  group('Fingerprint dedup across sender variants', () {
    test('same alert via different DLT prefixes produces same fingerprint',
        () {
      const body =
          'Dear UPI user A/C X4321 debited by 35.0 on date 01Jun26 trf to '
          'RAMESH KUMAR Refno 612345678901. -SBI';
      final a = SmsParserService.parseTransaction('BV-SBIUPI-S', body, now)!
          .withFingerprint();
      final b = SmsParserService.parseTransaction('AD-SBIUPI-T', body, now)!
          .withFingerprint();
      expect(a.fingerprint, b.fingerprint);
    });
  });

  // Some banks send credit alerts with no payee/"recipient" name at all — the
  // money came in via UPI ref, net banking, or a slash-delimited ref. These
  // must still be recorded as transactions; the label falls back to the
  // account number (or the embedded name when one is present).
  group('Credits that omit the recipient name', () {
    test('BOI "Credited to your Ac" with only a UPI ref — account fallback', () {
      final txn = SmsParserService.parseTransaction(
        'JM-BOIIND-S',
        'Rs.150.00 Credited to your Ac XX0227 on 25-06-26 by UPI ref '
        'No.654223485048.Avl Bal 15075.63',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 150.0);
      expect(txn.type, TransactionType.credit);
      expect(txn.accountInfo, 'XX0227');
      // No payer name in the body → labelled by the account it landed in.
      expect(txn.merchantName, 'XX0227');
    });

    test('Saraswat credit — last 4 of an unmasked a/c, payer name from UPI ref',
        () {
      final txn = SmsParserService.parseTransaction(
        'VM-SARASW-S',
        'Your A/c no. 000404 is credited with INR 150.00 on 25-06-2026 towards '
        'UPI/340983713462/HUSAIN M N/SR. Current Bal is INR 9,657.61 CR. '
        '- Saraswat Co-op Bank Ltd.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 150.0); // not the 9,657.61 balance
      expect(txn.type, TransactionType.credit);
      expect(txn.accountInfo, 'XX0404'); // last 4 of 000404, not 0004
      expect(txn.merchantName, 'Husain M N'); // pulled from the slash ref
    });

    test('IDBI net-banking credit with letter-masked a/c (NN15983)', () {
      final txn = SmsParserService.parseTransaction(
        'JD-IDBIBK-S',
        'IDBI Bank A/c NN15983 credited for INR 5400.00 through Net Banking. '
        'Bal INR 8438.51 (incl. of chq in clg)  as of 13 MAY 19:33 hrs.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 5400.0); // not the 8438.51 balance
      expect(txn.type, TransactionType.credit);
      expect(txn.accountInfo, 'XX5983'); // last 4 of the NN-masked number
    });
  });
}
