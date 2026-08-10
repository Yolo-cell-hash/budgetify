import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../models/transaction_rule_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_toast.dart';
import '../widgets/clear_tag_sheet.dart';

/// Every standing "Apply to All" rule, in one place.
///
/// Choosing **Apply to All** on a transaction quietly does two things: it tags
/// the matching transactions you already have, and it writes a rule that keeps
/// tagging the ones that arrive later. The second half had no UI at all — the
/// rules were invisible, could not be paused, and could not be removed, so a
/// tag applied by mistake kept coming back and the only apparent escape was
/// deleting the tag itself.
///
/// This screen makes them visible and reversible: what each rule tags, how
/// many transactions currently carry it, pause, and a delete that offers to
/// clear the tag it already applied.
class AutoTagRulesScreen extends StatefulWidget {
  const AutoTagRulesScreen({super.key});

  @override
  State<AutoTagRulesScreen> createState() => _AutoTagRulesScreenState();
}

class _AutoTagRulesScreenState extends State<AutoTagRulesScreen> {
  final DatabaseService _db = DatabaseService();

  List<TransactionRule> _rules = [];
  final Map<int, int> _counts = {}; // rule id → transactions it governs
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rules = await _db.getAllTransactionRules();
    _counts.clear();
    for (final rule in rules) {
      if (rule.id == null) continue;
      final tagged = await _db.findTaggedByMerchant(
        merchantName: rule.senderName,
        type: rule.transactionType,
        category: rule.category,
      );
      _counts[rule.id!] = tagged.length;
    }
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
  }

  /// Pause / resume a rule. A paused rule stops tagging new transactions but
  /// keeps everything it already tagged — the reversible middle ground
  /// between living with a rule and deleting it.
  Future<void> _toggleActive(TransactionRule rule) async {
    await _db.updateTransactionRule(rule.copyWith(isActive: !rule.isActive));
    await _load();
    if (!mounted) return;
    showAppToast(
      context,
      message: rule.isActive
          ? context.l10nRead.rulePaused(rule.senderName)
          : context.l10nRead.ruleResumed(rule.senderName),
      type: AppToastType.info,
    );
  }

  /// Delete a rule, and offer to clear the tag it already applied.
  ///
  /// These are two different intentions — "stop doing this from now on" and
  /// "that was wrong, take it back" — so the dialog asks rather than guessing,
  /// and the sweep is undoable either way.
  Future<void> _deleteRule(TransactionRule rule) async {
    final count = _counts[rule.id] ?? 0;
    final l10n = context.l10nRead;

    final choice = await showDeleteRuleSheet(
      context,
      payee: rule.senderName,
      tag: l10n.categoryName(rule.category),
      matchCount: count,
    );
    if (choice == null || !mounted) return;

    // Captured before anything is written, so Undo can put back the exact
    // rows and the exact rule.
    final affected = choice == DeleteRuleChoice.clearTags
        ? await _db.findTaggedByMerchant(
            merchantName: rule.senderName,
            type: rule.transactionType,
            category: rule.category,
          )
        : <TransactionModel>[];

    if (rule.id != null) await _db.deleteTransactionRule(rule.id!);
    if (affected.isNotEmpty) await _db.untagTransactions(affected);
    await _load();

    if (!mounted) return;
    showAppToast(
      context,
      message: affected.isEmpty
          ? l10n.ruleDeleted(rule.senderName)
          : l10n.ruleDeletedAndCleared(affected.length, rule.senderName),
      type: AppToastType.success,
      actionLabel: l10n.commonUndo,
      duration: const Duration(seconds: 6),
      onAction: () => _undoDelete(rule, affected),
    );
  }

  /// Put back a deleted rule and everything it had tagged.
  Future<void> _undoDelete(
    TransactionRule rule,
    List<TransactionModel> affected,
  ) async {
    // The row is re-inserted rather than updated: its id died with it.
    await _db.insertTransactionRule(
      TransactionRule(
        senderName: rule.senderName,
        transactionType: rule.transactionType,
        category: rule.category,
        notes: rule.notes,
        isActive: rule.isActive,
        createdAt: rule.createdAt,
      ),
    );
    if (affected.isNotEmpty) await _db.restoreTransactions(affected);
    await _load();
    if (!mounted) return;
    showAppToast(
      context,
      message: context.l10nRead.ruleRestored,
      type: AppToastType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          context.l10n.autoTagRules,
          icon: Icons.rule_folder_rounded,
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    context.l10n.autoTagRulesIntro,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_rules.isEmpty)
                    _buildEmpty(colors)
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            for (var i = 0; i < _rules.length; i++) ...[
                              if (i > 0)
                                Divider(height: 1, color: colors.border),
                              _buildRuleRow(_rules[i], colors),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rule_folder_outlined,
            size: 40,
            color: colors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.noAutoTagRules,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.noAutoTagRulesDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(TransactionRule rule, AppColors colors) {
    final count = _counts[rule.id] ?? 0;
    final tagColor = ExpenseCategories.getColor(rule.category);
    final paused = !rule.isActive;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tagColor.withValues(alpha: paused ? 0.06 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: tagColor.withValues(alpha: paused ? 0.12 : 0.22),
          ),
        ),
        child: Center(
          child: Text(
            ExpenseCategories.getIcon(rule.category),
            style: TextStyle(fontSize: 17, color: paused ? colors.textTertiary : null),
          ),
        ),
      ),
      title: Text(
        rule.senderName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: paused ? colors.textTertiary : colors.text,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          context.l10n.ruleMeta(
            context.l10n.categoryName(rule.category),
            rule.transactionType == TransactionType.debit,
            count,
            paused,
          ),
          style: TextStyle(fontSize: 12, color: colors.textTertiary),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 20,
            ),
            color: colors.textSecondary,
            tooltip: paused
                ? context.l10n.resumeRuleTooltip
                : context.l10n.pauseRuleTooltip,
            onPressed: () => _toggleActive(rule),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: const Color(0xFFD25A5F),
            tooltip: context.l10n.deleteRuleTooltip,
            onPressed: () => _deleteRule(rule),
          ),
        ],
      ),
    );
  }
}
