import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/widgets/savings_summary.dart';

void main() {
  group('isIncomeCategory (true income excludes own-money movement)', () {
    test('self-transfers and investments are not income', () {
      expect(ExpenseCategories.isIncomeCategory('Self Transfer'), isFalse);
      expect(ExpenseCategories.isIncomeCategory('Investments'), isFalse);
    });

    test('salary, refunds, untagged and other credits count as income', () {
      expect(ExpenseCategories.isIncomeCategory('Salary'), isTrue);
      expect(ExpenseCategories.isIncomeCategory('Refund'), isTrue);
      expect(ExpenseCategories.isIncomeCategory(null), isTrue);
      expect(ExpenseCategories.isIncomeCategory('Food & Dining'), isTrue);
    });
  });

  group('SavingsStats', () {
    test('positive savings', () {
      const s = SavingsStats(income: 100000, expenses: 60000);
      expect(s.savings, 40000);
      expect(s.hasIncome, isTrue);
      expect(s.isOverspent, isFalse);
      expect(s.ratePercent, 40);
      expect(s.savedFraction, closeTo(0.4, 1e-9));
    });

    test('overspending gives a negative rate and an empty fill', () {
      const s = SavingsStats(income: 50000, expenses: 70000);
      expect(s.savings, -20000);
      expect(s.isOverspent, isTrue);
      expect(s.ratePercent, -40);
      expect(s.savedFraction, 0.0); // bar shows the overspent state instead
    });

    test('no income -> undefined rate, no fill', () {
      const s = SavingsStats(income: 0, expenses: 5000);
      expect(s.hasIncome, isFalse);
      expect(s.ratePercent, isNull);
      expect(s.savedFraction, 0.0);
      expect(s.isOverspent, isTrue); // 0 - 5000 < 0
    });

    test('no activity -> undefined rate', () {
      const s = SavingsStats(income: 0, expenses: 0);
      expect(s.hasIncome, isFalse);
      expect(s.ratePercent, isNull);
      expect(s.savings, 0);
      expect(s.isOverspent, isFalse);
    });

    test('savedFraction never exceeds 1 even if expenses are negative', () {
      const s = SavingsStats(income: 100, expenses: -50); // e.g. net refunds
      expect(s.savedFraction, 1.0);
    });
  });
}
