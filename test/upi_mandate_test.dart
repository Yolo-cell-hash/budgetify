import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/models/upi_mandate.dart';
import 'package:budget_tracker/services/recurring_service.dart';
import 'package:budget_tracker/services/sms_parser_service.dart';
import 'package:budget_tracker/services/upi_mandate_parser.dart';

// The four real mandate-registration shapes, and the two execution alerts
// that follow them. Kept together because the whole point of this parser is
// telling one from the other — both say "UPI Mandate".

const _iciciCreated =
    'ICICI Bank SAVINGS Account XX197 will be debited for Rs 3000.00 on '
    '23-Jul-26 towards Autopay for ICCL GROWW AUTO, UPI Mandate, Unique '
    'Mandate Number 4a37de14c053467b8e7dfaa019ab432f@okicici  (ICICI Bank)';

const _hdfcCreated = 'Mandate Set\n'
    'Rs.1999.00\n'
    'For Google Play\n'
    'From HDFC Bank A/c x9463\n'
    'UMN: 49eacec4698a4140bf2e688e78a5d155@ok\n'
    'Not you?\n'
    'Call 18002586161';

const _boiCreated =
    'BOI UPI - Your UPI-Mandate is successfully created towards SPOTIFY '
    'INDIA PVT LTD for Rs.139.00.';

const _sbiCreated =
    'Your UPI-Mandate for Rs.1950.00 is successfully created towards Google '
    'Play from A/c No: XXXXXXXX1234. If not you, kindly report on 18001234. '
    '-SBI';

const _hdfcExecuted = 'UPI Mandate:\n'
    'Sent Rs.1999.00\n'
    'from HDFC Bank A/c 9463\n'
    'To Google Play\n'
    '11/06/26\n'
    'Ref 258129441626\n'
    'Not You? Call 18002586161/SMS BLOCK UPI to 7308080808';

const _iciciExecuted =
    'Rs 3000.00 debited from ICICI Bank Savings Account XX197 on 23-Jul-26 '
    'towards ICCL GROWW AUTO for UPI Mandate AutoPay Retrieval Ref '
    'No.103709467589';

// The other end of a mandate's life. Reported from a device on 2026-08-10:
// cancelling a Coursera subscription was logged as ₹2,099 of INCOME, because
// "Funds unblocked from A/C" scores as a credit and nothing objected. Note
// the UMN is written "Umn <id>" with no colon, so the creation patterns —
// which look for "UMN:" — never saw it either.
const _boiRevoked =
    'BOI UPI-Mandate revoked for Coursera Rs.2099.00.Funds unblocked from '
    'A/C No. XXXXXXXXXXX7848 Umn 6c33271a3a134e8582f78f10b68f2f7a@okicici '
    'Ref no 603466871809';

void main() {
  final now = DateTime(2026, 8, 4, 10, 30);

  group('Mandate creation is recognised', () {
    test('ICICI autopay registration', () {
      final m = UpiMandateParser.parse('AD-ICICIT-S', _iciciCreated, now);
      expect(m, isNotNull);
      expect(m!.merchant, 'Iccl Groww Auto');
      expect(m.amount, 3000.0);
      expect(m.firstDebitOn, DateTime(2026, 7, 23));
      expect(m.umn, '4a37de14c053467b8e7dfaa019ab432f@okicici');
      // ICICI masks to three digits ("Account XX197"). The account patterns
      // used to require a four-digit tail, so this came back null; they now
      // fall back to shorter masked runs, and the mandate records the same
      // account as the transactions it will match.
      expect(m.accountInfo, 'XX197');
    });

    test('HDFC "Mandate Set" block', () {
      final m = UpiMandateParser.parse('VM-HDFCBK-S', _hdfcCreated, now);
      expect(m, isNotNull);
      expect(m!.merchant, 'Google Play');
      expect(m.amount, 1999.0);
      expect(m.umn, '49eacec4698a4140bf2e688e78a5d155@ok');
      expect(m.accountInfo, 'XX9463');
    });

    test('BOI one-liner', () {
      final m = UpiMandateParser.parse('JM-BOIIND-S', _boiCreated, now);
      expect(m, isNotNull);
      expect(m!.merchant, 'Spotify India Pvt Ltd');
      expect(m.amount, 139.0);
      expect(m.umn, isNull); // BOI quotes none
    });

    test('SBI registration (amount before the merchant)', () {
      final m = UpiMandateParser.parse('BV-SBIUPI-S', _sbiCreated, now);
      expect(m, isNotNull);
      expect(m!.merchant, 'Google Play');
      expect(m.amount, 1950.0);
    });

    test('an unknown sender is ignored', () {
      expect(UpiMandateParser.parse('AX-NETFLX-T', _sbiCreated, now), isNull);
    });
  });

  group('Mandate creation is NOT a transaction', () {
    // The registration alerts announce money that has not moved. Logging one
    // is a phantom entry in the user's month — SBI's was landing as ₹1950 of
    // income, because "from A/c" scored as a credit.
    test('SBI registration is not logged as a ₹1950 credit', () {
      expect(
        SmsParserService.parseTransaction('BV-SBIUPI-S', _sbiCreated, now),
        isNull,
      );
    });

    test('none of the four registrations become transactions', () {
      for (final (sender, body) in [
        ('AD-ICICIT-S', _iciciCreated),
        ('VM-HDFCBK-S', _hdfcCreated),
        ('JM-BOIIND-S', _boiCreated),
        ('BV-SBIUPI-S', _sbiCreated),
      ]) {
        expect(SmsParserService.parseTransaction(sender, body, now), isNull,
            reason: sender);
      }
    });
  });

  group('Ending a mandate is not a transaction either', () {
    test('BOI revocation is not logged as ₹2,099 of income', () {
      expect(
        SmsParserService.parseTransaction('JM-BOIIND-S', _boiRevoked, now),
        isNull,
      );
    });

    test('a revocation is not offered as a new subscription', () {
      // It ends one; suggesting it would add a subscription on the day it was
      // cancelled.
      expect(UpiMandateParser.parse('JM-BOIIND-S', _boiRevoked, now), isNull);
    });

    test('the rest of the lifecycle is covered, not just BOI wording', () {
      for (final body in [
        'Your UPI Mandate for NETFLIX has been paused. Ref 1234',
        'UPI-Mandate cancelled for SPOTIFY Rs.119.00. Umn abc@okhdfc',
        'Mandate modified for Rs.499.00 towards HOTSTAR, A/C XX7848',
        'Rs.2099.00 funds blocked from A/C XX7848 for Coursera mandate',
      ]) {
        expect(
          SmsParserService.parseTransaction('JM-BOIIND-S', body, now),
          isNull,
          reason: body,
        );
      }
    });

    test('a real debit that mentions a cancellation is still a debit', () {
      // The escape hatch: a settled verb outranks the lifecycle wording, so
      // the final charge before a subscription ends is not thrown away.
      final txn = SmsParserService.parseTransaction(
        'JM-BOIIND-S',
        'Rs.499.00 debited from A/C XX7848 towards HOTSTAR. Mandate cancelled '
            'after this charge. Ref no 603466871810',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 499.0);
      expect(txn.type, TransactionType.debit);
    });
  });

  group('Mandate executions still count as real spending', () {
    test('the ICICI autopay debit is logged', () {
      // Regression: "AutoPay" was a hard reject, so this genuine ₹3000
      // outflow never reached the user's spending at all.
      final txn =
          SmsParserService.parseTransaction('AD-ICICIT-S', _iciciExecuted, now);
      expect(txn, isNotNull);
      expect(txn!.amount, 3000.0);
      expect(txn.type, TransactionType.debit);
      expect(txn.merchantName, 'Iccl Groww Auto');
    });

    test('the HDFC mandate debit is logged with its payee', () {
      final txn =
          SmsParserService.parseTransaction('VM-HDFCBK-S', _hdfcExecuted, now);
      expect(txn, isNotNull);
      expect(txn!.amount, 1999.0);
      expect(txn.type, TransactionType.debit);
      expect(txn.merchantName, 'Google Play');
    });

    test('executions are never mistaken for registrations', () {
      expect(UpiMandateParser.parse('VM-HDFCBK-S', _hdfcExecuted, now), isNull);
      expect(UpiMandateParser.parse('AD-ICICIT-S', _iciciExecuted, now), isNull);
    });

    test('a plain autopay reminder is still rejected', () {
      // "will be debited" wording with no money moved — the case the old hard
      // reject existed for. It must not become a transaction OR a mandate
      // suggestion twice over.
      final reminder =
          'Your a/c XX197 will be debited for Rs 500.00 on 05-Aug-26 towards '
          'AUTOPAY for NETFLIX. Maintain sufficient balance.';
      expect(
        SmsParserService.parseTransaction('AD-ICICIT-S', reminder, now),
        isNull,
      );
    });
  });

  group('Dedup keys', () {
    test('the UMN identifies the mandate when the bank quotes one', () {
      final a = UpiMandateParser.parse('VM-HDFCBK-S', _hdfcCreated, now)!;
      final b = UpiMandateParser.parse(
          'VM-HDFCBK-S', _hdfcCreated, now.add(const Duration(days: 30)))!;
      expect(a.dedupKey, b.dedupKey, reason: 'a rescan must not re-suggest');
      expect(a.dedupKey, startsWith('umn:'));
    });

    test('without a UMN, merchant + amount identify it', () {
      final a = UpiMandateParser.parse('JM-BOIIND-S', _boiCreated, now)!;
      expect(a.dedupKey, startsWith('mp:'));
      expect(a.dedupKey, contains('139.00'));
    });

    test('two different subscriptions do not collide', () {
      final spotify = UpiMandateParser.parse('JM-BOIIND-S', _boiCreated, now)!;
      final play = UpiMandateParser.parse('BV-SBIUPI-S', _sbiCreated, now)!;
      expect(spotify.dedupKey, isNot(play.dedupKey));
    });
  });

  group('Suggestion state', () {
    test('a fresh mandate starts as a suggestion, never tracked', () {
      final m = UpiMandateParser.parse('BV-SBIUPI-S', _sbiCreated, now)!;
      expect(m.state, MandateState.suggested);
    });

    test('state survives a round-trip through the database map', () {
      final m = UpiMandateParser.parse('AD-ICICIT-S', _iciciCreated, now)!
          .copyWith(id: 7, state: MandateState.dismissed);
      final back = UpiMandate.fromMap(m.toMap());
      expect(back.id, 7);
      expect(back.state, MandateState.dismissed);
      expect(back.merchant, 'Iccl Groww Auto');
      expect(back.amount, 3000.0);
      expect(back.firstDebitOn, DateTime(2026, 7, 23));
      expect(back.umn, m.umn);
    });
  });

  group('Mandates become subscription suggestions', () {
    UpiMandate mandate(String sender, String body, {int? id}) =>
        UpiMandateParser.parse(sender, body, now)!.copyWith(id: id);

    test('a mandate is offered the day it is set up', () {
      // The whole point: the history detector needs three charges over three
      // months before it will say anything. The mandate says it on day one.
      final out = RecurringService.candidatesFromMandates(
        [mandate('JM-BOIIND-S', _boiCreated, id: 1)],
        const [],
      );
      expect(out, hasLength(1));
      expect(out.single.merchant, 'Spotify India Pvt Ltd');
      expect(out.single.amount, 139.0);
      expect(out.single.source, CandidateSource.mandate);
      expect(out.single.mandateId, 1);
      expect(out.single.occurrences, 0, reason: 'nothing charged yet');
    });

    test('the stated first-debit date anchors the schedule', () {
      final out = RecurringService.candidatesFromMandates(
        [mandate('AD-ICICIT-S', _iciciCreated, id: 2)],
        const [],
      );
      expect(out.single.dayOfMonth, 23, reason: 'ICICI said 23-Jul-26');
    });

    test('a merchant already tracked is not offered again', () {
      final out = RecurringService.candidatesFromMandates(
        [mandate('BV-SBIUPI-S', _sbiCreated, id: 3)],
        const ['Google Play'],
      );
      expect(out, isEmpty);
    });

    test('a mandate and its look-alike history collapse to one suggestion', () {
      final fromMandate = RecurringService.candidatesFromMandates(
        [mandate('BV-SBIUPI-S', _sbiCreated, id: 4)],
        const [],
      );
      final fromHistory = [
        RecurringCandidate(
          merchant: 'Google Play',
          amount: 1950,
          dayOfMonth: 11,
          category: null,
          occurrences: 3,
          lastSeen: now,
        ),
        RecurringCandidate(
          merchant: 'Netflix',
          amount: 649,
          dayOfMonth: 4,
          category: null,
          occurrences: 4,
          lastSeen: now,
        ),
      ];
      final merged =
          RecurringService.mergeCandidates(fromMandate, fromHistory);
      expect(merged.map((c) => c.merchant), ['Google Play', 'Netflix']);
      expect(merged.first.source, CandidateSource.mandate,
          reason: 'the bank-stated one wins over the inferred one');
    });

    test('history suggestions survive when no mandate covers them', () {
      final fromHistory = [
        RecurringCandidate(
          merchant: 'Netflix',
          amount: 649,
          dayOfMonth: 4,
          category: null,
          occurrences: 4,
          lastSeen: now,
        ),
      ];
      expect(
        RecurringService.mergeCandidates(const [], fromHistory),
        hasLength(1),
      );
    });

    test('a recognised merchant brings its category along', () {
      final out = RecurringService.candidatesFromMandates(
        [
          mandate(
            'JM-BOIIND-S',
            'BOI UPI - Your UPI-Mandate is successfully created towards '
                'NETFLIX for Rs.649.00.',
            id: 5,
          )
        ],
        const [],
      );
      expect(out.single.category, 'Entertainment');
    });
  });
}
