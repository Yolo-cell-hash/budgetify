import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// The strip above the entry now on screen in Tidy up, naming the answer you
/// just gave and offering to take it back.
///
/// Tidy up used to acknowledge nothing: a tap swapped one card for another and
/// the count in the app bar ticked over. With two ₹100 credits back to back
/// there was no way to tell a registered answer from an ignored tap, or which
/// of the two you had actually answered — so this names the entry, not just
/// the verb.
///
/// Pure presentation, so the layout can be exercised in every language without
/// a database behind it.
class TidyUpReceipt extends StatelessWidget {
  /// Colour of the answer: green for kept, gold for corrected, amber for
  /// removed.
  final Color accent;
  final IconData icon;

  /// What was done — "Kept as it was", "Direction corrected", "Removed".
  final String label;

  /// Which entry it was done to: amount, payee and the time it landed. Null
  /// for the "brought back" acknowledgement, where the entry is on screen.
  final String? detail;

  final String undoLabel;

  /// Null when there is nothing to undo, which hides the button.
  final VoidCallback? onUndo;

  const TidyUpReceipt({
    super.key,
    required this.accent,
    required this.icon,
    required this.label,
    required this.undoLabel,
    this.detail,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onUndo != null)
            TextButton(
              onPressed: onUndo,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(undoLabel, maxLines: 1),
            ),
        ],
      ),
    );
  }
}
