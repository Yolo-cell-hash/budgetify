import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/transaction_model.dart';

void main() {
  group('Non-expense categories', () {
    test('Self Transfer and Investments are predefined', () {
      expect(ExpenseCategories.predefined, contains('Self Transfer'));
      expect(ExpenseCategories.predefined, contains('Investments'));
    });

    test('isExpenseCategory excludes the non-expense tags', () {
      expect(ExpenseCategories.isExpenseCategory('Self Transfer'), isFalse);
      expect(ExpenseCategories.isExpenseCategory('Investments'), isFalse);
    });

    test('regular categories and untagged still count as expense', () {
      expect(ExpenseCategories.isExpenseCategory('Food & Dining'), isTrue);
      expect(ExpenseCategories.isExpenseCategory('Shopping'), isTrue);
      expect(ExpenseCategories.isExpenseCategory(null), isTrue);
    });

    test('non-expense tags have an icon and a color', () {
      for (final c in ['Self Transfer', 'Investments']) {
        expect(ExpenseCategories.getIcon(c), isNotEmpty);
        expect(ExpenseCategories.getColor(c), isNotNull);
      }
    });
  });
}
