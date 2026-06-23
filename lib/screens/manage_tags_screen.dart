import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/custom_tag_service.dart';
import '../services/database_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';

/// Settings screen for managing tags: review every category and delete the
/// ones you don't use. Deleting a tag that has tagged transactions warns
/// first and untags those transactions (returns them to "unclassified").
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
      body: _loading
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
                const SizedBox(height: 32),
              ],
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
          borderRadius: BorderRadius.circular(11),
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
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded),
        color: const Color(0xFFD25A5F),
        tooltip: context.l10n.deleteTagTooltip,
        onPressed: () => _deleteTag(tag),
      ),
    );
  }
}
