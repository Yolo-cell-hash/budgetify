import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/recurring_plan.dart';
import 'package:budget_tracker/models/transaction_model.dart';
import 'package:budget_tracker/services/recurring_service.dart';

/// Builds a plan with sensible defaults; override what each test cares about.
RecurringPlan plan({
  int? id = 1,
  RecurringKind kind = RecurringKind.sip,
  double amount = 5000,
  bool isFixed = true,
  int dueDay = 18,
  DateTime? start,
  DateTime? end,
  String? signature,
  bool active = true,
}) {
  final now = DateTime(2026, 1, 1);
  return RecurringPlan(
    id: id,
    holdingId: 7,
    kind: kind,
    amount: amount,
    isFixed: isFixed,
    dueDay: dueDay,
    startDate: start,
    endDate: end,
    payeeSignature: signature,
    active: active,
    createdAt: now,
    updatedAt: now,
  );
}

TransactionModel txn({
  int? id = 100,
  double amount = 5000,
  TransactionType type = TransactionType.debit,
  String sender = 'BV-ICICIT-S',
  String? merchant = 'Zerodha Broking',
  required DateTime on,
}) {
  return TransactionModel(
    id: id,
    amount: amount,
    type: type,
    sender: sender,
    message: 'auto debit',
    detectedAt: on,
    merchantName: merchant,
  );
}

void main() {
  group('RecurringPlan helpers', () {
    test('dueDateIn clamps to the last day of short months', () {
      final p = plan(dueDay: 31);
      expect(p.dueDateIn(DateTime(2026, 2)), DateTime(2026, 2, 28));
      expect(p.dueDateIn(DateTime(2024, 2)), DateTime(2024, 2, 29)); // leap
      expect(p.dueDateIn(DateTime(2026, 6)), DateTime(2026, 6, 30));
      expect(plan(dueDay: 15).dueDateIn(DateTime(2026, 6)),
          DateTime(2026, 6, 15));
    });

    test('periodKey is zero-padded YYYY-MM', () {
      expect(RecurringPlan.periodKey(DateTime(2026, 6, 18)), '2026-06');
      expect(RecurringPlan.periodKey(DateTime(2026, 12, 1)), '2026-12');
    });

    test('isLiveOn respects active flag and date bounds', () {
      final p = plan(start: DateTime(2026, 1, 10), end: DateTime(2026, 12, 31));
      expect(p.isLiveOn(DateTime(2026, 6, 1)), isTrue);
      expect(p.isLiveOn(DateTime(2025, 12, 31)), isFalse); // before start
      expect(p.isLiveOn(DateTime(2027, 1, 1)), isFalse); // after end
      expect(plan(active: false).isLiveOn(DateTime(2026, 6, 1)), isFalse);
    });
  });

  group('signature normalization', () {
    test('normalizeSignature strips non-alphanumerics and upcases', () {
      expect(RecurringService.normalizeSignature('BSE Limited-123'),
          'BSELIMITED123');
      expect(RecurringService.normalizeSignature('ach/nach e-mandate'),
          'ACHNACHEMANDATE');
    });

    test('signatureForTxn prefers merchant, falls back to sender', () {
      expect(
          RecurringService.signatureForTxn(
              txn(on: DateTime(2026, 6, 18), merchant: 'Zerodha Broking')),
          'ZERODHABROKING');
      expect(
          RecurringService.signatureForTxn(
              txn(on: DateTime(2026, 6, 18), merchant: '', sender: 'AD-HDFCBK')),
          'ADHDFCBK');
    });
  });

  group('due-day window', () {
    test('matches on and near the due day', () {
      final p = plan(dueDay: 18);
      expect(RecurringService.inDueWindow(p, DateTime(2026, 6, 18)), isTrue);
      expect(RecurringService.inDueWindow(p, DateTime(2026, 6, 20)), isTrue);
      expect(RecurringService.inDueWindow(p, DateTime(2026, 6, 25)), isFalse);
    });

    test('tolerates month-boundary mandates (day 1 paid on the last day)', () {
      final p = plan(dueDay: 1);
      // A "1st of month" mandate that posts on 31 May is one day from 1 Jun.
      expect(RecurringService.inDueWindow(p, DateTime(2026, 5, 31)), isTrue);
    });
  });

  group('amount matching (fixed plans)', () {
    test('matches within 1% / ₹1 tolerance', () {
      final p = plan(amount: 5000);
      expect(RecurringService.amountMatches(p, 5000), isTrue);
      expect(RecurringService.amountMatches(p, 5040), isTrue); // within ₹50
      expect(RecurringService.amountMatches(p, 5100), isFalse);
    });

    test('small amounts use the ₹1 floor', () {
      final p = plan(amount: 50);
      expect(RecurringService.amountMatches(p, 51), isTrue);
      expect(RecurringService.amountMatches(p, 52), isFalse);
    });
  });

  group('isAutoMatch (learned signature → silent)', () {
    final t = txn(on: DateTime(2026, 6, 18), merchant: 'Zerodha Broking');

    test('matches a live in-window debit carrying the signature', () {
      expect(RecurringService.isAutoMatch(plan(signature: 'ZERODHA'), t), isTrue);
    });

    test('does not match without a learned signature', () {
      expect(RecurringService.isAutoMatch(plan(signature: null), t), isFalse);
    });

    test('does not match credits, wrong payee, out of window, or paused', () {
      expect(
          RecurringService.isAutoMatch(plan(signature: 'ZERODHA'),
              txn(on: DateTime(2026, 6, 18), type: TransactionType.credit)),
          isFalse);
      expect(
          RecurringService.isAutoMatch(
              plan(signature: 'GROWW'), t), // different payee
          isFalse);
      expect(
          RecurringService.isAutoMatch(plan(signature: 'ZERODHA'),
              txn(on: DateTime(2026, 6, 26), merchant: 'Zerodha')),
          isFalse); // out of window
      expect(
          RecurringService.isAutoMatch(
              plan(signature: 'ZERODHA', active: false), t),
          isFalse);
    });
  });

  group('isCandidate (no signature → needs confirm)', () {
    test('fixed plan: only an amount+window match is a candidate', () {
      final p = plan(signature: null, amount: 5000, isFixed: true);
      expect(
          RecurringService.isCandidate(
              p, txn(on: DateTime(2026, 6, 18), amount: 5000)),
          isTrue);
      expect(
          RecurringService.isCandidate(
              p, txn(on: DateTime(2026, 6, 18), amount: 9999)),
          isFalse);
    });

    test('variable plan: any in-window debit is a candidate', () {
      final p = plan(signature: null, isFixed: false);
      expect(
          RecurringService.isCandidate(
              p, txn(on: DateTime(2026, 6, 18), amount: 1234)),
          isTrue);
    });

    test('a plan that already has a signature is never a candidate', () {
      expect(
          RecurringService.isCandidate(
              plan(signature: 'ZERODHA'), txn(on: DateTime(2026, 6, 18))),
          isFalse);
    });
  });

  group('progress math', () {
    test('expectedInstallments counts due months through asOf', () {
      expect(
          RecurringService.expectedInstallments(
              DateTime(2026, 1, 5), DateTime(2026, 6, 17), 5),
          6);
      // asOf before this month's due day → current month not yet counted.
      expect(
          RecurringService.expectedInstallments(
              DateTime(2026, 1, 5), DateTime(2026, 6, 3), 5),
          5);
      expect(
          RecurringService.expectedInstallments(null, DateTime(2026, 6, 1), 5),
          0);
    });

    test('totalInstallments spans start..end inclusive, null when unbounded', () {
      expect(
          RecurringService.totalInstallments(
              plan(start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31))),
          12);
      expect(RecurringService.totalInstallments(plan()), isNull);
    });

    test('nextDue finds the next due date within bounds', () {
      final p = plan(dueDay: 18);
      expect(RecurringService.nextDue(p, DateTime(2026, 6, 10)),
          DateTime(2026, 6, 18));
      expect(RecurringService.nextDue(p, DateTime(2026, 6, 20)),
          DateTime(2026, 7, 18));
      // Past the end date → no further due date.
      final bounded = plan(dueDay: 18, end: DateTime(2026, 6, 30));
      expect(RecurringService.nextDue(bounded, DateTime(2026, 7, 1)), isNull);
    });

    test('computeProgress derives fraction, behind-status and projection', () {
      final p = plan(
        amount: 5000,
        isFixed: true,
        dueDay: 5,
        start: DateTime(2026, 1, 5),
        end: DateTime(2026, 12, 5),
      );
      final prog = RecurringService.computeProgress(
        p,
        contributed: 20000,
        installmentsDone: 4,
        asOf: DateTime(2026, 6, 17),
      );
      expect(prog.totalInstallments, 12);
      expect(prog.expectedInstallments, 6);
      expect(prog.installmentsDone, 4);
      expect(prog.projectedTotal, 60000);
      expect(prog.fractionComplete, closeTo(4 / 12, 1e-9));
      expect(prog.isBehind, isTrue); // 4 done < 6 expected
    });

    test('open-ended plans have no fraction or projection', () {
      final prog = RecurringService.computeProgress(plan(),
          contributed: 10000, installmentsDone: 2, asOf: DateTime(2026, 6, 17));
      expect(prog.fractionComplete, isNull);
      expect(prog.totalInstallments, isNull);
      expect(prog.projectedTotal, isNull);
    });
  });
}
