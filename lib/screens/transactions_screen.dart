import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      double mCredits = 0, mDebits = 0;
      for (final t in allMonthTxns) {
        if (t.type == TransactionType.credit) {
          mCredits += t.amount;
        } else {
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
      _searchQuery = '';
      _searchController.clear();
    });
    _loadTransactions();
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
          message: "Transaction deleted — it won't return on the next scan",
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
    if (_startDate != null && _typeFilter != null) {
      final monthName = DateFormat('MMMM').format(_startDate!);
      if (_typeFilter == TransactionType.credit) {
        return '$monthName Income';
      } else {
        return '$monthName Expenses';
      }
    }
    return 'Transactions';
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
              tooltip: 'Clear filters',
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
        label: const Text('Add'),
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
                hintText: 'Search by payee, amount, or date',
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
                _typeRowLabel('Type', isDark),
                const SizedBox(width: 10),
                _buildFilterChip(
                  label: 'All',
                  isSelected: _typeFilter == null,
                  onSelected: () => _setType(null),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Credits',
                  isSelected: _typeFilter == TransactionType.credit,
                  onSelected: () => _setType(TransactionType.credit),
                  color: const Color(0xFF2AA76F),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Debits',
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
                _typeRowLabel('Status', isDark),
                const SizedBox(width: 10),
                _buildFilterChip(
                  label: 'All',
                  isSelected: _classFilter == _ClassFilter.all,
                  onSelected: () => _setClass(_ClassFilter.all),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Classified',
                  isSelected: _classFilter == _ClassFilter.classified,
                  onSelected: () => _setClass(_ClassFilter.classified),
                  color: const Color(0xFF4A6489),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Unclassified',
                  isSelected: _classFilter == _ClassFilter.unclassified,
                  onSelected: () => _setClass(_ClassFilter.unclassified),
                  color: const Color(0xFFD79A3C),
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
                hint: 'Category',
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
                'All $hint',
                style: TextStyle(
                  color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
                ),
              ),
            ),
            ...items.map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(
                  item,
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
    final monthName = DateFormat('MMMM').format(DateTime.now());

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
              '$monthName Summary',
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
                      'Income',
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
                      'Expenses',
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
                      'Net',
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
                ? 'No matching transactions'
                : 'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Color(0xFF9A9DA6) : Color(0xFF6E727C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters
                ? 'Try adjusting your filters'
                : 'Transactions from bank SMS will appear here',
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
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Classification-status filter, independent of the credit/debit type filter.
enum _ClassFilter { all, classified, unclassified }
