import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../widgets/app_bar_title.dart';

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _category = widget.initialCategory!;
    }
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
      sender: context.l10nRead.manualEntry,
      message: _notesController.text.isEmpty
          ? context.l10nRead.manuallyAddedTxn
          : _notesController.text,
      detectedAt: _date,
      isClassified: true,
      category: _category,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      isManual: true,
    );

    await _db.insertTransaction(transaction);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.addTransactionTitle,
            icon: Icons.add_card_rounded),
      ),
      body: SafeArea(child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Transaction Type Toggle
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16181E) : Color(0xFFF6F6F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      TransactionType.debit,
                      '💸 ${context.l10n.expenseWord}',
                      Color(0xFFD25A5F),
                    ),
                  ),
                  Expanded(
                    child: _buildTypeButton(
                      TransactionType.credit,
                      '💰 ${context.l10n.commonIncome}',
                      Color(0xFF2AA76F),
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
                fillColor: isDark
                    ? const Color(0xFF16181E)
                    : Color(0xFFFAFAF8),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return context.l10nRead.enterAmount;
                if (double.tryParse(v) == null) {
                  return context.l10nRead.invalidAmount;
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: context.l10n.category,
                prefixIcon: const Icon(Icons.category_outlined),
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
                          Text(context.l10n.categoryName(c)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
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
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF262931)
                      : Color(0xFF9A9DA6),
                ),
              ),
              leading: const Icon(Icons.calendar_today),
              title: Text(context.l10n.dateLabel),
              subtitle: Text(context.l10n.fullDate(_date)),
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
                labelText: context.l10n.notesOptional,
                hintText: context.l10n.addDescriptionHint,
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
                      ? Color(0xFFD25A5F)
                      : Color(0xFF2AA76F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        context.l10n
                            .saveTxnLabel(_type == TransactionType.debit),
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
            color: selected ? Colors.white : Color(0xFF8A8D96),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
