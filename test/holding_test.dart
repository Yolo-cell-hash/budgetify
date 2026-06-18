import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/holding.dart';

Holding _h(String name, HoldingKind kind, String cat, double amt) => Holding(
      name: name,
      kind: kind,
      category: cat,
      amount: amt,
      updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  group('Holding', () {
    test('isInvestment only for investment-category assets', () {
      expect(_h('FD', HoldingKind.asset, 'Fixed Deposit', 1).isInvestment,
          isTrue);
      expect(_h('Savings', HoldingKind.asset, 'Savings', 1).isInvestment,
          isFalse);
      // A loan can never be an investment even if mis-categorised.
      expect(_h('x', HoldingKind.liability, 'Fixed Deposit', 1).isInvestment,
          isFalse);
    });

    test('round-trips through toMap/fromMap', () {
      final h = _h('HDFC FD', HoldingKind.asset, 'Fixed Deposit', 50000);
      final back = Holding.fromMap(h.toMap());
      expect(back.name, 'HDFC FD');
      expect(back.kind, HoldingKind.asset);
      expect(back.category, 'Fixed Deposit');
      expect(back.amount, 50000);
    });

    test('HoldingCategories.forKind switches lists', () {
      expect(HoldingCategories.forKind(HoldingKind.asset),
          contains('Mutual Fund'));
      expect(HoldingCategories.forKind(HoldingKind.liability),
          contains('Home Loan'));
      expect(HoldingCategories.isInvestment('Stocks'), isTrue);
      expect(HoldingCategories.isInvestment('Savings'), isFalse);
    });

    test('supportsRecurring is true only for SIP/RD-style investments', () {
      for (final c in ['Recurring Deposit', 'Mutual Fund', 'Stocks', 'Bonds']) {
        expect(HoldingCategories.supportsRecurring(c), isTrue, reason: c);
      }
      // Lump-sum investments and non-investments don't offer automation.
      for (final c in ['Fixed Deposit', 'Gold', 'Savings', 'Home Loan']) {
        expect(HoldingCategories.supportsRecurring(c), isFalse, reason: c);
      }
    });
  });

  group('NetWorthSummary', () {
    final holdings = [
      _h('HDFC FD', HoldingKind.asset, 'Fixed Deposit', 100000),
      _h('Nifty Index', HoldingKind.asset, 'Mutual Fund', 60000),
      _h('Savings', HoldingKind.asset, 'Savings', 40000),
      _h('Home loan', HoldingKind.liability, 'Home Loan', 120000),
      _h('Card', HoldingKind.liability, 'Credit Card', 5000),
    ];

    test('aggregates assets, liabilities, net worth and investments', () {
      const s = NetWorthSummary([]);
      expect(s.isEmpty, isTrue);

      final n = NetWorthSummary(holdings);
      expect(n.assets, 200000);
      expect(n.liabilities, 125000);
      expect(n.netWorth, 75000);
      expect(n.investments, 160000); // FD + MF, not Savings
    });

    test('asset allocation is grouped by category, largest first', () {
      final n = NetWorthSummary(holdings);
      final alloc = n.assetAllocation;
      expect(alloc.keys.first, 'Fixed Deposit'); // 100k is biggest
      expect(alloc['Mutual Fund'], 60000);
      expect(alloc['Savings'], 40000);
      expect(alloc.containsKey('Home Loan'), isFalse); // liabilities excluded
    });

    test('separates investment / other-asset / liability lists', () {
      final n = NetWorthSummary(holdings);
      expect(n.investmentHoldings.map((h) => h.name),
          containsAll(['HDFC FD', 'Nifty Index']));
      expect(n.otherAssetHoldings.map((h) => h.name), ['Savings']);
      expect(n.liabilityHoldings.length, 2);
    });
  });
}
