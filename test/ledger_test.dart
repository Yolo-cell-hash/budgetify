import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/ledger_models.dart';

void main() {
  final t = DateTime(2026, 6, 1);

  SplitEntry split({
    int? id,
    String? payer,
    required double total,
    required double myShare,
  }) =>
      SplitEntry(
        id: id,
        title: 'Test',
        totalAmount: total,
        myShare: myShare,
        payer: payer,
        date: t,
        createdAt: t,
      );

  SplitParticipant part(int splitId, String person, double share) =>
      SplitParticipant(splitId: splitId, person: person, share: share);

  group('LedgerMath.balances', () {
    test('when I pay, each participant owes me their share', () {
      final splits = [split(id: 1, total: 1200, myShare: 400)];
      final parts = {
        1: [part(1, 'Rohan', 400), part(1, 'Priya', 400)],
      };
      final bal = LedgerMath.balances(
        splits: splits,
        participantsBySplit: parts,
        settlements: const [],
      );
      expect(bal['Rohan'], 400);
      expect(bal['Priya'], 400);
    });

    test('when someone else pays, I owe them my share', () {
      final splits = [split(id: 1, payer: 'Rohan', total: 900, myShare: 300)];
      final bal = LedgerMath.balances(
        splits: splits,
        participantsBySplit: const {},
        settlements: const [],
      );
      expect(bal['Rohan'], -300); // negative ⇒ I owe Rohan
    });

    test('a settlement moves the balance toward zero', () {
      final splits = [split(id: 1, total: 1000, myShare: 500)];
      final parts = {
        1: [part(1, 'Rohan', 500)],
      };
      final settlements = [
        Settlement(
          person: 'Rohan',
          amount: 500,
          paidToMe: true, // Rohan pays me back
          date: t,
          createdAt: t,
        ),
      ];
      final bal = LedgerMath.balances(
        splits: splits,
        participantsBySplit: parts,
        settlements: settlements,
      );
      expect(bal['Rohan'], 0);
    });

    test('me paying a person back increases what they owe me (toward +)', () {
      final settlements = [
        Settlement(
          person: 'Asha',
          amount: 250,
          paidToMe: false, // I pay Asha
          date: t,
          createdAt: t,
        ),
      ];
      final bal = LedgerMath.balances(
        splits: const [],
        participantsBySplit: const {},
        settlements: settlements,
      );
      expect(bal['Asha'], 250);
    });

    test('balances accumulate across multiple splits', () {
      final splits = [
        split(id: 1, total: 600, myShare: 300), // I paid: Rohan owes 300
        split(id: 2, payer: 'Rohan', total: 400, myShare: 200), // I owe 200
      ];
      final parts = {
        1: [part(1, 'Rohan', 300)],
      };
      final bal = LedgerMath.balances(
        splits: splits,
        participantsBySplit: parts,
        settlements: const [],
      );
      expect(bal['Rohan'], 100); // 300 owed − 200 I owe = net 100 to me
    });
  });

  group('LedgerMath.summarize', () {
    test('rolls up owed/owe, net, and ordering', () {
      final bal = {'Rohan': 400.0, 'Priya': -150.0, 'Even': 0.2};
      final s = LedgerMath.summarize(bal);

      expect(s.owedToMe, 400);
      expect(s.iOwe, 150);
      expect(s.net, 250);

      // Sub-rupee residue counts as settled and sinks to the bottom.
      expect(s.people.last.person, 'Even');
      expect(s.people.last.isSettled, isTrue);
      expect(s.activeCount, 2);

      // Largest magnitude first among active balances.
      expect(s.people.first.person, 'Rohan');
    });

    test('PersonBalance classifies direction', () {
      const owe = PersonBalance('A', -100);
      const owed = PersonBalance('B', 100);
      const settled = PersonBalance('C', 0);
      expect(owe.iOwe, isTrue);
      expect(owed.owesMe, isTrue);
      expect(settled.isSettled, isTrue);
    });
  });
}
