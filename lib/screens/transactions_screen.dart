import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_screen.dart';
import 'add_transaction_screen.dart';

/// Screen displaying all detected transactions with filtering
class TransactionsScreen extends StatefulWidget {
  final bool initialUnclassifiedOnly;
  final TransactionType? initialTypeFilter;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const TransactionsScreen({
    super.key,
    this.initialUnclassifiedOnly = false,
    this.initialTypeFilter,
    this.initialStartDate,
    this.initialEndDate,
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

  @override
  void initState() {
    super.initState();
    _classFilter = widget.initialUnclassifiedOnly
        ? _ClassFilter.unclassified
        : _ClassFilter.all;
    _typeFilter = widget.initialTypeFilter;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _datePreset =
        widget.initialStartDate != null ? _DatePreset.custom : _DatePreset.all;
    _loadSwipeHintFlag();
    _loadFiltersData();
    _loadTransactions();
  }

  Future<void> _loadSwipeHintFlag() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (!(prefs.getBool(_swipeHintKey) ?? false)) {
      setState(() => _showSwipeHint = true);
    }
  }

  Future<void> _markSwipeHintShown() async {
    _showSwipeHint = false; // stop re-triggering on later rebuilds
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_swipeHintKey, true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Match a transaction against the free-text query. A transaction matches
  /// if the query appears in its merchant/payee/category, in its formatted
  /// date, or — when the query is numeric — in its amount.
  bool _matchesSearch(TransactionModel t) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

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
    if (haystack.toString().toLowerCase().contains(q)) return true;

    // Numeric query → match against the amount (with and without paise)
    final digits = q.replaceAll(RegExp(r'[^0-9.]'), '');
    if (digits.isNotEmpty) {
      if (t.amount.toStringAsFixed(2).contains(digits)) return true;
      if (t.amount.toStringAsFixed(0).contains(digits)) return true;
    }
    return false;
  }

  Future<void> _loadFiltersData() async {
    try {
      final categories = await _dbService.getUsedCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      debugPrint('Error loading filter data: $e');
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      var transactions = await _dbService.getFilteredTransactions(
        type: _typeFilter,
        category: _categoryFilter,
        classified: switch (_classFilter) {
          _ClassFilter.all => null,
          _ClassFilter.classified => true,
          _ClassFilter.unclassified => false,
        },
      );

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
          mDebits += t.amount;
        }
      }

      setState(() {
        _transactions = transactions;
        _monthlyCredits = mCredits;
        _monthlyDebits = mDebits;
        _isLoading = false;
      });
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
      (_categoryFilter != null ? 1 : 0);

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

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    if (transaction.id == null) return;

    await _dbService.deleteTransaction(transaction.id!);
    await _loadTransactions();

    if (mounted) {
      showAppToast(context,
          message: context.l10nRead.txnDeletedToast,
          type: AppToastType.info);
    }
  }

  void _openTransactionDetail(TransactionModel transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(transaction: transaction),
      ),
    );

    if (result == true) {
      _loadTransactions();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0B0E) : Color(0xFFF6F6F3),
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              onPressed: _clearFilters,
              tooltip: context.l10n.clearFilters,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          if (result == true) _loadTransactions();
        },
        icon: const Icon(Icons.add),
        label: Text(context.l10n.add),
      ),
      body: Column(
        children: [
          // Compact pinned chrome: one search row (with the filter-sheet
          // button), plus a slim strip of removable chips only while filters
          // are active — the list keeps the rest of the screen.
          _buildHeader(isDark),

          // Transactions list (the month summary scrolls away with it)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                ? _buildEmptyState(isDark)
                : RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 80),
                      itemCount: _transactions.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildSummaryStrip(isDark);
                        final transaction = _transactions[index - 1];
                        return TransactionCard(
                          transaction: transaction,
                          animateSwipeHint: index == 1 && _showSwipeHint,
                          onSwipeHintShown: _markSwipeHintShown,
                          onTap: () => _openTransactionDetail(transaction),
                          onDelete: () => _deleteTransaction(transaction),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// The compact pinned chrome: a single search row beside the filter-sheet
  /// button, plus (only while filters are active) one slim row of removable
  /// chips. All other filter controls live in [_openFilterSheet], so the
  /// transaction list keeps almost the whole screen.
  Widget _buildHeader(bool isDark) {
    final colors = AppColors.of(context);
    return Container(
      color: isDark ? const Color(0xFF121318) : Colors.white,
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
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
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
          if (_activeFilterCount > 0) _buildActiveFiltersStrip(isDark),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF2E313A) : const Color(0xFFE9E9E4),
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
          ? accent.withOpacity(isDark ? 0.18 : 0.14)
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
              color: active > 0 ? accent.withOpacity(0.55) : colors.border,
            ),
          ),
          child: Tooltip(
            message: context.l10n.filtersTitle,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune,
                  size: 20,
                  color: active > 0
                      ? accent
                      : (isDark
                          ? const Color(0xFF9A9DA6)
                          : const Color(0xFF4E525C)),
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
          label: _typeFilter == TransactionType.credit
              ? l10n.credits
              : l10n.debits,
          color: _typeFilter == TransactionType.credit
              ? const Color(0xFF2AA76F)
              : const Color(0xFFD25A5F),
          isDark: isDark,
          onRemove: () => _setType(null),
        ),
      if (_classFilter != _ClassFilter.all)
        _activeFilterChip(
          label: _classFilter == _ClassFilter.classified
              ? l10n.classified
              : l10n.unclassified,
          color: _classFilter == _ClassFilter.classified
              ? const Color(0xFF4A6489)
              : const Color(0xFFD79A3C),
          isDark: isDark,
          onRemove: () => _setClass(_ClassFilter.all),
        ),
      if (_datePreset != _DatePreset.all || _startDate != null)
        _activeFilterChip(
          label: _dateFilterLabel,
          color: const Color(0xFF4A6489),
          isDark: isDark,
          onRemove: () => _applyDatePreset(_DatePreset.all),
        ),
      if (_categoryFilter != null)
        _activeFilterChip(
          label: l10n.categoryName(_categoryFilter!),
          color: AppColors.of(context).brandAccent,
          isDark: isDark,
          onRemove: () {
            setState(() => _categoryFilter = null);
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
    required bool isDark,
    required VoidCallback onRemove,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.45), width: 0.8),
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
            Icon(Icons.close, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  /// Every filter control (Type, Status, Date, Category) as chip groups in a
  /// premium bottom sheet. Selections apply immediately, so the list updates
  /// live behind the sheet.
  Future<void> _openFilterSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF121318) : Colors.white,
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
                        color: isDark
                            ? const Color(0xFF2E313A)
                            : const Color(0xFFE9E9E4),
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
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1B1E28),
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
                            _sheetSection(l10n.filterType, isDark),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  label: l10n.filterAll,
                                  isSelected: _typeFilter == null,
                                  onSelected: () =>
                                      apply(() => _typeFilter = null),
                                  isDark: isDark,
                                ),
                                _buildFilterChip(
                                  label: l10n.credits,
                                  isSelected:
                                      _typeFilter == TransactionType.credit,
                                  onSelected: () => apply(() =>
                                      _typeFilter = TransactionType.credit),
                                  color: const Color(0xFF2AA76F),
                                  isDark: isDark,
                                ),
                                _buildFilterChip(
                                  label: l10n.debits,
                                  isSelected:
                                      _typeFilter == TransactionType.debit,
                                  onSelected: () => apply(() =>
                                      _typeFilter = TransactionType.debit),
                                  color: const Color(0xFFD25A5F),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            _sheetSection(l10n.filterStatus, isDark),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFilterChip(
                                  label: l10n.filterAll,
                                  isSelected: _classFilter == _ClassFilter.all,
                                  onSelected: () => apply(
                                      () => _classFilter = _ClassFilter.all),
                                  isDark: isDark,
                                ),
                                _buildFilterChip(
                                  label: l10n.classified,
                                  isSelected:
                                      _classFilter == _ClassFilter.classified,
                                  onSelected: () => apply(() =>
                                      _classFilter = _ClassFilter.classified),
                                  color: const Color(0xFF4A6489),
                                  isDark: isDark,
                                ),
                                _buildFilterChip(
                                  label: l10n.unclassified,
                                  isSelected:
                                      _classFilter == _ClassFilter.unclassified,
                                  onSelected: () => apply(() => _classFilter =
                                      _ClassFilter.unclassified),
                                  color: const Color(0xFFD79A3C),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            _sheetSection(l10n.dateLabel, isDark),
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
                                    isDark: isDark,
                                  ),
                                _buildFilterChip(
                                  label: _customChipLabel,
                                  isSelected: _datePreset == _DatePreset.custom,
                                  onSelected: () async {
                                    await _pickCustomRange();
                                    setSheetState(() {});
                                  },
                                  color: colors.brandAccent,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            if (_categories.isNotEmpty) ...[
                              _sheetSection(l10n.category, isDark),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildFilterChip(
                                    label: l10n.filterAll,
                                    isSelected: _categoryFilter == null,
                                    onSelected: () =>
                                        apply(() => _categoryFilter = null),
                                    isDark: isDark,
                                  ),
                                  for (final c in _categories)
                                    _buildFilterChip(
                                      label: l10n.categoryName(c),
                                      isSelected: _categoryFilter == c,
                                      onSelected: () =>
                                          apply(() => _categoryFilter = c),
                                      color: colors.brandAccent,
                                      isDark: isDark,
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
  Widget _sheetSection(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: isDark ? const Color(0xFF6E727C) : const Color(0xFF8A8D96),
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
    required bool isDark,
    Color? color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: isDark ? const Color(0xFF16181E) : Color(0xFFF6F6F3),
      selectedColor:
          color?.withOpacity(0.2) ??
          (isDark ? const Color(0xFF16181E) : Color(0xFFEFE6D2)),
      checkmarkColor: color ?? AppColors.of(context).brandAccent,
      labelStyle: TextStyle(
        color: isSelected
            ? (color ?? AppColors.of(context).brandAccent)
            : (isDark ? Color(0xFF9A9DA6) : Color(0xFF4E525C)),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  /// Compact month summary. It renders as the first list item so it scrolls
  /// away with the transactions instead of pinning above them.
  Widget _buildSummaryStrip(bool isDark) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final monthName = context.l10n.monthName(DateTime.now().month);
    final net = _monthlyCredits - _monthlyDebits;
    final netUp = net >= 0;
    final netColor =
        netUp ? const Color(0xFF4A6489) : const Color(0xFFD79A3C);
    final labelColor =
        isDark ? const Color(0xFF8A8D96) : const Color(0xFF6E727C);

    Widget cell(IconData icon, Color color, String label, String value) {
      return Expanded(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
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
          color: isDark ? const Color(0xFF2E313A) : const Color(0xFFE9E9E4),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
              color: isDark ? const Color(0xFF6E727C) : const Color(0xFF8A8D96),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              cell(
                Icons.arrow_downward,
                const Color(0xFF178A5B),
                context.l10n.commonIncome,
                formatter.format(_monthlyCredits),
              ),
              divider(),
              cell(
                Icons.arrow_upward,
                const Color(0xFFC94A50),
                context.l10n.commonExpenses,
                formatter.format(_monthlyDebits),
              ),
              divider(),
              cell(
                netUp ? Icons.trending_up : Icons.trending_down,
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: isDark ? Color(0xFF4E525C) : Color(0xFFD5D5CF),
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters
                ? context.l10n.noMatchingTransactions
                : context.l10n.noTransactionsYet,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters
                ? context.l10n.tryAdjustingFilters
                : context.l10n.txnsFromSmsAppearHere,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Color(0xFF6E727C) : Color(0xFF9A9DA6),
            ),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: Text(context.l10n.clearFilters),
            ),
          ],
        ],
      ),
    );
  }
}

/// Classification-status filter, independent of the credit/debit type filter.
enum _ClassFilter { all, classified, unclassified }

/// Quick date-range presets for the transactions filter (plus a custom range).
enum _DatePreset { all, thisMonth, lastMonth, last7, last30, custom }
