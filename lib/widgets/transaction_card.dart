import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/removal_service.dart';
import 'category_icon.dart';
import 'privacy_amount.dart';
import 'removal_choice_dialog.dart';

/// Card widget to display a transaction item with enhanced UI.
///
/// Swipe-to-remove is made discoverable in two ways, both themed via
/// [AppColors] so they track every app theme:
///  1. A **progressive reveal** — as you drag the card left, a rounded
///     danger-coloured panel slides out with a "Delete" label and a trash chip
///     that scales and firms up as you cross the dismiss threshold (with a
///     haptic tick), so the gesture reads as intentional, not accidental.
///  2. A **one-time hint** — the first card briefly peeks open on first view
///     ([animateSwipeHint]) to teach the gesture, then springs back and never
///     repeats (the owner persists that it has been shown).
///
/// The gesture completes in the *removal fork* (see [showRemovalChoiceDialog]),
/// not a bare delete confirmation: all that effort spent teaching this swipe was
/// previously funnelling users into a dead end that re-logs the same promo next
/// month, while the correction that actually fixes it sat behind an overflow
/// menu on another screen. Long-press ([onLongPress]) is the non-gesture
/// alternative, for selection mode and for accessibility.
class TransactionCard extends StatefulWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  /// Called after the user confirms removal, with the choice they made in the
  /// removal fork — a plain delete, or "not a transaction" (which also mutes
  /// the message shape). The owner performs the removal so it can offer Undo.
  final void Function(TransactionRemoval choice)? onRemove;

  /// Long-press. The non-gesture route into selection mode, and the
  /// accessibility-visible alternative to swiping.
  final VoidCallback? onLongPress;

  /// Selection-mode state. When [selectable] is true a tap toggles selection
  /// instead of opening the row, and swipe-to-remove is suppressed.
  final bool selectable;
  final bool selected;

  /// When true, this card plays a one-time "peek" on first build to reveal the
  /// swipe-to-delete affordance, then calls [onSwipeHintShown]. The owner is
  /// responsible for only setting this on the first row, once ever.
  final bool animateSwipeHint;
  final VoidCallback? onSwipeHintShown;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onRemove,
    this.onLongPress,
    this.selectable = false,
    this.selected = false,
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

  /// Swipe and the accessibility "remove" action share this, so the fork is
  /// never bypassed by either route.
  Future<bool> _askAndRemove() async {
    final choice = await showRemovalChoiceDialog(
      context,
      sender: widget.transaction.merchantName?.trim().isNotEmpty == true
          ? widget.transaction.merchantName!
          : widget.transaction.sender,
      canMute: RemovalService.canMute(widget.transaction),
    );
    if (choice == null) return false;
    widget.onRemove?.call(choice);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // In selection mode the row is a checkbox target, so swiping it away would
    // fight the gesture the user is actually making.
    if (widget.selectable || widget.onRemove == null) {
      return _semantic(child: _cardBody(context));
    }

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
      // The fork, not a bare delete confirmation: this is the one moment we know
      // the user wants the row gone, which makes it the right place to offer the
      // mute that stops the whole template.
      confirmDismiss: (_) => _askAndRemove(),
      // onRemove already fired from _askAndRemove, so the owner has begun the
      // removal by the time the card animates out.
      onDismissed: (_) {},
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
        child: _semantic(child: _cardBody(context)),
      ),
    );
  }

  /// Announces the row as one sentence a screen reader can actually use
  /// ("Paid 1,250 rupees to Swiggy, Food, 3 July") instead of the raw glyph
  /// soup of badges and separate Text nodes, and exposes removal as a real
  /// accessibility action — swipe alone was unreachable with TalkBack on.
  Widget _semantic({required Widget child}) {
    final t = widget.transaction;
    final l10n = context.l10n;
    final isCredit = t.type == TransactionType.credit;
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(t.amount);

    final parts = <String>[
      '${l10n.txnTypeName(isCredit)} $money',
      if (t.merchantName != null && t.merchantName!.trim().isNotEmpty)
        t.merchantName!
      else
        t.sender,
      if (t.category != null) l10n.categoryName(t.category!),
      if (!t.isClassified) l10n.unclassified,
      if (t.needsReview) l10n.needsReviewBadge,
      DateFormat('MMM d').format(t.detectedAt),
    ];

    return Semantics(
      container: true,
      button: widget.onTap != null,
      selected: widget.selectable ? widget.selected : null,
      label: parts.join(', '),
      customSemanticsActions: widget.onRemove == null || widget.selectable
          ? null
          : {
              CustomSemanticsAction(label: l10n.commonDelete): () {
                _askAndRemove();
              },
            },
      child: ExcludeSemantics(child: child),
    );
  }

  /// The rounded danger panel revealed under the card as it slides left.
  /// Sized/inset to match the card so it reads as a single premium reveal,
  /// and themed via [AppColors] so it adapts to every theme.
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
                size: 20,
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

    final colors = AppColors.of(context);
    final isSelected = widget.selectable && widget.selected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? Color.alphaBlend(
                colors.accent.withValues(alpha: 0.10),
                isDark ? const Color(0xFF16181E) : Colors.white,
              )
            : isDark
                ? const Color(0xFF16181E)
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.55)
              : isDark
                  ? const Color(0xFF262931)
                  : const Color(0xFFE9E9E4),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // In selection mode the leading art gives way to a tick, so the
                // row's state is unmistakable at a glance.
                if (widget.selectable) ...[
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 26,
                    color: isSelected ? colors.accent : colors.textTertiary,
                  ),
                  const SizedBox(width: 14),
                ] else ...[
                  TransactionLeadingIcon(
                      transaction: widget.transaction, size: 48),
                  const SizedBox(width: 14),
                ],

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wrap, not Row: three badges plus a long amount used to
                      // overflow the bounded width and silently clip whichever
                      // came last — which was "Check", the one badge that
                      // invites the user into the correction flow. Wrapping to
                      // a second line keeps every badge visible on narrow
                      // phones, in long-script languages, and at large text
                      // scales.
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Transaction type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
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
                          // Not tagged yet — a pending user action, so it wears
                          // the brand gold rather than the warning amber.
                          if (!widget.transaction.isClassified)
                            _attentionBadge(
                              context,
                              icon: Icons.pending_outlined,
                              label: context.l10n.unclassified,
                              color: AppColors.of(context).brandAccent,
                            ),
                          // The parser guessed something in this message —
                          // one tap on the detail screen confirms or fixes.
                          if (widget.transaction.needsReview)
                            _attentionBadge(
                              context,
                              icon: Icons.help_outline,
                              label: context.l10n.needsReviewBadge,
                              color: AppColors.of(context).warning,
                            ),
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

                // Amount. Deliberately NOT Flexible: a Flexible defaults to
                // flex 1, which makes the Row split the free space evenly with
                // the details column, and since the amount only uses its
                // intrinsic width the unused half collapses into dead space on
                // the right of every card. Left non-flexible, this column takes
                // exactly the width it needs and Expanded above absorbs the
                // rest — the original layout.
                //
                // The capped width is what keeps a lakh-scale amount at a large
                // accessibility text scale from pushing past the card: the cap
                // bounds the FittedBox, which then scales the figure down
                // instead of clipping it. Below the cap nothing changes.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: PrivacyAmount(
                          '${isCredit ? '+' : '-'} ${formatter.format(widget.transaction.amount)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: typeColor,
                          ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A small state chip ("Unclassified", "Check"). Tinted from a single theme
  /// colour so it sits correctly on every variant's card — these used to be
  /// opaque light-mode creams that painted unchanged on the dark themes.
  Widget _attentionBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          // Degrades by ellipsis rather than clipping: at the extremes (a long
          // Indic label on a 360dp phone at a large text scale) the chip may
          // not get its full intrinsic width, and losing a tail is far better
          // than throwing away the whole badge.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small "÷ your share ₹X" chip shown when only part of this transaction
  /// counts toward the user's spending. Themed via [AppColors] (all variants).
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

    // Aligned left and allowed to shrink: a long localised category name (or a
    // long custom tag) used to overflow this chip's inner Row and clip.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                context.l10n.categoryName(category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
