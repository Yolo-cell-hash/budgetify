import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';
import '../models/bank_summary.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/bank_directory.dart';
import '../services/database_service.dart';
import '../services/removal_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/bank_chips.dart';
import '../widgets/removal_choice_dialog.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_screen.dart';
import 'add_transaction_screen.dart';

/// Match a transaction against the search box's free-text query.
///
/// Text — payee, sender, category, formatted dates ("9 Jul 2026",
/// "09/07/2026") — matches loosely by substring. A purely numeric query
/// (optionally prefixed ₹/Rs/INR, with commas or paise) is an AMOUNT query
/// and matches strictly: searching "50" finds ₹50.00 but never ₹500, ₹250
/// or ₹1,150.50.
///
/// Top-level so the matching rules are unit-testable.
bool transactionMatchesQuery(TransactionModel t, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;

  // Amount query → strict equality (to the paisa).
  final numericQuery = double.tryParse(
    q.replaceFirst(RegExp(r'^(?:rs\.?|inr|₹)\s*'), '').replaceAll(',', ''),
  );
  if (numericQuery != null) {
    return (t.amount - numericQuery).abs() < 0.005;
  }

  final haystack = StringBuffer()
    ..write(t.merchantName ?? '')
    ..write(' ')
    ..write(t.sender)
    ..write(' ')
    ..write(t.category ?? '')
    ..write(' ')
    ..write(DateFormat('d MMM yyyy').format(t.detectedAt))
    ..write(' ')
    ..write(DateFormat('dd/MM/yyyy').format(t.detectedAt));
  return haystack.toString().toLowerCase().contains(q);
}

/// Screen displaying all detected transactions with filtering
class TransactionsScreen extends StatefulWidget {
  final bool initialUnclassifiedOnly;
  final TransactionType? initialTypeFilter;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  /// [BankIdentity.id] to open filtered to — how the Banks screen drills in.
  final String? initialBankId;

  /// What to call that bank on the active-filter chip. Defaults to the id,
  /// which for a resolved bank is already its display name; the Banks screen
  /// passes the translated label for the manual/imported buckets.
  final String? initialBankLabel;

  const TransactionsScreen({
    super.key,
    this.initialUnclassifiedOnly = false,
    this.initialTypeFilter,
    this.initialStartDate,
    this.initialEndDate,
    this.initialBankId,
    this.initialBankLabel,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<TransactionModel> _transactions = [];
  List<String> _categories = [];
  bool _isLoading = true;

  // Filters — type and classification status are independent and combine
  // (e.g. "unclassified debits", "classified credits").
  TransactionType? _typeFilter;
  String? _categoryFilter;
  _ClassFilter _classFilter = _ClassFilter.all;
  DateTime? _startDate;
  DateTime? _endDate;
  _DatePreset _datePreset = _DatePreset.all;

  /// Bank filter: a [BankIdentity.id], resolved from each transaction's
  /// sender. Null = every bank.
  String? _bankFilter;

  /// The bank facet for the current view: every bank the other filters leave
  /// standing, with what was spent from each. Rebuilt on every load.
  List<BankActivity> _banks = const [];

  // Free-text search across merchant/payee, amount, and date
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Monthly totals (for summary card — always current month, unfiltered)
  double _monthlyCredits = 0;
  double _monthlyDebits = 0;

  // One-time swipe-to-delete discoverability hint: the first card peeks open
  // on the user's first ever visit, then never again (persisted below).
  static const String _swipeHintKey = 'swipe_to_delete_hint_shown_v1';
  bool _showSwipeHint = false;

  // One-time nudge, fired the first time the user removes a message shape they
  // have already removed before — proof they're on the delete treadmill.
  static const String _repeatTipKey = 'repeat_delete_tip_shown_v1';
  bool _repeatTipShown = true; // assume shown until prefs say otherwise

  // Bulk selection. Empty set == not in selection mode, so a single flag can't
  // drift out of sync with the selection itself.
  final Set<int> _selectedIds = {};
  bool get _selectionMode => _selectedIds.isNotEmpty;

  // Tour anchor for the "open this transaction" tip.
  final GlobalKey _firstCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _classFilter = widget.initialUnclassifiedOnly
        ? _ClassFilter.unclassified
        : _ClassFilter.all;
    _typeFilter = widget.initialTypeFilter;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _bankFilter = widget.initialBankId;
    _datePreset =
        widget.initialStartDate != null ? _DatePreset.custom : _DatePreset.all;
    _loadSwipeHintFlag();
    _loadFiltersData();
    _loadTransactions();
    // Guided tour: reaching this list completes the "view your transactions"
    // step; the next tip points at the first card below.
    TutorialService.instance.advanceFrom(TutorialStep.viewTransactions);
    TutorialService.instance.addListener(_onTutorialTick);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowTutorialTip());
  }

  void _onTutorialTick() {
    if (mounted) _maybeShowTutorialTip();
  }

  /// Points the guided tour at the first transaction card, passing the tap
  /// through so opening it is the real action that advances the tour.
  void _maybeShowTutorialTip() {
    if (!mounted || _isLoading || _transactions.isEmpty) return;
    if (!TutorialService.instance.isAt(TutorialStep.openTransaction)) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final l10n = context.l10nRead;
    TutorialTips.show(
      context,
      step: TutorialStep.openTransaction,
      anchor: _firstCardKey,
      title: l10n.tutOpenTxnTitle,
      message: l10n.tutOpenTxnBody,
    );
  }

  Future<void> _loadSwipeHintFlag() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final repeatShown = prefs.getBool(_repeatTipKey) ?? false;
    setState(() {
      if (!(prefs.getBool(_swipeHintKey) ?? false)) _showSwipeHint = true;
      _repeatTipShown = repeatShown;
    });
  }

  Future<void> _markSwipeHintShown() async {
    _showSwipeHint = false; // stop re-triggering on later rebuilds
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_swipeHintKey, true);
  }

  @override
  void dispose() {
    TutorialService.instance.removeListener(_onTutorialTick);
    TutorialTips.dismissIfFor(TutorialStep.openTransaction);
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(TransactionModel t) =>
      transactionMatchesQuery(t, _searchQuery);

  Future<void> _loadFiltersData() async {
    try {
      final categories = await _dbService.getUsedCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (e) {
      debugPrint('Error loading filter data: $e');
    }
  }

  /// The label for the active-bank chip, which has to survive the filtered
  /// list going empty (no rows left to read a name off).
  String get _bankFilterLabel {
    for (final b in _banks) {
      if (b.id == _bankFilter) return bankDisplayLabel(context, b);
    }
    return widget.initialBankLabel ?? _bankFilter!;
  }

  /// Reload the list from the database.
  ///
  /// [keepPosition] leaves the current list on screen while the query runs.
  /// The full-screen spinner unmounts the [ListView], and the scroll offset
  /// goes with it — which is why coming back from a transaction used to dump
  /// the user at the top of a list they had scrolled a long way down. Reloads
  /// that only refresh what's already there (returning from a screen, a
  /// delete, an undo, pull-to-refresh) keep their place; filter and search
  /// changes still show the spinner, because a different result set genuinely
  /// does start at the top.
  Future<void> _loadTransactions({bool keepPosition = false}) async {
    if (!keepPosition) setState(() => _isLoading = true);

    try {
      var transactions = await _dbService.getFilteredTransactions(
        type: _typeFilter,
        category: _categoryFilter,
        classified: switch (_classFilter) {
          _ClassFilter.all => null,
          _ClassFilter.classified => true,
          _ClassFilter.unclassified => false,
          // Review flags are orthogonal to classification — fetch all and
          // narrow client-side below.
          _ClassFilter.needsReview => null,
        },
      );

      if (_classFilter == _ClassFilter.needsReview) {
        transactions = transactions.where((t) => t.needsReview).toList();
      }

      // Apply date range filter client-side if set
      if (_startDate != null && _endDate != null) {
        transactions = transactions.where((t) {
          return !t.detectedAt.isBefore(_startDate!) &&
              !t.detectedAt.isAfter(_endDate!);
        }).toList();
      }

      // Apply free-text search
      if (_searchQuery.trim().isNotEmpty) {
        transactions = transactions.where(_matchesSearch).toList();
      }

      // The bank facet is built from everything EXCEPT the bank filter, so
      // the chips keep showing every bank you could switch to — and their
      // amounts describe the period you're actually looking at, not all time.
      final banks = BankBreakdown.fromTransactions(transactions).banks;

      // Bank lives in the sender header, not a column, so it narrows here
      // rather than in SQL.
      final bank = _bankFilter;
      if (bank != null) {
        transactions = transactions
            .where((t) => BankDirectory.resolve(t).id == bank)
            .toList();
      }

      // Load current-month totals (always unfiltered) for the summary card
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final allMonthTxns = await _dbService.getTransactionsByDateRange(
        monthStart,
        monthEnd,
      );
      // Mirror the rest of the app's definition of income/spending: money
      // moved between your own accounts (Self Transfer) or put into
      // Investments is neither income nor an expense, so it's excluded here
      // too. Without this, the summary's Expenses double-counts
      // investments/self-transfers and no longer matches the Home dashboard.
      double mCredits = 0, mDebits = 0;
      for (final t in allMonthTxns) {
        if (t.type == TransactionType.credit) {
          if (ExpenseCategories.isIncomeCategory(t.category)) {
            mCredits += t.amount;
          }
        } else if (ExpenseCategories.isExpenseCategory(t.category)) {
          // A split bill costs the user their share only, matching Home.
          mDebits += t.effectiveAmount;
        }
      }

      setState(() {
        _transactions = transactions;
        _banks = banks;
        _monthlyCredits = mCredits;
        _monthlyDebits = mDebits;
        _isLoading = false;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeShowTutorialTip());
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showAppToast(context,
            message: context.l10nRead.errorLoadingTransactions(e),
            type: AppToastType.error);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _typeFilter = null;
      _categoryFilter = null;
      _bankFilter = null;
      _classFilter = _ClassFilter.all;
      _startDate = null;
      _endDate = null;
      _datePreset = _DatePreset.all;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadTransactions();
  }

  /// Apply a quick date-range preset (everything except [custom], which uses
  /// the range picker via [_pickCustomRange]).
  void _applyDatePreset(_DatePreset preset) {
    if (preset == _DatePreset.custom) return; // handled by _pickCustomRange
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final (DateTime? start, DateTime? end) = switch (preset) {
      _DatePreset.all => (null, null),
      _DatePreset.thisMonth => (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        ),
      _DatePreset.lastMonth => (
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 0, 23, 59, 59),
        ),
      _DatePreset.last7 => (
          today.subtract(const Duration(days: 6)),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
      _DatePreset.last30 => (
          today.subtract(const Duration(days: 29)),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        ),
      _DatePreset.custom => (null, null), // unreachable
    };
    setState(() {
      _datePreset = preset;
      _startDate = start;
      _endDate = end;
    });
    _loadTransactions();
  }

  /// Pick a specific date or a date range (select the same day twice for a
  /// single date).
  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: context.l10nRead.selectDateOrRange,
    );
    if (picked == null) return;
    setState(() {
      _datePreset = _DatePreset.custom;
      _startDate =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      _endDate = DateTime(
          picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
    });
    _loadTransactions();
  }

  /// Label for the custom-range chip — shows the picked range when active.
  String get _customChipLabel {
    if (_datePreset == _DatePreset.custom &&
        _startDate != null &&
        _endDate != null) {
      final l10n = context.l10nRead;
      final s = l10n.dayMonth(_startDate!);
      final e = l10n.dayMonth(_endDate!);
      return s == e ? s : '$s – $e';
    }
    return context.l10nRead.customRange;
  }

  bool get _hasActiveFilters =>
      _typeFilter != null ||
      _categoryFilter != null ||
      _classFilter != _ClassFilter.all ||
      _startDate != null ||
      _searchQuery.trim().isNotEmpty;

  /// Non-default filter dimensions (excluding search, which is visible in the
  /// field itself) — drives the filter-button badge and the active-chips row.
  int get _activeFilterCount =>
      (_typeFilter != null ? 1 : 0) +
      (_classFilter != _ClassFilter.all ? 1 : 0) +
      (_datePreset != _DatePreset.all || _startDate != null ? 1 : 0) +
      (_categoryFilter != null ? 1 : 0) +
      (_bankFilter != null ? 1 : 0);

  /// Label for the active date filter (preset name or the custom range).
  String get _dateFilterLabel {
    final l10n = context.l10nRead;
    return switch (_datePreset) {
      _DatePreset.all => l10n.filterAll,
      _DatePreset.thisMonth => l10n.thisMonth,
      _DatePreset.lastMonth => l10n.lastMonth,
      _DatePreset.last7 => l10n.lastNDays(7),
      _DatePreset.last30 => l10n.lastNDays(30),
      _DatePreset.custom => _customChipLabel,
    };
  }

  /// Carry out a removal the user already confirmed in the fork, then offer an
  /// Undo. The royal reaction is chosen inside [RemovalService] so a correction
  /// and a bare delete never look alike.
  Future<void> _removeTransactions(
    List<TransactionModel> transactions,
    TransactionRemoval choice,
  ) async {
    if (transactions.isEmpty) return;

    // Whether this is a repeat of a shape the user already deleted — read
    // before the removal writes its own tombstone, or every delete looks like
    // a repeat of itself.
    final nudge = choice == TransactionRemoval.deleteOnly &&
            transactions.length == 1 &&
            !_repeatTipShown &&
            RemovalService.canMute(transactions.first)
        ? await _dbService.hasEarlierDeletionOfShape(
            transactions.first.sender, transactions.first.message)
        : false;

    final receipt =
        await RemovalService.instance.remove(transactions, choice);
    await _loadTransactions(keepPosition: true);
    if (!mounted) return;

    final l10n = context.l10nRead;
    showAppToast(
      context,
      message: receipt.mutedAnything
          ? l10n.entryRemovedMuted
          : transactions.length > 1
              ? l10n.nEntriesRemoved(receipt.count)
              : l10n.txnDeletedToast,
      type: AppToastType.info,
      actionLabel: receipt.isRestorable ? l10n.commonUndo : null,
      onAction: receipt.isRestorable ? () => _undoRemoval(receipt) : null,
    );

    if (nudge) _showRepeatDeleteTip();
  }

  Future<void> _undoRemoval(RemovalReceipt receipt) async {
    final restored = await RemovalService.instance.undo(receipt);
    await _loadTransactions(keepPosition: true);
    if (!mounted) return;
    showAppToast(
      context,
      message: restored == 0
          ? context.l10nRead.cannotUndo
          : receipt.mutedAnything
              ? context.l10nRead.muteLifted
              : context.l10nRead.nEntriesRemoved(restored),
      type: restored == 0 ? AppToastType.error : AppToastType.success,
    );
  }

  /// The user just deleted a message shape they had already deleted before —
  /// exactly the treadmill that makes people report the app as broken. Say once
  /// that "Not a transaction" ends it, then never mention it again.
  Future<void> _showRepeatDeleteTip() async {
    _repeatTipShown = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_repeatTipKey, true);
    if (!mounted) return;
    final l10n = context.l10nRead;
    await showAppDialog<void>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.playlist_remove_rounded,
        accent: AppColors.of(ctx).warning,
        title: l10n.repeatDeleteTipTitle,
        subtitle: l10n.repeatDeleteTipBody,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
  }

  // ── Bulk selection ───────────────────────────────────────────────────
  // Long-press enters selection mode. Besides making bulk corrections possible
  // at all, this is the visible, non-gesture alternative to swiping that the
  // list previously lacked entirely.

  void _toggleSelection(TransactionModel t) {
    final id = t.id;
    if (id == null) return;
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  void _selectAll() => setState(() {
        _selectedIds
          ..clear()
          ..addAll(_transactions.map((t) => t.id).whereType<int>());
      });

  List<TransactionModel> get _selectedTransactions =>
      _transactions.where((t) => _selectedIds.contains(t.id)).toList();

  /// Bulk remove: one fork for the whole selection. Muting is offered only when
  /// every selected row can actually be muted, so the dialog never promises
  /// something it will silently skip for some rows.
  Future<void> _removeSelected() async {
    final chosen = _selectedTransactions;
    if (chosen.isEmpty) return;

    final choice = await showRemovalChoiceDialog(
      context,
      sender: chosen.first.sender,
      canMute: chosen.every(RemovalService.canMute),
      count: chosen.length,
    );
    if (choice == null) return;
    _clearSelection();
    await _removeTransactions(chosen, choice);
  }

  void _openTransactionDetail(TransactionModel transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(transaction: transaction),
      ),
    );

    if (result == true) {
      // Refresh in place: the user came back to the row they were looking at,
      // not to the top of the list.
      _loadTransactions(keepPosition: true);
    }
  }

  String get _appBarTitle {
    final l10n = context.l10nRead;
    if (_startDate != null && _typeFilter != null) {
      final monthName = l10n.monthName(_startDate!.month);
      if (_typeFilter == TransactionType.credit) {
        return '$monthName ${l10n.commonIncome}';
      } else {
        return '$monthName ${l10n.commonExpenses}';
      }
    }
    return l10n.transactions;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _selectionMode
          ? _buildSelectionAppBar()
          : AppBar(
              title: Text(_appBarTitle),
              actions: [
                if (_hasActiveFilters)
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    onPressed: _clearFilters,
                    tooltip: context.l10n.clearFilters,
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _loadTransactions(keepPosition: true),
                ),
              ],
            ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                );
                if (result == true) _loadTransactions(keepPosition: true);
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.add),
            ),
      body: SafeArea(child: Column(
        children: [
          // Compact pinned chrome: one search row (with the filter-sheet
          // button), plus a slim strip of removable chips only while filters
          // are active — the list keeps the rest of the screen. Hidden in
          // selection mode, where the app bar carries the actions instead.
          if (!_selectionMode) _buildHeader(isDark),

          // Transactions list (the month summary scrolls away with it)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    // Pull-to-refresh has its own spinner; swapping the list
                    // out for a second one would also lose the user's place.
                    onRefresh: () => _loadTransactions(keepPosition: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 80),
                      itemCount: _transactions.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _selectionMode
                              ? const SizedBox.shrink()
                              : _buildSummaryStrip(isDark);
                        }
                        final transaction = _transactions[index - 1];
                        final card = TransactionCard(
                          transaction: transaction,
                          animateSwipeHint: index == 1 &&
                              _showSwipeHint &&
                              !_selectionMode,
                          onSwipeHintShown: _markSwipeHintShown,
                          selectable: _selectionMode,
                          selected: _selectedIds.contains(transaction.id),
                          onLongPress: () => _toggleSelection(transaction),
                          onTap: () => _selectionMode
                              ? _toggleSelection(transaction)
                              : _openTransactionDetail(transaction),
                          onRemove: (choice) =>
                              _removeTransactions([transaction], choice),
                        );
                        // Tour anchor: the first card is what the "open this
                        // transaction" tip points at.
                        if (index == 1) {
                          return KeyedSubtree(
                            key: _firstCardKey,
                            child: card,
                          );
                        }
                        return card;
                      },
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  /// Contextual app bar for selection mode: count, select-all, and the bulk
  /// remove that routes through the same fork a single swipe does.
  AppBar _buildSelectionAppBar() {
    final l10n = context.l10n;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearSelection,
        tooltip: l10n.commonCancel,
      ),
      title: Text(l10n.nSelected(_selectedIds.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all_rounded),
          onPressed: _selectAll,
          tooltip: l10n.selectAll,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _removeSelected,
          tooltip: l10n.commonDelete,
        ),
      ],
    );
  }

  /// The compact pinned chrome: a single search row beside the filter-sheet
  /// button, plus (only while filters are active) one slim row of removable
  /// chips. All other filter controls live in [_openFilterSheet], so the
  /// transaction list keeps almost the whole screen.
  Widget _buildHeader(bool isDark) {
    final colors = AppColors.of(context);
    return Container(
      color: colors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                // Search bar — matches payee/merchant, amount, or date
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                      _loadTransactions();
                    },
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: context.l10n.searchTxnHint,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _searchController.clear();
                                _loadTransactions();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colors.cardAlt,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildFilterButton(isDark),
              ],
            ),
          ),
          // One-tap bank filter, above the active-filter chips. Only when
          // there is a choice to make — with a single bank on record,
          // filtering by it selects everything and is pure clutter.
          if (_banks.length > 1) ...[
            const SizedBox(height: 10),
            BankChips(
              breakdown: BankBreakdown(_banks),
              selectedId: _bankFilter,
              onSelectAll: () {
                setState(() => _bankFilter = null);
                _loadTransactions();
              },
              onSelect: (bank) {
                setState(() =>
                    _bankFilter = _bankFilter == bank.id ? null : bank.id);
                _loadTransactions();
              },
            ),
            const SizedBox(height: 4),
          ],
          if (_activeFilterCount > 0) _buildActiveFiltersStrip(isDark),
          Divider(
            height: 1,
            color: colors.border,
          ),
        ],
      ),
    );
  }

  /// The tune button beside the search field: opens the filter sheet and
  /// carries a count badge while filters are active.
  Widget _buildFilterButton(bool isDark) {
    final colors = AppColors.of(context);
    final accent = colors.brandAccent;
    final active = _activeFilterCount;
    return Material(
      color: active > 0
          ? accent.withValues(alpha: isDark ? 0.18 : 0.14)
          : colors.cardAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openFilterSheet,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active > 0 ? accent.withValues(alpha: 0.55) : colors.border,
            ),
          ),
          child: Tooltip(
            message: context.l10n.filtersTitle,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: active > 0
                      ? accent
                      : (colors.textSecondary),
                ),
                if (active > 0)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 15,
                      height: 15,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$active',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: Color(0xFF14161F),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One slim horizontal row summarizing the active filters, each removable
  /// in place. Hidden entirely when nothing is filtered.
  Widget _buildActiveFiltersStrip(bool isDark) {
    final l10n = context.l10n;
    final chips = <Widget>[
      if (_typeFilter != null)
        _activeFilterChip(
          isDark: isDark,
          label: _typeFilter == TransactionType.credit
              ? l10n.credits
              : l10n.debits,
          color: _typeFilter == TransactionType.credit
              ? const Color(0xFF2AA76F)
              : const Color(0xFFD25A5F),
          onRemove: () => _setType(null),
        ),
      if (_classFilter != _ClassFilter.all)
        _activeFilterChip(
          isDark: isDark,
          label: switch (_classFilter) {
            _ClassFilter.classified => l10n.classified,
            _ClassFilter.needsReview => l10n.needsReviewFilter,
            _ => l10n.unclassified,
          },
          color: switch (_classFilter) {
            _ClassFilter.classified => const Color(0xFF4A6489),
            _ClassFilter.needsReview => const Color(0xFFC05621),
            _ => const Color(0xFFD79A3C),
          },
          onRemove: () => _setClass(_ClassFilter.all),
        ),
      if (_datePreset != _DatePreset.all || _startDate != null)
        _activeFilterChip(
          isDark: isDark,
          label: _dateFilterLabel,
          color: const Color(0xFF4A6489),
          onRemove: () => _applyDatePreset(_DatePreset.all),
        ),
      if (_categoryFilter != null)
        _activeFilterChip(
          isDark: isDark,
          label: l10n.categoryName(_categoryFilter!),
          color: AppColors.of(context).brandAccent,
          onRemove: () {
            setState(() => _categoryFilter = null);
            _loadTransactions();
          },
        ),
      if (_bankFilter != null)
        _activeFilterChip(
          isDark: isDark,
          label: _bankFilterLabel,
          color: const Color(0xFF4A6489),
          onRemove: () {
            setState(() => _bankFilter = null);
            _loadTransactions();
          },
        ),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  /// A removable pill for one active filter — tap anywhere on it to clear
  /// that dimension.
  Widget _activeFilterChip({
    required String label,
    required Color color,
    required VoidCallback onRemove,
    // Not a colour: the tint's *alpha*, which genuinely differs by brightness —
    // the same wash reads heavier on a dark canvas than a light one.
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  /// Every filter control (Type, Status, Date, Category) as chip groups in a
  /// premium bottom sheet. Selections apply immediately, so the list updates
  /// live behind the sheet.
  Future<void> _openFilterSheet() async {
    final colors = AppColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            // Mutate filter state on both the screen and the open sheet.
            void apply(VoidCallback change) {
              setState(change);
              setSheetState(() {});
              _loadTransactions();
            }

            final l10n = context.l10nRead;
            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
                      child: Row(
                        children: [
                          Text(
                            l10n.filtersTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              _clearFilters();
                              setSheetState(() {});
                            },
                            child: Text(l10n.clearFilters),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sheetSection(l10n.filterType),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  label: l10n.filterAll,
                                  isSelected: _typeFilter == null,
                                  onSelected: () =>
                                      apply(() => _typeFilter = null),
                                ),
                                _buildFilterChip(
                                  label: l10n.credits,
                                  isSelected:
                                      _typeFilter == TransactionType.credit,
                                  onSelected: () => apply(() =>
                                      _typeFilter = TransactionType.credit),
                                  color: const Color(0xFF2AA76F),
                                ),
                                _buildFilterChip(
                                  label: l10n.debits,
                                  isSelected:
                                      _typeFilter == TransactionType.debit,
                                  onSelected: () => apply(() =>
                                      _typeFilter = TransactionType.debit),
                                  color: const Color(0xFFD25A5F),
                                ),
                              ],
                            ),
                            _sheetSection(l10n.filterStatus),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  label: l10n.filterAll,
                                  isSelected: _classFilter == _ClassFilter.all,
                                  onSelected: () => apply(
                                      () => _classFilter = _ClassFilter.all),
                                ),
                                _buildFilterChip(
                                  label: l10n.classified,
                                  isSelected:
                                      _classFilter == _ClassFilter.classified,
                                  onSelected: () => apply(() =>
                                      _classFilter = _ClassFilter.classified),
                                  color: const Color(0xFF4A6489),
                                ),
                                _buildFilterChip(
                                  label: l10n.unclassified,
                                  isSelected:
                                      _classFilter == _ClassFilter.unclassified,
                                  onSelected: () => apply(() => _classFilter =
                                      _ClassFilter.unclassified),
                                  color: const Color(0xFFD79A3C),
                                ),
                                _buildFilterChip(
                                  label: l10n.needsReviewFilter,
                                  isSelected:
                                      _classFilter == _ClassFilter.needsReview,
                                  onSelected: () => apply(() => _classFilter =
                                      _ClassFilter.needsReview),
                                  color: const Color(0xFFC05621),
                                ),
                              ],
                            ),
                            _sheetSection(l10n.dateLabel),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final (preset, label) in [
                                  (_DatePreset.all, l10n.filterAll),
                                  (_DatePreset.thisMonth, l10n.thisMonth),
                                  (_DatePreset.lastMonth, l10n.lastMonth),
                                  (_DatePreset.last7, l10n.lastNDays(7)),
                                  (_DatePreset.last30, l10n.lastNDays(30)),
                                ])
                                  _buildFilterChip(
                                    label: label,
                                    isSelected: _datePreset == preset,
                                    onSelected: () {
                                      _applyDatePreset(preset);
                                      setSheetState(() {});
                                    },
                                    color: preset == _DatePreset.all
                                        ? null
                                        : const Color(0xFF4A6489),
                                  ),
                                _buildFilterChip(
                                  label: _customChipLabel,
                                  isSelected: _datePreset == _DatePreset.custom,
                                  onSelected: () async {
                                    await _pickCustomRange();
                                    setSheetState(() {});
                                  },
                                  color: colors.brandAccent,
                                ),
                              ],
                            ),
                            // Only banks with transactions on record — a
                            // filter you can't get results from is noise.
                            if (_banks.isNotEmpty) ...[
                              _sheetSection(l10n.bankLabel),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildFilterChip(
                                    label: l10n.filterAll,
                                    isSelected: _bankFilter == null,
                                    onSelected: () =>
                                        apply(() => _bankFilter = null),
                                  ),
                                  for (final bank in _banks)
                                    _buildFilterChip(
                                      label: bankDisplayLabel(context, bank),
                                      isSelected: _bankFilter == bank.id,
                                      onSelected: () =>
                                          apply(() => _bankFilter = bank.id),
                                      color: const Color(0xFF4A6489),
                                    ),
                                ],
                              ),
                            ],
                            if (_categories.isNotEmpty) ...[
                              _sheetSection(l10n.category),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildFilterChip(
                                    label: l10n.filterAll,
                                    isSelected: _categoryFilter == null,
                                    onSelected: () =>
                                        apply(() => _categoryFilter = null),
                                  ),
                                  for (final c in _categories)
                                    _buildFilterChip(
                                      label: l10n.categoryName(c),
                                      isSelected: _categoryFilter == c,
                                      onSelected: () =>
                                          apply(() => _categoryFilter = c),
                                      color: colors.brandAccent,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.brandAccent,
                            foregroundColor: const Color(0xFF14161F),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            l10n.commonDone,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Small grey group label inside the filter sheet.
  Widget _sheetSection(String text) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: colors.textTertiary,
        ),
      ),
    );
  }

  void _setType(TransactionType? type) {
    setState(() => _typeFilter = type);
    _loadTransactions();
  }

  void _setClass(_ClassFilter f) {
    setState(() => _classFilter = f);
    _loadTransactions();
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    final colors = AppColors.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: colors.background,
      // With no colour of its own, a selected chip wears the theme's accent at
      // the same strength the coloured ones use — the old fallback was a fixed
      // cream that only ever suited the light theme.
      selectedColor: (color ?? colors.brandAccent).withValues(alpha: 0.2),
      checkmarkColor: color ?? AppColors.of(context).brandAccent,
      labelStyle: TextStyle(
        color: isSelected
            ? (color ?? AppColors.of(context).brandAccent)
            : (colors.textSecondary),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  /// Compact month summary. It renders as the first list item so it scrolls
  /// away with the transactions instead of pinning above them.
  Widget _buildSummaryStrip(bool isDark) {
    final colors = AppColors.of(context);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final monthName = context.l10n.monthName(DateTime.now().month);
    final net = _monthlyCredits - _monthlyDebits;
    final netUp = net >= 0;
    final netColor =
        netUp ? const Color(0xFF4A6489) : const Color(0xFFD79A3C);
    final labelColor =
        colors.textSecondary;

    Widget cell(IconData icon, Color color, String label, String value) {
      return Expanded(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: labelColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget divider() => Container(
          width: 1,
          height: 34,
          color: colors.border,
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Text(
            '$monthName ${context.l10n.summaryWord}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              cell(
                Icons.arrow_downward_rounded,
                const Color(0xFF178A5B),
                context.l10n.commonIncome,
                formatter.format(_monthlyCredits),
              ),
              divider(),
              cell(
                Icons.arrow_upward_rounded,
                const Color(0xFFC94A50),
                context.l10n.commonExpenses,
                formatter.format(_monthlyDebits),
              ),
              divider(),
              cell(
                netUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                netColor,
                context.l10n.netLabel,
                formatter.format(net),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: colors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters
                ? context.l10n.noMatchingTransactions
                : context.l10n.noTransactionsYet,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters
                ? context.l10n.tryAdjustingFilters
                : context.l10n.txnsFromSmsAppearHere,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: Text(context.l10n.clearFilters),
            ),
          ],
        ],
      ),
    );
  }
}

/// Classification-status filter, independent of the credit/debit type filter.
enum _ClassFilter { all, classified, unclassified, needsReview }

/// Quick date-range presets for the transactions filter (plus a custom range).
enum _DatePreset { all, thisMonth, lastMonth, last7, last30, custom }
