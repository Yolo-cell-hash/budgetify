import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/bank_account_model.dart';
import '../services/database_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? initialCategory;

  const AddTransactionScreen({super.key, this.initialCategory});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final DatabaseService _db = DatabaseService();

  TransactionType _type = TransactionType.debit;
  String _category = 'Other';
  DateTime _date = DateTime.now();
  int? _bankAccountId;
  List<BankAccount> _bankAccounts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _category = widget.initialCategory!;
    }
    _loadBankAccounts();
  }

  Future<void> _loadBankAccounts() async {
    final accounts = await _db.getAllBankAccounts();
    setState(() => _bankAccounts = accounts);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final amount = double.parse(_amountController.text);
    final transaction = TransactionModel(
      amount: amount,
      type: _type,
      sender: 'Manual Entry',
      message: _notesController.text.isEmpty
          ? 'Manually added transaction'
          : _notesController.text,
      detectedAt: _date,
      isClassified: true,
      category: _category,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      bankAccountId: _bankAccountId,
      isManual: true,
    );

    await _db.insertTransaction(transaction);

    // Update bank balance if linked
    if (_bankAccountId != null) {
      final account = _bankAccounts.firstWhere((a) => a.id == _bankAccountId);
      final newBalance = _type == TransactionType.credit
          ? account.currentBalance + amount
          : account.currentBalance - amount;
      await _db.updateBankAccount(account.copyWith(currentBalance: newBalance));
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Transaction Type Toggle
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      TransactionType.debit,
                      '💸 Expense',
                      Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _buildTypeButton(
                      TransactionType.credit,
                      '💰 Income',
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if (double.tryParse(v) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: Text(
                  ExpenseCategories.getIcon(_category),
                  style: const TextStyle(fontSize: 24),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: ExpenseCategories.categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Text(ExpenseCategories.getIcon(c)),
                          const SizedBox(width: 12),
                          Text(c),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),

            // Bank Account
            if (_bankAccounts.isNotEmpty)
              DropdownButtonFormField<int?>(
                value: _bankAccountId,
                decoration: InputDecoration(
                  labelText: 'Bank Account (Optional)',
                  prefixIcon: const Icon(Icons.account_balance),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No Bank Account'),
                  ),
                  ..._bankAccounts.map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name} (${a.bankCode})'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _bankAccountId = v),
              ),
            const SizedBox(height: 16),

            // Date Picker
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add a description...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == TransactionType.debit
                      ? Colors.red
                      : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Save ${_type == TransactionType.debit ? 'Expense' : 'Income'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(TransactionType type, String label, Color color) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
