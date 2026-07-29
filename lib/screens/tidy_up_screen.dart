import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/database_service.dart';
import '../services/removal_service.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/removal_choice_dialog.dart';

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

  void _advance() {
    setState(() {
      _handled++;
      _index++;
    });
  }

  Future<void> _looksRight() async {
    final t = _current;
    if (t?.id == null) return;
    await _db.confirmTransactionReview(t!.id!);
    _changed = true;
    _advance();
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
    _advance();
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
    await RemovalService.instance.remove([t], choice);
    _changed = true;
    _advance();
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
        appBar: AppBar(
          title: Text(l10n.tidyUp),
          actions: [
            if (!_loading && _queue.isNotEmpty && _current != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    l10n.tidyUpProgress(_handled, _queue.length),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _current == null
                  ? _buildAllSet(colors, l10n)
                  : _buildCard(colors, l10n, _current!),
        ),
      ),
    );
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tidyUpTagline,
            style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.merchantName?.trim().isNotEmpty == true
                            ? t.merchantName!
                            : t.sender,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: PrivacyAmount(
                          '${isCredit ? '+' : '-'} ${money.format(t.amount)}',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('MMM d, h:mm a').format(t.detectedAt),
                  style: TextStyle(fontSize: 12.5, color: colors.textTertiary),
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
      ),
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
