import 'package:intl/intl.dart';

import '../models/ledger_models.dart';
import 'database_service.dart';

/// One entry in a person's activity feed — either a split that involves them
/// or a settlement with them. [delta] is the effect on *their* balance with
/// you (positive ⇒ they now owe you more).
class LedgerActivity {
  final DateTime date;
  final String title;
  final double delta;
  final bool isSettlement;
  final SplitEntry? split;
  final Settlement? settlement;

  const LedgerActivity._({
    required this.date,
    required this.title,
    required this.delta,
    required this.isSettlement,
    this.split,
    this.settlement,
  });

  factory LedgerActivity.fromSplit(SplitEntry s, double delta) =>
      LedgerActivity._(
        date: s.date,
        title: s.title,
        delta: delta,
        isSettlement: false,
        split: s,
      );

  factory LedgerActivity.fromSettlement(Settlement st) => LedgerActivity._(
        date: st.date,
        title: st.paidToMe ? 'They paid you back' : 'You paid them',
        delta: st.paidToMe ? -st.amount : st.amount,
        isSettlement: true,
        settlement: st,
      );
}

/// Orchestrates the offline split ledger: balances, the per-person feed,
/// settle-ups, and the "my share" link that ties a split to a transaction so
/// it only counts the user's portion toward spending. Pure arithmetic lives in
/// [LedgerMath]; this layer is the database glue.
class LedgerService {
  final DatabaseService _db;
  LedgerService([DatabaseService? db]) : _db = db ?? DatabaseService();

  /// Whole-ledger roll-up for the summary header + people list.
  Future<LedgerSummary> summary() async {
    final splits = await _db.getSplits();
    final parts = await _db.getAllParticipants();
    final settlements = await _db.getSettlements();
    final bal = LedgerMath.balances(
      splits: splits,
      participantsBySplit: parts,
      settlements: settlements,
    );
    return LedgerMath.summarize(bal);
  }

  Future<List<String>> knownPeople() => _db.getKnownPeople();

  /// Per-person context for the list subtitle: the most recent expense title
  /// they're part of and how many splits involve them.
  Future<Map<String, PersonContext>> peopleContext() async {
    final splits = await _db.getSplits(); // newest first (date DESC, id DESC)
    final parts = await _db.getAllParticipants();
    final latest = <String, String>{};
    final count = <String, int>{};
    for (final s in splits) {
      final involved = <String>{};
      if (s.paidByMe) {
        for (final p in parts[s.id] ?? const <SplitParticipant>[]) {
          if (p.share > 0) involved.add(p.person);
        }
      } else {
        involved.add(s.payer!);
      }
      for (final person in involved) {
        latest.putIfAbsent(person, () => s.title); // first seen = newest
        count[person] = (count[person] ?? 0) + 1;
      }
    }
    return {
      for (final person in {...latest.keys, ...count.keys})
        person: PersonContext(
          latestExpense: latest[person],
          splitCount: count[person] ?? 0,
        ),
    };
  }

  /// Create a split, applying the my-share override to its linked transaction.
  Future<int> addSplit(
    SplitEntry split,
    List<SplitParticipant> participants,
  ) async {
    final id = await _db.insertSplit(split, participants);
    if (split.transactionId != null) {
      await _db.setTransactionSplitShare(split.transactionId!, split.myShare);
    }
    return id;
  }

  /// Update a split, reconciling the transaction override if the link or share
  /// changed (clear the old transaction, set the new one).
  Future<void> updateSplit(
    SplitEntry split,
    List<SplitParticipant> participants,
  ) async {
    final old = split.id == null ? null : await _db.getSplit(split.id!);
    await _db.updateSplit(split, participants);
    if (old?.transactionId != null &&
        old!.transactionId != split.transactionId) {
      await _db.setTransactionSplitShare(old.transactionId!, null);
    }
    if (split.transactionId != null) {
      await _db.setTransactionSplitShare(split.transactionId!, split.myShare);
    }
  }

  /// Delete a split and release any transaction override it held.
  Future<void> deleteSplit(int id) async {
    final s = await _db.getSplit(id);
    if (s?.transactionId != null) {
      await _db.setTransactionSplitShare(s!.transactionId!, null);
    }
    await _db.deleteSplit(id);
  }

  Future<int> addSettlement(Settlement s) => _db.insertSettlement(s);
  Future<void> deleteSettlement(int id) => _db.deleteSettlement(id);

  /// A unified, newest-first feed of everything involving [person].
  Future<List<LedgerActivity>> activityFor(String person) async {
    final splits = await _db.getSplits();
    final parts = await _db.getAllParticipants();
    final settlements = await _db.getSettlements();

    final out = <LedgerActivity>[];
    for (final s in splits) {
      double? delta;
      if (s.paidByMe) {
        final share = (parts[s.id] ?? const <SplitParticipant>[])
            .where((p) => p.person == person)
            .fold<double>(0, (a, p) => a + p.share);
        if (share > 0) delta = share; // they owe you their share
      } else if (s.payer == person) {
        delta = -s.myShare; // you owe them your share
      }
      if (delta != null) out.add(LedgerActivity.fromSplit(s, delta));
    }
    for (final st in settlements.where((x) => x.person == person)) {
      out.add(LedgerActivity.fromSettlement(st));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static final NumberFormat _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  /// A WhatsApp-friendly one-liner for the share sheet.
  String shareSummary(String person, double net) {
    if (net.abs() < personBalanceEps) {
      return '$person and I are all settled up. ✅\n— tracked on Budgetify';
    }
    if (net > 0) {
      return '$person owes me ${_inr.format(net)}.\n— tracked on Budgetify';
    }
    return 'I owe $person ${_inr.format(net.abs())}.\n— tracked on Budgetify';
  }
}

/// List-subtitle context for a person: their latest shared expense and how
/// many splits they appear in.
class PersonContext {
  final String? latestExpense;
  final int splitCount;
  const PersonContext({this.latestExpense, this.splitCount = 0});
}

/// Shared "treat sub-rupee residue as settled" threshold.
const double personBalanceEps = 0.5;
