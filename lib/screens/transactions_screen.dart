import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/bank_account_model.dart';
import '../services/database_service.dart';
import '../widgets/transaction_card.dart';
import 'transaction_detail_screen.dart';

/// Screen displaying all detected transactions with filtering
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<TransactionModel> _transactions = [];
  List<BankAccount> _bankAccounts = [];
  List<String> _categories = [];
  bool _isLoading = true;

  // Filters
  TransactionType? _typeFilter;
  String? _categoryFilter;
  int? _bankAccountFilter;
  bool _unclassifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadFiltersData();
    _loadTransactions();
  }

  Future<void> _loadFiltersData() async {
    try {
      final accounts = await _dbService.getAllBankAccounts();
      final categories = await _dbService.getUsedCategories();
      setState(() {
        _bankAccounts = accounts;
        _categories = categories;
      });
    } catch (e) {
      debugPrint('Error loading filter data: $e');
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await _dbService.getFilteredTransactions(
        type: _typeFilter,
        category: _categoryFilter,
        bankAccountId: _bankAccountFilter,
        unclassifiedOnly: _unclassifiedOnly ? true : null,
      );

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _typeFilter = null;
      _categoryFilter = null;
      _bankAccountFilter = null;
      _unclassifiedOnly = false;
    });
    _loadTransactions();
  }

  bool get _hasActiveFilters =>
      _typeFilter != null ||
      _categoryFilter != null ||
      _bankAccountFilter != null ||
      _unclassifiedOnly;

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    if (transaction.id == null) return;

    await _dbService.deleteTransaction(transaction.id!);
    await _loadTransactions();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Transactions'),
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
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          // Type filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  isSelected: _typeFilter == null && !_unclassifiedOnly,
                  onSelected: () {
                    setState(() {
                      _typeFilter = null;
                      _unclassifiedOnly = false;
                    });
                    _loadTransactions();
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Credits',
                  isSelected: _typeFilter == TransactionType.credit,
                  onSelected: () {
                    setState(() {
                      _typeFilter = TransactionType.credit;
                      _unclassifiedOnly = false;
                    });
                    _loadTransactions();
                  },
                  color: Colors.green,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Debits',
                  isSelected: _typeFilter == TransactionType.debit,
                  onSelected: () {
                    setState(() {
                      _typeFilter = TransactionType.debit;
                      _unclassifiedOnly = false;
                    });
                    _loadTransactions();
                  },
                  color: Colors.red,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Unclassified',
                  isSelected: _unclassifiedOnly,
                  onSelected: () {
                    setState(() {
                      _typeFilter = null;
                      _unclassifiedOnly = true;
                    });
                    _loadTransactions();
                  },
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Category & Bank filters
          if (_categories.isNotEmpty || _bankAccounts.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Category dropdown
                  if (_categories.isNotEmpty)
                    Expanded(
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

                  if (_categories.isNotEmpty && _bankAccounts.isNotEmpty)
                    const SizedBox(width: 12),

                  // Bank account dropdown
                  if (_bankAccounts.isNotEmpty)
                    Expanded(child: _buildBankDropdownFilter(isDark)),
                ],
              ),
            ),

          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ],
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
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
      selectedColor:
          color?.withOpacity(0.2) ??
          (isDark ? Colors.indigo.shade800 : Colors.indigo.shade100),
      checkmarkColor:
          color ?? (isDark ? Colors.indigo.shade200 : Colors.indigo.shade700),
      labelStyle: TextStyle(
        color: isSelected
            ? (color ??
                  (isDark ? Colors.indigo.shade200 : Colors.indigo.shade700))
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
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
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: isDark ? Colors.grey.shade400 : Colors.grey,
          ),
          dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                'All $hint',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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

  Widget _buildBankDropdownFilter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _bankAccountFilter,
          hint: Text(
            'Bank',
            style: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: isDark ? Colors.grey.shade400 : Colors.grey,
          ),
          dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'All Banks',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            ..._bankAccounts.map(
              (account) => DropdownMenuItem(
                value: account.id,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor:
                          account.color ??
                          BankCodes.getBankColor(account.bankCode),
                      child: Text(
                        account.bankCode.substring(0, 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      account.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => _bankAccountFilter = value);
            _loadTransactions();
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    double totalCredits = 0;
    double totalDebits = 0;

    for (final t in _transactions) {
      if (t.type == TransactionType.credit) {
        totalCredits += t.amount;
      } else {
        totalDebits += t.amount;
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Icon(
                  Icons.arrow_downward,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  'Income',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatter.format(totalCredits),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          Expanded(
            child: Column(
              children: [
                Icon(Icons.arrow_upward, color: Colors.red.shade600, size: 20),
                const SizedBox(height: 4),
                Text(
                  'Expenses',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatter.format(totalDebits),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          Expanded(
            child: Column(
              children: [
                Icon(
                  totalCredits >= totalDebits
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: totalCredits >= totalDebits
                      ? Colors.blue
                      : Colors.orange,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  'Net',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatter.format(totalCredits - totalDebits),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: totalCredits >= totalDebits
                        ? Colors.blue
                        : Colors.orange,
                  ),
                ),
              ],
            ),
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
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _hasActiveFilters
                ? 'No matching transactions'
                : 'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters
                ? 'Try adjusting your filters'
                : 'Transactions from bank SMS will appear here',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
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
