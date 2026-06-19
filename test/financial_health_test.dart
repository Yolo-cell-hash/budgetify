import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/financial_health_service.dart';

void main() {
  group('Savings pillar', () {
    test('20% rate (or better) is a perfect 100', () {
      expect(
        const FinancialHealth(income: 100000, expenses: 80000).savingsScore,
        100,
      );
      // Beyond the target is still capped at 100.
      expect(
        const FinancialHealth(income: 100000, expenses: 40000).savingsScore,
        100,
      );
    });

    test('scales linearly below the target rate', () {
      // 10% saved → half of the 20% target → 50.
      expect(
        const FinancialHealth(income: 100000, expenses: 90000).savingsScore,
        closeTo(50, 1e-9),
      );
    });

    test('zero savings or overspending is 0', () {
      expect(
        const FinancialHealth(income: 100000, expenses: 100000).savingsScore,
        0,
      );
      expect(
        const FinancialHealth(income: 50000, expenses: 70000).savingsScore,
        0,
      );
    });

    test('no income → pillar unavailable', () {
      expect(
        const FinancialHealth(income: 0, expenses: 5000).savingsScore,
        isNull,
      );
    });
  });

  group('Budget pillar', () {
    test('at or under the limit scores full marks', () {
      const h = FinancialHealth(
        income: 0,
        expenses: 0,
        budgets: [BudgetUsage(limit: 10000, spent: 8000)],
      );
      expect(h.budgetScore, 100);
      const atLimit = FinancialHealth(
        income: 0,
        expenses: 0,
        budgets: [BudgetUsage(limit: 10000, spent: 10000)],
      );
      expect(atLimit.budgetScore, 100);
    });

    test('ramps to 0 by 25% over the limit', () {
      const half = FinancialHealth(
        income: 0,
        expenses: 0,
        // 12.5% over → halfway down the ramp.
        budgets: [BudgetUsage(limit: 10000, spent: 11250)],
      );
      expect(half.budgetScore, closeTo(50, 1e-9));

      const zero = FinancialHealth(
        income: 0,
        expenses: 0,
        budgets: [BudgetUsage(limit: 10000, spent: 12500)],
      );
      expect(zero.budgetScore, 0);

      const wayOver = FinancialHealth(
        income: 0,
        expenses: 0,
        budgets: [BudgetUsage(limit: 10000, spent: 30000)],
      );
      expect(wayOver.budgetScore, 0);
    });

    test('combines multiple envelopes weighted by limit', () {
      const h = FinancialHealth(
        income: 0,
        expenses: 0,
        budgets: [
          BudgetUsage(limit: 30000, spent: 0), // big envelope, perfect → 100
          BudgetUsage(limit: 10000, spent: 12500), // small, blown → 0
        ],
      );
      // (100*30000 + 0*10000) / 40000 = 75
      expect(h.budgetScore, closeTo(75, 1e-9));
    });

    test('no budgets / zero limits → pillar unavailable', () {
      expect(const FinancialHealth(income: 1, expenses: 0).budgetScore, isNull);
      expect(
        const FinancialHealth(
          income: 1,
          expenses: 0,
          budgets: [BudgetUsage(limit: 0, spent: 5000)],
        ).budgetScore,
        isNull,
      );
    });
  });

  group('Recurring-load pillar', () {
    test('no recurring commitments is a perfect 100', () {
      expect(
        const FinancialHealth(income: 100000, expenses: 0, recurringMonthly: 0)
            .recurringScore,
        100,
      );
    });

    test('comfortable up to half of income, then ramps down to 0', () {
      expect(
        const FinancialHealth(
                income: 100000, expenses: 0, recurringMonthly: 50000)
            .recurringScore,
        100,
      );
      expect(
        const FinancialHealth(
                income: 100000, expenses: 0, recurringMonthly: 75000)
            .recurringScore,
        closeTo(50, 1e-9),
      );
      expect(
        const FinancialHealth(
                income: 100000, expenses: 0, recurringMonthly: 100000)
            .recurringScore,
        0,
      );
    });

    test('no income → pillar unavailable', () {
      expect(
        const FinancialHealth(income: 0, expenses: 0, recurringMonthly: 5000)
            .recurringScore,
        isNull,
      );
    });
  });

  group('Net-worth pillar', () {
    test('all assets / no debt is 100', () {
      expect(
        const FinancialHealth(income: 0, expenses: 0, assets: 500000)
            .netWorthScore,
        100,
      );
    });

    test('assets equal to debts is the 50 mid-point', () {
      expect(
        const FinancialHealth(
                income: 0, expenses: 0, assets: 100000, liabilities: 100000)
            .netWorthScore,
        closeTo(50, 1e-9),
      );
    });

    test('mostly debt trends toward 0', () {
      expect(
        const FinancialHealth(
                income: 0, expenses: 0, assets: 20000, liabilities: 80000)
            .netWorthScore,
        closeTo(20, 1e-9),
      );
    });

    test('no holdings → pillar unavailable ("if any")', () {
      expect(const FinancialHealth(income: 1, expenses: 0).netWorthScore,
          isNull);
    });
  });

  group('Composite score', () {
    test('weighted blend of all four pillars', () {
      const h = FinancialHealth(
        income: 100000,
        expenses: 80000, // savings 20% → 100
        budgets: [BudgetUsage(limit: 80000, spent: 80000)], // at limit → 100
        recurringMonthly: 20000, // 20% of income → 100
        assets: 500000,
        liabilities: 100000, // equity 5/6 → ~83.33
      );
      // (100*.35 + 100*.25 + 100*.20 + 83.33*.20) = 96.667
      expect(h.scoreValue, closeTo(96.667, 0.01));
      expect(h.score, 97);
      expect(h.band, HealthBand.excellent);
    });

    test('renormalises when the budget pillar is missing', () {
      // No budgets set → that pillar drops out and the other three carry it.
      const h = FinancialHealth(
        income: 100000,
        expenses: 80000, // savings → 100
        recurringMonthly: 20000, // 20% of income → recurring 100
        assets: 100000,
        liabilities: 100000, // net worth → 50
      );
      expect(h.budgetScore, isNull);
      // (100*.35 + 100*.20 + 50*.20) / (.35 + .20 + .20) = 65 / 0.75 = 86.667
      expect(h.scoreValue, closeTo(86.667, 0.01));
    });

    test('with no income, only the budget and net-worth pillars remain', () {
      // Savings and recurring load both need income, so they drop together.
      const h = FinancialHealth(
        income: 0,
        expenses: 5000,
        budgets: [BudgetUsage(limit: 10000, spent: 8000)], // → 100
        assets: 50000,
        liabilities: 50000, // net worth → 50
      );
      expect(h.savingsScore, isNull);
      expect(h.recurringScore, isNull);
      // (100*.25 + 50*.20) / (.25 + .20) = 35 / 0.45 = 77.778
      expect(h.scoreValue, closeTo(77.778, 0.01));
    });

    test('a struggling profile scores low', () {
      const h = FinancialHealth(
        income: 50000,
        expenses: 60000, // overspending → savings 0
        budgets: [BudgetUsage(limit: 40000, spent: 60000)], // blown → 0
        recurringMonthly: 30000, // 60% of income → 80
        assets: 50000,
        liabilities: 300000, // equity ~14.3
      );
      expect(h.score, lessThan(25));
      expect(h.band, anyOf(HealthBand.atRisk, HealthBand.needsWork));
    });

    test('no data at all → no score', () {
      const h = FinancialHealth(income: 0, expenses: 0);
      expect(h.hasScore, isFalse);
      expect(h.score, isNull);
      expect(h.scoreValue, isNull);
    });
  });

  group('Bands', () {
    test('thresholds map to the right band', () {
      expect(FinancialHealth.bandFor(80), HealthBand.excellent);
      expect(FinancialHealth.bandFor(79.9), HealthBand.good);
      expect(FinancialHealth.bandFor(60), HealthBand.good);
      expect(FinancialHealth.bandFor(59.9), HealthBand.fair);
      expect(FinancialHealth.bandFor(40), HealthBand.fair);
      expect(FinancialHealth.bandFor(39.9), HealthBand.needsWork);
      expect(FinancialHealth.bandFor(20), HealthBand.needsWork);
      expect(FinancialHealth.bandFor(19.9), HealthBand.atRisk);
      expect(FinancialHealth.bandFor(0), HealthBand.atRisk);
    });

    test('every band has a label and a caption', () {
      for (final b in HealthBand.values) {
        expect(b.label, isNotEmpty);
        expect(b.caption, isNotEmpty);
      }
    });
  });
}
