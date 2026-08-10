import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/database_service.dart';
import '../services/removal_service.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/removal_choice_dialog.dart';
import '../widgets/tidy_up_receipt.dart';

/// "Tidy up": work through the rows the parser was unsure about, one at a time.
///
/// The flags, the per-reason explanations and the three corrections all existed
/// already — but they were reachable only by opening a row, finding the amber
/// banner, and knowing what the overflow menu contained. Batching them into one
/// deliberate session makes correcting the parser a task a user can finish,
/// with an end state, instead of an open-ended chore they never start.
///
/// Deliberately not wired into streaks: finishing is rewarded (the royal
/// approves, the queue empties), neglecting it costs nothing. A correction
/// prompt that punishes you for ignoring it is a nag, and sentiment is the one
/// thing worth protecting here.
class TidyUpScreen extends StatefulWidget {
  const TidyUpScreen({super.key});

  @override
  State<TidyUpScreen> createState() => _TidyUpScreenState();
}

class _TidyUpScreenState extends State<TidyUpScreen> {
  final DatabaseService _db = DatabaseService();

  List<TransactionModel> _queue = [];
  int _index = 0;
  int _handled = 0;
  bool _loading = true;
  bool _changed = false;

  /// What the last tap did, kept until the next one replaces it. Shown above
  /// the entry now on screen and undoable from there — the answer to "did that
  /// register, and was it this one or the one before?", which two identical
  /// ₹100 credits back to back made impossible to tell.
  _LastAction? _last;

  /// Brief "brought back" acknowledgement, so undo gets the same courtesy the
  /// actions do. Cleared as soon as the next answer replaces it.
  bool _undoNotice = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final queue = await _db.getNeedsReviewTransactions();
    if (!mounted) return;
    setState(() {
      _queue = queue;
      _index = 0;
      _handled = 0;
      _loading = false;
    });
  }

  TransactionModel? get _current =>
      _index < _queue.length ? _queue[_index] : null;

  void _advance(_LastAction done) {
    setState(() {
      _handled++;
      _index++;
      _last = done;
      _undoNotice = false;
    });
  }

  Future<void> _looksRight() async {
    final t = _current;
    if (t?.id == null) return;
    await _db.confirmTransactionReview(t!.id!);
    _changed = true;
    _advance(_LastAction(kind: _ActionKind.confirmed, transaction: t));
  }

  Future<void> _flipDirection() async {
    final t = _current;
    if (t == null) return;
    await _db.flipTransactionType(
      t,
      t.type == TransactionType.debit
          ? TransactionType.credit
          : TransactionType.debit,
    );
    _changed = true;
    requestRoyalReaction(RoyalReaction.taught);
    _advance(_LastAction(kind: _ActionKind.flipped, transaction: t));
  }

  Future<void> _remove() async {
    final t = _current;
    if (t == null) return;
    final choice = await showRemovalChoiceDialog(
      context,
      sender: t.merchantName?.trim().isNotEmpty == true
          ? t.merchantName!
          : t.sender,
      canMute: RemovalService.canMute(t),
    );
    if (choice == null || !mounted) return;
    final receipt = await RemovalService.instance.remove([t], choice);
    _changed = true;
    _advance(_LastAction(
      kind: _ActionKind.removed,
      transaction: t,
      receipt: receipt,
    ));
  }

  /// Put the last answer back and return to that entry, so a mis-tap costs one
  /// tap to fix instead of a hunt through the transaction list afterwards.
  Future<void> _undoLast() async {
    final last = _last;
    if (last == null) return;
    final t = last.transaction;

    switch (last.kind) {
      case _ActionKind.confirmed:
        if (t.id != null) {
          await _db.restoreTransactionReview(t.id!, t.reviewReasons);
        }
      case _ActionKind.flipped:
        await _db.undoTypeFlip(t);
      case _ActionKind.removed:
        final receipt = last.receipt;
        if (receipt == null || !receipt.isRestorable) return;
        await RemovalService.instance.undo(receipt);
    }
    // Read the row back rather than trusting the copy held here: undo has just
    // rewritten it, and a restored removal is re-inserted. It keeps its id —
    // the table is AUTOINCREMENT, so nothing can have taken it — but the
    // database is the authority, not this screen.
    final restored = t.id == null ? null : await _db.getTransactionById(t.id!);
    if (!mounted) return;
    if (restored == null) {
      // The row didn't come back where it was expected. Rebuilding the queue
      // from scratch is always right, and beats showing a card whose buttons
      // would quietly act on nothing.
      setState(() {
        _last = null;
        _undoNotice = true;
      });
      await _load();
      return;
    }
    setState(() {
      // Step back onto the entry that was just answered, holding whatever the
      // database says it is now.
      if (_index > 0) _index--;
      if (_handled > 0) _handled--;
      _queue[_index] = restored;
      _last = null;
      _undoNotice = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: Text(l10n.tidyUp)),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _current == null
                  ? _buildAllSet(colors, l10n)
                  : Column(
                      children: [
                        _buildProgress(colors, l10n),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildReceipt(colors, l10n),
                                // Keyed by row id, so answering one entry
                                // visibly swaps in a different card instead of
                                // silently redrawing the same rectangle.
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0.06, 0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  ),
                                  child: KeyedSubtree(
                                    key: ValueKey(_current!.id ??
                                        _current!.detectedAt
                                            .millisecondsSinceEpoch),
                                    child: _buildCard(colors, l10n, _current!),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  /// A bar that visibly moves on every answer, with the count beside it. The
  /// old screen carried the same numbers as plain text in the app bar, where a
  /// tap changed "2 of 12" to "3 of 12" and nothing else on screen moved.
  Widget _buildProgress(AppColors colors, AppStrings l10n) {
    final total = _queue.length;
    final left = total - _handled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.tidyUpTagline,
                  style:
                      TextStyle(fontSize: 13.5, color: colors.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.tidyUpProgress(_handled, total),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedProgressBar(
            value: total == 0 ? 0 : _handled / total,
            color: colors.success,
            backgroundColor: colors.cardAlt,
            height: 5,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.tidyUpLeft(left),
            style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }

  /// What the last tap did, named against the entry it happened to, with an
  /// Undo. This is the acknowledgement the screen never gave: without it, two
  /// identical amounts in a row make it impossible to tell a registered answer
  /// from an ignored one.
  Widget _buildReceipt(AppColors colors, AppStrings l10n) {
    final last = _last;
    final showing = last != null || _undoNotice;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !showing
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _undoNotice
                  ? TidyUpReceipt(
                      accent: colors.textSecondary,
                      icon: Icons.undo_rounded,
                      label: l10n.tidyUpUndone,
                      undoLabel: l10n.commonUndo,
                    )
                  : TidyUpReceipt(
                      undoLabel: l10n.commonUndo,
                      accent: switch (last!.kind) {
                        _ActionKind.confirmed => colors.success,
                        _ActionKind.flipped => colors.accent,
                        _ActionKind.removed => colors.warning,
                      },
                      icon: switch (last.kind) {
                        _ActionKind.confirmed => Icons.check_rounded,
                        _ActionKind.flipped => Icons.swap_vert_rounded,
                        _ActionKind.removed => Icons.playlist_remove_rounded,
                      },
                      label: switch (last.kind) {
                        _ActionKind.confirmed => l10n.tidyUpDidConfirm,
                        _ActionKind.flipped => l10n.tidyUpDidFlip,
                        _ActionKind.removed => l10n.tidyUpDidRemove,
                      },
                      // Names the entry it happened to, not just the verb.
                      detail: _identity(last.transaction),
                      onUndo: last.kind == _ActionKind.removed &&
                              !(last.receipt?.isRestorable ?? false)
                          ? null
                          : _undoLast,
                    ),
            ),
    );
  }

  /// One line that identifies an entry: amount, who, and the time it landed.
  /// The time is what separates two ₹100 credits from the same sender.
  String _identity(TransactionModel t) {
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final who = t.merchantName?.trim().isNotEmpty == true
        ? t.merchantName!.trim()
        : t.sender;
    final sign = t.type == TransactionType.credit ? '+' : '-';
    return '$sign${money.format(t.amount)} · $who · '
        '${DateFormat('d MMM, h:mm a').format(t.detectedAt)}';
  }

  /// The finish line. Reaching it is the reward — the queue is empty, the royal
  /// approves, and nothing here scolds the user for how long it took.
  Widget _buildAllSet(AppColors colors, AppStrings l10n) {
    final nothingToDo = _handled == 0;
    if (!nothingToDo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        requestRoyalReaction(RoyalReaction.cheer);
      });
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 44, color: colors.success),
            ),
            const SizedBox(height: 22),
            Text(
              l10n.tidyUpAllSet,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.tidyUpAllSetBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _changed),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l10n.commonDone,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(AppColors colors, AppStrings l10n, TransactionModel t) {
    final isCredit = t.type == TransactionType.credit;
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final typeColor = isCredit ? colors.success : colors.danger;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The amount leads, with the direction spelled out beside it —
                // direction is the thing most often wrong, and the thing the
                // middle button changes.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PrivacyAmount(
                          '${isCredit ? '+' : '-'} ${money.format(t.amount)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCredit ? l10n.commonIncome : l10n.commonExpenses,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  t.merchantName?.trim().isNotEmpty == true
                      ? t.merchantName!
                      : t.sender,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                // Promoted from tertiary fine print: when two entries carry the
                // same amount from the same sender, this is the only thing that
                // tells them apart.
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 12, color: colors.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      DateFormat('EEE, d MMM yyyy · h:mm a')
                          .format(t.detectedAt),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Why this row is here at all — the same reasons the detail
                // screen's banner lists, so the two never disagree.
                ...t.reviewReasonList.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.help_outline,
                            size: 14, color: colors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _reasonText(l10n, r),
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    t.message,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Three plain buttons, no gestures to discover: the whole point of
          // this screen is that every correction is visible.
          _action(
            colors,
            icon: Icons.check_rounded,
            label: l10n.looksRight,
            accent: colors.success,
            filled: true,
            onTap: _looksRight,
          ),
          const SizedBox(height: 10),
          _action(
            colors,
            icon: Icons.swap_vert_rounded,
            label: isCredit ? l10n.changeToDebit : l10n.changeToCredit,
            accent: colors.accent,
            filled: false,
            onTap: _flipDirection,
          ),
          const SizedBox(height: 10),
          _action(
            colors,
            icon: Icons.playlist_remove_rounded,
            label: l10n.notATransaction,
            accent: colors.warning,
            filled: false,
            onTap: _remove,
          ),
        ],
    );
  }

  Widget _action(
    AppColors colors, {
    required IconData icon,
    required String label,
    required Color accent,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label, textAlign: TextAlign.center),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label, textAlign: TextAlign.center),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: accent.withValues(alpha: 0.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
    );
  }

  String _reasonText(AppStrings l10n, String reason) => switch (reason) {
        ReviewReasons.unknownSender => l10n.reviewReasonUnknownSender,
        ReviewReasons.payeeUnknown => l10n.reviewReasonPayeeUnknown,
        ReviewReasons.directionUncertain => l10n.reviewReasonDirection,
        ReviewReasons.amountUncertain => l10n.reviewReasonAmount,
        _ => reason,
      };
}

enum _ActionKind { confirmed, flipped, removed }

/// The answer just given, kept so the screen can name it and take it back.
/// [transaction] is the row *as it was before* the answer, which is exactly
/// what each undo needs to restore.
class _LastAction {
  final _ActionKind kind;
  final TransactionModel transaction;

  /// Only for [_ActionKind.removed] — RemovalService's own undo contract.
  final RemovalReceipt? receipt;

  const _LastAction({
    required this.kind,
    required this.transaction,
    this.receipt,
  });
}
