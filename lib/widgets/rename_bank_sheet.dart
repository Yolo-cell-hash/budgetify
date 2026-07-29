import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/bank_summary.dart';
import '../services/bank_alias_service.dart';
import '../services/bank_directory.dart';
import 'app_toast.dart';

/// "Call this bank something else" bottom sheet.
///
/// Only the label changes: the transactions stay wired to the sender header
/// they came from, so nothing moves between rows and a future SMS from the
/// same bank still lands here. Clearing the field restores the detected name,
/// so there is always a way back.
///
/// Resolves true when the name changed, false/null when the user backed out.
Future<bool?> showRenameBankSheet(
  BuildContext context,
  BankActivity bank,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final identity = bank.bank;
  final controller = TextEditingController(text: bank.name);

  final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;
  final subtextColor =
      isDark ? const Color(0xFF9A9DA6) : const Color(0xFF6E727C);
  final inputBg = isDark ? const Color(0xFF262931) : const Color(0xFFFAFAF8);

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      Future<void> save(String value) async {
        await BankAliasService().setAlias(identity.id, value);
        if (!ctx.mounted) return;
        Navigator.pop(ctx, true);
      }

      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ctx.l10n.renameBank,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ctx.l10n.renameBankHint(identity.defaultName),
              style: TextStyle(fontSize: 12.5, height: 1.4, color: subtextColor),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: save,
              maxLength: 40,
              decoration: InputDecoration(
                hintText: identity.defaultName,
                filled: true,
                fillColor: inputBg,
                counterText: '',
                prefixIcon: Icon(Icons.account_balance_outlined,
                    size: 20, color: subtextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: textColor),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (identity.isRenamed)
                  TextButton(
                    onPressed: () async {
                      await BankAliasService().clearAlias(identity.id);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx, true);
                    },
                    child: Text(ctx.l10n.resetToDetectedName),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.l10n.commonCancel),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => save(controller.text),
                  child: Text(ctx.l10n.commonSave),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Opens the rename sheet and reports the outcome, so every call site gives
/// the same feedback.
Future<bool> renameBankAndReport(
  BuildContext context,
  BankActivity bank,
) async {
  final changed = await showRenameBankSheet(context, bank);
  if (changed != true || !context.mounted) return false;
  final now = BankDirectory.forId(bank.id, bank.bank.defaultName);
  showAppToast(
    context,
    message: context.l10nRead.bankRenamedTo(now),
    type: AppToastType.success,
  );
  return true;
}
