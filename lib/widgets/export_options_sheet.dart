import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/export_service.dart';

/// What the export sheet returns when the user taps Export.
class ExportRequest {
  final ExportFormat format;
  final ExportFilter filter;
  const ExportRequest(this.format, this.filter);
}

/// Bottom sheet for choosing an export format and filters (date range,
/// type, categories, merchant/payee). Pops an [ExportRequest] or null.
class ExportOptionsSheet extends StatefulWidget {
  const ExportOptionsSheet({super.key});

  @override
  State<ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<ExportOptionsSheet> {
  ExportFormat _format = ExportFormat.excel;
  DateTimeRange? _dateRange;
  final Set<TransactionType> _types = {};
  final Set<String> _categories = {};
  final TextEditingController _merchant = TextEditingController();

  @override
  void dispose() {
    _merchant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final categories = [...ExpenseCategories.allCategories, 'Uncategorized'];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Export Data',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 18),

            _label('Format'),
            const SizedBox(height: 8),
            Row(
              children: [
                _formatChip(ExportFormat.excel, 'Excel', Icons.grid_on, colors),
                const SizedBox(width: 8),
                _formatChip(
                    ExportFormat.csv, 'CSV', Icons.description_outlined, colors),
                const SizedBox(width: 8),
                _formatChip(ExportFormat.text, 'Text', Icons.notes, colors),
              ],
            ),
            const SizedBox(height: 20),

            _label('Date Range'),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dateRange == null
                            ? 'All time'
                            : '${DateFormat('dd MMM yyyy').format(_dateRange!.start)}  →  '
                                '${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
                        style: TextStyle(color: colors.text, fontSize: 14),
                      ),
                    ),
                    if (_dateRange != null)
                      GestureDetector(
                        onTap: () => setState(() => _dateRange = null),
                        child: Icon(Icons.close, size: 18, color: colors.textTertiary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _label('Type'),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip(null, 'All', colors),
                const SizedBox(width: 8),
                _typeChip(TransactionType.debit, 'Expenses', colors),
                const SizedBox(width: 8),
                _typeChip(TransactionType.credit, 'Income', colors),
              ],
            ),
            const SizedBox(height: 20),

            _label('Payee / Merchant contains'),
            const SizedBox(height: 8),
            TextField(
              controller: _merchant,
              decoration: const InputDecoration(
                hintText: 'e.g. Swiggy, Amazon (leave blank for all)',
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label(_categories.isEmpty
                    ? 'Categories (all)'
                    : 'Categories (${_categories.length})'),
                if (_categories.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(_categories.clear),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final selected = _categories.contains(c);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _categories.remove(c);
                    } else {
                      _categories.add(c);
                    }
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.accent.withOpacity(0.14)
                          : colors.cardAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? colors.accent : colors.border,
                      ),
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? colors.accent : colors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  ExportRequest(
                    _format,
                    ExportFilter(
                      dateRange: _dateRange,
                      types: Set.of(_types),
                      categories: Set.of(_categories),
                      merchantQuery: _merchant.text,
                    ),
                  ),
                ),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Export'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    final colors = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: colors.textSecondary,
      ),
    );
  }

  Widget _formatChip(
      ExportFormat fmt, String label, IconData icon, AppColors colors) {
    final selected = _format == fmt;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _format = fmt),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.accent.withOpacity(0.14) : colors.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20, color: selected ? colors.accent : colors.textSecondary),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.accent : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(TransactionType? type, String label, AppColors colors) {
    final selected =
        type == null ? _types.isEmpty : (_types.length == 1 && _types.contains(type));
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _types.clear();
          if (type != null) _types.add(type);
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.accent.withOpacity(0.14) : colors.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.accent : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }
}
