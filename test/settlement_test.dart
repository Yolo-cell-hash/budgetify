import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/models/ledger_models.dart';

void main() {
  group('Settlement is a neutral category', () {
    test('excluded from both income and expense totals', () {
      expect(ExpenseCategories.isIncomeCategory('Settlement'), isFalse);
      expect(ExpenseCategories.isExpenseCategory('Settlement'), isFalse);
      // …alongside the existing neutral categories
      expect(ExpenseCategories.nonExpense.contains('Settlement'), isTrue);
    });

    test('real income/spend categories still count', () {
      expect(ExpenseCategories.isIncomeCategory('Salary'), isTrue);
      expect(ExpenseCategories.isExpenseCategory('Food & Dining'), isTrue);
    });
  });

  group('SettlementSuggestion.suggest', () {
    test('a single debtor matching the amount is suggested by name', () {
      const balances = [PersonBalance('Rohan', 250), PersonBalance('Asha', 90)];
      final s = SettlementSuggestion.suggest(250, balances);
      expect(s.looksLikeSettlement, isTrue);
      expect(s.person, 'Rohan');
    });

    test('several debtors owing the same amount → suggest, but no name', () {
      // The exact ambiguous case: 3 friends each owe 250, one pays 250 back.
      const balances = [
        PersonBalance('A', 250),
        PersonBalance('B', 250),
        PersonBalance('C', 250),
      ];
      final s = SettlementSuggestion.suggest(250, balances);
      expect(s.looksLikeSettlement, isTrue);
      expect(s.person, isNull); // never guess between equal debts
    });

    test('no suggestion when nothing matches the amount', () {
      const balances = [PersonBalance('Rohan', 400)];
      final s = SettlementSuggestion.suggest(250, balances);
      expect(s.looksLikeSettlement, isFalse);
      expect(s.person, isNull);
    });

    test('people you owe (negative balance) are never matched', () {
      const balances = [PersonBalance('Rohan', -250)];
      final s = SettlementSuggestion.suggest(250, balances);
      expect(s.looksLikeSettlement, isFalse);
    });

    test('tolerant of sub-rupee rounding', () {
      const balances = [PersonBalance('Rohan', 250.4)];
      final s = SettlementSuggestion.suggest(250, balances);
      expect(s.person, 'Rohan');
    });
  });
}
