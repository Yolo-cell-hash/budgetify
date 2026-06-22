import 'package:budget_tracker/models/cashflow.dart';
import 'package:budget_tracker/models/net_worth_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetWorthProjection · savings only (no growth)', () {
    const p = NetWorthProjection(
      currentNetWorth: 100000,
      monthlyContribution: 10000,
    );

    test('projects linearly', () {
      expect(p.project(0), 100000);
      expect(p.project(12), 220000);
      expect(p.projectYears(1), 220000);
    });

    test('monthsToReach counts the months to a target', () {
      expect(p.monthsToReach(100000), 0); // already there
      expect(p.monthsToReach(220000), 12);
      expect(p.monthsToReach(225000), 13);
    });

    test('never reaches a higher target with no contribution or growth', () {
      const flat =
          NetWorthProjection(currentNetWorth: 50000, monthlyContribution: 0);
      expect(flat.monthsToReach(100000), isNull);
    });
  });

  group('NetWorthProjection · with growth', () {
    test('compounds the balance and contributions', () {
      const p = NetWorthProjection(
        currentNetWorth: 100000,
        monthlyContribution: 10000,
        annualReturnRate: 0.12, // 1% per month
      );
      // 100000*1.01 + 10000*((1.01-1)/0.01) = 101000 + 10000 = 111000
      expect(p.project(1), closeTo(111000, 1e-6));
      // Growth makes the same horizon reach more than the flat case.
      expect(p.project(24), greaterThan(100000 + 10000 * 24));
    });
  });

  group('monthlySavingsBaseline', () {
    final series = const [
      MonthlyCashflow(year: 2026, month: 1, income: 50000, expense: 30000),
      MonthlyCashflow(year: 2026, month: 2, income: 50000, expense: 20000),
      MonthlyCashflow(year: 2026, month: 3, income: 50000, expense: 35000),
    ];

    test('is the median of completed months (excludes the current month)', () {
      // April → all three months completed: savings 20000/30000/15000.
      expect(
        monthlySavingsBaseline(series, now: DateTime(2026, 4, 15)),
        20000,
      );
      // March in progress → only Jan & Feb count: median(20000, 30000)=25000.
      expect(
        monthlySavingsBaseline(series, now: DateTime(2026, 3, 10)),
        25000,
      );
    });

    test('needs at least two completed months', () {
      expect(
        monthlySavingsBaseline(series, now: DateTime(2026, 2, 1)),
        isNull, // only January is completed
      );
    });
  });

  group('nextNetWorthMilestone', () {
    test('returns the next milestone strictly above the value', () {
      expect(nextNetWorthMilestone(50000), 100000);
      expect(nextNetWorthMilestone(100000), 500000);
      expect(nextNetWorthMilestone(9000000), 10000000);
    });

    test('is null once past the top milestone', () {
      expect(nextNetWorthMilestone(200000000), isNull);
    });
  });
}
