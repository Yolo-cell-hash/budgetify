import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/database_service.dart';
import 'package:budget_tracker/services/sms_parser_service.dart';

/// Feature coverage for the parser confidence work:
///  - bank template packs produce named payees with template provenance,
///  - the generic cascade / placeholders / account fallback are graded,
///  - review reasons fire exactly when the parser guessed,
///  - message-shape signatures power mutes and direction overrides,
///  - transfer-pair candidates are detected for the self-transfer nudge.
void main() {
  final now = DateTime(2026, 7, 10, 11, 0);

  group('bank template provenance', () {
    test('HDFC NEFT credit parses via the HDFC template pack', () {
      final txn = SmsParserService.parseTransaction(
        'JM-HDFCBK-S',
        'Update! INR 47,449.63 deposited in HDFC Bank A/c XX9463 on 06-JUN-26 '
        'for NEFT Cr-ICIC0099999-GODREJ AND BOYCE MFG CO LTD-JAY RAJESH KEER-'
        'INXXXXXXXXXX6697.Avl bal INR 67,371.03.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.merchantName, 'Godrej And Boyce Mfg Co Ltd');
      expect(txn.parseSource, 'HDFC · NEFT credit');
      expect(txn.needsReview, isFalse);
    });

    test('ICICI "; PAYEE credited" parses via the ICICI template pack', () {
      final txn = SmsParserService.parseTransaction(
        'AD-ICICIT-S',
        'ICICI Bank Acct XX197 debited for Rs 73.00 on 16-Jun-26; '
        'JAY RAJESH KEER credited. UPI:123834511400.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.merchantName, 'Jay Rajesh Keer');
      expect(txn.parseSource, 'ICICI · UPI transfer-out');
      expect(txn.needsReview, isFalse);
    });

    test('Kotak VPA debit parses via the Kotak template pack', () {
      final txn = SmsParserService.parseTransaction(
        'AD-KOTAKB-S',
        'Sent Rs.60.00 from Kotak Bank AC X9883 to paytm.s21upj5@pty on '
        '27-06-26.UPI Ref 617835353944.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.merchantName, 'Paytm S21upj5');
      expect(txn.parseSource, 'Kotak · UPI transfer-out');
    });

    test('IPPB credit parses via the IPPB template pack', () {
      final txn = SmsParserService.parseTransaction(
        'JX-IPBMSG-S',
        'You have received a payment of Rs. 140.00 in a/c X4434 on '
        '28/09/2025 22:36 from padarthi santhosh ku thru IPPB. '
        'Info: UPI/CREDIT/946195505938.-IPPB',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.merchantName, 'Padarthi Santhosh Ku');
      expect(txn.parseSource, 'IPPB · UPI credit');
    });

    test('BOM credit parses via the BOM template pack', () {
      final txn = SmsParserService.parseTransaction(
        'AX-MAHABK-S',
        'A/c X7763 credited with Rs. 453.00 on 01-Jul-26 from Miss AISHWARYA '
        'RRN: 125560855601 -Bank of Maharashtra',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.merchantName, 'Miss Aishwarya');
      expect(txn.parseSource, 'BOM · UPI credit');
    });

    test('BOM UPI debit parses via the BOM template pack', () {
      final txn = SmsParserService.parseTransaction(
        'AD-MAHABK-S',
        'A/c X7763 debited by Rs. 101.00 for UPI payment to aish872k okaxis '
        'on 09-Jul-26. RRN: 619085826595 if not you, call 18002334526 '
        '-Bank of Maharashtra',
        now,
      );
      expect(txn, isNotNull);
      // BOM strips the "@" from VPAs; the handle token must not be
      // title-cased into a surname ("Aish872k Okaxis").
      expect(txn!.merchantName, 'Aish872k');
      expect(txn.parseSource, 'BOM · UPI transfer-out');
      expect(txn.needsReview, isFalse);
    });

    test('a bank without a pack rides the generic cascade', () {
      final txn = SmsParserService.parseTransaction(
        'BV-SBIUPI-S',
        'Dear UPI user A/C X4321 debited by 35.0 on date 01Jun26 trf to '
        'RAMESH KUMAR Refno 612345678901. -SBI',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.merchantName, 'Ramesh Kumar');
      expect(txn.parseSource, 'general patterns');
      // Named payee + explicit verb + anchored amount → nothing to review.
      expect(txn.needsReview, isFalse);
    });

    test('nameless UPI credit is a recognised placeholder, not a guess', () {
      final txn = SmsParserService.parseTransaction(
        'BP-BOIIND-S',
        'BOI -  Rs.800.00 Credited to your Ac XX7848 on 24-06-26 by UPI '
        'ref No.654169525627.Avl Bal 17871.44',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.merchantName, 'UPI Transfer');
      expect(txn.parseSource, 'recognised · upi transfer');
      expect(txn.needsReview, isFalse);
    });
  });

  group('review reasons', () {
    test('fallback-trust sender is flagged as an unknown sender', () {
      final txn = SmsParserService.parseTransaction(
        'JD-ABCBANK-S',
        'Rs.250.00 debited from A/c XX9912 on 05-Jul-26 for UPI payment to '
        'SWIGGY. Refno 719912345678. Avl Bal Rs.10,201.55',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.needsReview, isTrue);
      expect(txn.reviewReasonList, contains(ReviewReasons.unknownSender));
    });

    test('weak-keyword direction verdict is flagged', () {
      final txn = SmsParserService.parseTransaction(
        'BV-SBIUPI-S',
        'Rs.120 payment to RAMESH via APP done -SBI',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.type, TransactionType.debit);
      expect(
        txn.reviewReasonList,
        contains(ReviewReasons.directionUncertain),
      );
    });

    test('an amount picked among several currency figures is flagged', () {
      final txn = SmsParserService.parseTransaction(
        'BV-SBIUPI-S',
        'Rs.500 debited from A/c XX1111 for order. Coupon worth Rs.750 '
        'applied. -SBI',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.amount, 500.0);
      expect(txn.reviewReasonList, contains(ReviewReasons.amountUncertain));
    });

    test('account-fallback payee is flagged as a template miss', () {
      final txn = SmsParserService.parseTransaction(
        'BOMSMS',
        'A/c XX1234 Credited by Rs.15,000.00 on 01-06-2026 by Mob Banking. '
        'Avl Bal Rs.27,345.67 - Bank of Maharashtra',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.merchantName, 'XX1234');
      expect(txn.parseSource, 'account fallback');
      expect(txn.reviewReasonList, contains(ReviewReasons.payeeUnknown));
    });

    test('a clean verb-anchored parse carries no review flags', () {
      final txn = SmsParserService.parseTransaction(
        'AD-ICICIT-S',
        'ICICI Bank Acct XX197 credited with Rs 73.00 on 16-Jun-26 from '
        'JAY RAJESH KEER. UPI:123834511400.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.reviewReasons, isNull);
      expect(txn.needsReview, isFalse);
    });

    test('a nameless transfer format is flagged only for its payee', () {
      // SBI's "debit by transfer" names nobody — payee_unknown is the one
      // honest flag; direction and amount stay confident.
      final txn = SmsParserService.parseTransaction(
        'VM-SBIINB-S',
        'Your A/C XXXXX4321 has a debit by transfer of Rs 2,500.00 on '
        '01Jun26. Avl Bal Rs 18,450.50.',
        now,
      );
      expect(txn, isNotNull);
      expect(txn!.reviewReasonList, [ReviewReasons.payeeUnknown]);
    });
  });

  group('message shape signatures (mutes & direction overrides)', () {
    test('same template with different numbers shares one signature', () {
      const a = 'BOI -  Rs.800.00 Credited to your Ac XX7848 on 24-06-26 by '
          'UPI ref No.654169525627.Avl Bal 17871.44';
      const b = 'BOI -  Rs.113.00 Credited to your Ac XX7848 on 15-04-26 by '
          'UPI ref No.610507611710.Avl Bal 200.30';
      expect(
        DatabaseService.messageSignature(a),
        DatabaseService.messageSignature(b),
      );
    });

    test('different templates produce different signatures', () {
      const credit = 'BOI -  Rs.800.00 Credited to your Ac XX7848 on '
          '24-06-26 by UPI ref No.654169525627.Avl Bal 17871.44';
      const charges = 'BOI -  Rs 23.60 Debited(TRF) SMSChrgsJAN-MAR26 GST '
          '101 CUST in your Ac XX7848 on 12-04-2026. .Avl BalRs 1807.20.';
      expect(
        DatabaseService.messageSignature(credit),
        isNot(DatabaseService.messageSignature(charges)),
      );
    });

    test('whitespace and case differences do not split a signature', () {
      expect(
        DatabaseService.messageSignature('Rs.99  credited   to your a/c'),
        DatabaseService.messageSignature('RS.42 CREDITED TO YOUR A/C'),
      );
    });
  });

  group('self-transfer pair candidates', () {
    TransactionModel txn({
      int? id,
      required TransactionType type,
      double amount = 800.0,
      int minutesAfter = 0,
      String? category,
    }) {
      return TransactionModel(
        id: id,
        amount: amount,
        type: type,
        sender: 'BP-BOIIND-S',
        message: 'msg',
        detectedAt: now.add(Duration(minutes: minutesAfter)),
        category: category,
      );
    }

    test('opposite types, same amount, minutes apart → candidate', () {
      final debit = txn(id: 1, type: TransactionType.debit);
      final credit =
          txn(id: 2, type: TransactionType.credit, minutesAfter: 5);
      expect(DatabaseService.isTransferPairCandidate(debit, credit), isTrue);
    });

    test('same direction is never a pair', () {
      final a = txn(id: 1, type: TransactionType.debit);
      final b = txn(id: 2, type: TransactionType.debit, minutesAfter: 5);
      expect(DatabaseService.isTransferPairCandidate(a, b), isFalse);
    });

    test('different amounts are never a pair', () {
      final a = txn(id: 1, type: TransactionType.debit);
      final b = txn(
          id: 2, type: TransactionType.credit, amount: 799.0, minutesAfter: 2);
      expect(DatabaseService.isTransferPairCandidate(a, b), isFalse);
    });

    test('outside the 15-minute window is not a pair', () {
      final a = txn(id: 1, type: TransactionType.debit);
      final b =
          txn(id: 2, type: TransactionType.credit, minutesAfter: 20);
      expect(DatabaseService.isTransferPairCandidate(a, b), isFalse);
    });

    test('an already-settled half is not re-suggested', () {
      final a = txn(id: 1, type: TransactionType.debit);
      final b = txn(
        id: 2,
        type: TransactionType.credit,
        minutesAfter: 3,
        category: 'Self Transfer',
      );
      expect(DatabaseService.isTransferPairCandidate(a, b), isFalse);
    });
  });

  group('review model helpers', () {
    test('reviewReasonList parses the comma-joined column', () {
      final txn = TransactionModel(
        amount: 1,
        type: TransactionType.debit,
        sender: 's',
        message: 'm',
        detectedAt: now,
        reviewReasons:
            '${ReviewReasons.unknownSender},${ReviewReasons.payeeUnknown}',
      );
      expect(txn.reviewReasonList,
          [ReviewReasons.unknownSender, ReviewReasons.payeeUnknown]);
      expect(txn.needsReview, isTrue);
    });

    test('null and empty reasons mean nothing to review', () {
      final txn = TransactionModel(
        amount: 1,
        type: TransactionType.debit,
        sender: 's',
        message: 'm',
        detectedAt: now,
      );
      expect(txn.needsReview, isFalse);
      expect(txn.copyWith(reviewReasons: '').needsReview, isFalse);
    });

    test('confirmedReview clears the flags and keeps everything else', () {
      final txn = TransactionModel(
        amount: 1,
        type: TransactionType.debit,
        sender: 's',
        message: 'm',
        detectedAt: now,
        reviewReasons: ReviewReasons.payeeUnknown,
        parseSource: 'general patterns',
      );
      final confirmed = txn.confirmedReview();
      expect(confirmed.needsReview, isFalse);
      expect(confirmed.parseSource, 'general patterns');
      expect(confirmed.amount, 1);
    });

    test('review columns survive a map round-trip', () {
      final txn = TransactionModel(
        amount: 5,
        type: TransactionType.credit,
        sender: 's',
        message: 'm',
        detectedAt: now,
        reviewReasons: ReviewReasons.amountUncertain,
        parseSource: 'HDFC · NEFT credit',
      ).withFingerprint();
      final roundTrip = TransactionModel.fromMap({
        ...txn.toMap(),
        'id': 7,
        'is_classified': 0,
      });
      expect(roundTrip.reviewReasons, ReviewReasons.amountUncertain);
      expect(roundTrip.parseSource, 'HDFC · NEFT credit');
    });
  });
}
