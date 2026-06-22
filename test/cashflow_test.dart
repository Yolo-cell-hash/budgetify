import 'package:budget_tracker/models/cashflow.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _tx(
  double amount,
  TransactionType type,
  DateTime when, {
  String? category,
  double? split,
}) =>
    TransactionModel(
      amount: amount,
      type: type,
      sender: 'BANK',
      message: 'test',
      detectedAt: when,
      category: category,
      splitShare: split,
    );

void main() {
  group('buildMonthlyCashflow', () {
    test('aggregates income/expense per month with the app rules', () {
      final txns = [
        _tx(50000, TransactionType.credit, DateTime(2026, 1, 5),
            category: 'Salary'),
        _tx(10000, TransactionType.debit, DateTime(2026, 1, 10),
            category: 'Food & Dining'),
        // Split: only the user's share (800) counts.
        _tx(2000, TransactionType.debit, DateTime(2026, 1, 12),
            category: 'Shopping', split: 800),
        // Excluded: moving your own money / investing isn't spend or income.
        _tx(99999, TransactionType.debit, DateTime(2026, 1, 15),
            category: 'Self Transfer'),
        _tx(99999, TransactionType.debit, DateTime(2026, 1, 16),
            category: 'Investments'),
        _tx(99999, TransactionType.credit, DateTime(2026, 1, 17),
            category: 'Self Transfer'),
        _tx(60000, TransactionType.credit, DateTime(2026, 2, 5),
            category: 'Salary'),
        _tx(20000, TransactionType.debit, DateTime(2026, 2, 8),
            category: 'Bills & Utilities'),
      ];

      final series = buildMonthlyCashflow(txns);
      expect(series.length, 2);

      final jan = series[0];
      expect(jan.year, 2026);
      expect(jan.month, 1);
      expect(jan.income, 50000);
      expect(jan.expense, 10800); // 10000 + 800 split share
      expect(jan.savings, 39200);

      final feb = series[1];
      expect(feb.month, 2);
      expect(feb.income, 60000);
      expect(feb.expense, 20000);
      expect(feb.savingsRate, closeTo((60000 - 20000) / 60000, 1e-9));
    });

    test('is sorted oldest → newest across year boundaries', () {
      final txns = [
        _tx(100, TransactionType.debit, DateTime(2026, 2, 1),
            category: 'Food & Dining'),
        _tx(100, TransactionType.debit, DateTime(2025, 12, 1),
            category: 'Food & Dining'),
        _tx(100, TransactionType.debit, DateTime(2026, 1, 1),
            category: 'Food & Dining'),
      ];
      final series = buildMonthlyCashflow(txns);
      expect(series.map((m) => m.key), ['2025-12', '2026-01', '2026-02']);
    });

    test('savingsRate is null when there is no income', () {
      final series = buildMonthlyCashflow([
        _tx(500, TransactionType.debit, DateTime(2026, 3, 2),
            category: 'Shopping'),
      ]);
      expect(series.single.income, 0);
      expect(series.single.savingsRate, isNull);
    });

    test('cashflowForMonth returns a zero entry for an absent month', () {
      final series = buildMonthlyCashflow([
        _tx(1000, TransactionType.credit, DateTime(2026, 1, 5),
            category: 'Salary'),
      ]);
      final missing = cashflowForMonth(series, 2026, 7);
      expect(missing.income, 0);
      expect(missing.expense, 0);
      expect(missing.savings, 0);
    });
  });
}
