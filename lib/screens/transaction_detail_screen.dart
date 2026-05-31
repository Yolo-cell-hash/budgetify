import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/transaction_rule_model.dart';
import '../services/database_service.dart';

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

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _selectedCategory = _transaction.category;
    _notesController.text = _transaction.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Display name for the merchant/payee used in dialogs
  String get _merchantDisplayName {
    return _transaction.merchantName ?? _transaction.sender;
  }

  Future<void> _saveClassification() async {
    if (_transaction.id == null || _selectedCategory == null) return;

    setState(() => _isSaving = true);

    try {
      final updatedTransaction = _transaction.copyWith(
        category: _selectedCategory,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        isClassified: true,
      );

      await _dbService.updateTransaction(updatedTransaction);

      if (mounted) {
        // Show bulk flagging options dialog
        await _showBulkFlaggingDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _showBulkFlaggingDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C2333) : Colors.white;
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
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Apply to Similar Transactions?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Found transactions for "$_merchantDisplayName". How would you like to classify them?',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _buildOption(
              ctx,
              icon: Icons.select_all,
              title: 'Apply to All',
              subtitle: 'Classify all existing & auto-flag future transactions',
              value: 1,
              color: Colors.green,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildOption(
              ctx,
              icon: Icons.history,
              title: 'Apply to Existing Only',
              subtitle:
                  'Classify existing transactions, flag future ones manually',
              value: 2,
              color: Colors.orange,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildOption(
              ctx,
              icon: Icons.touch_app,
              title: 'Only This One',
              subtitle: 'Tag only this transaction, handle others manually',
              value: 3,
              color: Colors.blue,
              isDark: isDark,
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await _processBulkFlagging(result);
    } else if (mounted) {
      // User dismissed the dialog — transaction was already saved above,
      // so pop with true to signal the calling screen to refresh.
      Navigator.pop(context, true);
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
    final cardBg = isDark ? const Color(0xFF2D3748) : Colors.grey.shade50;
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
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
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
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
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

    String message = 'Transaction saved';

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
          final typeStr = transactionType == TransactionType.debit
              ? 'debits'
              : 'credits';
          message = 'Updated $updatedCount similar $typeStr';
        } else {
          message = 'Transaction saved (no merchant to match)';
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
          final typeStr = transactionType == TransactionType.debit
              ? 'debits'
              : 'credits';
          message +=
              ' • Future $typeStr from "$_merchantDisplayName" will be auto-classified';
        }
      }
      // Option 2: Just bulk update, no rule for future (already handled above)
      // Option 3: Only this one transaction (no bulk update, no rule)

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCredit = _transaction.type == TransactionType.credit;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormatter = DateFormat('EEEE, MMMM d, y • h:mm a');

    final bgColor = isDark ? const Color(0xFF0D1117) : Colors.grey.shade100;
    final cardColor = isDark ? const Color(0xFF1C2333) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final chipBgUnselected = isDark
        ? const Color(0xFF2D3748)
        : Colors.grey.shade50;
    final chipBorderUnselected = isDark
        ? const Color(0xFF3D4758)
        : Colors.grey.shade200;
    final inputBgColor = isDark ? const Color(0xFF2D3748) : Colors.grey.shade50;
    final messageBgColor = isDark
        ? const Color(0xFF161B22)
        : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Transaction Details'),
        backgroundColor: cardColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
                          ? Colors.green.withAlpha(26)
                          : Colors.red.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isCredit ? Colors.green : Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${isCredit ? '+' : '-'} ${formatter.format(_transaction.amount)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCredit
                          ? Colors.green.withAlpha(26)
                          : Colors.red.withAlpha(26),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _transaction.type.displayName,
                      style: TextStyle(
                        color: isCredit ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    'Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'From',
                    _transaction.sender,
                    subtextColor,
                    textColor,
                  ),
                  if (_transaction.merchantName != null)
                    _buildDetailRow(
                      'Payee',
                      _transaction.merchantName!,
                      subtextColor,
                      textColor,
                    ),
                  if (_transaction.accountInfo != null)
                    _buildDetailRow(
                      'Account',
                      _transaction.accountInfo!,
                      subtextColor,
                      textColor,
                    ),
                  Divider(
                    height: 24,
                    color: isDark ? Colors.grey.shade700 : null,
                  ),
                  Text(
                    'Original Message',
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

            // Category section
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
                  Row(
                    children: [
                      Text(
                        'Category',
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
                            color: Colors.orange.withAlpha(26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Unclassified',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
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
                    children: ExpenseCategories.categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = isSelected ? null : category;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                      ? Colors.blue.shade900.withAlpha(150)
                                      : Colors.blue.shade50)
                                : chipBgUnselected,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue.shade300
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
                                category,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? (isDark
                                            ? Colors.blue.shade200
                                            : Colors.blue.shade700)
                                      : (isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade700),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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
                    'Notes',
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
                      hintText: 'Add notes about this transaction...',
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

            // Save button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: (_isSaving || _selectedCategory == null)
                    ? null
                    : _saveClassification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
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
                    : const Text(
                        'Save Classification',
                        style: TextStyle(
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
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color subtextColor,
    Color textColor,
  ) {
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
        ],
      ),
    );
  }
}
