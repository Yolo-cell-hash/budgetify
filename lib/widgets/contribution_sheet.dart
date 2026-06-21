import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../providers/theme_provider.dart';

typedef ContributionInput = ({double amount, DateTime date, String? note});

/// Add money toward a goal. [remaining] pre-fills a "complete it" shortcut.
Future<ContributionInput?> showContributionSheet(
  BuildContext context, {
  required double remaining,
}) {
  return showModalBottomSheet<ContributionInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContributionSheet(remaining: remaining),
  );
}

class _ContributionSheet extends StatefulWidget {
  final double remaining;
  const _ContributionSheet({required this.remaining});

  @override
  State<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends State<_ContributionSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid => (double.tryParse(_amount.text.trim()) ?? 0) > 0;

  void _save() {
    Navigator.pop(
      context,
      (
        amount: double.parse(_amount.text.trim()),
        date: _date,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final quick = [500.0, 1000.0, 5000.0];

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: colors.border),
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
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add to goal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final q in quick)
                  ActionChip(
                    label: Text('+${fmt.format(q)}'),
                    onPressed: () => setState(() => _amount.text = q.toStringAsFixed(0)),
                  ),
                if (widget.remaining > 0)
                  ActionChip(
                    label: Text('Complete (${fmt.format(widget.remaining)})'),
                    onPressed: () =>
                        setState(() => _amount.text = widget.remaining.toStringAsFixed(0)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2015),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _valid ? _save : null,
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
