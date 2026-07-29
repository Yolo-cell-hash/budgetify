import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/bank_summary.dart';
import '../providers/theme_provider.dart';
import '../services/bank_directory.dart';
import '../services/custom_tag_service.dart';
import 'privacy_amount.dart';

/// What a bank reads as in the UI.
///
/// Bank names are proper nouns and stay as they are — "HDFC Bank" is "HDFC
/// Bank" in every language — so only the buckets that aren't a named bank
/// get translated copy.
///
/// A sender we couldn't put a name to keeps its raw header, because that is
/// the only identifying thing we have, but is tagged so it doesn't sit in
/// the list passing itself off as a bank called "JUPITR". The header leads,
/// so an ellipsis in a narrow pill eats the tag rather than the identity.
///
/// Uses `l10nRead`: this is called from sheet builders and callbacks as well
/// as from `build`, and `watch` throws outside a build.
String bankDisplayLabel(BuildContext context, BankActivity bank) {
  // A name the user chose stands on its own: no "Imported ·" prefix, and
  // certainly no "Unknown bank" tag on something they have just named.
  if (bank.bank.isRenamed) return bank.name;

  return switch (bank.bank.kind) {
    BankKind.manual => context.l10nRead.manualEntryBank,
    BankKind.imported => '${context.l10nRead.importedBank} · ${bank.name}',
    BankKind.unknown => bank.bank.isUnnamed
        ? context.l10nRead.unknownBank
        : '${bank.name} · ${context.l10nRead.unknownBank}',
    BankKind.bank => bank.name,
  };
}

/// A horizontally scrolling strip of small bank pills — each one a bank and
/// what was spent from it in the period.
///
/// Two jobs, one widget: read-only on Home (tap drills into that bank's
/// transactions) and as a quick filter on the transactions list, where
/// [selectedId] highlights the active bank and [onSelectAll] adds the
/// leading "All" pill that clears it.
class BankChips extends StatelessWidget {
  final BankBreakdown breakdown;

  /// The highlighted bank, when the strip is acting as a filter.
  final String? selectedId;

  /// Tapping a bank pill.
  final void Function(BankActivity bank)? onSelect;

  /// When set, a leading "All" pill appears and calls this — filter mode.
  final VoidCallback? onSelectAll;

  /// When set, a trailing "See all" pill appears and calls this.
  final VoidCallback? onSeeAll;

  const BankChips({
    super.key,
    required this.breakdown,
    this.selectedId,
    this.onSelect,
    this.onSelectAll,
    this.onSeeAll,
  });

  static final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return const SizedBox.shrink();
    final colors = AppColors.of(context);

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (onSelectAll != null) ...[
            _pill(
              context,
              label: context.l10n.filterAll,
              selected: selectedId == null,
              accent: colors.textSecondary,
              onTap: onSelectAll!,
            ),
            const SizedBox(width: 8),
          ],
          for (final bank in breakdown.banks) ...[
            _pill(
              context,
              label: bankDisplayLabel(context, bank),
              amount: _fmt.format(bank.spent),
              selected: selectedId == bank.id,
              accent: CustomTagService.colorFromName(bank.id),
              onTap: onSelect == null ? null : () => onSelect!(bank),
            ),
            const SizedBox(width: 8),
          ],
          if (onSeeAll != null)
            _pill(
              context,
              label: context.l10n.seeAllLower,
              selected: false,
              accent: colors.brandAccent,
              trailingIcon: Icons.chevron_right,
              onTap: onSeeAll!,
            ),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required bool selected,
    required Color accent,
    String? amount,
    IconData? trailingIcon,
    VoidCallback? onTap,
  }) {
    final colors = AppColors.of(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.16) : colors.cardAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? accent : colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (amount != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          ConstrainedBox(
            // Long co-operative bank names would otherwise push the amount
            // off the pill.
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? accent : colors.text,
              ),
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 7),
            PrivacyAmount(
              amount,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
          if (trailingIcon != null)
            Icon(trailingIcon, size: 15, color: accent),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: content,
    );
  }
}
