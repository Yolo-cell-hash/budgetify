/// Pure decision logic for merging a backed-up transaction onto the row a
/// device already has. No I/O and no Flutter — unit-tested in isolation,
/// because the database layer it feeds isn't reachable from a test.
///
/// ## Why a merge is needed at all
///
/// Restoring on a reinstalled device is not a blank slate. Onboarding asks for
/// SMS permission and the first scan re-creates the same transactions from the
/// same messages — freshly parsed, so they carry today's parse verdict and
/// none of the user's decisions. The backup arrives *after* that, finds the
/// row already there, and has to reconcile two versions of one transaction.
///
/// ## The rule
///
/// A restore may only ever ADD BACK the user's own decisions. It must never
/// undo work done on this device since the backup was written, and never
/// re-open a question the user has already answered.
///
/// So every field below is one-directional: the backup fills a gap, or clears
/// a flag the user already cleared, but a blank in the backup never wipes
/// something the local row has.
library;

/// Which columns a restore should write onto an existing transaction row.
class RestoreMerge {
  const RestoreMerge._();

  /// Whether [value] is a string worth restoring (present and not blank).
  static bool _hasText(Object? value) =>
      value is String && value.trim().isNotEmpty;

  /// The column→value updates to apply to [local] from the backed-up [backup]
  /// row, or an empty map when the backup has nothing to add.
  ///
  /// Only genuine CHANGES are emitted — a value the local row already holds is
  /// left out. That keeps the map an honest description of what a restore did,
  /// which the caller counts: restating every field would report a five-figure
  /// "transactions restored" on a backup that changed nothing.
  ///
  /// Both maps are raw `transactions` rows as the database stores them.
  static Map<String, Object?> updatesFor({
    required Map<String, Object?> backup,
    required Map<String, Object?> local,
  }) {
    final out = <String, Object?>{};

    /// Stage [column] unless [local] already holds [value].
    void put(String column, Object? value) {
      if (local[column] != value) out[column] = value;
    }

    // ── The spending tag ──────────────────────────────────────────────
    // The backup is authoritative for a tag it actually has; a blank one
    // never wipes a tag applied on this device since.
    if (_hasText(backup['category'])) {
      put('category', backup['category']);
      put('is_classified', backup['is_classified'] ?? 1);
    }

    // ── The note ──────────────────────────────────────────────────────
    // Restored on its own footing rather than riding along with the tag: a
    // note is user writing, and it used to be dropped whenever the backed-up
    // row happened to carry no category.
    if (_hasText(backup['notes'])) {
      put('notes', backup['notes']);
    }

    // ── The review verdict ────────────────────────────────────────────
    // The bug this class exists for. "Looks right" in Tidy up clears
    // review_reasons to NULL, and that NULL is what the backup carries — but
    // the merge only ever copied the category across, so every confirmed row
    // came back wearing the fresh scan's flags and the whole Needs Review
    // queue reappeared after a restore.
    //
    // One-directional, like everything else here: a cleared backup clears the
    // local flags, and a flagged backup never re-flags a row the user has
    // since confirmed on this device.
    //
    // The judgement call: review_reasons cannot tell "the user confirmed this"
    // from "this parsed cleanly" — both are NULL — so a row that parsed
    // cleanly at backup time also lands confirmed today, even if a newer
    // parser would now flag it. That is the right way round to be wrong. The
    // cost is one skipped question on rows that were already fine; the
    // alternative is asking the user to redo an entire queue they finished.
    if (!_hasText(backup['review_reasons']) &&
        _hasText(local['review_reasons'])) {
      out['review_reasons'] = null;
    }

    // ── The tax section ───────────────────────────────────────────────
    // Same shape as the category, and the same reason: filing a year of
    // premiums into 80C is user work, and losing it silently at restore is
    // exactly the failure the tax screen is supposed to prevent.
    if (_hasText(backup['tax_bucket'])) {
      put('tax_bucket', backup['tax_bucket']);
    }

    // ── The split share ───────────────────────────────────────────────
    // Without this a restored split bill counts its FULL amount as spend
    // again, because split_share is what every total coalesces to.
    final share = backup['split_share'];
    final localShare = local['split_share'];
    if (share is num &&
        (localShare is! num || localShare.toDouble() != share.toDouble())) {
      out['split_share'] = share.toDouble();
    }

    // ── The date, when the user corrected it ──────────────────────────
    // A transaction's date is normally the moment its SMS arrived, and the
    // post-reinstall scan re-derives exactly that from the same message. So
    // the local row's date is the parse date by construction, and the only
    // thing that can make the backup's date differ from it is the user having
    // moved the transaction by hand.
    //
    // That correction is a decision in the same family as the tag, the note
    // and the split share, and without this clause it was the one decision a
    // restore threw away: the row came back on the SMS's date, silently, in
    // whatever month the bank had happened to send the alert.
    //
    // The narrow case this cannot tell apart is a date edited on THIS device
    // between the first scan and the restore — the backup would win there
    // too. It is the same call [category] and [tax_bucket] already make ("the
    // backup is authoritative for a value it actually has"), and the window
    // is the few minutes of a restore flow.
    final backupDate = backup['detected_at'];
    if (backupDate is int && local['detected_at'] != backupDate) {
      out['detected_at'] = backupDate;
    }

    // ── The payee ─────────────────────────────────────────────────────
    // Only fills a gap. A name the user taught is worth restoring, but the
    // local row was parsed by today's reader, which may well name a payee the
    // backup's reader could not — so a real local name always stands.
    if (_hasText(backup['merchant_name']) && !localPayeeIsNamed(local)) {
      put('merchant_name', backup['merchant_name']);
    }

    return out;
  }

  /// Whether [local] already carries a payee worth keeping.
  ///
  /// Deliberately narrow: anything non-blank counts, because the account
  /// number fallback is repaired by its own upgrade pass and re-deciding it
  /// here would put two readers in disagreement about the same row.
  static bool localPayeeIsNamed(Map<String, Object?> local) =>
      _hasText(local['merchant_name']);

  /// Whether a backed-up row must not come back at all, because the user has
  /// since told the app this message shape is not a transaction.
  ///
  /// "Not a transaction" is an answer, and the rule at the top of this file
  /// says a restore may never re-open one. Without this check the answer only
  /// held until the next restore: the mute is stored, the row is deleted, and
  /// then the backup — written while the row still existed — inserts it
  /// straight back into Needs review. Reported on 2026-08-10 by a user whose
  /// ignored BOI mandate-revocation returned after every single restore,
  /// while everything they had merely *approved* stayed clean (an approval
  /// travels inside the row; a mute lives in another table entirely).
  ///
  /// [shapeKey] is the row's `sender_core|signature` pair, and
  /// [mutedShapeKeys] the same for every mute the device knows — both
  /// computed by the caller, which owns the sender-normalising and
  /// signature rules.
  ///
  /// Manual rows are never muted, mirroring `RemovalService.canMute`: a mute
  /// keys off a message shape, and a row typed in by hand has no message to
  /// key off.
  static bool isMutedShape({
    required Map<String, Object?> backup,
    required String? shapeKey,
    required Set<String> mutedShapeKeys,
  }) {
    if (shapeKey == null || mutedShapeKeys.isEmpty) return false;
    if ((backup['is_manual'] as int? ?? 0) == 1) return false;
    if (!_hasText(backup['message'])) return false;
    return mutedShapeKeys.contains(shapeKey);
  }
}
