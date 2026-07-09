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
}
