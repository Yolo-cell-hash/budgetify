import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/models/transaction_rule_model.dart';
import 'package:budget_tracker/services/database_service.dart';
import 'package:budget_tracker/services/sms_parser_service.dart';

/// A nameless UPI alert says only that money moved and quotes a reference
/// number. Two of them from two different people are byte-identical apart
/// from the amount and the ref, so the app cannot tell them apart — and must
/// not behave as though it can.
///
/// Raised by the user 2026-08-19: "if X transfers me 100 and I rename it to
/// Mr. X, can you ensure a later transfer from Y is not tagged as Mr. X?"
///
/// These pin both halves of the answer: what the app is not allowed to reach,
/// and the over-match that proves why the guard has to exist.
void main() {
  final now = DateTime(2026, 8, 17, 12, 41);

  /// The reported message: a BOI credit that names nobody at all.
  const namelessCredit = 'BOI -  Rs.98.00 Credited to your Ac XX7848 on '
      '17-08-26 by UPI ref No.622932497727.Avl Bal 5075.38';

  group('a nameless alert is recognised as nameless', () {
    test('the payee is the shared placeholder, and it is flagged', () {
      final txn =
          SmsParserService.parseTransaction('AD-BOIIND-S', namelessCredit, now);
      expect(txn, isNotNull);
      expect(txn!.merchantName, SmsParserService.payeeUpiTransfer);
      expect(txn.reviewReasonList, contains(ReviewReasons.payeeUnknown));
      // The scope sheet asks exactly this question to decide whether the two
      // bulk options may be offered.
      expect(
        DatabaseService.isUnnamedPayee(txn.merchantName, txn.accountInfo),
        isTrue,
      );
    });

    test('two transfers from two different people are indistinguishable', () {
      // Nothing in either message identifies a sender: same bank, same shape,
      // different amount and ref. This is the fact that makes "learn who this
      // was and recognise them next time" impossible for this alert — not a
      // gap in the parser.
      const fromSomeoneElse = 'BOI -  Rs.500.00 Credited to your Ac XX7848 on '
          '18-08-26 by UPI ref No.111122223333.Avl Bal 5575.38';
      expect(
        DatabaseService.messageSignature(fromSomeoneElse),
        DatabaseService.messageSignature(namelessCredit),
      );
      final a =
          SmsParserService.parseTransaction('AD-BOIIND-S', namelessCredit, now);
      final b =
          SmsParserService.parseTransaction('AD-BOIIND-S', fromSomeoneElse, now);
      expect(a!.merchantName, b!.merchantName);
    });

    test('a curated placeholder that IS one counterparty stays nameable', () {
      // "ATM" and "Bank Charges" are each one real party, so the bulk scopes
      // remain available on them — the guard must not over-reach into these.
      expect(DatabaseService.isUnnamedPayee('ATM', 'XX7848'), isFalse);
      expect(DatabaseService.isUnnamedPayee('Bank Charges', 'XX7848'), isFalse);
      expect(DatabaseService.isUnnamedPayee('Sharma Kirana', 'XX7848'), isFalse);
    });
  });

  group('why the bulk scopes must not be offered', () {
    test('a rule taught on the placeholder sweeps unrelated payees', () {
      // Measured, not reasoned: "upi" is a rail word and is dropped, so a
      // rule taught on "UPI Transfer" is really the pattern "transfer".
      final rule = TransactionRule(
        senderName: SmsParserService.payeeUpiTransfer,
        transactionType: TransactionType.credit,
        category: 'Gifts',
      );
      // The user's exact worry: the next nameless transfer, from anyone.
      // Every one of them carries this identical placeholder.
      expect(rule.matches('UPI Transfer', TransactionType.credit), isTrue);
      // And the collateral: real payees that happen to use the leftover word.
      expect(rule.matches('Bank Transfer', TransactionType.credit), isTrue);
      expect(
        rule.matches('Rent Transfer To Landlord', TransactionType.credit),
        isTrue,
      );
      // What no longer happens: reaching a name that merely has the letters
      // somewhere inside it. That was KI-001, fixed by whole-word matching —
      // see test/rule_name_matching_test.dart. The three cases above survive
      // it untouched, which is why the scope guard is still the fix here: a
      // placeholder is a bad rule pattern even when matching is well behaved.
      expect(rule.matches('Ans', TransactionType.credit), isFalse);
    });
  });

  group('naming one row cannot reach any other', () {
    test('the alias key stays the placeholder after a rename', () {
      // renamePayee derives its alias key from the MESSAGE, not from what is
      // on screen, and refuses to write one for a placeholder — so the rename
      // degrades to a single-row update. Renaming again later cannot escape
      // the guard either: the key is re-derived from the same message.
      final txn =
          SmsParserService.parseTransaction('AD-BOIIND-S', namelessCredit, now)!;

      final keyBefore = SmsParserService.extractMerchantStatic(
        txn.message,
        txn.accountInfo,
      );
      expect(
        DatabaseService.isAccountFallbackPayee(keyBefore, txn.accountInfo),
        isTrue,
      );

      final renamed = txn.copyWith(merchantName: 'Mr. X');
      final keyAfter = SmsParserService.extractMerchantStatic(
        renamed.message,
        renamed.accountInfo,
      );
      expect(keyAfter, keyBefore);
      expect(
        DatabaseService.isAccountFallbackPayee(keyAfter, renamed.accountInfo),
        isTrue,
      );
    });

    test('a later nameless transfer does not answer to the name given', () {
      // Y's transfer parses to the placeholder, never to "Mr. X", because no
      // alias was learned. Even a rule accidentally built on the renamed row
      // cannot claim it.
      const fromY = 'BOI -  Rs.100.00 Credited to your Ac XX7848 on 19-08-26 '
          'by UPI ref No.999988887777.Avl Bal 5675.38';
      final y = SmsParserService.parseTransaction('AD-BOIIND-S', fromY, now)!;
      expect(y.merchantName, isNot('Mr. X'));

      final ruleOnRenamedRow = TransactionRule(
        senderName: 'Mr. X',
        transactionType: TransactionType.credit,
        category: 'Gifts',
      );
      expect(
        ruleOnRenamedRow.matches(y.merchantName, TransactionType.credit),
        isFalse,
      );
    });
  });
}
