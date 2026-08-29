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
      // Saraswat's card rail. Absent from the DLT registry and not caught by
      // the "contains BANK" net, so without the curated entry its spends
      // were dropped outright.
      expect(SmsParserService.senderTrust('JX-SBCARD-S'),
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
      // ── A card arriving is not money arriving (device report, 2026-08-05) ─
      // Three of these were sitting in one user's income: the amount quoted is
      // the card's credit limit. All came from allowlisted headers, so the
      // promotional-route filter never saw them.
      const _GateCase(
        name: 'AU card dispatch notice is not a ₹4,00,000 credit',
        sender: 'AUBANK',
        message: 'OUT FOR DELIVERY-Your Credit Card ending with XX39 have a '
            'Credit Limit of INR 4,00,000 is Dispatched, For more benefits '
            'Check here https://o4l.me/4913/i0Egc1',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'Kotak card approval notice is not a ₹3,55,000 credit',
        sender: 'KTKBNK',
        message: 'Good News 8104605209- Your Kotak Credit card of Limit '
            'Rs.3,55,000/- is approved. Please Confirm Your details: '
            'https://v6e.in/jxFFh',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'Kotak card approval, unspaced limit, is not a credit',
        sender: 'KOTAKB',
        message: 'Hello 8104605209- Your Kotak Credit card of Limit '
            'Rs.3,15000/- is approved. Please Confirm Your details: '
            'https://v6e.in/k0siX',
        expectParsed: false,
      ),
      // The other side of that rule: a card being *used* still parses, even
      // when the alert quotes the very same limit. The reject keys on the card
      // arriving ("is approved"/"is dispatched"), never on the word "limit" —
      // an earlier draft matched "credit limit of" outright and swallowed this
      // ₹2,500 debit, because a two-digit card tail isn't account evidence.
      const _GateCase(
        name: 'card spend quoting the credit limit still parses',
        sender: 'AUBANK',
        message: 'Rs.2,500.00 spent on your AU Credit Card XX39 at SWIGGY. '
            'Your credit limit of INR 4,00,000 is now INR 3,97,500',
        expectParsed: true,
      ),
      const _GateCase(
        name: 'card spend with an available-limit footer still parses',
        sender: 'VM-HDFCBK-S',
        message: 'Rs.2,500.00 spent on your HDFC Bank Credit Card xx1234 at '
            'AMAZON on 05-08-26. Avl Lmt: Rs 55,000. Not you? Call 18002586161',
        expectParsed: true,
      ),
      // ── Changing a limit is not spending it (device report, 2026-08-06) ───
      // The reported message, logged as a ₹10,000 debit in "Needs review", and
      // logged again on every later change — which is the whole problem, since
      // people move their transfer cap up and down routinely.
      const _GateCase(
        name: 'HDFC third-party transfer limit is not a ₹10,000 debit',
        sender: 'VM-HDFCBK-S',
        message: 'Transfer Limit Updated! HDFC Bank Third Party Transfer '
            'limit is set to Rs. 10000. Limit applicable per Customer ID per '
            'day. Not you? Call 18002586161',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'HDFC own-account transfer limit is not a ₹5,00,000 debit',
        sender: 'VM-HDFCBK-S',
        message: 'Transfer Limit Updated! HDFC Bank Own Account Transfer '
            'limit is set to Rs. 500000. Limit applicable per Customer ID per '
            'day. Not you? Call 18002586161',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'debit-card usage limits being updated is not a transaction',
        sender: 'AD-HDFCBK-S',
        message: 'Dear Customer, the daily limits on your HDFC Bank Debit '
            'Card XX1234 have been updated. ATM: Rs.25000, POS: Rs.50000, '
            'Online: Rs.100000.',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'UPI limit changed, verb-first phrasing, is not a transaction',
        sender: 'VM-HDFCBK-S',
        message: 'As requested, we have updated your daily UPI transfer limit '
            'to Rs. 25000. Not you? Call 18002586161',
        expectParsed: false,
      ),
      // ── A credit limit being cut (device report, 2026-08-13) ─────────────
      // The reported message, logged as ₹2,00,000 of INCOME: "changed from
      // INR 200000" reads as money arriving, and the card tail gave it the
      // account evidence it needed. The card and its number sit between
      // "limit" and "has been changed", so the tight noun-verb windows above
      // never saw the pair.
      const _GateCase(
        name: 'ICICI credit limit reduction is not a ₹2,00,000 credit',
        sender: 'JX-ICICIT-S',
        message: 'Dear Customer, The credit limit for your ICICI Bank Credit '
            'Card XX6528 has been changed from INR 200000 to INR 60000 on '
            '2026-08-08.',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'a limit being raised the same way is not income either',
        sender: 'VM-HDFCBK-S',
        message: 'Dear Customer, the daily UPI transfer limit on your HDFC '
            'Bank Account XX9463 has been increased from Rs.25,000 to '
            'Rs.1,00,000.',
        expectParsed: false,
      ),
      // The other side of that rule, and the reason it is guarded on a settled
      // verb rather than rejecting the word "limit" outright: an alert that
      // reports the remaining cap alongside a spend is still a spend.
      const _GateCase(
        name: 'spend that reports the updated limit still parses',
        sender: 'VM-HDFCBK-S',
        message: 'Rs.2,500.00 spent on your HDFC Bank Credit Card xx1234 at '
            'AMAZON on 06-08-26. Available limit updated to Rs 3,97,500.',
        expectParsed: true,
      ),
      // ...and the same, worded with the phrase the new pattern keys on. A
      // settled verb outranks every limit reject, so a spend survives even
      // when the bank reports the cap change in the same breath.
      const _GateCase(
        name: 'spend alongside a "limit has been changed" note still parses',
        sender: 'VM-HDFCBK-S',
        message: 'Rs.2,500.00 spent on your HDFC Bank Credit Card xx1234 at '
            'AMAZON on 06-08-26. Your credit limit has been changed to '
            'Rs 3,97,500.',
        expectParsed: true,
      ),

      // ── Marketing on the transactional route ─────────────────────────────
      // Promo CTAs used to be checked for fallback-trust senders only, on the
      // reasoning that a registered bank header is trustworthy. Banks market
      // to their own customers on -S too. Reported from a device 2026-08-18:
      // this landed as ₹250 of INCOME and sat in the Tidy-up queue, which is
      // meant for genuine transactions the reader was unsure about.
      const _GateCase(
        name: 'HDFC voucher pitch on the -S route, rejected',
        sender: 'VM-HDFCBN-S',
        message: 'Congrats!Claim Rs.250 voucher for activating HDFC Bank '
            'Credit Card in July 26\nUse code 1T7B34F2 by 13-Sep-2026 '
            'https://1.hdfc.bank.in/HDFCBK/s/8Kqd18AX\nT&C',
        expectParsed: false,
      ),
      const _GateCase(
        name: 'allowlisted-sender promo quoting a card tail, rejected',
        sender: 'VM-ICICIB-S',
        message: 'Congratulations! Your ICICI Bank Card XX9012 is '
            'pre-approved for a limited time offer. T&C apply.',
        expectParsed: false,
      ),
      // The guard's other half: promo copy only gets to decide when nothing
      // in the message says money actually moved. A real debit that carries
      // the same footer must survive, or every bank's "T&C apply" tagline
      // would start deleting transactions.
      const _GateCase(
        name: 'genuine debit whose footer carries T&C still parses',
        sender: 'VM-HDFCBK-S',
        message: 'Rs.499.00 debited from A/c XX1234 on 18-08-26 for a '
            'voucher purchase at BOOKMYSHOW. Refno 812345678901. '
            'Avl Bal Rs.7,020.10. T&C apply.',
        expectParsed: true,
      ),
      // A terse UPI alert has no settled verb AND no account, ref or balance
      // to stand on. Absence of evidence therefore cannot be a rejection on
      // its own — only promo vocabulary can tip it — so this must parse.
      const _GateCase(
        name: 'terse SBI UPI debit with neither verb nor evidence parses',
        sender: 'BV-SBIUPI-S',
        message: 'Rs.120 payment to RAMESH via APP done -SBI',
        expectParsed: true,
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

  // The schema-31 heal: a parser fix reaches messages read after it ships, but
  // the rows already in the table keep whatever reading they were given. Two of
  // the three card promos reported on 2026-08-05 were *already* unreadable by
  // the parser — they had simply never been re-read, and sat in the user's
  // income for months.
  group('stored rows today\'s parser refuses', () {
    test('a card-dispatch promo already logged is dropped', () {
      expect(
        SmsParserService.wouldRejectStoredMessage(
          'AUBANK',
          'OUT FOR DELIVERY-Your Credit Card ending with XX39 have a Credit '
              'Limit of INR 4,00,000 is Dispatched, For more benefits Check '
              'here https://o4l.me/4913/i0Egc1',
          now,
        ),
        isTrue,
      );
    });

    test('a limit-change notice already logged is dropped', () {
      // What the schema-32 pass is for: this one repeats, so a user who has
      // been changing their transfer cap has a row per change to clear.
      expect(
        SmsParserService.wouldRejectStoredMessage(
          'VM-HDFCBK-S',
          'Transfer Limit Updated! HDFC Bank Third Party Transfer limit is '
              'set to Rs. 10000. Limit applicable per Customer ID per day. '
              'Not you? Call 18002586161',
          now,
        ),
        isTrue,
      );
    });

    test('a genuine stored debit is kept', () {
      expect(
        SmsParserService.wouldRejectStoredMessage(
          'JD-ABCBANK-S',
          'Rs.250.00 debited from A/c XX9912 on 05-Jul-26 for UPI payment to '
              'SWIGGY. Refno 719912345678. Avl Bal Rs.10,201.55',
          now,
        ),
        isFalse,
      );
    });

    test('a row whose header lost trust is kept, message notwithstanding', () {
      // The sender must never be the reason a stored row is deleted: an
      // allowlist that narrows would otherwise take genuine history with it.
      expect(SmsParserService.isBankSms('AX-NETFLX-T'), isFalse);
      expect(
        SmsParserService.wouldRejectStoredMessage(
          'AX-NETFLX-T',
          'Your subscription is active.',
          now,
        ),
        isFalse,
      );
    });

    test('a row with no message behind it is kept', () {
      expect(
        SmsParserService.wouldRejectStoredMessage('Manual entry', '   ', now),
        isFalse,
      );
    });

    test('imported statement rows need the caller\'s guard, not this test', () {
      // A statement import writes `IMPORT-<LABEL>` senders and narrations the
      // parser was never meant to read. "IMPORT-HDFC BANK" contains BANK, so
      // it clears the header net and its narration parses to nothing — this
      // predicate alone would delete every imported row. The migration's
      // `sender NOT LIKE 'IMPORT-%'` guard is what holds them out, and this
      // test fails loudly if anyone decides that guard looks redundant.
      expect(SmsParserService.isBankSms('IMPORT-HDFC BANK'), isTrue);
      expect(
        SmsParserService.wouldRejectStoredMessage(
          'IMPORT-HDFC BANK',
          'POS PURCHASE BIG BAZAAR (Ref 88213)',
          now,
        ),
        isTrue,
      );
    });
  });

  group('rows stored under the old account fallback are re-read', () {
    // Reported from the device on 2026-08-01: two IndusInd credits still
    // showing "Received from XX3209" above "Account XX3209", with "Read by:
    // account fallback" underneath — a label the parser stopped producing in
    // v1.55.1. The messages parse correctly now; these rows were written by
    // the older build and nothing re-reads a stored row, so the fix never
    // reached them.
    const indusIndCredit =
        'A/C *XX3209 credited by Rs 90.00 from kumbharyashvant5-1@okaxis. '
        'RRN:621348000140. Avl Bal:7416.01. Not you? Call 18602677777 - '
        'IndusInd bank';

    test('the reported credit heals to the payer, not the account', () {
      final fresh = DatabaseService.rereadAccountFallbackPayee(
        storedPayee: 'XX3209',
        accountInfo: 'XX3209',
        message: indusIndCredit,
      );
      expect(fresh, isNotNull);
      expect(fresh!.payee, 'Kumbharyashvant5-1');
      expect(fresh.payee, isNot('XX3209'));
      expect(fresh.source, isNot('account fallback'));
    });

    test('an unreadable payer is cleared rather than left as the account', () {
      // The invariant the migration carries into stored rows: the account is
      // one side of the transaction, so it is never the other. With no payer
      // in the body the counterparty is simply unknown.
      final fresh = DatabaseService.rereadAccountFallbackPayee(
        storedPayee: 'XX3209',
        accountInfo: 'XX3209',
        message: 'A/C *XX3209 credited by Rs 90.00. RRN:621348000140. '
            'Avl Bal:7416.01. - IndusInd bank',
      );
      expect(fresh, isNotNull);
      expect(fresh!.payee, isNull);
      expect(fresh.source, 'no payee named');
    });

    test('a bare masked number from any account counts as the fallback', () {
      // Rows saved before account_info was reliable carry the mask alone.
      final fresh = DatabaseService.rereadAccountFallbackPayee(
        storedPayee: '**3209',
        accountInfo: null,
        message: indusIndCredit,
      );
      expect(fresh?.payee, 'Kumbharyashvant5-1');
    });

    test('a name the user typed over the fallback is left alone', () {
      expect(
        DatabaseService.rereadAccountFallbackPayee(
          storedPayee: 'Yashvant',
          accountInfo: 'XX3209',
          message: indusIndCredit,
        ),
        isNull,
      );
    });

    test('real payees and curated placeholders are left alone', () {
      // "UPI Transfer" and "ATM" are what the parser says today, not the old
      // fallback — re-reading them would be churn at best.
      for (final stored in ['Sharma Kirana', 'UPI Transfer', 'ATM']) {
        expect(
          DatabaseService.rereadAccountFallbackPayee(
            storedPayee: stored,
            accountInfo: 'XX7848',
            message: 'Rs.800.00 Credited to your Ac XX7848 on 24-06-26 by '
                'UPI ref No.654169525627',
          ),
          isNull,
          reason: '$stored must survive the migration',
        );
      }
    });

    test('a manual entry with no message behind it is left alone', () {
      expect(
        DatabaseService.rereadAccountFallbackPayee(
          storedPayee: 'XX3209',
          accountInfo: 'XX3209',
          message: '',
        ),
        isNull,
      );
    });
  });

  group('rows the parser could not name are re-read (schema 33)', () {
    // Reported from the device on 2026-08-29: a ₹1,96,901 Flywire tuition
    // payment stored with no payee at all. The message parses correctly now;
    // the row was written by an older build, and nothing re-reads a stored
    // row, so the fix would never have reached it.
    const hdfcFlywire =
        'UPDATE: INR 1,96,901.00 debited from HDFC Bank XX9463 on 27-AUG-26. '
        'Info: FLYWIRE TXN RFX 270826FLYT03707. Avl bal:INR 2,021.93';

    test('the stored row qualifies as unnamed and today re-reads to a name',
        () {
      // The two halves of the migration's condition. Both must hold for the
      // reported row, or the sweep walks straight past it.
      expect(DatabaseService.isUnnamedPayee(null, 'XX9463'), isTrue);
      final fresh = SmsParserService.extractMerchantDetailed(
        hdfcFlywire,
        'XX9463',
      );
      expect(fresh.name, 'Flywire');
      expect(fresh.payeeUnknown, isFalse);
      expect(DatabaseService.isUnnamedPayee(fresh.name, 'XX9463'), isFalse);
    });

    test('a name the user typed over it is not unnamed, so it survives', () {
      // The sweep touches only rows the parser could not name; anything the
      // user has since called it is left exactly as it is.
      expect(DatabaseService.isUnnamedPayee('Uni fees', 'XX9463'), isFalse);
      expect(DatabaseService.isUnnamedPayee('ATM', 'XX9463'), isFalse);
      expect(DatabaseService.isUnnamedPayee('Bank Charges', 'XX9463'), isFalse);
    });

    test('"UPI Transfer" and the old account fallback still qualify', () {
      // Rows the earlier passes parked on a placeholder get another chance
      // now that the parser reads more shapes.
      expect(DatabaseService.isUnnamedPayee('UPI Transfer', 'XX9463'), isTrue);
      expect(DatabaseService.isUnnamedPayee('XX9463', 'XX9463'), isTrue);
      expect(DatabaseService.isUnnamedPayee('', 'XX9463'), isTrue);
    });
  });
}
