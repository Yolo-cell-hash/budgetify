import 'package:budget_tracker/models/cashflow.dart';
import 'package:budget_tracker/models/period_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildPeriodComparison · month', () {
    final series = const [
      MonthlyCashflow(year: 2026, month: 1, income: 50000, expense: 30000),
      MonthlyCashflow(year: 2026, month: 2, income: 50000, expense: 25000),
      MonthlyCashflow(year: 2026, month: 3, income: 50000, expense: 20000),
      MonthlyCashflow(year: 2026, month: 4, income: 50000, expense: 40000),
    ];

    test('compares the last full month to the one before', () {
      // May → last full month = April, prior = March.
      final cmp = buildPeriodComparison(series, now: DateTime(2026, 5, 10));
      expect(cmp.current.expense, 40000); // April
      expect(cmp.previous.expense, 20000); // March
      expect(cmp.expenseDelta, 20000);
      expect(cmp.current.savings, 10000);
      expect(cmp.previous.savings, 30000);
      expect(cmp.savingsDelta, -20000);
      expect(cmp.hasComparison, isTrue);
    });

    test('savingsRateDeltaPoints is the change in percentage points', () {
      final cmp = buildPeriodComparison(series, now: DateTime(2026, 5, 10));
      // April rate 20%, March rate 60% → -40 points.
      expect(cmp.savingsRateDeltaPoints, closeTo(-40, 1e-9));
    });

    test('hasComparison is false without a prior period', () {
      final only = const [
        MonthlyCashflow(year: 2026, month: 4, income: 50000, expense: 40000),
      ];
      final cmp = buildPeriodComparison(only, now: DateTime(2026, 5, 10));
      expect(cmp.current.hasData, isTrue);
      expect(cmp.previous.hasData, isFalse);
      expect(cmp.hasComparison, isFalse);
    });
  });

  group('buildPeriodComparison · quarter', () {
    final series = const [
      MonthlyCashflow(year: 2025, month: 10, income: 40000, expense: 30000),
      MonthlyCashflow(year: 2025, month: 11, income: 40000, expense: 30000),
      MonthlyCashflow(year: 2025, month: 12, income: 40000, expense: 30000),
      MonthlyCashflow(year: 2026, month: 1, income: 50000, expense: 30000),
      MonthlyCashflow(year: 2026, month: 2, income: 50000, expense: 25000),
      MonthlyCashflow(year: 2026, month: 3, income: 50000, expense: 20000),
    ];

    test('compares the last completed quarter to the prior one', () {
      // April 2026 (Q2 in progress) → current = Q1 2026, previous = Q4 2025.
      final cmp = buildPeriodComparison(
        series,
        now: DateTime(2026, 4, 10),
        period: ComparePeriod.quarter,
      );
      expect(cmp.current.income, 150000); // Jan+Feb+Mar
      expect(cmp.current.expense, 75000);
      expect(cmp.previous.income, 120000); // Oct+Nov+Dec 2025
      expect(cmp.previous.expense, 90000);
      expect(cmp.savingsDelta, (150000 - 75000) - (120000 - 90000)); // 45000
    });
  });
}
