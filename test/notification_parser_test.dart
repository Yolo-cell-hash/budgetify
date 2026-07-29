import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/notification_parser_service.dart';

/// The notification grammar's contract is precision over recall: a missed
/// payment is the pre-feature status quo, a false positive corrupts totals.
/// So the reject cases here are as load-bearing as the accept cases.
void main() {
  TransactionModel? parse({
    String pkg = 'com.phonepe.app',
    String title = '',
    String text = '',
    String big = '',
    DateTime? at,
  }) =>
      NotificationParserService.parse(
        packageName: pkg,
        title: title,
        text: text,
        bigText: big,
        postedAt: at ?? DateTime(2026, 7, 20, 14, 30),
      );

  group('accepts completed payments', () {
    test('PhonePe-style debit: amount, payee, sender, source', () {
      final t = parse(
        title: '₹250 paid to Swiggy',
        text: 'Paid via HDFC Bank ••1234',
      );
      expect(t, isNotNull);
      expect(t!.amount, 250);
      expect(t.type, TransactionType.debit);
      expect(t.merchantName, 'Swiggy');
      expect(t.sender, 'NOTIF-PhonePe');
      expect(t.parseSource, 'app alert · PhonePe');
      expect(t.isManual, isFalse);
    });

    test('GPay-style credit with "from"', () {
      final t = parse(
        pkg: 'com.google.android.apps.nbu.paisa.user',
        title: 'You received ₹500 from Rohan Sharma',
      );
      expect(t, isNotNull);
      expect(t!.type, TransactionType.credit);
      expect(t.amount, 500);
      expect(t.merchantName, 'Rohan Sharma');
      expect(t.sender, 'NOTIF-GPay');
    });

    test('Indian digit grouping and decimals', () {
      final t = parse(title: 'Payment of ₹1,23,456.78 successful', text: 'To Tata Motors');
      expect(t, isNotNull);
      expect(t!.amount, 123456.78);
    });

    test('Rs. spelling parses like ₹', () {
      final t = parse(title: 'Rs. 99 sent to Ramesh Kirana');
      expect(t, isNotNull);
      expect(t!.amount, 99);
      expect(t.merchantName, 'Ramesh Kirana');
    });

    test('sub-₹100 payment — the whole reason this parser exists', () {
      final t = parse(title: '₹40 paid to Chai Point');
      expect(t, isNotNull);
      expect(t!.amount, 40);
    });

    test('autopay success is a real debit (feeds recurring matching)', () {
      final t = parse(title: 'Autopay of ₹149 paid to Netflix');
      expect(t, isNotNull);
      expect(t!.type, TransactionType.debit);
    });

    test('no payee still parses, flagged for the review queue', () {
      final t = parse(title: '₹120 debited', text: 'UPI transaction successful');
      expect(t, isNotNull);
      expect(t!.merchantName, isNull);
      expect(t.reviewReasonList, contains(ReviewReasons.payeeUnknown));
    });

    test('VPA payee keeps a name-like handle, title-cased', () {
      final t = parse(title: '₹300 paid to swiggy@axis');
      expect(t, isNotNull);
      expect(t!.merchantName, 'Swiggy');
    });

    test('gibberish VPA handle becomes payee-unknown, not noise', () {
      final t = parse(title: '₹300 paid to q6748@ybl');
      expect(t, isNotNull);
      expect(t!.merchantName, isNull);
      expect(t.reviewReasonList, contains(ReviewReasons.payeeUnknown));
    });

    test('Hindi completed payment parses', () {
      final t = parse(title: '₹250 का भुगतान सफल', text: 'Swiggy');
      expect(t, isNotNull);
      expect(t!.type, TransactionType.debit);
    });
  });

  // PayZapp is the one allowlisted app that alerts on money leaving as well
  // as money arriving, so it is the only one whose debits this parser can
  // ever see. The copy below is verbatim from the device, including the
  // trailing verdict ("… was successful.") that no other app puts after the
  // payee name.
  group('PayZapp — the both-ways app', () {
    const payzapp = 'com.enstage.wibmo.hdfc';

    test('debit to a person, with the verdict trailing the name', () {
      final t = parse(
        pkg: payzapp,
        title: 'Payment sent successfully',
        text: 'Your payment of Rs.200 to Ashokkumar Sharma was successful.',
      );
      expect(t, isNotNull);
      expect(t!.type, TransactionType.debit);
      expect(t.amount, 200);
      // Not "Ashokkumar Sharma Was" — the trailing verb has to stop the
      // payee capture, which is what `was` in the connective list buys.
      expect(t.merchantName, 'Ashokkumar Sharma');
      expect(t.sender, 'NOTIF-PayZapp');
      expect(t.parseSource, 'app alert · PayZapp');
    });

    test('sub-₹100 merchant debit — the case SMS no longer covers', () {
      final t = parse(
        pkg: payzapp,
        title: 'Payment sent successfully',
        text: 'Your payment of Rs.20 to ADITYA MEDICAL was successful.',
      );
      expect(t, isNotNull);
      expect(t!.type, TransactionType.debit);
      expect(t.amount, 20);
      expect(t.merchantName, 'Aditya Medical');
    });

    test('credit names the sender', () {
      final t = parse(
        pkg: payzapp,
        title: 'Received Money',
        text: 'You received Rs.1 from JAY RAJESH KEER',
      );
      expect(t, isNotNull);
      expect(t!.type, TransactionType.credit);
      expect(t.amount, 1);
      expect(t.merchantName, 'Jay Rajesh Keer');
      expect(t.sender, 'NOTIF-PayZapp');
    });

    test('"sent successfully" is not read as "unsuccessful"', () {
      // The reject list carries `unsuccessful`; PayZapp says "successful" in
      // both the title and the body of every completed payment, so a sloppy
      // substring match here would silently reject the app entirely.
      final t = parse(
        pkg: payzapp,
        title: 'Payment sent successfully',
        text: 'Your payment of Rs.500 to Kirana Store was successful.',
      );
      expect(t, isNotNull);
      expect(t!.amount, 500);
    });

    test('a failed PayZapp payment is still rejected', () {
      expect(
        parse(
          pkg: payzapp,
          title: 'Payment failed',
          text: 'Your payment of Rs.200 to Ashokkumar Sharma was not successful.',
        ),
        isNull,
      );
    });
  });

  group('coverage is declared per app', () {
    test('PayZapp alerts both ways; the UPI apps only announce credits', () {
      expect(
        NotificationParserService.watchedPackages['com.enstage.wibmo.hdfc']!
            .coverage,
        NotifCoverage.bothWays,
      );
      for (final pkg in const [
        'com.phonepe.app',
        'com.google.android.apps.nbu.paisa.user',
        'net.one97.paytm',
      ]) {
        expect(
          NotificationParserService.watchedPackages[pkg]!.coverage,
          NotifCoverage.creditsOnly,
          reason: '$pkg confirms payments in-app, it does not notify them',
        );
      }
    });

    test('the two coverage groups partition the allowlist', () {
      // Settings renders exactly these two lists; an app in neither would
      // silently vanish from the "only these apps are read" disclosure.
      expect(
        NotificationParserService.bothWaysApps.length +
            NotificationParserService.creditsOnlyApps.length,
        NotificationParserService.watchedPackages.length,
      );
      expect(
        NotificationParserService.bothWaysApps.map((a) => a.label),
        contains('PayZapp'),
      );
    });
  });

  group('rejects everything that is not a completed payment', () {
    final rejects = <String, Map<String, String>>{
      'collect request': {'title': 'Rahul requested ₹500'},
      'payment request wording': {'title': 'Payment request of ₹500 from Rahul'},
      'failed payment': {'title': '₹250 payment failed', 'text': 'Money not debited'},
      'pending payment': {'title': '₹250 payment pending'},
      'future/scheduled': {'title': '₹149 will be debited for Netflix on 25 Jul'},
      'bill reminder': {'title': 'Electricity bill of ₹1,200 due tomorrow'},
      'refund (bank credit is the truth)': {'title': 'Refund of ₹299 credited'},
      'cashback noise': {'title': 'You won ₹10 cashback!'},
      'scratch card': {'title': 'You got a scratch card', 'text': 'Win up to ₹100'},
      'offer/promo': {'title': 'Get 20% off up to ₹75 on your next payment'},
      'wallet top-up (bank SMS covers the debit)': {'title': '₹500 added to wallet'},
      'mandate setup': {'title': 'Autopay mandate created for ₹149'},
      'OTP': {'title': 'Your OTP is 445566 for payment of ₹2,000'},
      'no amount at all': {'title': 'Payment successful'},
      'no verb, bare amount': {'title': '₹250', 'text': 'UPI ID: abc@upi'},
      'Hindi request': {'title': 'राहुल ने ₹500 का अनुरोध किया'},
    };

    rejects.forEach((name, event) {
      test(name, () {
        expect(
          parse(title: event['title'] ?? '', text: event['text'] ?? ''),
          isNull,
        );
      });
    });

    test('unknown package is dropped even with perfect payment copy', () {
      expect(
        parse(pkg: 'com.evil.app', title: '₹250 paid to Swiggy'),
        isNull,
      );
    });

    test('WhatsApp is not on the allowlist — by design', () {
      expect(
        NotificationParserService.watchedPackages.containsKey('com.whatsapp'),
        isFalse,
      );
      // Nor is the HDFC Bank app, whose payments arrive as richer bank SMS —
      // PayZapp being on the list is not a foot in the door for bank apps.
      expect(
        NotificationParserService.watchedPackages
            .containsKey('com.snapwork.hdfc'),
        isFalse,
      );
      expect(
        parse(pkg: 'com.whatsapp', title: '₹250 paid to Swiggy'),
        isNull,
      );
    });

    test('absurd amount fails sanity bounds', () {
      expect(parse(title: '₹99,99,99,999 paid to X'), isNull);
    });
  });

  group('source marking', () {
    test('NOTIF- prefix is recognisable for the reconciler and exports', () {
      final t = parse(title: '₹250 paid to Swiggy');
      expect(NotificationParserService.isNotificationSender(t!.sender), isTrue);
      expect(NotificationParserService.isNotificationSender('AD-SBIUPI-T'),
          isFalse);
      expect(NotificationParserService.isNotificationSender('IMPORT-HDFC'),
          isFalse);
    });

    test('fingerprint is deterministic → queue replay is idempotent', () {
      final a = parse(title: '₹250 paid to Swiggy').fingerprinted();
      final b = parse(title: '₹250 paid to Swiggy').fingerprinted();
      expect(a, isNotNull);
      expect(a, b);
    });
  });
}

extension on TransactionModel? {
  String? fingerprinted() => this?.withFingerprint().fingerprint;
}
