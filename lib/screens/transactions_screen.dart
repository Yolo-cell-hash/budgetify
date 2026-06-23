import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    _loadFiltersData();
    _loadTransactions();
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
            message: 'Error loading transactions: $e',
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
          // Filter section
          _buildFilterSection(isDark),

          // Summary card
          if (!_isLoading && _transactions.isNotEmpty)
            _buildSummaryCard(isDark),

          // Transactions list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                ? _buildEmptyState(isDark)
                : RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _transactions[index];
                        return TransactionCard(
                          transaction: transaction,
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

  Widget _buildFilterSection(bool isDark) {
    final colors = AppColors.of(context);
    return Container(
      color: isDark ? const Color(0xFF121318) : Colors.white,
      child: Column(
        children: [
          // Search bar — matches payee/merchant, amount, or date
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          // Type filter row (All / Credits / Debits) — independent of status
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _typeRowLabel(context.l10n.filterType, isDark),
                const SizedBox(width: 10),
                _buildFilterChip(
                  label: context.l10n.filterAll,
                  isSelected: _typeFilter == null,
                  onSelected: () => _setType(null),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: context.l10n.credits,
                  isSelected: _typeFilter == TransactionType.credit,
                  onSelected: () => _setType(TransactionType.credit),
                  color: const Color(0xFF2AA76F),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: context.l10n.debits,
                  isSelected: _typeFilter == TransactionType.debit,
                  onSelected: () => _setType(TransactionType.debit),
                  color: const Color(0xFFD25A5F),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          // Status filter row (All / Classified / Unclassified) — combines
          // with the type filter above
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                _typeRowLabel(context.l10n.filterStatus, isDark),
                const SizedBox(width: 10),
                _buildFilterChip(
                  label: context.l10n.filterAll,
                  isSelected: _classFilter == _ClassFilter.all,
                  onSelected: () => _setClass(_ClassFilter.all),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: context.l10n.classified,
                  isSelected: _classFilter == _ClassFilter.classified,
                  onSelected: () => _setClass(_ClassFilter.classified),
                  color: const Color(0xFF4A6489),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: context.l10n.unclassified,
                  isSelected: _classFilter == _ClassFilter.unclassified,
                  onSelected: () => _setClass(_ClassFilter.unclassified),
                  color: const Color(0xFFD79A3C),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Date filter row (All / This month / Last month / Last 7 / Last 30
          // / Custom range) — combines with every other filter.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _typeRowLabel(context.l10n.dateLabel, isDark),
                const SizedBox(width: 10),
                _buildFilterChip(
                  label: context.l10n.filterAll,
                  isSelected: _datePreset == _DatePreset.all,
                  onSelected: () => _applyDatePreset(_DatePreset.all),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: context.l10n.thisMonth,
                  isSelected: _datePreset == _DatePreset.thisMonth,
                  onSelected: () => _applyDatePreset(_DatePreset.thisMonth),
                  color: const Color(0xFF4A6489),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: context.l10n.lastMonth,
                  isSelected: _datePreset == _DatePreset.lastMonth,
                  onSelected: () => _applyDatePreset(_DatePreset.lastMonth),
                  color: const Color(0xFF4A6489),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: context.l10n.lastNDays(7),
                  isSelected: _datePreset == _DatePreset.last7,
                  onSelected: () => _applyDatePreset(_DatePreset.last7),
                  color: const Color(0xFF4A6489),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: context.l10n.lastNDays(30),
                  isSelected: _datePreset == _DatePreset.last30,
                  onSelected: () => _applyDatePreset(_DatePreset.last30),
                  color: const Color(0xFF4A6489),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: _customChipLabel,
                  isSelected: _datePreset == _DatePreset.custom,
                  onSelected: _pickCustomRange,
                  color: const Color(0xFFA8843C),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Category filter
          if (_categories.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildDropdownFilter(
                value: _categoryFilter,
                hint: context.l10n.category,
                items: _categories,
                onChanged: (value) {
                  setState(() => _categoryFilter = value);
                  _loadTransactions();
                },
                isDark: isDark,
              ),
            ),

          Divider(
            height: 1,
            color: isDark ? Color(0xFF2E313A) : Color(0xFFE9E9E4),
          ),
        ],
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

  Widget _typeRowLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFF6E727C) : const Color(0xFF8A8D96),
      ),
    );
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
      checkmarkColor:
          color ?? (isDark ? Color(0xFFD8BC7E) : Color(0xFFA8843C)),
      labelStyle: TextStyle(
        color: isSelected
            ? (color ??
                  (isDark ? Color(0xFFD8BC7E) : Color(0xFFA8843C)))
            : (isDark ? Color(0xFF9A9DA6) : Color(0xFF4E525C)),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181E) : Color(0xFFF6F6F3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
            ),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: isDark ? Color(0xFF9A9DA6) : Color(0xFF8A8D96),
          ),
          dropdownColor: isDark ? const Color(0xFF16181E) : Colors.white,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                context.l10n.allOfFilter(hint),
                style: TextStyle(
                  color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
                ),
              ),
            ),
            ...items.map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(
                  context.l10n.categoryName(item),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final monthName = context.l10n.monthName(DateTime.now().month);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
          // "This Month" label
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '$monthName ${context.l10n.summaryWord}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      color: Color(0xFF178A5B),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.commonIncome,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatter.format(_monthlyCredits),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF178A5B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: isDark ? Color(0xFF2E313A) : Color(0xFFE9E9E4),
              ),
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      color: Color(0xFFC94A50),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.commonExpenses,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatter.format(_monthlyDebits),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC94A50),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: isDark ? Color(0xFF2E313A) : Color(0xFFE9E9E4),
              ),
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      _monthlyCredits >= _monthlyDebits
                          ? Icons.trending_up
                          : Icons.trending_down,
                      color: _monthlyCredits >= _monthlyDebits
                          ? Color(0xFF4A6489)
                          : Color(0xFFD79A3C),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.netLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Color(0xFF8A8D96) : Color(0xFF6E727C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatter.format(_monthlyCredits - _monthlyDebits),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _monthlyCredits >= _monthlyDebits
                            ? Color(0xFF4A6489)
                            : Color(0xFFD79A3C),
                      ),
                    ),
                  ],
                ),
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
