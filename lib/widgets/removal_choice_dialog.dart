import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import 'app_dialog.dart';

/// What the user chose to do with a row they are removing.
enum TransactionRemoval {
  /// Remove it *and* mute the message shape, so no future message from this
  /// sender matching the same template is ever logged again.
  notATransaction,

  /// Remove just this row. A similar message can still log later.
  deleteOnly,
}

/// The removal fork.
///
/// Deleting an SMS-derived row only tombstones that one message: a promo
/// template returns next month with a new amount and a new fingerprint, so the
/// user deletes it again, and again, and concludes the app is broken. Muting the
/// *shape* is the only thing that ends it — and it used to live behind an
/// app-bar overflow menu two screens away, where nobody found it.
///
/// So it is offered here instead: at the exact moment the user has already
/// decided to remove something. Each option states its consequence, because the
/// difference between them is the entire point.
///
/// Returns null if the user backed out. Manual rows (nothing re-creates them)
/// and rows with no message to key a mute on skip the fork and get a plain
/// confirmation, resolving to [TransactionRemoval.deleteOnly].
Future<TransactionRemoval?> showRemovalChoiceDialog(
  BuildContext context, {
  required String sender,
  required bool canMute,
  int count = 1,
}) {
  final l10n = context.l10nRead;
  final colors = AppColors.of(context);
  final title =
      count > 1 ? l10n.removeNEntriesTitle(count) : l10n.removeEntryTitle;

  if (!canMute) {
    return showAppDialog<TransactionRemoval>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        accent: colors.danger,
        title: title,
        subtitle: ctx.l10nRead.deleteTransactionConfirm,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10nRead.commonCancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, TransactionRemoval.deleteOnly),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(ctx.l10nRead.commonDelete),
          ),
        ],
      ),
    );
  }

  return showAppDialog<TransactionRemoval>(
    context,
    builder: (ctx) {
      final l = ctx.l10nRead;
      return AppDialog(
        icon: Icons.help_outline_rounded,
        accent: colors.warning,
        title: title,
        subtitle: l.removeEntryQuestion,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Listed first and accented: it is the option that actually solves
            // the user's problem, so it should not read as the risky one.
            _RemovalOption(
              icon: Icons.playlist_remove_rounded,
              accent: colors.warning,
              emphasised: true,
              title: l.notATransaction,
              body: count > 1
                  ? l.notATransactionNBody(count)
                  : l.notATransactionOptionBody(sender),
              onTap: () =>
                  Navigator.pop(ctx, TransactionRemoval.notATransaction),
            ),
            const SizedBox(height: 10),
            _RemovalOption(
              icon: Icons.delete_outline_rounded,
              accent: colors.danger,
              emphasised: false,
              title: l.justRemoveThisOne,
              body: l.justRemoveThisOneBody,
              onTap: () => Navigator.pop(ctx, TransactionRemoval.deleteOnly),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
        ],
      );
    },
  );
}

/// One tappable choice: icon, label, and the consequence of picking it.
class _RemovalOption extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final bool emphasised;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _RemovalOption({
    required this.icon,
    required this.accent,
    required this.emphasised,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      child: Material(
        color: emphasised
            ? accent.withValues(alpha: 0.10)
            : colors.cardAlt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: emphasised
                    ? accent.withValues(alpha: 0.38)
                    : colors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: colors.textSecondary,
                        ),
                      ),
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
}
