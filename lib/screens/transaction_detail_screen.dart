import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/ledger_models.dart';
import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import '../models/transaction_rule_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/custom_tag_service.dart';
import '../services/ledger_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_toast.dart';
import '../widgets/recurring_editor_sheet.dart';
import '../widgets/settlement_sheet.dart';
import '../widgets/split_transaction_sheet.dart';

/// Screen for viewing and classifying a transaction
class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  late TransactionModel _transaction;
  String? _selectedCategory;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  // Set when a split/settlement is added/edited/removed here, so the back
  // navigation signals the transactions list to refresh.
  bool _changed = false;
  // Tier-3 proactive suggestion: does this incoming credit look like a known
  // person settling a debt? Computed once on open for unclassified credits.
  SettlementSuggestion? _settleSuggestion;

  // Guided-tour anchors: the category chips card and the Save button.
  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _selectedCategory = _transaction.category;
    _notesController.text = _transaction.notes ?? '';
    _maybeSuggestSettlement();
    // Guided tour: opening any detail completes the "open it up" step; the
    // in-screen tips (choose a tag → save it) take over from here.
    TutorialService.instance.advanceFrom(TutorialStep.openTransaction);
    TutorialService.instance.addListener(_onTutorialTick);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowTutorialTip());
  }

  void _onTutorialTick() {
    if (mounted) _maybeShowTutorialTip();
  }

  /// The guided tour inside this screen: first point at the category chips
  /// (the tap passes through), then — once a tag is picked — at Save.
  void _maybeShowTutorialTip() {
    if (!mounted) return;
    final svc = TutorialService.instance;
    final l10n = context.l10nRead;
    if (svc.isAt(TutorialStep.chooseTag)) {
      TutorialTips.show(
        context,
        step: TutorialStep.chooseTag,
        anchor: _categoryKey,
        title: l10n.tutChooseTagTitle,
        message: l10n.tutChooseTagBody,
      );
    } else if (svc.isAt(TutorialStep.saveTag)) {
      TutorialTips.show(
        context,
        step: TutorialStep.saveTag,
        anchor: _saveKey,
        title: l10n.tutSaveTagTitle,
        message: l10n.tutSaveTagBody,
      );
    }
  }

  /// Check (once) whether an incoming, not-yet-settled credit matches an
  /// outstanding ledger debt, to offer the "mark as settlement" nudge.
  Future<void> _maybeSuggestSettlement() async {
    if (_transaction.type != TransactionType.credit) return;
    if (_transaction.category == 'Settlement') return;
    final s = await LedgerService().suggestSettlement(_transaction.amount);
    if (mounted && s.looksLikeSettlement) {
      setState(() => _settleSuggestion = s);
    }
  }

  @override
  void dispose() {
    TutorialService.instance.removeListener(_onTutorialTick);
    TutorialTips.dismissIfFor(TutorialStep.chooseTag);
    TutorialTips.dismissIfFor(TutorialStep.saveTag);
    _notesController.dispose();
    super.dispose();
  }

  /// Display name for the merchant/payee used in dialogs
  String get _merchantDisplayName {
    return _transaction.merchantName ?? _transaction.sender;
  }

  /// Open the split sheet for this transaction, then refresh the row so the
  /// headline + split card reflect the new share immediately.
  Future<void> _openSplit() async {
    final changed =
        await showSplitTransactionSheet(context, transaction: _transaction);
    if (!changed) return;
    _changed = true;
    if (_transaction.id != null) {
      final fresh = await _dbService.getTransactionById(_transaction.id!);
      if (fresh != null && mounted) {
        setState(() => _transaction = fresh);
      }
    }
  }

  /// Open the settlement sheet for this transaction, then refresh the row.
  Future<void> _openSettlement({String? suggested}) async {
    final changed = await showSettlementSheet(
      context,
      transaction: _transaction,
      suggestedPerson: suggested,
    );
    if (!changed) return;
    _changed = true;
    if (_transaction.id != null) {
      final fresh = await _dbService.getTransactionById(_transaction.id!);
      if (fresh != null && mounted) {
        setState(() {
          _transaction = fresh;
          _selectedCategory = fresh.category;
          _settleSuggestion = null; // resolved; hide the nudge
        });
      }
    }
  }

  Future<void> _saveClassification() async {
    if (_transaction.id == null) return;

    // Guided tour: pressing Save completes its step; the apply-options sheet
    // that follows carries the tour's explainer banner.
    TutorialService.instance.advanceFrom(TutorialStep.saveTag);

    setState(() => _isSaving = true);

    try {
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      if (_selectedCategory == null) {
        // Un-tag: clear the category and put it back in the
        // unclassified queue
        final untagged = _transaction.untagged().copyWith(notes: notes);
        await _dbService.updateTransaction(untagged);
        if (mounted) {
          showAppToast(context,
              message: context.l10nRead.tagRemoved, type: AppToastType.info);
          Navigator.pop(context, true);
        }
        return;
      }

      final updatedTransaction = _transaction.copyWith(
        category: _selectedCategory,
        notes: notes,
        isClassified: true,
      );

      await _dbService.updateTransaction(updatedTransaction);

      if (mounted) {
        // Show bulk flagging options dialog
        await _showBulkFlaggingDialog();
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: context.l10nRead.errorSaving(e), type: AppToastType.error);
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _showBulkFlaggingDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFF9A9DA6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10nRead.applyToSimilarTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10nRead.foundTxnsForMerchant(_merchantDisplayName),
              style: TextStyle(
                color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
              ),
            ),
            // Guided tour: a one-time explainer for how far a tag can reach —
            // the three options below each describe their own behavior.
            if (TutorialService.instance.isAt(TutorialStep.applyOptions)) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(isDark ? 0.12 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withOpacity(0.45)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10nRead.tutApplyBody,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildOption(
              ctx,
              icon: Icons.select_all,
              title: context.l10nRead.applyToAll,
              subtitle: context.l10nRead.applyToAllDesc,
              value: 1,
              color: Color(0xFF2AA76F),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildOption(
              ctx,
              icon: Icons.history,
              title: context.l10nRead.applyToExisting,
              subtitle: context.l10nRead.applyToExistingDesc,
              value: 2,
              color: Color(0xFFD79A3C),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildOption(
              ctx,
              icon: Icons.touch_app,
              title: context.l10nRead.onlyThisOne,
              subtitle: context.l10nRead.onlyThisOneDesc,
              value: 3,
              color: Color(0xFF4A6489),
              isDark: isDark,
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );

    // Guided tour: the options sheet has been seen (chosen or dismissed).
    // The tour continues on Home, so after the save settles we pop the whole
    // way back there in one motion instead of stranding the user on the list.
    final wasTourClassification =
        TutorialService.instance.isAt(TutorialStep.applyOptions);
    final navigator = Navigator.of(context);
    TutorialService.instance.advanceFrom(TutorialStep.applyOptions);

    if (result != null && mounted) {
      await _processBulkFlagging(result);
    } else if (mounted) {
      // User dismissed the dialog — transaction was already saved above,
      // so pop with true to signal the calling screen to refresh.
      Navigator.pop(context, true);
    }

    if (wasTourClassification) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  Widget _buildOption(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int value,
    required Color color,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF262931) : Color(0xFFFAFAF8);
    final textColor = isDark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: () => Navigator.pop(ctx, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Color(0xFF4E525C) : Color(0xFFE9E9E4),
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
                      color: isDark
                          ? Color(0xFF9A9DA6)
                          : Color(0xFF6E727C),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFF9A9DA6)),
          ],
        ),
      ),
    );
  }

  Future<void> _processBulkFlagging(int option) async {
    final merchantName = _transaction.merchantName;
    final transactionType = _transaction.type;
    final category = _selectedCategory!;
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    final l10n = context.l10nRead;
    String message = l10n.txnSaved;

    try {
      if (option == 1 || option == 2) {
        // Step 1: Backfill merchant names for any transactions that don't have them
        // This re-parses ALL stored SMS bodies to extract merchant/payee
        await _dbService.backfillMerchantNames();

        if (merchantName != null && merchantName.isNotEmpty) {
          // Step 2: Bulk update existing transactions matching this merchant + type
          final updatedCount = await _dbService.bulkUpdateByMerchant(
            merchantName: merchantName,
            transactionType: transactionType,
            category: category,
            notes: notes,
          );
          message = l10n.updatedSimilarTxns(
              updatedCount, transactionType == TransactionType.debit);
        } else {
          message = l10n.txnSavedNoMerchant;
        }
      }

      if (option == 1) {
        // Create/update rule for future auto-classification
        if (merchantName != null && merchantName.isNotEmpty) {
          final existingRule = await _dbService.findExistingRule(
            merchantName,
            transactionType,
          );
          if (existingRule != null) {
            // Update existing rule
            final updatedRule = existingRule.copyWith(
              category: category,
              notes: notes,
              isActive: true,
            );
            await _dbService.updateTransactionRule(updatedRule);
          } else {
            // Create new rule for future transactions using the MERCHANT name
            final rule = TransactionRule(
              senderName: merchantName, // Stores merchant, not bank sender
              transactionType: transactionType,
              category: category,
              notes: notes,
              isActive: true,
            );
            await _dbService.insertTransactionRule(rule);
          }
          message += l10n.futureTxnsAutoClassified(
              transactionType == TransactionType.debit, _merchantDisplayName);
        }
      }
      // Option 2: Just bulk update, no rule for future (already handled above)
      // Option 3: Only this one transaction (no bulk update, no rule)

      if (mounted) {
        showAppToast(context, message: message, type: AppToastType.success);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: context.l10nRead.errorGeneric(e),
            type: AppToastType.error);
        Navigator.pop(context, true);
      }
    }
  }

  static const List<String> _emojiChoices = [
    '🏠', '🎮', '💊', '🎁', '🐾', '🍕', '🏋️', '📱', '☕', '🎵',
    '💇', '🧹', '🚕', '🎓', '👶', '💍', '🏦', '⛽', '🅿️', '📦',
    '🛒', '🍿', '🏥', '✂️', '🧾', '💻', '📸', '🎂', '🌐', '🔧',
  ];

  /// Long-press on a category chip: pick a custom emoji for that tag
  /// (works for predefined categories and custom tags alike).
  Future<void> _showEmojiPickerForTag(String category, bool isDark) async {
    final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10nRead.emojiForTag(context.l10nRead.categoryName(category)),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _emojiChoices.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.pop(ctx, _emojiChoices[i]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF262931)
                          : const Color(0xFFF6F6F3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _emojiChoices[i],
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );

    if (chosen != null) {
      await CustomTagService().setTagEmoji(category, chosen);
      if (mounted) setState(() {});
    }
  }

  Future<void> _showCreateTagDialog(bool isDark) async {
    final nameController = TextEditingController();
    String selectedEmoji = '🏷️';

    const emojis = _emojiChoices;

    final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C);
    final inputBg = isDark ? const Color(0xFF262931) : Color(0xFFFAFAF8);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Color(0xFF9A9DA6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.l10nRead.createCustomTag,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10nRead.createTagDesc,
                    style: TextStyle(color: subtextColor),
                  ),
                  const SizedBox(height: 20),
                  // Tag name input
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: context.l10nRead.tagNameHint,
                      hintStyle: TextStyle(color: subtextColor),
                      filled: true,
                      fillColor: inputBg,
                      prefixIcon: Container(
                        width: 48,
                        alignment: Alignment.center,
                        child: Text(
                          selectedEmoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Emoji picker grid
                  Text(
                    context.l10nRead.pickAnEmoji,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: emojis.length,
                      itemBuilder: (_, i) {
                        final emoji = emojis[i];
                        final isSelected = emoji == selectedEmoji;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() => selectedEmoji = emoji);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(0xFF4A6489).withAlpha(40)
                                  : (isDark
                                        ? const Color(0xFF262931)
                                        : Color(0xFFF6F6F3)),
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(
                                      color: Color(0xFF8FA9C7),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Create button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final l10n = context.l10nRead;
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          showAppToast(context,
                              message: l10n.enterTagName,
                              type: AppToastType.warning);
                          return;
                        }
                        final success = await CustomTagService().addCustomTag(
                          name,
                          selectedEmoji,
                        );
                        if (!success) {
                          if (context.mounted) {
                            showAppToast(context,
                                message: l10n.tagExists,
                                type: AppToastType.warning);
                          }
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {
                          _selectedCategory = name;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4A6489),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        context.l10nRead.createTag,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCredit = _transaction.type == TransactionType.credit;
    final colors = AppColors.of(context);
    // A debit with a share override is "split": the headline shows the user's
    // own share (what counts toward budgets), with the full amount struck out.
    final isSplit = _transaction.splitShare != null;
    final isSettlement = _transaction.category == 'Settlement';
    final headlineAmount = _transaction.effectiveAmount;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormatter = DateFormat('EEEE, MMMM d, y • h:mm a');

    final bgColor = isDark ? const Color(0xFF0A0B0E) : Color(0xFFF6F6F3);
    final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C);
    final chipBgUnselected = isDark
        ? const Color(0xFF262931)
        : Color(0xFFFAFAF8);
    final chipBorderUnselected = isDark
        ? const Color(0xFF3D4758)
        : Color(0xFFE9E9E4);
    final inputBgColor = isDark ? const Color(0xFF262931) : Color(0xFFFAFAF8);
    final messageBgColor = isDark
        ? const Color(0xFF121318)
        : Color(0xFFFAFAF8);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: AppBarTitle(context.l10n.transactionDetailsTitle,
            icon: Icons.receipt_long_rounded),
        backgroundColor: cardColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SafeArea(child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCredit
                          ? Color(0xFF2AA76F).withAlpha(26)
                          : Color(0xFFD25A5F).withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isCredit ? Color(0xFF2AA76F) : Color(0xFFD25A5F),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${isCredit ? '+' : '-'} ${formatter.format(headlineAmount)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Color(0xFF2AA76F) : Color(0xFFD25A5F),
                    ),
                  ),
                  if (isSplit) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatter.format(_transaction.amount),
                      style: TextStyle(
                        fontSize: 15,
                        color: subtextColor,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: subtextColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCredit
                              ? Color(0xFF2AA76F).withAlpha(26)
                              : Color(0xFFD25A5F).withAlpha(26),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          context.l10n.txnTypeName(isCredit),
                          style: TextStyle(
                            color: isCredit
                                ? Color(0xFF2AA76F)
                                : Color(0xFFD25A5F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isSplit) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: colors.accent.withValues(alpha: 0.30)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.call_split_rounded,
                                  size: 13, color: colors.accent),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.splitBadgeLabel,
                                style: TextStyle(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isSettlement) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: colors.accent.withValues(alpha: 0.30)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.handshake_rounded,
                                  size: 13, color: colors.accent),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.settlementBadge,
                                style: TextStyle(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateFormatter.format(_transaction.detectedAt),
                    style: TextStyle(fontSize: 13, color: subtextColor),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tier-3 nudge: this incoming credit looks like a known repayment.
            if (_settleSuggestion != null) ...[
              _buildSettlementSuggestion(colors),
              const SizedBox(height: 16),
            ],

            // Details section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.detailsLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    context.l10n.fromLabel,
                    _transaction.sender,
                    subtextColor,
                    textColor,
                  ),
                  // The counterparty row is always labelled "Payee" — a
                  // credit/debit-dependent label read inconsistent in testing.
                  // The pencil teaches a payee alias: SMS-derived names (VPAs,
                  // account numbers) are often unrecognisable, so one rename
                  // here fixes matching rows and every future SMS parse.
                  if (_transaction.merchantName != null)
                    _buildDetailRow(
                      context.l10n.payeeLabel,
                      _transaction.merchantName!,
                      subtextColor,
                      textColor,
                      onEdit: _transaction.isManual
                          ? null
                          : () => _showRenamePayeeSheet(isDark),
                    ),
                  if (_transaction.accountInfo != null)
                    _buildDetailRow(
                      context.l10n.accountLabel,
                      _transaction.accountInfo!,
                      subtextColor,
                      textColor,
                    ),
                  Divider(
                    height: 24,
                    color: isDark ? Color(0xFF4E525C) : null,
                  ),
                  Text(
                    context.l10n.originalMessage,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: messageBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _transaction.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Split section — debits only, and not when this is a settlement.
            if (!isCredit && !isSettlement) ...[
              _buildSplitCard(colors, isSplit, formatter),
              const SizedBox(height: 16),
              _buildTrackRecurringCard(colors),
              const SizedBox(height: 16),
            ],

            // Settlement section — a repayment that shouldn't count as
            // income/spend (shown for both directions; primary case is credits).
            _buildSettlementCard(colors, isSettlement),
            const SizedBox(height: 16),

            // Category section
            Container(
              key: _categoryKey, // guided-tour anchor
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        context.l10n.category,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (!_transaction.isClassified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFD79A3C).withAlpha(26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.l10n.unclassified,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD79A3C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...ExpenseCategories.categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = isSelected ? null : category;
                            });
                            if (!isSelected) {
                              // Guided tour: a tag was picked — point at
                              // Save next.
                              TutorialService.instance
                                  .advanceFrom(TutorialStep.chooseTag);
                            }
                          },
                          onLongPress: () =>
                              _showEmojiPickerForTag(category, isDark),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                        ? Color(0xFF2A3B52).withAlpha(150)
                                        : Color(0xFFEDF2F8))
                                  : chipBgUnselected,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? Color(0xFF8FA9C7)
                                    : chipBorderUnselected,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ExpenseCategories.getIcon(category),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  context.l10n.categoryName(category),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? (isDark
                                              ? Color(0xFFAFC2D9)
                                              : Color(0xFF3E5577))
                                        : (isDark
                                              ? Color(0xFFD5D5CF)
                                              : Color(0xFF4E525C)),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      // Create new tag button
                      GestureDetector(
                        onTap: () => _showCreateTagDialog(isDark),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Color(0xFF6E727C)
                                  : Color(0xFF9A9DA6),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 16,
                                color: isDark
                                    ? Color(0xFF9A9DA6)
                                    : Color(0xFF6E727C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.newTag,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Color(0xFF9A9DA6)
                                      : Color(0xFF6E727C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notes section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.notesLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: context.l10n.addNotesHint,
                      hintStyle: TextStyle(color: subtextColor),
                      filled: true,
                      fillColor: inputBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save button — also handles un-tagging when the user
            // deselects the current category
            Padding(
              key: _saveKey, // guided-tour anchor
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: (_isSaving ||
                        (_selectedCategory == null &&
                            _transaction.category == null))
                    ? null
                    : _saveClassification,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedCategory == null && _transaction.category != null
                          ? const Color(0xFFC94A50)
                          : Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: isDark
                      ? Color(0xFF2E313A)
                      : Color(0xFFD5D5CF),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        _selectedCategory == null &&
                                _transaction.category != null
                            ? context.l10n.removeTag
                            : context.l10n.saveClassification,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// "Split this transaction" entry (debits only). Shows the call-to-action
  /// when unsplit, or the user's share of the total when already split. Themed
  /// via [AppColors] so it adapts across all four app themes.
  Widget _buildSplitCard(
    AppColors colors,
    bool isSplit,
    NumberFormat formatter,
  ) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openSplit,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSplit
                    ? colors.accent.withValues(alpha: 0.35)
                    : colors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.call_split_rounded,
                      color: colors.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSplit
                            ? l10n.yourShareOfTotal(
                                formatter.format(_transaction.effectiveAmount),
                                formatter.format(_transaction.amount),
                              )
                            : l10n.splitThisTransaction,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSplit ? l10n.editSplit : l10n.splitTagline,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a recurring-plan template from this transaction and open the editor;
  /// persists the plan the user confirms. Lowest-friction way to start tracking
  /// a bill the user is already looking at.
  Future<void> _trackAsRecurring() async {
    final t = _transaction;
    final now = DateTime.now();
    final label = (t.merchantName?.trim().isNotEmpty ?? false)
        ? t.merchantName!.trim()
        : t.sender;
    final day = t.detectedAt.day.clamp(1, 28);
    var anchor = DateTime(now.year, now.month, day);
    if (!anchor.isAfter(DateTime(now.year, now.month, now.day))) {
      anchor = DateTime(now.year, now.month + 1, day);
    }
    final template = RecurringPayment(
      name: label,
      category: t.category ?? 'Bills & Utilities',
      amount: t.amount,
      cadence: RecurringCadence.monthly,
      dayOfMonth: anchor.day,
      anchorDate: anchor,
      matchHint: label,
      createdAt: now,
    );
    final plan = await showRecurringEditor(context, template: template);
    if (plan == null) return;
    await DatabaseService().insertRecurringPayment(plan);
    if (mounted) {
      showAppToast(context,
          message: context.l10nRead.recurringPaymentsTitle,
          type: AppToastType.success);
    }
  }

  /// "Track as recurring" entry (debits only) — turn a one-off spend into a
  /// tracked subscription/bill. Themed via [AppColors] for all four themes.
  Widget _buildTrackRecurringCard(AppColors colors) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _trackAsRecurring,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.autorenew_rounded,
                      color: colors.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.trackAsRecurring,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.trackAsRecurringDesc,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "This is a settlement" entry. When already a settlement, shows the state
  /// with edit/remove (inside the sheet); otherwise a one-tap CTA. Themed via
  /// [AppColors] for all four themes.
  Widget _buildSettlementCard(AppColors colors, bool isSettlement) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSettlement(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSettlement
                    ? colors.accent.withValues(alpha: 0.35)
                    : colors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.handshake_rounded,
                      color: colors.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSettlement
                            ? l10n.settlementBadge
                            : l10n.thisIsASettlement,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.settlementTagline,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tier-3 nudge banner: "looks like a known person settling up — mark as
  /// settlement?" Tapping opens the sheet with the suggestion pre-selected.
  Widget _buildSettlementSuggestion(AppColors colors) {
    final s = _settleSuggestion!;
    final l10n = context.l10n;
    final text = s.person != null
        ? l10n.settlementSuggestFrom(s.person!)
        : l10n.settlementSuggestGeneric;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSettlement(suggested: s.person),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.accent.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: colors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: colors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom sheet to rename this transaction's payee. Beyond this row, the
  /// rename teaches a persistent alias keyed on the raw parser output, so
  /// matching transactions, category rules and every future SMS parse pick
  /// up the corrected name.
  Future<void> _showRenamePayeeSheet(bool isDark) async {
    final controller =
        TextEditingController(text: _transaction.merchantName ?? '');

    final cardColor = isDark ? const Color(0xFF16181E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C);
    final inputBg = isDark ? const Color(0xFF262931) : Color(0xFFFAFAF8);

    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFF9A9DA6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10nRead.renamePayeeTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10nRead.renamePayeeHelp,
              style: TextStyle(color: subtextColor),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: context.l10nRead.renamePayeeHint,
                hintStyle: TextStyle(color: subtextColor),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (value) => Navigator.pop(ctx, value),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4A6489),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  context.l10nRead.commonSave,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final trimmed = newName?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == _transaction.merchantName) {
      return;
    }

    try {
      final count = await _dbService.renamePayee(
        transaction: _transaction,
        newName: trimmed,
      );
      _changed = true;
      if (_transaction.id != null) {
        final fresh = await _dbService.getTransactionById(_transaction.id!);
        if (fresh != null && mounted) setState(() => _transaction = fresh);
      }
      if (mounted) {
        showAppToast(context,
            message: context.l10nRead.payeeRenamed(count),
            type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: context.l10nRead.errorGeneric(e),
            type: AppToastType.error);
      }
    }
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color subtextColor,
    Color textColor, {
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: subtextColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          if (onEdit != null)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.edit_outlined, size: 16, color: subtextColor),
              ),
            ),
        ],
      ),
    );
  }
}
