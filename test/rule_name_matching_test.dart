import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/models/transaction_rule_model.dart';

/// KI-001: auto-tag rules used to compare payee names by raw substring
/// containment in both directions, with no word boundary and no length floor.
/// A rule taught on "Ola" therefore claimed "Motorola Service", and a rule
/// taught on "Amazon Pay" claimed a payee called "Maz".
///
/// Matching is now whole-token: both names are split on non-alphanumeric runs
/// and one token list has to appear as a contiguous run of the other.
///
/// The first group is the regression guard. The second is the reason the
/// reverse direction exists at all and must keep working — a rule taught on a
/// long name still has to catch the short variant of it, which is what users
/// expect after tagging "Swiggy Instamart" once.
void main() {
  bool hits(String rulePattern, String payee) => TransactionRule(
        senderName: rulePattern,
        transactionType: TransactionType.debit,
        category: 'Travel',
      ).matches(payee, TransactionType.debit);

  group('a rule no longer claims names that merely contain its letters', () {
    test('a short pattern does not match mid-word', () {
      // The reported shape: "ola" sits inside "motorola".
      expect(hits('Ola', 'Motorola Service'), isFalse);
      expect(hits('Ola', 'Sola Foods'), isFalse);
      expect(hits('Ola', 'Gola Sweets'), isFalse);
      expect(hits('Zo', 'Amazon'), isFalse);
      expect(hits('Zo', 'Bazooka Ltd'), isFalse);
      expect(hits('IOB', 'Radiobox'), isFalse);
    });

    test('a long pattern does not match a short fragment of itself', () {
      for (final fragment in ['Maz', 'Azo', 'Ama']) {
        expect(hits('Amazon Pay', fragment), isFalse, reason: fragment);
      }
      for (final fragment in ['Rat', 'Pet', 'Role', 'Bhar']) {
        expect(hits('Bharat Petroleum', fragment), isFalse, reason: fragment);
      }
      for (final fragment in ['Lac', 'Aca', 'Ac']) {
        expect(hits('Olacabs', fragment), isFalse, reason: fragment);
      }
    });

    test('two names sharing one word in different places do not match', () {
      expect(hits('State Bank', 'Bank of Baroda'), isFalse);
      expect(hits('HDFC Bank', 'Bank of Maharashtra'), isFalse);
    });

    test('a two-letter pattern matches only itself', () {
      // Initials are too weak to run-match: "BP" must not claim a person.
      expect(hits('BP', 'BP Singh'), isFalse);
      expect(hits('BP', 'BP'), isTrue);
      expect(hits('BP', 'bp'), isTrue);
    });
  });

  group('what rules are for still works', () {
    test('a pattern matches a longer payee built on it', () {
      expect(hits('Swiggy', 'Swiggy Instamart'), isTrue);
      expect(hits('Swiggy', 'Swiggy Genie'), isTrue);
      expect(hits('Ola', 'Ola Cabs'), isTrue);
      expect(hits('Ola', 'Ola Money'), isTrue);
    });

    test('a pattern taught on a long name catches the short variant', () {
      expect(hits('Swiggy Instamart', 'Swiggy'), isTrue);
      expect(hits('Amazon Pay', 'Amazon'), isTrue);
      expect(hits('Bharat Petroleum', 'Petroleum'), isTrue);
    });

    test('the run may sit anywhere in the longer name', () {
      expect(hits('Swiggy', 'Order From Swiggy'), isTrue);
      expect(hits('Instamart', 'Swiggy Instamart Mumbai'), isTrue);
    });

    test('case, spacing and punctuation are ignored', () {
      expect(hits('swiggy instamart', 'SWIGGY  INSTAMART'), isTrue);
      expect(hits('Mr. Sharma', 'MR SHARMA'), isTrue);
      expect(hits('Big-Bazaar', 'Big Bazaar'), isTrue);
    });

    test('three-letter brands still reach their branches', () {
      expect(hits('KFC', 'KFC Andheri'), isTrue);
      expect(hits('Pvr', 'PVR Cinemas'), isTrue);
    });
  });

  group('rail words are dropped as words, never as letters', () {
    test('a rail prefix on one side does not prevent a match', () {
      expect(hits('UPI Swiggy', 'Swiggy'), isTrue);
      expect(hits('Swiggy', 'VPA Swiggy'), isTrue);
      expect(hits('NEFT Acme Corp', 'Acme Corp'), isTrue);
    });

    test('a name that merely contains a rail spelling survives intact', () {
      // "upi" sits inside "Rupinder"; stripping it as a substring left
      // "rnder", which then matched other mangled names by accident.
      expect(hits('Rupinder Singh', 'Rupinder Singh'), isTrue);
      expect(hits('Rupinder Singh', 'Bhupinder Singh'), isFalse);
      expect(hits('Gupinder', 'Rupinder'), isFalse);
      expect(hits('Impshire Ltd', 'Rtgsville'), isFalse);
    });

    test('a pattern made only of rail words matches nothing', () {
      // Nothing is left to compare, so it must not become a wildcard.
      expect(hits('UPI', 'Swiggy'), isFalse);
      expect(hits('UPI', 'UPI Transfer'), isFalse);
      expect(hits('NEFT', 'Anything At All'), isFalse);
    });
  });

  group('non-name guards are unchanged', () {
    test('type must still match exactly', () {
      final rule = TransactionRule(
        senderName: 'Swiggy',
        transactionType: TransactionType.debit,
        category: 'Food',
      );
      expect(rule.matches('Swiggy', TransactionType.debit), isTrue);
      expect(rule.matches('Swiggy', TransactionType.credit), isFalse);
    });

    test('an empty or null payee never matches', () {
      final rule = TransactionRule(
        senderName: 'Swiggy',
        transactionType: TransactionType.debit,
        category: 'Food',
      );
      expect(rule.matches(null, TransactionType.debit), isFalse);
      expect(rule.matches('', TransactionType.debit), isFalse);
      expect(rule.matches('   ', TransactionType.debit), isFalse);
    });
  });
}
