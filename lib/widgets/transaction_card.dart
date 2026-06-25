import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import 'app_dialog.dart';
import 'category_icon.dart';
import 'privacy_amount.dart';

/// Card widget to display a transaction item with enhanced UI.
///
/// Swipe-to-delete is made discoverable in two ways, both themed via
/// [AppColors] so they track all four app themes:
///  1. A **progressive delete reveal** — as you drag the card left, a rounded
///     danger-coloured panel slides out with a "Delete" label and a trash chip
///     that scales and firms up as you cross the dismiss threshold (with a
///     haptic tick), so the gesture reads as intentional, not accidental.
///  2. A **one-time hint** — the first card briefly peeks open on first view
///     ([animateSwipeHint]) to teach the gesture, then springs back and never
///     repeats (the owner persists that it has been shown).
class TransactionCard extends StatefulWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// When true, this card plays a one-time "peek" on first build to reveal the
  /// swipe-to-delete affordance, then calls [onSwipeHintShown]. The owner is
  /// responsible for only setting this on the first row, once ever.
  final bool animateSwipeHint;
  final VoidCallback? onSwipeHintShown;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
    this.animateSwipeHint = false,
    this.onSwipeHintShown,
  });

  @override
  State<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<TransactionCard>
    with SingleTickerProviderStateMixin {
  // How far (px) the card slides during the one-time discoverability hint —
  // enough to clearly reveal the "Delete" affordance without dismissing.
  static const double _hintPeek = 84;

  late final AnimationController _hintCtrl;
  late final Animation<double> _hint;

  // Live drag state, driven by Dismissible.onUpdate, used to animate the
  // reveal panel (label fade + chip scale + icon firming up at threshold).
  double _dragProgress = 0;
  bool _dragReached = false;

  @override
  void initState() {
    super.initState();
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    // Peek out, hold briefly, then settle back — a gentle "this swipes" nudge.
    _hint = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 34,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 16),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_hintCtrl);

    if (widget.animateSwipeHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Let the list settle before nudging.
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        await _hintCtrl.forward();
        widget.onSwipeHintShown?.call();
      });
    }
  }

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(widget.transaction.id?.toString() ?? widget.transaction.message),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.4},
      background: _deleteReveal(progress: _dragProgress, reached: _dragReached),
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          HapticFeedback.selectionClick();
        }
        setState(() {
          _dragProgress = details.progress;
          _dragReached = details.reached;
        });
      },
      confirmDismiss: (direction) async {
        return await showAppDialog<bool>(
              context,
              builder: (context) => AppDialog(
                icon: Icons.delete_outline_rounded,
                accent: AppColors.of(context).danger,
                title: context.l10nRead.deleteTransactionTitle,
                subtitle: context.l10nRead.deleteTransactionConfirm,
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10nRead.commonCancel),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.of(context).danger,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(context.l10nRead.commonDelete),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => widget.onDelete?.call(),
      // The one-time hint peeks the card open over its own copy of the reveal
      // panel; real drags use Dismissible's [background] instead (the hint is
      // idle by then), so the two never paint at once.
      child: AnimatedBuilder(
        animation: _hint,
        builder: (context, child) {
          final h = _hint.value;
          return Stack(
            children: [
              if (h > 0.001)
                Positioned.fill(
                  child: _deleteReveal(progress: h, reached: false),
                ),
              Transform.translate(
                offset: Offset(-h * _hintPeek, 0),
                child: child,
              ),
            ],
          );
        },
        child: _cardBody(context),
      ),
    );
  }

  /// The rounded danger panel revealed under the card as it slides left.
  /// Sized/inset to match the card so it reads as a single premium reveal,
  /// and themed via [AppColors] so it adapts to all four themes.
  Widget _deleteReveal({required double progress, required bool reached}) {
    final danger = AppColors.of(context).danger;
    final p = progress.clamp(0.0, 1.0);
    // Label fades in once the user has clearly committed to the gesture; the
    // chip grows and the icon switches to a filled trash at the threshold.
    final labelOpacity = ((p - 0.12) / 0.26).clamp(0.0, 1.0);
    final chipScale = 0.82 + 0.26 * Curves.easeOut.transform(p);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.only(right: 18),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: danger,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Opacity(
            opacity: labelOpacity,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                context.l10n.commonDelete,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          Transform.scale(
            scale: chipScale,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                reached ? Icons.delete_rounded : Icons.delete_outline_rounded,
                color: danger,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCredit = widget.transaction.type == TransactionType.credit;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormatter = DateFormat('MMM d, h:mm a');
    final typeColor = isCredit ? const Color(0xFF2AA76F) : const Color(0xFFD25A5F);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262931) : const Color(0xFFE9E9E4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Type indicator with icon
                TransactionLeadingIcon(transaction: widget.transaction, size: 48),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Transaction type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.l10n
                                  .txnTypeName(isCredit)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: typeColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (!widget.transaction.isClassified) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF1E0),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFEED3A4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.pending_outlined,
                                    size: 10,
                                    color: Color(0xFFB57A22),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    context.l10n.unclassified,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFFB57A22),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Category chip with icon
                      if (widget.transaction.category != null) ...[
                        _buildCategoryChip(
                            context, widget.transaction.category!),
                        const SizedBox(height: 4),
                      ] else
                        Text(
                          widget.transaction.sender,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFD5D5CF)
                                : const Color(0xFF2E313A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormatter.format(widget.transaction.detectedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A8D96),
                        ),
                      ),
                      if (widget.transaction.splitShare != null) ...[
                        const SizedBox(height: 5),
                        _buildSplitChip(context),
                      ],
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PrivacyAmount(
                      '${isCredit ? '+' : '-'} ${formatter.format(widget.transaction.amount)}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                    if (widget.transaction.accountInfo != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2E313A)
                              : const Color(0xFFF6F6F3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.transaction.accountInfo!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFF9A9DA6)
                                : const Color(0xFF6E727C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Small "÷ your share ₹X" chip shown when only part of this transaction
  /// counts toward the user's spending. Themed via [AppColors] (4 themes).
  Widget _buildSplitChip(BuildContext context) {
    final colors = AppColors.of(context);
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.call_split_rounded, size: 10, color: colors.accent),
          const SizedBox(width: 4),
          Text(
            context.l10n.cardYourShare(
                fmt.format(widget.transaction.effectiveAmount)),
            style: TextStyle(
              fontSize: 10.5,
              color: colors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, String category) {
    final color = ExpenseCategories.getColor(category);
    final icon = ExpenseCategories.getIcon(category);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                context.l10n.categoryName(category),
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
