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
      expect(TransactionSplitMath.owedShares(500, 500, ['A']),
          [(person: 'A', share: 0.0)]);
    });

    test('empty when no people are given', () {
      expect(TransactionSplitMath.owedShares(500, 100, const []), isEmpty);
    });
  });

  group('TransactionSplitMath.owedShares with hand-set amounts', () {
    test('the untouched person absorbs what the typed ones leave', () {
      // ₹10,000 bill, ₹2,000 mine, Sayali pinned at ₹5,000 → Jay gets ₹3,000.
      final shares = TransactionSplitMath.owedShares(
        10000,
        2000,
        ['Sayali', 'Jay'],
        fixed: {'Sayali': 5000},
      );
      expect(shares, [
        (person: 'Sayali', share: 5000.0),
        (person: 'Jay', share: 3000.0),
      ]);
    });

    test('several untouched people split the leftover evenly', () {
      final shares = TransactionSplitMath.owedShares(
        10000,
        2000,
        ['A', 'B', 'C'],
        fixed: {'A': 2000},
      );
      expect(shares, [
        (person: 'A', share: 2000.0),
        (person: 'B', share: 3000.0),
        (person: 'C', share: 3000.0),
      ]);
    });

    test('typed amounts are kept verbatim even when they overshoot', () {
      final shares = TransactionSplitMath.owedShares(
        10000,
        2000,
        ['A', 'B'],
        fixed: {'A': 9000},
      );
      // A keeps the ₹9,000 the user meant; B has nothing left to take.
      expect(shares, [
        (person: 'A', share: 9000.0),
        (person: 'B', share: 0.0),
      ]);
      expect(
        TransactionSplitMath.allocationGap(
            10000, 2000, shares.map((s) => s.share)),
        1000,
      );
    });

    test('every amount typed by hand is left exactly as entered', () {
      final shares = TransactionSplitMath.owedShares(
        10000,
        2000,
        ['A', 'B'],
        fixed: {'A': 5000, 'B': 2000},
      );
      expect(shares.map((s) => s.share), [5000.0, 2000.0]);
    });

    test('rounding leftover lands on the first free person', () {
      final shares = TransactionSplitMath.owedShares(
        1000,
        1,
        ['A', 'B'],
      );
      expect(shares.map((s) => s.share), [500.0, 499.0]);
      expect(
        TransactionSplitMath.isBalanced(1000, 1, shares.map((s) => s.share)),
        isTrue,
      );
    });
  });

  group('TransactionSplitMath.allocationGap', () {
    test('zero when the parts add back up to the bill', () {
      expect(TransactionSplitMath.allocationGap(10000, 2000, [5000, 3000]), 0);
      expect(
          TransactionSplitMath.isBalanced(10000, 2000, [5000, 3000]), isTrue);
    });

    test('negative when part of the bill is unassigned', () {
      expect(TransactionSplitMath.allocationGap(10000, 2000, [5000]), -3000);
      expect(TransactionSplitMath.isBalanced(10000, 2000, [5000]), isFalse);
    });

    test('positive when more is split than was spent', () {
      expect(
          TransactionSplitMath.allocationGap(10000, 2000, [5000, 5000]), 2000);
      expect(
          TransactionSplitMath.isBalanced(10000, 2000, [5000, 5000]), isFalse);
    });

    test('a rupee of rounding residue still counts as balanced', () {
      expect(TransactionSplitMath.isBalanced(1000, 1, [500, 499]), isTrue);
      expect(TransactionSplitMath.isBalanced(1000, 1, [500, 498]), isTrue);
      expect(TransactionSplitMath.isBalanced(1000, 1, [500, 497]), isFalse);
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
