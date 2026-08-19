import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/ledger_models.dart';
import '../models/plus_products.dart';
import '../models/recurring_payment.dart';
import '../models/tax_bucket.dart';
import '../models/transaction_model.dart';
import '../models/transaction_rule_model.dart';
import '../providers/theme_provider.dart';
import '../services/bank_directory.dart';
import '../services/database_service.dart';
import '../services/custom_tag_service.dart';
import '../services/ledger_service.dart';
import '../services/removal_service.dart';
import '../services/tax_service.dart';
import '../services/tutorial_service.dart';
import 'auto_tag_rules_screen.dart';
import 'plus_screen.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/clear_tag_sheet.dart';
import '../widgets/create_tag_sheet.dart';
import '../widgets/recurring_editor_sheet.dart';
import '../widgets/removal_choice_dialog.dart';
import '../widgets/settlement_sheet.dart';
import '../widgets/split_transaction_sheet.dart';

/// Parser corrections offered in the detail-screen overflow menu.
enum _CorrectionAction { changeType, notATransaction }

/// Sheet return value meaning "clear the tax bucket" — distinct from null,
/// which means the sheet was dismissed. Can't collide with a real bucket id.
const String _kTaxNoneSentinel = '__tax_none__';

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
  // The tax-deduction bucket (a second, orthogonal axis to the category). Saved
  // immediately on pick, independent of the category Save button.
  String? _taxBucket;
  // A built-in / rule-based bucket suggestion for this payee, shown as a
  // one-tap chip when the transaction has no bucket yet. Suggestion only.
  String? _taxSuggestion;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  // Set when a split/settlement is added/edited/removed here, so the back
  // navigation signals the transactions list to refresh.
  bool _changed = false;
  // Tier-3 proactive suggestion: does this incoming credit look like a known
  // person settling a debt? Computed once on open for unclassified credits.
  SettlementSuggestion? _settleSuggestion;
  // The other half of a same-amount, opposite-direction pair landing within
  // minutes — the "looks like a self-transfer" nudge. Computed once on open.
  TransactionModel? _transferPair;
  // The standing "Apply to All" rule behind this row's tag, when there is
  // one. Drives the "tagged automatically" notice and the third clear scope
  // ("…and stop auto-tagging"), which is the only real undo of Apply to All.
  TransactionRule? _autoTagRule;

  // Guided-tour anchors: the category chips card and the Save button.
  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _selectedCategory = _transaction.category;
    _taxBucket = _transaction.taxBucket;
    _notesController.text = _transaction.notes ?? '';
    _maybeSuggestSettlement();
    _maybeSuggestTransferPair();
    _maybeSuggestTaxBucket();
    _loadAutoTagRule();
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

  /// Check (once) whether a same-amount opposite entry landed within
  /// minutes of this one — the two halves of one transfer between the
  /// user's own accounts, which shouldn't count as income + spending.
  Future<void> _maybeSuggestTransferPair() async {
    if (_transaction.category == 'Self Transfer') return;
    final pair = await _dbService.findTransferPair(_transaction);
    if (mounted && pair != null) {
      setState(() => _transferPair = pair);
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

  /// Look up the standing auto-tag rule for this payee, if the tag on this
  /// row came from one.
  Future<void> _loadAutoTagRule() async {
    final payee = _transaction.merchantName;
    if (payee == null || payee.isEmpty) return;
    final rule = await _dbService.findExistingRule(payee, _transaction.type);
    if (!mounted) return;
    // Only relevant while the rule actually governs this row's tag: a rule
    // pointing at a different tag than the one showing means the user has
    // since re-tagged this one by hand.
    setState(() {
      _autoTagRule =
          (rule != null && rule.category == _transaction.category) ? rule : null;
    });
  }

  Future<void> _openRules() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AutoTagRulesScreen()),
    );
    if (!mounted) return;
    _changed = true;
    await _refreshTransaction();
  }

  /// Re-read this row (and its rule) after something changed it elsewhere.
  Future<void> _refreshTransaction() async {
    if (_transaction.id == null) return;
    final fresh = await _dbService.getTransactionById(_transaction.id!);
    if (fresh == null || !mounted) return;
    setState(() {
      _transaction = fresh;
      _selectedCategory = fresh.category;
    });
    await _loadAutoTagRule();
  }

  /// Clear the tag on this transaction, asking first how far to reach.
  ///
  /// Tagging offers three distances (this one / every past one from this
  /// payee / those plus everything future); clearing offers the same three in
  /// reverse, so a tag applied in one gesture comes off in one gesture. Every
  /// scope is undoable from the toast that follows.
  Future<void> _clearTag() async {
    final tag = _transaction.category;
    if (tag == null || _transaction.id == null) return;
    final payee = _merchantDisplayName;
    final l10n = context.l10nRead;

    // What "all from this payee" would actually reach, counted before the
    // question is asked so the sheet can state it.
    final siblings = (_transaction.merchantName?.isNotEmpty ?? false)
        ? await _dbService.findTaggedByMerchant(
            merchantName: _transaction.merchantName!,
            type: _transaction.type,
            category: tag,
          )
        : <TransactionModel>[];
    if (!mounted) return;

    final scope = await showClearTagSheet(
      context,
      tag: tag,
      payee: payee,
      matchCount: siblings.length,
      hasRule: _autoTagRule != null,
    );
    if (scope == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      // Snapshotted before any write, so Undo restores exactly this.
      final affected = scope == ClearTagScope.onlyThis
          ? [_transaction]
          : siblings;
      final removedRule =
          scope == ClearTagScope.allAndStopRule ? _autoTagRule : null;

      await _dbService.untagTransactions(affected);
      if (removedRule?.id != null) {
        await _dbService.deleteTransactionRule(removedRule!.id!);
      }

      _changed = true;
      await _refreshTransaction();
      if (!mounted) return;

      showAppToast(
        context,
        message: removedRule != null
            ? l10n.clearedAndStoppedRule(affected.length, payee)
            : affected.length == 1
                ? l10n.tagRemoved
                : l10n.clearedFromCount(affected.length, payee),
        type: AppToastType.success,
        actionLabel: l10n.commonUndo,
        duration: const Duration(seconds: 6),
        onAction: () => _undoClear(affected, removedRule),
      );
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: l10n.errorGeneric(e), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Put back everything the last clear removed — the tags and, if it went
  /// that far, the auto-tag rule.
  Future<void> _undoClear(
    List<TransactionModel> affected,
    TransactionRule? removedRule,
  ) async {
    await _dbService.restoreTransactions(affected);
    if (removedRule != null) {
      // Re-inserted rather than updated: the row's id died with it.
      await _dbService.insertTransactionRule(
        TransactionRule(
          senderName: removedRule.senderName,
          transactionType: removedRule.transactionType,
          category: removedRule.category,
          notes: removedRule.notes,
          isActive: removedRule.isActive,
          createdAt: removedRule.createdAt,
        ),
      );
    }
    await _refreshTransaction();
    if (!mounted) return;
    showAppToast(context,
        message: context.l10nRead.tagRestored, type: AppToastType.info);
  }

  /// Save the tag the user picked — but only once they've said how far it
  /// should reach.
  ///
  /// The scope sheet is asked FIRST and a dismissal cancels the whole save,
  /// which is the same contract [_clearTag] has always had. This used to write
  /// the transaction before opening the sheet, on the reasoning that "nothing
  /// is lost" if the sheet was then dismissed — but something was: the user's
  /// consent. Backing out of the sheet silently left the row tagged as though
  /// they had chosen "Only this one", so the one gesture available for saying
  /// "actually, no" did the opposite. Tagging and clearing are the same
  /// decision in two directions and now behave identically.
  Future<void> _saveClassification() async {
    if (_transaction.id == null) return;

    // Guided tour: pressing Save completes its step; the apply-options sheet
    // that follows carries the tour's explainer banner.
    TutorialService.instance.advanceFrom(TutorialStep.saveTag);

    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    if (_selectedCategory == null) {
      // Deselecting the chip and pressing the "Clear" button above are the
      // same intent, so both go through the one place that asks how far the
      // clear should reach. Which gesture the user happened to find must
      // not decide whether ten transactions keep a tag they shouldn't have.
      setState(() => _isSaving = true);
      try {
        if (notes != null && notes != _transaction.notes) {
          await _dbService.updateTransaction(
            _transaction.copyWith(notes: notes),
          );
          await _refreshTransaction();
        }
      } catch (e) {
        if (mounted) {
          showAppToast(context,
              message: context.l10nRead.errorSaving(e),
              type: AppToastType.error);
        }
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      await _clearTag();
      return;
    }

    // How far should it reach? Nothing has been written yet, so backing out
    // here leaves the transaction exactly as it was found.
    final scope = await _askApplyScope();

    if (!mounted) return;
    // The tour treats the sheet as seen whether it was chosen or dismissed.
    final wasTourClassification =
        TutorialService.instance.isAt(TutorialStep.applyOptions);
    final navigator = Navigator.of(context);
    TutorialService.instance.advanceFrom(TutorialStep.applyOptions);

    if (scope == null) return; // dismissed — nothing to save

    // Plus gate (dormant during the free window): only "Apply to All" (1) —
    // the future+existing sweep — locks after the free window. "Apply to All
    // Existing" (2) and "Only this one" (3) stay free forever. When locked the
    // paywall opens and, unless Plus was bought right there, the save degrades
    // to the free single-transaction path rather than failing outright.
    var effective = scope;
    if (scope == 1) {
      final allowed =
          await PlusScreen.maybePush(context, PlusFeature.tagApplyToAll);
      if (!mounted) return;
      if (!allowed) effective = 3;
    }

    // "Name it & tag this one": collect the name first, then fall through as
    // a single-transaction save. The rename sheet writes and refreshes
    // _transaction itself, so the tag below lands on the freshly named row.
    //
    // Backing out of the naming sheet does NOT cancel the save the way
    // dismissing the scope sheet does — the user already answered the scope
    // question by picking this option, and "only this one" is what that
    // answer resolves to whether or not they got around to typing a name.
    if (scope == _nameAndTagScope) {
      await _showRenamePayeeSheet();
      if (!mounted) return;
      effective = 3;
    }

    setState(() => _isSaving = true);
    try {
      await _dbService.updateTransaction(
        _transaction.copyWith(
          category: _selectedCategory,
          notes: notes,
          isClassified: true,
        ),
      );
      if (!mounted) return;
      await _processBulkFlagging(effective);
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: context.l10nRead.errorSaving(e), type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    // The tour continues on Home, so once the save settles pop the whole way
    // back there in one motion instead of stranding the user on the list.
    if (wasTourClassification) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  /// Scope sentinel for "name the counterparty, then tag this row alone".
  /// Offered only when [_payeeIsUnnamed]; it resolves to scope 3 once the
  /// naming step is done, so nothing downstream has to know about it.
  static const int _nameAndTagScope = 0;

  /// Whether this row's payee is the parser saying "nobody was named" rather
  /// than an identity — an empty name, or the shared "UPI Transfer" /
  /// account-number placeholder.
  ///
  /// Both bulk scopes reach other rows *by payee name*, so on a placeholder
  /// they reach every unrelated transaction that happens to carry the same
  /// placeholder. "ATM" and "Bank Charges" are deliberately not placeholders:
  /// each is one real counterparty, and "all my ATM withdrawals are Cash" is
  /// a rule worth having. Same test [DatabaseService.renamePayee] uses, so
  /// tagging and renaming can never disagree about what counts as a name.
  bool get _payeeIsUnnamed => DatabaseService.isUnnamedPayee(
        _transaction.merchantName,
        _transaction.accountInfo,
      );

  /// Ask how far the new tag should reach: 1 = this and every future one from
  /// this payee, 2 = every existing one, 3 = only this transaction. Null when
  /// the user backed out, which cancels the save.
  ///
  /// When the payee is unnamed ([_payeeIsUnnamed]) the two bulk scopes are
  /// not offered at all — they would club unrelated payments under one tag.
  /// In their place, [_nameAndTagScope]: name the counterparty, then tag this
  /// row. Replaced rather than greyed out, so the sheet still answers "what
  /// can I do here" instead of only "what you can't".
  ///
  /// Purely a question — it writes nothing and navigates nowhere, so the
  /// caller stays in control of whether anything happens at all.
  Future<int?> _askApplyScope() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    final cardColor = colors.card;
    final textColor = colors.text;
    final unnamed = _payeeIsUnnamed;

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
                  color: colors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              unnamed
                  ? context.l10nRead.unnamedPayeeTitle
                  : context.l10nRead.applyToSimilarTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              unnamed
                  ? context.l10nRead.unnamedPayeeBody
                  : context.l10nRead.foundTxnsForMerchant(_merchantDisplayName),
              style: TextStyle(
                color: colors.textSecondary,
                height: unnamed ? 1.45 : null,
              ),
            ),
            // Guided tour: a one-time explainer for how far a tag can reach —
            // the three options below each describe their own behavior.
            if (TutorialService.instance.isAt(TutorialStep.applyOptions)) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.brandAccent
                      .withValues(alpha: isDark ? 0.12 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colors.brandAccent.withValues(alpha: 0.45)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: colors.brandAccent,
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
            // Nameless payee: the two bulk scopes are gone, and naming the
            // counterparty stands in their place. It is the only action that
            // can turn this row into something a future tag could ever reach.
            if (unnamed) ...[
              _buildOption(
                ctx,
                icon: Icons.drive_file_rename_outline_rounded,
                title: context.l10nRead.nameThisPayment,
                subtitle: context.l10nRead.nameThisPaymentDesc,
                value: _nameAndTagScope,
                color: Color(0xFF2AA76F),
              ),
              const SizedBox(height: 12),
            ] else ...[
              _buildOption(
                ctx,
                icon: Icons.select_all_rounded,
                title: context.l10nRead.applyToAll,
                subtitle: context.l10nRead.applyToAllDesc,
                value: 1,
                color: Color(0xFF2AA76F),
              ),
              const SizedBox(height: 12),
              _buildOption(
                ctx,
                icon: Icons.history_rounded,
                title: context.l10nRead.applyToExisting,
                subtitle: context.l10nRead.applyToExistingDesc,
                value: 2,
                color: Color(0xFFD79A3C),
              ),
              const SizedBox(height: 12),
            ],
            _buildOption(
              ctx,
              icon: Icons.touch_app_outlined,
              title: context.l10nRead.onlyThisOne,
              subtitle: context.l10nRead.onlyThisOneDesc,
              value: 3,
              color: Color(0xFF4A6489),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
    return result;
  }

  Widget _buildOption(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int value,
    required Color color,
  }) {
    final colors = AppColors.of(context);
    final cardBg = colors.cardAlt;
    final textColor = colors.text;

    return InkWell(
      onTap: () => Navigator.pop(ctx, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.border,
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
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
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

  /// Long-press on a category chip: pick a custom emoji for that tag
  /// (works for predefined categories and custom tags alike).
  Future<void> _showEmojiPickerForTag(String category) async {
    final colors = AppColors.of(context);
    final cardColor = colors.card;
    final textColor = colors.text;

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
                itemCount: kTagEmojiChoices.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.pop(ctx, kTagEmojiChoices[i]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.cardAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        kTagEmojiChoices[i],
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

  /// "+ New Tag" on the category grid. The sheet itself is shared with
  /// Settings → Manage tags (see [showCreateTagSheet]); all this screen adds is
  /// selecting the tag it just created.
  Future<void> _showCreateTagDialog() async {
    final created = await showCreateTagSheet(context);
    if (created == null || !mounted) return;
    setState(() => _selectedCategory = created);
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = _transaction.type == TransactionType.credit;
    final bank = BankDirectory.resolve(_transaction);
    final colors = AppColors.of(context);
    // A debit with a share override is "split": the headline shows the user's
    // own share (what counts toward budgets), with the full amount struck out.
    final isSplit = _transaction.splitShare != null;
    final isSettlement = _transaction.category == 'Settlement';
    // The debit branch hangs this loose under the quick-action row, since the
    // tax *tile* has no room for a subtitle to carry it. Hoisted up here
    // because the `...[]` spread it lives in can't declare a local; the
    // credit/settlement branch's tax card builds its own.
    final taxSuggestionChip = _buildTaxSuggestionChip(colors);
    final headlineAmount = _transaction.effectiveAmount;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormatter = DateFormat('EEEE, MMMM d, y • h:mm a');

    final bgColor = colors.background;
    final cardColor = colors.card;
    final textColor = colors.text;
    final subtextColor = colors.textSecondary;
    final chipBgUnselected = colors.cardAlt;
    final chipBorderUnselected = colors.border;
    final inputBgColor = colors.cardAlt;
    final messageBgColor = colors.cardAlt;

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
        // Parser corrections live in an overflow menu instead of body cards,
        // so the primary actions (split/recurring/settlement) stay
        // uncluttered. Manual entries have no SMS shape to correct.
        actions: [
          if (!_transaction.isManual) _buildCorrectionsMenu(colors, textColor),
        ],
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
                      isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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
                                  size: 12, color: colors.accent),
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
                                  size: 12, color: colors.accent),
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

            // The parser guessed something in this message — say exactly
            // what, and offer a one-tap "looks right" to clear the flag.
            if (_transaction.needsReview) ...[
              _buildReviewBanner(colors),
              const SizedBox(height: 16),
            ],

            // A same-amount opposite entry landed within minutes — probably
            // one transfer between the user's own accounts.
            if (_transferPair != null) ...[
              _buildTransferPairSuggestion(colors),
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
                  // The bank, not the DLT routing header it arrived under.
                  // "AD-IDBIBK-S" is the telecom operator's envelope, not an
                  // answer to "who is this from" — the directory already maps
                  // it to "IDBI Bank" for the Banks screen and honours the
                  // user's own name for it. The raw header stays underneath
                  // for the same reason "Read by" does: it is what a bug
                  // report needs, and hiding it would make an unrecognised
                  // header impossible to read off the screen.
                  _buildDetailRow(
                    context.l10n.fromLabel,
                    bank.isUnnamed ? _transaction.sender : bank.name,
                    subtextColor,
                    textColor,
                    subvalue: bank.isUnnamed || bank.name == _transaction.sender
                        ? null
                        : _transaction.sender,
                  ),
                  // Counterparty row. "Payee" kept being misread as "the one
                  // who paid" (two independent tester reports — Jun/Jul '26
                  // BOM), even when extraction was verifiably correct. So the
                  // label states the direction outright: debits "Paid to",
                  // credits "Received from" — same verb-phrase style both
                  // ways, so it can't read inconsistent like the earlier
                  // mixed noun/label attempt did.
                  // The pencil teaches a payee alias: SMS-derived names (VPAs,
                  // account numbers) are often unrecognisable, so one rename
                  // here fixes matching rows and every future SMS parse.
                  if (_transaction.merchantName != null)
                    _buildDetailRow(
                      isCredit
                          ? context.l10n.receivedFromLabel
                          : context.l10n.paidToLabel,
                      _transaction.merchantName!,
                      subtextColor,
                      textColor,
                      onEdit: _transaction.isManual
                          ? null
                          : () => _showRenamePayeeSheet(),
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
                    color: colors.border,
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
                  // Which reader parsed this SMS ("HDFC · NEFT credit",
                  // "general patterns") — trust + debugging fine print.
                  if (_transaction.parseSource != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${context.l10n.readBy}: ${_transaction.parseSource}',
                      style: TextStyle(
                        fontSize: 11,
                        color: subtextColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick actions — a single compact row instead of a tall stack of
            // cards, so the category tags sit higher and need less scrolling to
            // reach. Debits (that aren't already settlements) get all four
            // actions, tax included: tagging a deduction is a per-transaction
            // action like the other three, and burying it under the tag grid
            // meant nobody scrolled far enough to find it. Every other case has
            // "settle", which keeps its roomier descriptive card since there's
            // no stacking to compress, with the tax row directly beneath it.
            if (!isCredit && !isSettlement) ...[
              _buildQuickActions(colors, isSplit),
              if (taxSuggestionChip != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: taxSuggestionChip,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ] else ...[
              _buildSettlementCard(colors, isSettlement),
              // Deduction sections are all money the user PAID OUT, so a credit
              // never earns one — see [typeCanCarryTaxBucket]. Settlement
              // *debits* keep the row: they're still money leaving.
              if (typeCanCarryTaxBucket(_transaction.type)) ...[
                const SizedBox(height: 12),
                _buildTaxSectionRow(colors, cardColor, textColor, subtextColor),
              ],
              const SizedBox(height: 16),
            ],

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
                      // The heading (plus its badge) takes the whole row and
                      // yields to the trailing Clear action, which stays
                      // pinned to the right edge. A bare Flexible + Spacer
                      // pair left the button floating short of the edge: both
                      // claim flex 1, so the slack the ellipsised heading
                      // didn't use was stranded after the button.
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                context.l10n.category,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                      ),
                      // Removing a tag used to mean deselecting the chip and
                      // noticing that the Save button had turned red — a
                      // hidden gesture nobody found, and one that could only
                      // ever reach this single row. This says what it does,
                      // and the sheet behind it reaches as far as tagging did.
                      if (_transaction.category != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _isSaving ? null : _clearTag,
                          icon: const Icon(Icons.label_off_rounded, size: 16),
                          label: Text(context.l10n.clearTag),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFC94A50),
                            // Right padding trimmed so the label lines up with
                            // the card's content edge, not 10px inside it.
                            padding: const EdgeInsets.fromLTRB(10, 0, 2, 0),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Why a tag appeared without the user choosing it here.
                  if (_autoTagRule != null) ...[
                    const SizedBox(height: 12),
                    AutoTaggedNotice(
                      payee: _autoTagRule!.senderName,
                      onManage: _openRules,
                    ),
                  ],
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
                              _showEmojiPickerForTag(category),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              // Selection wears the theme accent at the same
                              // strengths every other chip in the app uses. It
                              // used to be a fixed steel blue that belonged to
                              // no theme — and a border that ignored even
                              // brightness.
                              color: isSelected
                                  ? colors.brandAccent
                                        .withValues(alpha: 0.16)
                                  : chipBgUnselected,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? colors.brandAccent
                                          .withValues(alpha: 0.45)
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
                                        ? colors.brandAccent
                                        : colors.textSecondary,
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
                        onTap: _showCreateTagDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colors.textSecondary,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.newTag,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary,
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
                  disabledBackgroundColor: colors.border,
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

  /// Compact horizontal action row for debit transactions: Split · Recurring ·
  /// Settle · Tax, laid out as four equal tiles instead of a tall stack of
  /// cards. This keeps the category tags high on the screen so they're
  /// reachable with far less scrolling. Themed via [AppColors] so it adapts to
  /// every theme.
  Widget _buildQuickActions(AppColors colors, bool isSplit) {
    final l10n = context.l10n;
    final bucket = taxBucketById(_taxBucket);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // IntrinsicHeight bounds the row's cross-axis so the tiles can share a
      // height. Without it, CrossAxisAlignment.stretch resolves against the
      // scroll view's unbounded height — an invalid constraint that breaks
      // layout (and silently mangles the screen in a release build).
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildActionTile(
                colors,
                icon: Icons.call_split_rounded,
                label: l10n.splitBadgeLabel,
                onTap: _openSplit,
                // An already-split debit reads as "on" — the headline carries
                // the share amount, so the tile only needs the active state.
                isActive: isSplit,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionTile(
                colors,
                icon: Icons.autorenew_rounded,
                label: l10n.recurringTitle,
                onTap: _trackAsRecurring,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionTile(
                colors,
                icon: Icons.handshake_rounded,
                label: l10n.settleUp,
                onTap: () => _openSettlement(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionTile(
                colors,
                icon: Icons.receipt_long_rounded,
                // Once tagged the tile *is* the readout — there's no subtitle
                // here — so it wears the section itself ("80C") rather than the
                // generic word.
                label: bucket?.compactSection ?? l10n.taxTile,
                // A transaction with no row id can't be tagged (nothing to
                // write to); the tile goes inert rather than disappearing.
                onTap: _transaction.id == null ? null : _pickTaxBucket,
                isActive: bucket != null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One quick-action tile: an icon above a short label on a themed card
  /// surface. [isActive] gives it an accent-tinted, accent-bordered treatment;
  /// a null [onTap] makes the tile inert. Sized for four across a phone, so
  /// the metrics are deliberately tight and the label may wrap to two lines
  /// (Bengali "নিষ্পত্তি করুন" and Telugu "పునరావృతం" need it).
  Widget _buildActionTile(
    AppColors colors, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          decoration: BoxDecoration(
            color: isActive
                ? colors.accent.withValues(alpha: 0.10)
                : colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? colors.accent.withValues(alpha: 0.45)
                  : colors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Top-aligned, not centred: a two-line label on one tile would
            // otherwise push its icon out of line with the other three.
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Accent chip behind the icon — the app's signature treatment,
              // and what gives the tile a clear anchor on low-contrast dark
              // surfaces where card and page background sit close together.
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colors.accent, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
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

  /// The "Tax section" row: shows the current bucket (or a prompt to add one)
  /// and opens the picker. Tagging here is independent of the category Save
  /// button — a tax bucket is a different axis and persists on its own.
  Widget _buildTaxSectionRow(
    AppColors colors,
    Color cardColor,
    Color textColor,
    Color subtextColor,
  ) {
    final l10n = context.l10n;
    final bucket = taxBucketById(_taxBucket);
    final suggestionChip = _buildTaxSuggestionChip(colors);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _transaction.id == null ? null : _pickTaxBucket,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt_long_rounded,
                          color: colors.accent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.taxSection,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bucket == null
                                ? l10n.taxAddSection
                                : '${bucket.section} · ${bucket.shortLabel}',
                            style:
                                TextStyle(fontSize: 12.5, color: subtextColor),
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
          // One-tap suggestion: "Looks like Section 80C — tap to tag".
          if (suggestionChip != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: suggestionChip,
              ),
            ),
        ],
      ),
    );
  }

  /// The one-tap auto-suggest chip ("Looks like Section 80C — tap to tag"),
  /// or null when there's nothing to suggest. Only offered while the
  /// transaction is still untagged; acting on it tags and dismisses.
  Widget? _buildTaxSuggestionChip(AppColors colors) {
    final suggested = taxBucketById(_taxSuggestion);
    if (_taxBucket != null || suggested == null) return null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _applyTaxBucket(suggested.id),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: colors.accent),
              const SizedBox(width: 6),
              Text(
                context.l10n.taxSuggestChip(suggested.section),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom sheet to pick (or clear) the tax bucket. Persists immediately via
  /// a targeted single-column write, so it never touches the category flow.
  Future<void> _pickTaxBucket() async {
    if (_transaction.id == null) return;
    // Event handler, not build: `l10n` watches and would assert here.
    final l10n = context.l10nRead;
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  l10n.taxPickSection,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.text),
                ),
              ),
              // "None" clears the bucket. Popped with a sentinel (not null) so
              // it's distinguishable from dismissing the sheet.
              ListTile(
                onTap: () => Navigator.pop(ctx, _kTaxNoneSentinel),
                title: Text(l10n.taxNone,
                    style: TextStyle(color: colors.text)),
                trailing: _taxBucket == null
                    ? Icon(Icons.check_rounded, color: colors.accent)
                    : null,
              ),
              for (final b in kTaxBuckets)
                ListTile(
                  onTap: () => Navigator.pop(ctx, b.id),
                  title: Text(b.section,
                      style: TextStyle(
                          color: colors.text, fontWeight: FontWeight.w600)),
                  subtitle: Text(b.shortLabel,
                      style: TextStyle(color: colors.textSecondary)),
                  trailing: _taxBucket == b.id
                      ? Icon(Icons.check_rounded, color: colors.accent)
                      : null,
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (chosen == null) return; // dismissed without choosing
    final newBucket = chosen == _kTaxNoneSentinel ? null : chosen;
    if (newBucket == _taxBucket) return;
    await _applyTaxBucket(newBucket);
  }

  /// Persist the chosen bucket (or clear with null), then — when a real bucket
  /// was set on an identifying payee — offer "apply to all from {payee}".
  Future<void> _applyTaxBucket(String? newBucket) async {
    await _dbService.setTaxBucket(_transaction.id!, newBucket);
    _changed = true;
    if (!mounted) return;
    setState(() {
      _taxBucket = newBucket;
      _taxSuggestion = null; // acted on; hide the chip
      _transaction = newBucket == null
          ? _transaction.clearedTaxBucket()
          : _transaction.copyWith(taxBucket: newBucket);
    });
    if (newBucket != null) {
      await _maybeOfferApplyToAll(newBucket);
    }
  }

  /// Compute a bucket suggestion for this payee (built-in keyword or a
  /// user-taught rule), shown as a one-tap chip while the row is untagged.
  Future<void> _maybeSuggestTaxBucket() async {
    if (_transaction.taxBucket != null) return;
    // Nothing to suggest on money coming in — see [typeCanCarryTaxBucket].
    if (!typeCanCarryTaxBucket(_transaction.type)) return;
    final suggestion =
        await TaxService().suggestionFor(_transaction.merchantName);
    if (mounted && suggestion != null && _taxBucket == null) {
      setState(() => _taxSuggestion = suggestion);
    }
  }

  /// After tagging, offer to apply the same bucket to every other transaction
  /// from this payee (and remember it for future ones) — but only for an
  /// identifying payee, never a placeholder like "UPI Transfer".
  Future<void> _maybeOfferApplyToAll(String bucket) async {
    final payee = _transaction.merchantName;
    if (payee == null || !isIdentifyingTaxPayee(payee)) return;
    final b = taxBucketById(bucket);
    if (b == null) return;
    final l10n = context.l10nRead;

    final apply = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.receipt_long_rounded,
        title: l10n.taxApplyAllTitle,
        subtitle: l10n.taxApplyAllBody(payee, b.section),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.taxApplyAllNo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.taxApplyAllYes),
          ),
        ],
      ),
    );
    if (apply != true) return;

    final count = await TaxService().saveRuleAndApply(payee, bucket);
    if (!mounted) return;
    showAppToast(context,
        message: l10n.taxApplyAllDone(count), type: AppToastType.success);
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

  /// Plain-language text for a parser review flag.
  String _reviewReasonText(String reason) {
    final l10n = context.l10n;
    switch (reason) {
      case ReviewReasons.unknownSender:
        return l10n.reviewReasonUnknownSender;
      case ReviewReasons.payeeUnknown:
        return l10n.reviewReasonPayeeUnknown;
      case ReviewReasons.directionUncertain:
        return l10n.reviewReasonDirection;
      case ReviewReasons.amountUncertain:
        return l10n.reviewReasonAmount;
      default:
        return reason;
    }
  }

  /// One tap says the parse is fine; the flag never comes back for this row.
  Future<void> _confirmLooksRight() async {
    if (_transaction.id == null) return;
    await _dbService.confirmTransactionReview(_transaction.id!);
    _changed = true;
    if (mounted) {
      setState(() => _transaction = _transaction.confirmedReview());
    }
  }

  /// Flip debit↔credit; the correction is remembered for this SMS shape.
  Future<void> _flipType() async {
    final flipped = _transaction.type == TransactionType.debit
        ? TransactionType.credit
        : TransactionType.debit;
    final updated =
        await _dbService.flipTransactionType(_transaction, flipped);
    _changed = true;
    if (mounted) {
      setState(() => _transaction = updated);
    }
  }

  /// Remove a false positive. Shares the removal fork with the swipe gesture
  /// and bulk selection — one dialog, one set of consequences, one place where
  /// the mute decision is explained — rather than the bespoke checkbox dialog
  /// this used to own. Picking "Not a transaction" mutes the message shape;
  /// picking "Just remove this one" keeps the old delete-only behaviour.
  Future<void> _notATransaction() async {
    if (_transaction.id == null) return;

    final choice = await showRemovalChoiceDialog(
      context,
      sender: _transaction.merchantName?.trim().isNotEmpty == true
          ? _transaction.merchantName!
          : _transaction.sender,
      canMute: RemovalService.canMute(_transaction),
    );
    if (choice == null || !mounted) return;

    await RemovalService.instance.remove([_transaction], choice);
    if (!mounted) return;
    showAppToast(
      context,
      message: choice == TransactionRemoval.notATransaction
          ? context.l10nRead.entryRemovedMuted
          : context.l10nRead.entryRemoved,
      type: AppToastType.info,
    );
    Navigator.pop(context, true);
  }

  /// Mark this transaction and its detected opposite half as Self Transfer.
  Future<void> _markTransferPair() async {
    final pair = _transferPair;
    if (pair == null) return;
    await _dbService.markTransferPair(_transaction, pair);
    _changed = true;
    if (_transaction.id != null) {
      final fresh = await _dbService.getTransactionById(_transaction.id!);
      if (fresh != null && mounted) {
        setState(() {
          _transaction = fresh;
          _selectedCategory = fresh.category;
          _transferPair = null; // resolved; hide the nudge
        });
      }
    }
  }

  /// Amber banner naming exactly what the parser guessed, with a one-tap
  /// "Looks right" that clears the flag.
  Widget _buildReviewBanner(AppColors colors) {
    final l10n = context.l10n;
    const amber = Color(0xFFC05621);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: amber.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, size: 18, color: amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.needsReviewTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._transaction.reviewReasonList.map(
              (r) => Padding(
                padding: const EdgeInsets.only(left: 26, bottom: 2),
                child: Text(
                  '•  ${_reviewReasonText(r)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Both answers to "is this right?" live here, side by side. The
            // banner only appears when the reader was unsure — precisely when a
            // false positive is likely — so this is where "Not a transaction"
            // earns its place in the open, instead of only in the overflow menu
            // where nobody found it.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _notATransaction,
                  icon: const Icon(Icons.playlist_remove_rounded, size: 18),
                  label: Text(l10n.notATransaction),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _confirmLooksRight,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l10n.looksRight),
                  style: TextButton.styleFrom(foregroundColor: amber),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Nudge banner: a same-amount opposite entry landed within minutes —
  /// mark both halves as Self Transfer with one tap.
  Widget _buildTransferPairSuggestion(AppColors colors) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.selfTransferSuggestionTitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.selfTransferSuggestionBody,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _markTransferPair,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(l10n.markBoth),
                style: TextButton.styleFrom(foregroundColor: colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// App-bar overflow menu holding the parser corrections (change direction,
  /// not a transaction). Kept out of the body so the primary action cards
  /// stay uncluttered; each item still teaches the app this SMS shape.
  Widget _buildCorrectionsMenu(AppColors colors, Color iconColor) {
    final l10n = context.l10n;
    final toCredit = _transaction.type == TransactionType.debit;
    const danger = Color(0xFFC0392B);
    return PopupMenuButton<_CorrectionAction>(
      icon: Icon(Icons.more_vert_rounded, color: iconColor),
      color: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tooltip: l10n.fixThis,
      onSelected: (action) {
        switch (action) {
          case _CorrectionAction.changeType:
            _flipType();
          case _CorrectionAction.notATransaction:
            _notATransaction();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: _CorrectionAction.changeType,
          child: Row(
            children: [
              Icon(Icons.swap_vert_rounded, size: 20, color: colors.accent),
              const SizedBox(width: 12),
              Text(toCredit ? l10n.changeToCredit : l10n.changeToDebit),
            ],
          ),
        ),
        PopupMenuItem(
          value: _CorrectionAction.notATransaction,
          child: Row(
            children: [
              const Icon(Icons.playlist_remove_rounded,
                  size: 20, color: danger),
              const SizedBox(width: 12),
              Text(l10n.notATransaction,
                  style: const TextStyle(color: danger)),
            ],
          ),
        ),
      ],
    );
  }

  /// Bottom sheet to rename this transaction's payee. Beyond this row, the
  /// rename teaches a persistent alias keyed on the raw parser output, so
  /// matching transactions, category rules and every future SMS parse pick
  /// up the corrected name.
  Future<void> _showRenamePayeeSheet() async {
    final colors = AppColors.of(context);
    final controller =
        TextEditingController(text: _transaction.merchantName ?? '');

    final cardColor = colors.card;
    final textColor = colors.text;
    final subtextColor = colors.textSecondary;
    final inputBg = colors.cardAlt;

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
                  color: colors.textSecondary,
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

  /// One label/value line. [subvalue] is fine print under the value — the
  /// raw sender header behind a resolved bank name, so nothing the screen
  /// used to show is lost when a friendlier name is put in front of it.
  Widget _buildDetailRow(
    String label,
    String value,
    Color subtextColor,
    Color textColor, {
    VoidCallback? onEdit,
    String? subvalue,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // Wide enough for the direction-explicit labels ("Received
            // from") to sit on one line; the value column flexes.
            width: 92,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: subtextColor),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                if (subvalue != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subvalue,
                      style: TextStyle(
                        fontSize: 11,
                        color: subtextColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
              ],
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
