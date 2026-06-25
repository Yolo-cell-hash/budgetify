import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/recurring_payment.dart';
import 'package:budget_tracker/services/recurring_service.dart';

RecurringPayment _monthly({
  required DateTime anchor,
  double? amount = 499,
  bool paused = false,
}) =>
    RecurringPayment(
      id: 1,
      name: 'Netflix',
      category: 'Entertainment',
      amount: amount,
      cadence: RecurringCadence.monthly,
      dayOfMonth: anchor.day,
      anchorDate: anchor,
      paused: paused,
      createdAt: anchor,
    );

RecurringCharge _charge(DateTime due, RecurringChargeStatus status) =>
    RecurringCharge(
      planId: 1,
      periodKey: RecurringPayment.periodKeyFor(due),
      dueDate: due,
      amount: 499,
      status: status,
      resolvedAt: due,
    );

void main() {
  group('statusViewFor', () {
    final plan = _monthly(anchor: DateTime(2026, 6, 10));

    RecurringStatusView view(DateTime now, Map<String, RecurringCharge> ledger) =>
        RecurringService.statusViewFor(plan, now, (k) => ledger[k]);

    test('unresolved past cycle is overdue with negative days', () {
      final v = view(DateTime(2026, 6, 15), const {});
      expect(v.state, RecurringDueState.overdue);
      expect(v.daysUntilDue, -5);
      expect(v.dueDate, DateTime(2026, 6, 10));
    });

    test('the due day itself is dueToday', () {
      final v = view(DateTime(2026, 6, 10), const {});
      expect(v.state, RecurringDueState.dueToday);
      expect(v.daysUntilDue, 0);
    });

    test('before the cycle it is upcoming', () {
      final v = view(DateTime(2026, 6, 5), const {});
      expect(v.state, RecurringDueState.upcoming);
      expect(v.daysUntilDue, 5);
      expect(v.dueDate, DateTime(2026, 6, 10));
    });

    test('paying the current cycle shows Paid immediately (not the next)', () {
      final ledger = {
        RecurringPayment.periodKeyFor(DateTime(2026, 6, 10)):
            _charge(DateTime(2026, 6, 10), RecurringChargeStatus.confirmed),
      };
      // The next cycle (10 Jul) is 25 days out — still far — so the row keeps
      // reading "Paid" for the cycle the user just resolved.
      final v = view(DateTime(2026, 6, 15), ledger);
      expect(v.state, RecurringDueState.paid);
      expect(v.dueDate, DateTime(2026, 6, 10));
    });

    test('a detected charge counts as handled (shows Paid on that cycle)', () {
      final ledger = {
        RecurringPayment.periodKeyFor(DateTime(2026, 6, 10)):
            _charge(DateTime(2026, 6, 10), RecurringChargeStatus.detected),
      };
      final v = view(DateTime(2026, 6, 11), ledger);
      expect(v.state, RecurringDueState.paid);
      expect(v.dueDate, DateTime(2026, 6, 10));
    });

    test('flips to upcoming once the next cycle is within the look-ahead', () {
      final ledger = {
        RecurringPayment.periodKeyFor(DateTime(2026, 6, 10)):
            _charge(DateTime(2026, 6, 10), RecurringChargeStatus.confirmed),
      };
      // 30 Jun: next cycle (10 Jul) is 10 days out (<= 14) → upcoming.
      final v = view(DateTime(2026, 6, 30), ledger);
      expect(v.state, RecurringDueState.upcoming);
      expect(v.dueDate, DateTime(2026, 7, 10));
      expect(v.daysUntilDue, 10);
    });

    test('a skipped current cycle shows Skipped', () {
      final ledger = {
        RecurringPayment.periodKeyFor(DateTime(2026, 6, 10)):
            _charge(DateTime(2026, 6, 10), RecurringChargeStatus.skipped),
      };
      final v = view(DateTime(2026, 6, 15), ledger);
      expect(v.state, RecurringDueState.skipped);
      expect(v.dueDate, DateTime(2026, 6, 10));
    });

    test('paused plan reports none', () {
      final paused = _monthly(anchor: DateTime(2026, 6, 10), paused: true);
      final v = RecurringService.statusViewFor(
          paused, DateTime(2026, 6, 15), (_) => null);
      expect(v.state, RecurringDueState.none);
      expect(v.dueDate, isNull);
    });
  });
}
