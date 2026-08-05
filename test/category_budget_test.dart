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

    // Spend queries bound on `detected_at <= currentPeriodEnd`, so an end at
    // midnight drops the whole of the period's last day: the gauge, the
    // threshold alerts and the home widget all went a day behind everything
    // else on the 31st, and the widget disagreed with its own "spent this
    // month" figure.
    test('monthly currentPeriodEnd covers the last day, not midnight on it',
        () {
      final now = DateTime.now();
      final b = Budget(name: 'M', amount: 1, startDate: DateTime(2020, 1, 1));
      final end = b.currentPeriodEnd;
      final lastDay = DateTime(now.year, now.month + 1, 0).day;

      expect(end.day, lastDay);
      expect([end.hour, end.minute, end.second], [23, 59, 59]);
      // A spend at 8pm on the final day must fall inside the period.
      final lateOnLastDay =
          DateTime(now.year, now.month, lastDay, 20, 0);
      expect(lateOnLastDay.isAfter(end), isFalse);
    });

    test('weekly currentPeriodEnd covers all of Sunday', () {
      final b = Budget(
        name: 'W',
        amount: 1,
        period: 'weekly',
        startDate: DateTime(2020, 1, 1),
      );
      final start = b.currentPeriodStart;
      final end = b.currentPeriodEnd;

      expect(start.weekday, DateTime.monday);
      expect(end.weekday, DateTime.sunday);
      expect([end.hour, end.minute, end.second], [23, 59, 59]);
      // Monday 00:00 → Sunday 23:59:59 is seven whole days.
      expect(end.difference(start).inDays, 6);
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
