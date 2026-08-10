import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';

/// How far a "clear this tag" gesture should reach.
///
/// Deliberately the mirror image of the three options the apply sheet offers
/// after a tag is saved (Apply to All / Apply to All Existing / Only this
/// one). Tagging can reach ten transactions and every future one in a single
/// tap; if clearing could only ever reach one, the only way back was to
/// delete the tag outright — which is what users were resorting to.
enum ClearTagScope {
  /// Clear the tag from this transaction alone. The auto-tag rule, if any,
  /// stays — so the next message from this payee is tagged again.
  onlyThis,

  /// Clear the tag from every transaction from this payee that carries it.
  /// The rule stays, so future ones are still tagged.
  allFromPayee,

  /// Clear every one AND delete the auto-tag rule — the true undo of
  /// "Apply to All". Only offered when such a rule actually exists.
  allAndStopRule,
}

/// Bottom sheet asking how far to clear a tag.
///
/// Resolves to the chosen scope, or null if the user backed out. The caller
/// does the work: this sheet only states the consequences, with real counts,
/// so nothing destructive is ever a surprise.
///
/// Shared by the transaction detail screen and Settings → Auto-tag rules, so
/// clearing behaves identically wherever it's reached from.
Future<ClearTagScope?> showClearTagSheet(
  BuildContext context, {
  required String tag,
  required String payee,
  required int matchCount,
  required bool hasRule,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;
  final subtextColor =
      isDark ? const Color(0xFF9A9DA6) : const Color(0xFF6E727C);

  return showModalBottomSheet<ClearTagScope>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final l10n = ctx.l10nRead;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9A9DA6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.clearTagTitle(l10n.categoryName(tag)),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.clearTagSubtitle(payee),
                style: TextStyle(color: subtextColor, height: 1.35),
              ),
              const SizedBox(height: 22),
              _ClearOption(
                icon: Icons.touch_app_outlined,
                title: l10n.clearOnlyThis,
                subtitle: l10n.clearOnlyThisDesc,
                color: const Color(0xFF4A6489),
                isDark: isDark,
                onTap: () => Navigator.pop(ctx, ClearTagScope.onlyThis),
              ),
              // Only worth offering when there is more than this one row to
              // reach — otherwise the two options do the same thing.
              if (matchCount > 1) ...[
                const SizedBox(height: 12),
                _ClearOption(
                  icon: Icons.history_rounded,
                  title: l10n.clearAllFromPayee,
                  subtitle: l10n.clearAllFromPayeeDesc(matchCount, payee),
                  color: const Color(0xFFD79A3C),
                  isDark: isDark,
                  onTap: () => Navigator.pop(ctx, ClearTagScope.allFromPayee),
                ),
              ],
              // The exact undo of "Apply to All" — shown only when that rule
              // is really there, so the sheet never promises to stop
              // something that isn't happening.
              if (hasRule) ...[
                const SizedBox(height: 12),
                _ClearOption(
                  icon: Icons.rule_folder_outlined,
                  title: l10n.clearAllAndStopRule,
                  subtitle: l10n.clearAllAndStopRuleDesc(matchCount, payee),
                  color: const Color(0xFFC94A50),
                  isDark: isDark,
                  onTap: () => Navigator.pop(ctx, ClearTagScope.allAndStopRule),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.undo_rounded, size: 14, color: subtextColor),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      l10n.clearTagUndoHint,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: subtextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// What deleting an auto-tag rule should do to the transactions it already
/// tagged.
enum DeleteRuleChoice {
  /// Stop tagging from now on; leave the past tags in place.
  keepTags,

  /// Take it all back — delete the rule and clear the tag it applied.
  clearTags,
}

/// Bottom sheet for deleting an auto-tag rule.
///
/// "Stop doing this from now on" and "that was wrong, take it back" are two
/// different intentions and the app cannot tell them apart, so it asks
/// instead of guessing. A sheet rather than a dialog because three
/// side-by-side dialog buttons don't survive a long-script language.
Future<DeleteRuleChoice?> showDeleteRuleSheet(
  BuildContext context, {
  required String payee,
  required String tag,
  required int matchCount,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;
  final subtextColor =
      isDark ? const Color(0xFF9A9DA6) : const Color(0xFF6E727C);

  return showModalBottomSheet<DeleteRuleChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final l10n = ctx.l10nRead;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9A9DA6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.deleteRuleTitle(payee),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.deleteRuleSubtitle(payee, tag),
                style: TextStyle(color: subtextColor, height: 1.35),
              ),
              const SizedBox(height: 22),
              _ClearOption(
                icon: Icons.pause_circle_outline_rounded,
                title: l10n.deleteRuleKeepTags,
                subtitle: l10n.deleteRuleKeepTagsDesc,
                color: const Color(0xFF4A6489),
                isDark: isDark,
                onTap: () => Navigator.pop(ctx, DeleteRuleChoice.keepTags),
              ),
              if (matchCount > 0) ...[
                const SizedBox(height: 12),
                _ClearOption(
                  icon: Icons.layers_clear_rounded,
                  title: l10n.deleteRuleAndClear,
                  subtitle: l10n.deleteRuleAndClearDesc(matchCount, tag),
                  color: const Color(0xFFC94A50),
                  isDark: isDark,
                  onTap: () => Navigator.pop(ctx, DeleteRuleChoice.clearTags),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.undo_rounded, size: 14, color: subtextColor),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      l10n.clearTagUndoHint,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: subtextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One tappable scope row. Same shape as the apply-options rows so the two
/// sheets read as a matched pair.
class _ClearOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ClearOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg =
        isDark ? const Color(0xFF262931) : const Color(0xFFFAFAF8);
    final textColor = isDark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF4E525C) : const Color(0xFFE9E9E4),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: isDark
                          ? const Color(0xFF9A9DA6)
                          : const Color(0xFF6E727C),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A9DA6)),
          ],
        ),
      ),
    );
  }
}

/// The banner shown on a transaction whose tag came from an auto-tag rule
/// rather than from the user tagging this row. Explains why a tag appeared
/// on its own — the missing half of "Apply to All" — and offers the way out.
class AutoTaggedNotice extends StatelessWidget {
  final String payee;
  final VoidCallback onManage;

  const AutoTaggedNotice({
    super.key,
    required this.payee,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.autoTaggedByRule(payee),
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onManage,
            style: TextButton.styleFrom(
              foregroundColor: colors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              l10n.manageRule,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
