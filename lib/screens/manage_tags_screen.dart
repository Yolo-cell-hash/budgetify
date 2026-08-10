import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../models/transaction_rule_model.dart';
import '../providers/theme_provider.dart';
import '../services/custom_tag_service.dart';
import '../services/database_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/create_tag_sheet.dart';

/// What the per-tag overflow menu can do.
enum _TagAction { clear, delete }

/// Settings screen for managing tags: review every category, empty the ones
/// whose transactions you want back, and delete the ones you don't use.
/// Deleting a tag that has tagged transactions warns first and untags those
/// transactions (returns them to "unclassified").
class ManageTagsScreen extends StatefulWidget {
  const ManageTagsScreen({super.key});

  @override
  State<ManageTagsScreen> createState() => _ManageTagsScreenState();
}

class _ManageTagsScreenState extends State<ManageTagsScreen> {
  final DatabaseService _db = DatabaseService();
  final CustomTagService _tags = CustomTagService();

  List<String> _categories = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final categories = ExpenseCategories.allCategories;
    final counts = <String, int>{};
    for (final c in categories) {
      counts[c] = await _db.countTransactionsWithCategory(c);
    }
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _counts = counts;
      _loading = false;
    });
  }

  Future<void> _deleteTag(String tag) async {
    final count = _counts[tag] ?? 0;
    final isCustom = _tags.isCustomTag(tag);

    final confirmed = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.label_off_rounded,
        accent: const Color(0xFFD25A5F),
        title: context.l10nRead.deleteTagTitle(tag),
        subtitle: count > 0
            ? context.l10nRead.deleteTagWithCount(count, tag)
            : isCustom
                ? context.l10nRead.deleteCustomTagDesc
                : context.l10nRead.deleteBuiltinTagDesc,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10nRead.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD25A5F),
              foregroundColor: Colors.white,
            ),
            child: Text(count > 0
                ? context.l10nRead.untagAndDelete
                : context.l10nRead.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (count > 0) await _db.untagCategory(tag);
    // Rules outlive the tag they write. Left behind, an "Apply to All" rule
    // keeps stamping a deleted tag back onto every new transaction from that
    // payee — the tag is gone from the pickers but never gone from the data.
    await _db.deleteRulesForCategory(tag);
    await _tags.deleteTag(tag);
    await _load();
    if (mounted) {
      showAppToast(
        context,
        message: count > 0
            ? context.l10nRead.deletedTagWithCount(count, tag)
            : context.l10nRead.deletedTag(tag),
        type: AppToastType.success,
      );
    }
  }

  /// Take a tag off every transaction carrying it — and keep the tag.
  ///
  /// The screen used to offer only "delete", so a user who wanted their
  /// transactions back out of "Groceries" had to destroy the tag to get
  /// there. These are different intentions and now they're different
  /// actions: this one empties the tag, delete removes it.
  Future<void> _clearTagFromAll(String tag) async {
    final l10n = context.l10nRead;
    final rows = await _db.getFilteredTransactions(category: tag);
    if (rows.isEmpty || !mounted) return;
    final rules = await _db.getRulesForCategory(tag);
    if (!mounted) return;

    final confirmed = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.layers_clear_rounded,
        accent: const Color(0xFFC94A50),
        title: l10n.clearTagFromAllTitle(l10n.categoryName(tag)),
        subtitle: l10n.clearTagFromAllDesc(
          rows.length,
          rules.length,
          l10n.categoryName(tag),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC94A50),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.clearTagAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _db.untagTransactions(rows);
    // Clearing without removing the rules would undo itself: the next
    // transaction from those payees arrives already tagged again.
    if (rules.isNotEmpty) await _db.deleteRulesForCategory(tag);
    await _load();
    if (!mounted) return;

    showAppToast(
      context,
      message: l10n.clearedTagFromAll(rows.length, l10n.categoryName(tag)),
      type: AppToastType.success,
      actionLabel: l10n.commonUndo,
      duration: const Duration(seconds: 6),
      onAction: () => _undoClearAll(rows, rules),
    );
  }

  Future<void> _undoClearAll(
    List<TransactionModel> rows,
    List<TransactionRule> rules,
  ) async {
    await _db.restoreTransactions(rows);
    for (final rule in rules) {
      // Re-inserted rather than updated: each row's id died with it.
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
    }
    await _load();
    if (!mounted) return;
    showAppToast(context,
        message: context.l10nRead.tagRestored, type: AppToastType.info);
  }

  /// Create a tag from the management screen itself. Managing tags means
  /// adding as well as deleting, and the alternative was opening a transaction
  /// just to reach the "+ New Tag" chip. Same sheet as that chip, so a tag made
  /// here is identical to one made there.
  Future<void> _newTag() async {
    final created = await showCreateTagSheet(context);
    if (created == null) return;
    await _load();
    if (mounted) {
      showAppToast(context,
          message: context.l10nRead.createdTag(created),
          type: AppToastType.success);
    }
  }

  Future<void> _restore(String tag) async {
    await _tags.restoreTag(tag);
    await _load();
    if (mounted) {
      showAppToast(context,
          message: context.l10nRead.restoredTag(tag), type: AppToastType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hidden = _tags.hiddenPredefined;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.manageTags, icon: Icons.sell_rounded),
      ),
      // Matches how every other list screen offers its "add" (goals, splits,
      // transactions), and stays reachable once the tag list is scrolled.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTag,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.newTag),
      ),
      body: SafeArea(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.l10n.manageTagsIntro,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  colors,
                  children: [
                    for (var i = 0; i < _categories.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: colors.border),
                      _buildTagRow(_categories[i], colors),
                    ],
                  ],
                ),
                if (hidden.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.hiddenTags,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCard(
                    colors,
                    children: [
                      for (var i = 0; i < hidden.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: colors.border),
                        ListTile(
                          leading: Text(
                            ExpenseCategories.getIcon(hidden[i]),
                            style: const TextStyle(fontSize: 20),
                          ),
                          title: Text(context.l10n.categoryName(hidden[i])),
                          trailing: TextButton(
                            onPressed: () => _restore(hidden[i]),
                            child: Text(context.l10n.restore),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                // Clears the extended FAB so the last tag stays tappable.
                const SizedBox(height: 96),
              ],
            ),
      ),
    );
  }

  Widget _buildCard(AppColors colors, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildTagRow(String tag, AppColors colors) {
    final count = _counts[tag] ?? 0;
    final isCustom = _tags.isCustomTag(tag);
    final color = ExpenseCategories.getColor(tag);

    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Center(
          child: Text(
            ExpenseCategories.getIcon(tag),
            style: const TextStyle(fontSize: 17),
          ),
        ),
      ),
      title: Text(
        context.l10n.categoryName(tag),
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: colors.text,
        ),
      ),
      subtitle: Text(
        context.l10n.tagMeta(isCustom, count),
        style: TextStyle(fontSize: 12, color: colors.textTertiary),
      ),
      // Two distinct intentions behind one row: "take this tag off my
      // transactions" and "I never want to see this tag again". A menu keeps
      // both one tap away without the destructive one being the only one.
      trailing: PopupMenuButton<_TagAction>(
        icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
        color: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tooltip: context.l10n.tagActionsTooltip,
        onSelected: (action) {
          switch (action) {
            case _TagAction.clear:
              _clearTagFromAll(tag);
            case _TagAction.delete:
              _deleteTag(tag);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _TagAction.clear,
            enabled: count > 0,
            child: Row(
              children: [
                Icon(
                  Icons.layers_clear_rounded,
                  size: 20,
                  color: count > 0 ? colors.accent : colors.textTertiary,
                ),
                const SizedBox(width: 12),
                Flexible(child: Text(context.l10n.clearFromTransactions(count))),
              ],
            ),
          ),
          PopupMenuItem(
            value: _TagAction.delete,
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Color(0xFFD25A5F),
                ),
                const SizedBox(width: 12),
                Text(context.l10n.deleteTagTooltip),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
