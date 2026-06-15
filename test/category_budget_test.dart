import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/budget_model.dart';

void main() {
  group('Budget category & period', () {
    test('isCategoryBudget reflects the category field', () {
      final overall = Budget(name: 'Monthly', amount: 1000, startDate: DateTime.now());
      final cat = Budget(
        name: 'Food & Dining',
        amount: 500,
        category: 'Food & Dining',
        startDate: DateTime.now(),
      );
      expect(overall.isCategoryBudget, isFalse);
      expect(cat.isCategoryBudget, isTrue);
    });

    test('monthly currentPeriodKey is YYYY-MM for the current month', () {
      final now = DateTime.now();
      final b = Budget(name: 'M', amount: 1, startDate: DateTime(2020, 1, 1));
      final expected =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      expect(b.currentPeriodKey, expected);
    });

    test('weekly currentPeriodKey is a dated week anchor', () {
      final b = Budget(
        name: 'W',
        amount: 1,
        period: 'weekly',
        startDate: DateTime(2020, 1, 1),
      );
      expect(b.currentPeriodKey, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('notifiedPeriod round-trips through toMap/fromMap', () {
      final b = Budget(
        name: 'Food & Dining',
        amount: 500,
        category: 'Food & Dining',
        startDate: DateTime(2026, 6, 1),
        lastNotifiedThreshold: 75,
        notifiedPeriod: '2026-06',
      );
      final restored = Budget.fromMap(b.toMap());
      expect(restored.notifiedPeriod, '2026-06');
      expect(restored.lastNotifiedThreshold, 75);
      expect(restored.category, 'Food & Dining');
      expect(restored.isCategoryBudget, isTrue);
    });

    test('a budget with no notified period defaults to null', () {
      final b = Budget(name: 'M', amount: 1000, startDate: DateTime(2026, 6, 1));
      final restored = Budget.fromMap(b.toMap());
      expect(restored.notifiedPeriod, isNull);
    });
  });
}
