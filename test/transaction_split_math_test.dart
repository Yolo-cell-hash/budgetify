import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_split_math.dart';

void main() {
  group('TransactionSplitMath.equalShare', () {
    test('even split divides cleanly', () {
      expect(TransactionSplitMath.equalShare(500, 2), 250);
      expect(TransactionSplitMath.equalShare(400, 4), 100);
    });

    test('rounding remainder goes to you, parts still sum to total', () {
      final me = TransactionSplitMath.equalShare(500, 3); // 168
      expect(me, 168);
      // others get 166 each → 168 + 166 + 166 = 500
      expect(me + 166 + 166, 500);
    });

    test('one person means the whole amount is yours', () {
      expect(TransactionSplitMath.equalShare(500, 1), 500);
    });

    test('guards against zero/negative people and totals', () {
      expect(TransactionSplitMath.equalShare(500, 0), 500);
      expect(TransactionSplitMath.equalShare(0, 3), 0);
    });
  });

  group('TransactionSplitMath.owedShares', () {
    test('single friend owes the whole remainder', () {
      final shares = TransactionSplitMath.owedShares(500, 100, ['Rohan']);
      expect(shares, [(person: 'Rohan', share: 400.0)]);
    });

    test('remainder splits evenly among several people', () {
      final shares = TransactionSplitMath.owedShares(500, 100, ['A', 'B']);
      expect(shares, [(person: 'A', share: 200.0), (person: 'B', share: 200.0)]);
    });

    test('rounding remainder is absorbed by the first person and sums back', () {
      final shares = TransactionSplitMath.owedShares(500, 100, ['A', 'B', 'C']);
      final total = shares.fold<double>(0, (a, s) => a + s.share);
      expect(total, 400); // 134 + 133 + 133
      expect(shares.first.share, 134);
    });

    test('nothing owed when your share is the whole total', () {
      expect(TransactionSplitMath.owedShares(500, 500, ['A']), isEmpty);
    });

    test('empty when no people are given', () {
      expect(TransactionSplitMath.owedShares(500, 100, const []), isEmpty);
    });
  });

  group('TransactionSplitMath validity helpers', () {
    test('isValidShare allows 0..total (0 = you covered it entirely)', () {
      expect(TransactionSplitMath.isValidShare(500, 0), isTrue);
      expect(TransactionSplitMath.isValidShare(500, 100), isTrue);
      expect(TransactionSplitMath.isValidShare(500, 500), isTrue);
      expect(TransactionSplitMath.isValidShare(500, 600), isFalse);
      expect(TransactionSplitMath.isValidShare(500, -1), isFalse);
    });

    test('reducesSpend only when the share is below the total', () {
      expect(TransactionSplitMath.reducesSpend(500, 100), isTrue);
      expect(TransactionSplitMath.reducesSpend(500, 500), isFalse);
    });
  });
}
