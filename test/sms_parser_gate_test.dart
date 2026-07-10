import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/database_service.dart';
import 'package:budget_tracker/services/sms_parser_service.dart';

/// Table-driven corpus for the promo/transaction gate.
///
/// Each case is a real-shaped SMS with the sender header it would arrive
/// from. `expectParsed` states whether the parser must log it. Grow this
/// table with every misparse reported in open testing: one report → one row
/// → one permanent regression guard.
class _GateCase {
  final String name;
  final String sender;
  final String message;
  final bool expectParsed;

  const _GateCase({
    required this.name,
    required this.sender,
    required this.message,
    required this.expectParsed,
  });
}

void main() {
  final now = DateTime(2026, 7, 5, 10, 30);

  group('senderTrust — header tiers', () {
    test('allowlisted bank headers get full trust', () {
      expect(SmsParserService.senderTrust('VM-HDFCBK-S'),
          SenderTrust.allowlisted);
      expect(SmsParserService.senderTrust('BV-SBIUPI-T'),
          SenderTrust.allowlisted);
      expect(SmsParserService.senderTrust('Bank of Maharashtra'),
          SenderTrust.allowlisted);
    });

    test('unknown headers containing BANK get fallback trust only', () {
      expect(SmsParserService.senderTrust('JD-ABCBANK-S'),
          SenderTrust.headerFallback);
      expect(SmsParserService.senderTrust('SVC BANK'),
          SenderTrust.headerFallback);
    });

    test('non-bank and promotional-route senders get no trust', () {
      expect(SmsParserService.senderTrust('AX-NETFLX-T'), SenderTrust.none);
      expect(SmsParserService.senderTrust('VM-HDFCBK-P'), SenderTrust.none);
      expect(SmsParserService.senderTrust('JD-ABCBANK-P'), SenderTrust.none);
    });

    test('isBankSms keeps its meaning: any trust at all', () {
      expect(SmsParserService.isBankSms('VM-HDFCBK-S'), isTrue);
      expect(SmsParserService.isBankSms('JD-ABCBANK-S'), isTrue);
      expect(SmsParserService.isBankSms('AX-NETFLX-T'), isFalse);
    });
  });

  group('promo/transaction gate corpus', () {
    final cases = <_GateCase>[
      // ── Fallback-trust senders: evidence required ────────────────────────
      const _GateCase(
        name: 'unknown co-op bank, genuine debit with a/c + ref, parses',
        sender: 'JD-ABCBANK-S',
        message: 'Rs.250.00 debited from A/c XX9912 on 05-Jul-26 for UPI '
            'payment to SWIGGY. Refno 719912345678. Avl Bal Rs.10,201.55',
        expectParsed: true,
      ),
      const _GateCase(
        name: 'loan promo without -P suffix, no evidence, rejected',
        sender: 'JD-BANKBZR-S',
        message: 'Dear Customer, get a personal loan of Rs.5,00,000 credited '
            'to your account in 10 minutes! Zero paperwork.',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'promo naming an account but carrying a CTA, rejected',
        sender: 'AX-HOMEBANK-S',
        message: 'Rs.2,000 cashback credited for A/c XX1234 users! Apply now',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'pre-approved pitch with transaction verb, rejected',
        sender: 'JD-ABCBANK-S',
        message: 'Pre-approved loan of Rs.3,00,000 can be credited to A/c '
            'XX8821 today. Reply YES.',
        expectParsed: false,
      ),
      // ── Soft-reject keywords now need evidence, all sender tiers ─────────
      const _GateCase(
        name: 'allowlisted cashback-offer promo with verb, no evidence, '
            'rejected',
        sender: 'VM-HDFCBK-S',
        message: 'Rs.500 CASHBACK OFFER! Amount credited instantly when you '
            'shop above Rs.4999. Limited period offer.',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'genuine credit with an offer footer keeps parsing',
        sender: 'BV-SBIUPI-S',
        message: 'Dear Customer, Rs.1,200.00 credited to A/c XX4321 on '
            '05Jul26 by transfer. Avl Bal Rs.15,000.00. Explore YONO offer '
            'on personal loans.',
        expectParsed: true,
      ),
      // ── Promised money is not moved money ────────────────────────────────
      const _GateCase(
        name: 'refund promise "will be credited" is not income yet',
        sender: 'VM-ICICIB-S',
        message: 'Refund of Rs.999.00 initiated for your order. The amount '
            'will be credited to your account within 5-7 working days.',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'autopay reminder "will be debited" stays rejected',
        sender: 'VM-HDFCBK-S',
        message: 'Reminder: Rs.599.00 will be debited from A/c XX9463 on '
            '10-Jul-26 towards your OTT autopay mandate.',
        expectParsed: false,
      ),
      // Real user report (open-testing device, 2026-07): Saraswat standing-
      // instruction reminder from the allowlisted SARBNK header was logged
      // as a ₹1200 debit. Reminder-speak = money not moved yet.
      const _GateCase(
        name: 'Saraswat S.I. reminder "will be executed" is not a debit',
        sender: 'JX-SARBNK-S',
        message: 'Dear Customer, Your scheduled S.I. transaction for INR '
            '1200 towards 0777 installment debit to account no. ending with '
            '0777 will be executed on 10-07-2026. Please maintain sufficient '
            'balance to avoid penal charges.- Saraswat Co-op Bank Ltd.',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'NACH "will be processed" reminder is rejected',
        sender: 'VM-HDFCBK-S',
        message: 'Your NACH mandate of Rs.2,500.00 for MUTUAL FUND SIP will '
            'be processed on 12-Jul-26 from A/c XX9463.',
        expectParsed: false,
      ),
      // Real user report: a declined card transaction was sitting in the
      // ledger as a ₹457.42 debit (logged by a pre-hardening app version).
      const _GateCase(
        name: 'declined card transaction is not a debit',
        sender: 'AD-HDFCBK-S',
        message: 'Transaction Declined!\nRs.457.42\nOn HDFC Bank Card 7531 '
            'by Visa\nReason: Non-Compliant transaction.\nKindly use '
            'Alternate mode.',
        expectParsed: false,
      ),
    ];

    for (final c in cases) {
      test(c.name, () {
        final txn = SmsParserService.parseTransaction(c.sender, c.message, now);
        if (c.expectParsed) {
          expect(txn, isNotNull, reason: 'should parse: ${c.message}');
        } else {
          expect(txn, isNull, reason: 'should reject: ${c.message}');
        }
      });
    }

    test('fallback-trust genuine debit parses with the right numbers', () {
      final txn = SmsParserService.parseTransaction(
        'JD-ABCBANK-S',
        'Rs.250.00 debited from A/c XX9912 on 05-Jul-26 for UPI payment to '
        'SWIGGY. Refno 719912345678. Avl Bal Rs.10,201.55',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 250.0);
      expect(txn.type, TransactionType.debit);
      expect(txn.merchantName, isNotNull);
    });
  });

  group('review-queue containment for fallback-trust senders', () {
    const swiggyDebit = 'Rs.250.00 debited from A/c XX9912 on 05-Jul-26 for '
        'UPI payment to SWIGGY. Refno 719912345678. Avl Bal Rs.10,201.55';

    test('fallback-trust transaction lands in the unclassified queue', () {
      final txn =
          SmsParserService.parseTransaction('JD-ABCBANK-S', swiggyDebit, now);
      expect(txn, isNotNull);
      // The category may still be detected, but the user confirms it once
      // instead of the app silently tagging a weakly-trusted sender.
      expect(txn!.isClassified, isFalse);
    });

    test('same message from an allowlisted bank stays auto-classified', () {
      final txn =
          SmsParserService.parseTransaction('BV-SBIUPI-S', swiggyDebit, now);
      expect(txn, isNotNull);
      expect(txn!.category, isNotNull);
      expect(txn.isClassified, isTrue);
    });
  });

  group('payee alias key normalization', () {
    test('case and whitespace runs collapse into one key', () {
      expect(DatabaseService.normalizePayeeKey('  paytm.s21upj5@pty '),
          'PAYTM.S21UPJ5@PTY');
      expect(DatabaseService.normalizePayeeKey('Sharma   Kirana'),
          'SHARMA KIRANA');
      expect(DatabaseService.normalizePayeeKey('sharma kirana'),
          DatabaseService.normalizePayeeKey('SHARMA KIRANA'));
    });

    test('distinct payees stay distinct keys', () {
      expect(
        DatabaseService.normalizePayeeKey('XX1234') ==
            DatabaseService.normalizePayeeKey('XX1235'),
        isFalse,
      );
    });
  });

  group('payee extraction — common bank formats', () {
    // Real user report: HDFC ATM withdrawals collapsed to the card number
    // ("XX7531"); a rename/alias on that string then spread to every
    // unknown-payee message from the same card. All cash withdrawals now
    // share the uniform payee "ATM" so one tag rule covers them all.
    test('HDFC ATM withdrawal (card at location) → payee "ATM"', () {
      final txn = SmsParserService.parseTransaction(
        'AD-HDFCBK-S',
        'Withdrawn Rs.500 From HDFC Bank Card x7531 At BHANDUP BRANCH On '
        '2026-03-31:21:13:43 Bal Rs.16849.87 Not You? '
        'Call 18002586161/SMS BLOCK DC  7531 to 7308080808',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.debit);
      expect(txn.amount, 500.0);
      expect(txn.merchantName, 'ATM');
    });

    test('HDFC ATM withdrawal at an airport gate → still payee "ATM"', () {
      final txn = SmsParserService.parseTransaction(
        'JM-HDFCBK-S',
        'Withdrawn Rs.5000 From HDFC Bank Card x7531 At T2 MUM DEP OUT '
        'GATE2 On 2026-03-21:15:02:34 Bal Rs.30571.87 Not You? '
        'Call 18002586161/SMS BLOCK DC  7531 to 7308080808',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 5000.0);
      expect(txn.merchantName, 'ATM');
    });

    test('SBI "ATM WDL" → payee "ATM"', () {
      final txn = SmsParserService.parseTransaction(
        'BV-SBIUPI-S',
        'ATM WDL of Rs 2,000 from A/c XX4321 on 05Jul26 at S1AW000123 '
        'KANDIVALI. Avl Bal Rs 8,111.00.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.debit);
      expect(txn.amount, 2000.0);
      expect(txn.merchantName, 'ATM');
    });

    test('card spend at a merchant is NOT collapsed to "ATM"', () {
      final txn = SmsParserService.parseTransaction(
        'VM-HDFCBK-S',
        'Spent Rs.289 From HDFC Bank Card x7531 At XSOLLA *POKEMON On '
        '2026-07-08:00:40:19 Bal Rs.10000.00 Not You? Call 18002586161',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.merchantName, isNot('ATM'));
    });

    test('ICICI debit "; PAYEE credited" names the recipient', () {
      final txn = SmsParserService.parseTransaction(
        'AD-ICICIT-S',
        'ICICI Bank Acct XX197 debited for Rs 73.00 on 16-Jun-26; '
        'JAY RAJESH KEER credited. UPI:123834511400. Call 18002662 for '
        'dispute. SMS BLOCK 197 to 9215676766.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.debit);
      expect(txn.merchantName, 'Jay Rajesh Keer');
    });

    test('ICICI credit "from {PAYER}" names the payer', () {
      final txn = SmsParserService.parseTransaction(
        'AD-ICICIT-S',
        'ICICI Bank Acct XX197 credited with Rs 73.00 on 16-Jun-26 from '
        'JAY RAJESH KEER. UPI:123834511400. Call 18002662 for dispute.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.credit);
      expect(txn.merchantName, 'Jay Rajesh Keer');
    });

    test('Axis UPI/P2M narration names the merchant', () {
      final txn = SmsParserService.parseTransaction(
        'AX-AXISBK-S',
        'INR 500.00 debited from A/c no. XX1234 on 05-07-26 12:32:11 '
        'UPI/P2M/519163817411/SHARMA STORES/Not You? SMS BLOCK to 919951860002',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.debit);
      expect(txn.merchantName, 'Sharma Stores');
    });
  });

  group('account-fallback payees never become aliases', () {
    test('detects the fallback shapes', () {
      expect(DatabaseService.isAccountFallbackPayee('XX7531', 'XX7531'),
          isTrue);
      expect(DatabaseService.isAccountFallbackPayee('XX7531', null), isTrue);
      expect(DatabaseService.isAccountFallbackPayee('xx7531', 'XX7531'),
          isTrue);
      expect(DatabaseService.isAccountFallbackPayee('**1234', null), isTrue);
    });

    test('nameless-transfer placeholder is never an alias key', () {
      // Distinct counterparties share "UPI Transfer", so a rename on one
      // must stay per-row instead of teaching a spreading alias.
      expect(DatabaseService.isAccountFallbackPayee('UPI Transfer', 'XX7848'),
          isTrue);
      expect(DatabaseService.isAccountFallbackPayee('UPI TRANSFER', null),
          isTrue);
    });

    test('real payee names are not treated as fallbacks', () {
      // "ATM" stays aliasable: cash withdrawals share one real counterparty.
      expect(DatabaseService.isAccountFallbackPayee('ATM', 'XX7531'),
          isFalse);
      expect(DatabaseService.isAccountFallbackPayee('Sharma Kirana', 'XX7531'),
          isFalse);
      expect(
          DatabaseService.isAccountFallbackPayee('JAY RAJESH KEER', null),
          isFalse);
      expect(DatabaseService.isAccountFallbackPayee(null, 'XX7531'), isFalse);
    });
  });
}
