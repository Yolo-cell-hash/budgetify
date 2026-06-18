import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/sip.dart';

Sip _sip({
  double? amount = 5000,
  bool amountIsFixed = true,
  int dayOfMonth = 10,
  DateTime? start,
  DateTime? end,
  int prior = 0,
}) =>
    Sip(
      name: 'Test SIP',
      category: 'Mutual Fund',
      amount: amount,
      amountIsFixed: amountIsFixed,
      dayOfMonth: dayOfMonth,
      startDate: start,
      endDate: end,
      priorInstallments: prior,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Sip schedule math', () {
    test('clamps day-of-month to the month length', () {
      final s = _sip(dayOfMonth: 31);
      expect(s.dueDateInMonth(2026, 6), DateTime(2026, 6, 30)); // June has 30
      expect(s.dueDateInMonth(2026, 2), DateTime(2026, 2, 28)); // non-leap
      expect(s.dueDateInMonth(2024, 2), DateTime(2024, 2, 29)); // leap
      expect(s.dueDateInMonth(2026, 1), DateTime(2026, 1, 31));
    });

    test('nextDueOnOrAfter rolls into the next month once the day passes', () {
      final s = _sip(dayOfMonth: 10);
      expect(s.nextDueOnOrAfter(DateTime(2026, 6, 5)), DateTime(2026, 6, 10));
      expect(s.nextDueOnOrAfter(DateTime(2026, 6, 10)), DateTime(2026, 6, 10));
      expect(s.nextDueOnOrAfter(DateTime(2026, 6, 18)), DateTime(2026, 7, 10));
    });

    test('nextDueOnOrAfter returns null once the plan has ended', () {
      final s = _sip(start: DateTime(2026, 1, 10), end: DateTime(2026, 3, 10));
      expect(s.nextDueOnOrAfter(DateTime(2026, 4, 1)), isNull);
    });

    test('totalInstallments counts inclusive of both ends', () {
      final s = _sip(start: DateTime(2026, 1, 10), end: DateTime(2026, 12, 10));
      expect(s.totalInstallments, 12);

      // End falls a day before the due date → that month doesn't count.
      final s2 = _sip(start: DateTime(2026, 1, 10), end: DateTime(2026, 12, 9));
      expect(s2.totalInstallments, 11);
    });

    test('no schedule means zero total and no progress fraction', () {
      final s = _sip();
      expect(s.hasSchedule, isFalse);
      expect(s.totalInstallments, 0);
    });

    test('scheduledInstallmentsThrough counts up to the as-of date', () {
      final s = _sip(start: DateTime(2026, 1, 10), end: DateTime(2026, 12, 10));
      expect(s.scheduledInstallmentsThrough(DateTime(2026, 6, 18)), 6);
      // Before the start there are none.
      expect(s.scheduledInstallmentsThrough(DateTime(2025, 12, 1)), 0);
      // Capped at the end date.
      expect(s.scheduledInstallmentsThrough(DateTime(2030, 1, 1)), 12);
    });
  });

  group('SipProgress', () {
    final sip = _sip(start: DateTime(2026, 1, 10), end: DateTime(2026, 12, 10), prior: 3);

    test('aggregates prior + paid instalments into progress', () {
      final p = SipProgress(
        sip: sip,
        paidCount: 2,
        investedSoFar: 10000,
        dueThisPeriod: true,
      );
      expect(p.completed, 5); // 3 prior + 2 paid
      expect(p.total, 12);
      expect(p.remaining, 7);
      expect(p.fraction, closeTo(5 / 12, 1e-9));
      expect(p.isComplete, isFalse);
    });

    test('marks complete and clamps once every instalment is in', () {
      final p = SipProgress(
        sip: sip,
        paidCount: 20,
        investedSoFar: 100000,
        dueThisPeriod: false,
      );
      expect(p.isComplete, isTrue);
      expect(p.fraction, 1.0);
      expect(p.remaining, 0);
    });

    test('fraction is null without a start/end window', () {
      final p = SipProgress(
        sip: _sip(),
        paidCount: 4,
        investedSoFar: 20000,
        dueThisPeriod: false,
      );
      expect(p.fraction, isNull);
      expect(p.remaining, isNull);
    });
  });

  group('Sip serialization', () {
    test('round-trips through toMap/fromMap', () {
      final s = _sip(
        start: DateTime(2026, 1, 10),
        end: DateTime(2026, 12, 10),
        prior: 4,
      ).copyWith(holdingId: 7, autoDetect: false, lastReminderPeriod: '2026-06');
      final back = Sip.fromMap(s.toMap());
      expect(back.name, s.name);
      expect(back.category, s.category);
      expect(back.amount, 5000);
      expect(back.amountIsFixed, isTrue);
      expect(back.dayOfMonth, 10);
      expect(back.startDate, s.startDate);
      expect(back.endDate, s.endDate);
      expect(back.autoDetect, isFalse);
      expect(back.holdingId, 7);
      expect(back.priorInstallments, 4);
      expect(back.lastReminderPeriod, '2026-06');
    });

    test('non-fixed amount survives a null amount', () {
      final s = _sip(amount: null, amountIsFixed: false);
      final back = Sip.fromMap(s.toMap());
      expect(back.amount, isNull);
      expect(back.amountIsFixed, isFalse);
    });

    test('SipStatus parses and serializes its name', () {
      expect(SipStatusName.parse('confirmed'), SipStatus.confirmed);
      expect(SipStatusName.parse('skipped'), SipStatus.skipped);
      expect(SipStatusName.parse(null), SipStatus.detected);
      expect(SipStatus.confirmed.name, 'confirmed');
      expect(SipStatus.skipped.isPaid, isFalse);
      expect(SipStatus.detected.isPaid, isTrue);
    });
  });
}
