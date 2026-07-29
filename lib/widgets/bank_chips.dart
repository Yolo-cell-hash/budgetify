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

/// How the strip presents itself.
enum BankChipStyle {
  /// Dashboard: a card per bank, its name over what the month spent through
  /// it. Reads as content, sized to sit under the balance card.
  card,

  /// Transactions list: a compact single-line pill per bank, sized to work as
  /// a filter row above a list.
  pill,
}

/// A horizontally scrolling strip of the banks the period's money moved
/// through, and what was spent from each one.
///
/// Two jobs, one widget: read-only on Home ([BankChipStyle.card], where a tap
/// drills into that bank's transactions) and a quick filter on the
/// transactions list ([BankChipStyle.pill], where [selectedId] highlights the
/// active bank and [onSelectAll] adds the leading "All" pill that clears it).
class BankChips extends StatelessWidget {
  final BankBreakdown breakdown;

  /// The highlighted bank, when the strip is acting as a filter.
  final String? selectedId;

  /// Tapping a bank.
  final void Function(BankActivity bank)? onSelect;

  /// When set, a leading "All" pill appears and calls this — filter mode.
  final VoidCallback? onSelectAll;

  final BankChipStyle style;

  const BankChips({
    super.key,
    required this.breakdown,
    this.selectedId,
    this.onSelect,
    this.onSelectAll,
    this.style = BankChipStyle.pill,
  });

  static final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return const SizedBox.shrink();

    return switch (style) {
      BankChipStyle.card => _buildCards(context),
      BankChipStyle.pill => _buildPills(context),
    };
  }

  /// The cards divide the row between them: same width each, same gap
  /// between each pair, and the strip's outer edges line up with the balance
  /// card above it. Most people bank with two or three, which fit, so this is
  /// what the strip normally looks like.
  ///
  /// Past that it scrolls, and the cards keep their equal width while a
  /// quarter of the next one shows at the edge — that sliver is the only
  /// thing saying there is more, now there is no trailing "See all" pill to
  /// say it in words.
  ///
  /// Height comes from the content rather than a fixed box, so a long bank
  /// name at a large system text size grows the strip instead of overflowing
  /// it.
  Widget _buildCards(BuildContext context) {
    const gap = 10.0;
    const padding = 16.0;
    // Under this a card can't hold a bank name and an amount without
    // ellipsing the name down to nothing.
    const minCard = 150.0;
    final banks = breakdown.banks;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - padding * 2;
        // How many cards fit at a width that can still be read.
        final perView =
            ((available + gap) / (minCard + gap)).floor().clamp(1, 4);

        // Every card as tall as the tallest, so the row reads as one strip
        // whatever each bank's name and amount need.
        if (banks.length <= perView) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: padding),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, bank) in banks.indexed) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(child: _card(context, bank)),
                  ],
                ],
              ),
            ),
          );
        }

        final width = (available - gap * perView) / (perView + 0.25);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: padding),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, bank) in banks.indexed) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(width: width, child: _card(context, bank)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPills(BuildContext context) {
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
        ],
      ),
    );
  }

  /// One bank's card, unsized — how wide it is belongs to the strip, which is
  /// the only thing that knows how many have to share the row.
  Widget _card(BuildContext context, BankActivity bank) {
    final colors = AppColors.of(context);
    final accent = CustomTagService.colorFromName(bank.id);
    const radius = BorderRadius.all(Radius.circular(16));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: radius,
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelect == null ? null : () => onSelect!(bank),
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        bankDisplayLabel(context, bank),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                PrivacyAmount(
                  _fmt.format(bank.spent),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required bool selected,
    required Color accent,
    String? amount,
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
