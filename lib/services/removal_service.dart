import '../models/transaction_model.dart';
import '../widgets/removal_choice_dialog.dart';
import 'app_events.dart';
import 'database_service.dart';

/// What a removal did, and everything needed to take it back.
class RemovalReceipt {
  /// Tombstone rows to restore from, newest first.
  final List<int> tombstoneIds;

  /// Shapes that were muted, as (sender, message) pairs, so an undo can lift
  /// exactly the mutes this removal added.
  final List<(String, String)> mutedShapes;

  const RemovalReceipt({
    required this.tombstoneIds,
    required this.mutedShapes,
  });

  int get count => tombstoneIds.length;
  bool get mutedAnything => mutedShapes.isNotEmpty;
  bool get isRestorable => tombstoneIds.isNotEmpty;
}

/// Performs transaction removals so every entry point — swipe, detail screen,
/// bulk selection, tidy-up — behaves identically: the same muting rule, the
/// same royal reaction, and the same undo contract.
class RemovalService {
  RemovalService._();
  static final RemovalService instance = RemovalService._();

  final DatabaseService _db = DatabaseService();

  /// Whether a mute can be keyed off this row at all. Manual rows are never
  /// re-created from an SMS, so muting a "shape" for them is meaningless.
  static bool canMute(TransactionModel t) =>
      !t.isManual && t.message.trim().isNotEmpty;

  /// Remove [transactions] according to [choice] and return the receipt.
  ///
  /// For [TransactionRemoval.notATransaction] the message shape is muted first,
  /// so a concurrent inbox scan can't re-log the row between the mute and the
  /// delete.
  Future<RemovalReceipt> remove(
    List<TransactionModel> transactions,
    TransactionRemoval choice,
  ) async {
    final tombstones = <int>[];
    final muted = <(String, String)>[];

    for (final t in transactions) {
      if (t.id == null) continue;

      if (choice == TransactionRemoval.notATransaction && canMute(t)) {
        await _db.addMessageMute(t.sender, t.message);
        muted.add((t.sender, t.message));
      }

      final (_, tombstoneId) = await _db.deleteTransactionForUndo(t.id!);
      if (tombstoneId != null) tombstones.add(tombstoneId);
    }

    // A correction teaches the parser; a bare delete is a dead end. They must
    // not look the same, or the app is cheering for the wrong habit.
    requestRoyalReaction(
      choice == TransactionRemoval.notATransaction
          ? RoyalReaction.taught
          : RoyalReaction.strike,
    );

    return RemovalReceipt(tombstoneIds: tombstones, mutedShapes: muted);
  }

  /// Put back everything [receipt] removed and lift any mutes it added.
  /// Returns how many rows came back.
  Future<int> undo(RemovalReceipt receipt) async {
    for (final (sender, message) in receipt.mutedShapes) {
      await _db.removeMessageMuteFor(sender, message);
    }

    var restored = 0;
    for (final id in receipt.tombstoneIds) {
      if (await _db.restoreTransaction(id) != null) restored++;
    }
    return restored;
  }
}
