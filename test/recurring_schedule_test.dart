import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/recurring_payment.dart';

RecurringPayment _plan({
  RecurringCadence cadence = RecurringCadence.monthly,
  required DateTime anchor,
  double? amount,
  bool amountIsFixed = true,
  DateTime? endDate,
  bool paused = false,
}) =>
    RecurringPayment(
      name: 'Test',
      category: 'Bills & Utilities',
      amount: amount,
      amountIsFixed: amountIsFixed,
      cadence: cadence,
      dayOfMonth: anchor.day,
      anchorDate: anchor,
      endDate: endDate,
      paused: paused,
      createdAt: anchor,
    );

void main() {
  group('periodKeyFor', () {
    test('formats the due date as YYYY-MM-DD', () {
      expect(RecurringPayment.periodKeyFor(DateTime(2026, 1, 5)), '2026-01-05');
      expect(RecurringPayment.periodKeyFor(DateTime(2026, 12, 31)),
          '2026-12-31');
    });
  });

  group('monthly schedule', () {
    final p = _plan(anchor: DateTime(2026, 1, 15));

    test('nextDueOnOrAfter returns the anchor on its own day', () {
      expect(p.nextDueOnOrAfter(DateTime(2026, 1, 15)), DateTime(2026, 1, 15));
    });

    test('nextDueOnOrAfter rolls to next month the day after', () {
      expect(p.nextDueOnOrAfter(DateTime(2026, 1, 16)), DateTime(2026, 2, 15));
    });

    test('dueOnOrBefore returns the most recent cycle', () {
      expect(p.dueOnOrBefore(DateTime(2026, 2, 20)), DateTime(2026, 2, 15));
    });

    test('dueOnOrBefore is null before the anchor', () {
      expect(p.dueOnOrBefore(DateTime(2026, 1, 10)), isNull);
    });

    test('occurrencesBetween lists each monthly due', () {
      expect(
        p.occurrencesBetween(DateTime(2026, 1, 1), DateTime(2026, 3, 31)),
        [DateTime(2026, 1, 15), DateTime(2026, 2, 15), DateTime(2026, 3, 15)],
      );
    });
  });

  group('month-length clamping', () {
    final p = _plan(anchor: DateTime(2026, 1, 31));

    test('day 31 clamps to February length then recovers', () {
      expect(p.nextDueOnOrAfter(DateTime(2026, 2, 1)), DateTime(2026, 2, 28));
      // Stepping on from the clamped Feb date returns to the 31st in March.
      expect(p.nextDueOnOrAfter(DateTime(2026, 3, 1)), DateTime(2026, 3, 31));
    });
  });

  group('weekly schedule', () {
    final p = _plan(cadence: RecurringCadence.weekly, anchor: DateTime(2026, 1, 5));

    test('steps by 7 days', () {
      expect(p.nextDueOnOrAfter(DateTime(2026, 1, 6)), DateTime(2026, 1, 12));
    });

    test('occurrencesBetween lists weekly dues', () {
      expect(
        p.occurrencesBetween(DateTime(2026, 1, 5), DateTime(2026, 1, 26)),
        [
          DateTime(2026, 1, 5),
          DateTime(2026, 1, 12),
          DateTime(2026, 1, 19),
          DateTime(2026, 1, 26),
        ],
      );
    });
  });

  group('quarterly + yearly', () {
    test('quarterly steps by three months', () {
      final p =
          _plan(cadence: RecurringCadence.quarterly, anchor: DateTime(2026, 1, 10));
      expect(
        p.occurrencesBetween(DateTime(2026, 1, 1), DateTime(2026, 12, 31)),
        [
          DateTime(2026, 1, 10),
          DateTime(2026, 4, 10),
          DateTime(2026, 7, 10),
          DateTime(2026, 10, 10),
        ],
      );
    });

    test('yearly steps by twelve months', () {
      final p =
          _plan(cadence: RecurringCadence.yearly, anchor: DateTime(2026, 3, 1));
      expect(p.nextDueOnOrAfter(DateTime(2026, 3, 2)), DateTime(2027, 3, 1));
    });
  });

  group('end date', () {
    final p = _plan(
      anchor: DateTime(2026, 1, 15),
      endDate: DateTime(2026, 2, 28),
    );

    test('nextDueOnOrAfter past the end is null', () {
      expect(p.nextDueOnOrAfter(DateTime(2026, 3, 1)), isNull);
    });

    test('occurrencesBetween stops at the end date', () {
      expect(
        p.occurrencesBetween(DateTime(2026, 1, 1), DateTime(2026, 12, 31)),
        [DateTime(2026, 1, 15), DateTime(2026, 2, 15)],
      );
    });
  });

  group('monthlyEquivalent', () {
    test('normalises each cadence to a monthly figure', () {
      expect(
        _plan(anchor: DateTime(2026, 1, 1), amount: 500).monthlyEquivalent,
        500,
      );
      expect(
        _plan(
          cadence: RecurringCadence.quarterly,
          anchor: DateTime(2026, 1, 1),
          amount: 600,
        ).monthlyEquivalent,
        200,
      );
      expect(
        _plan(
          cadence: RecurringCadence.yearly,
          anchor: DateTime(2026, 1, 1),
          amount: 1200,
        ).monthlyEquivalent,
        100,
      );
    });

    test('is zero for variable-amount plans', () {
      expect(
        _plan(anchor: DateTime(2026, 1, 1), amount: null, amountIsFixed: false)
            .monthlyEquivalent,
        0,
      );
    });
  });

  group('isActiveForMonth', () {
    test('false when paused', () {
      final p = _plan(anchor: DateTime(2026, 1, 1), paused: true);
      expect(p.isActiveForMonth(DateTime(2026, 6, 1)), isFalse);
    });

    test('false before the anchor month and after the end', () {
      final p = _plan(
        anchor: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 5, 31),
      );
      expect(p.isActiveForMonth(DateTime(2026, 2, 15)), isFalse);
      expect(p.isActiveForMonth(DateTime(2026, 4, 15)), isTrue);
      expect(p.isActiveForMonth(DateTime(2026, 6, 15)), isFalse);
    });
  });
}
