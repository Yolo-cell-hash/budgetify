import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/recurring_payment.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';

/// Create or edit a recurring payment. Returns the built [RecurringPayment]
/// (unsaved — the caller persists it), or null if cancelled.
///
/// Pass [existing] to edit, or [template] to pre-fill a new plan (e.g. from a
/// transaction's "Track as recurring", or a detected-subscription suggestion).
Future<RecurringPayment?> showRecurringEditor(
  BuildContext context, {
  RecurringPayment? existing,
  RecurringPayment? template,
}) {
  return showModalBottomSheet<RecurringPayment>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecurringEditorSheet(existing: existing, template: template),
  );
}

class _RecurringEditorSheet extends StatefulWidget {
  final RecurringPayment? existing;
  final RecurringPayment? template;
  const _RecurringEditorSheet({this.existing, this.template});

  @override
  State<_RecurringEditorSheet> createState() => _RecurringEditorSheetState();
}

class _RecurringEditorSheetState extends State<_RecurringEditorSheet> {
  RecurringPayment? get _base => widget.existing ?? widget.template;

  late final TextEditingController _name =
      TextEditingController(text: _base?.name ?? '');
  late final TextEditingController _amount = TextEditingController(
    text: (_base?.amount == null) ? '' : _base!.amount!.toStringAsFixed(0),
  );
  late bool _varies = _base == null ? false : !_base!.amountIsFixed;
  late String _category = _base?.category ?? 'Bills & Utilities';
  late RecurringCadence _cadence = _base?.cadence ?? RecurringCadence.monthly;
  late DateTime _anchor = _dateOnly(_base?.anchorDate ?? _defaultAnchor());
  late DateTime? _endDate = _base?.endDate;
  late bool _autoMatch = _base?.autoMatch ?? true;
  late int _leadDays = _base?.reminderLeadDays ?? 2;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _defaultAnchor() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_name.text.trim().isEmpty) return false;
    if (_varies) return true;
    return (double.tryParse(_amount.text.trim()) ?? 0) > 0;
  }

  void _save() {
    final amt = _varies ? null : double.tryParse(_amount.text.trim());
    final now = DateTime.now();
    final result = RecurringPayment(
      id: widget.existing?.id,
      name: _name.text.trim(),
      category: _category,
      amount: amt,
      amountIsFixed: !_varies,
      cadence: _cadence,
      dayOfMonth: _anchor.day,
      anchorDate: _anchor,
      endDate: _endDate,
      autoMatch: _autoMatch,
      matchHint: widget.existing?.matchHint ??
          widget.template?.matchHint ??
          _name.text.trim(),
      reminderLeadDays: _leadDays,
      paused: widget.existing?.paused ?? false,
      lastReminderPeriod: widget.existing?.lastReminderPeriod,
      note: _base?.note,
      createdAt: widget.existing?.createdAt ?? now,
    );
    Navigator.pop(context, result);
  }

  Future<void> _pickAnchor() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _anchor = _dateOnly(picked));
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _anchor,
      firstDate: _anchor,
      lastDate: DateTime(_anchor.year + 30),
    );
    if (picked != null) setState(() => _endDate = _dateOnly(picked));
  }

  String _cadenceLabel(RecurringCadence c) => switch (c) {
        RecurringCadence.weekly => context.l10n.cadenceWeekly,
        RecurringCadence.monthly => context.l10n.cadenceMonthly,
        RecurringCadence.quarterly => context.l10n.cadenceQuarterly,
        RecurringCadence.yearly => context.l10n.cadenceYearly,
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final categories = ExpenseCategories.categories;
    if (!categories.contains(_category) && categories.isNotEmpty) {
      _category = categories.first;
    }

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
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null
                  ? context.l10n.newRecurring
                  : context.l10n.editRecurring,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: colors.text),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: context.l10n.recurringNameLabel,
                hintText: context.l10n.recurringNameHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    enabled: !_varies,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration: InputDecoration(
                      labelText: context.l10n.commonAmount,
                      prefixText: '₹ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                _VariesToggle(
                  value: _varies,
                  onChanged: (v) => setState(() => _varies = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label(colors, context.l10n.category),
            const SizedBox(height: 8),
            _CategoryDropdown(
              value: _category,
              items: categories,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 16),
            _label(colors, context.l10n.repeatsLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in RecurringCadence.values)
                  ChoiceChip(
                    label: Text(_cadenceLabel(c)),
                    selected: _cadence == c,
                    onSelected: (_) => setState(() => _cadence = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label(colors, context.l10n.nextDueDateLabel),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickAnchor,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(DateFormat('EEE, d MMM yyyy').format(_anchor)),
            ),
            const SizedBox(height: 16),
            _label(colors, context.l10n.remindMeLabel),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoMatch,
              onChanged: (v) => setState(() => _autoMatch = v),
              title: Text(context.l10n.autoDetectSmsLabel,
                  style: TextStyle(fontSize: 14, color: colors.text)),
              subtitle: Text(context.l10n.autoDetectSmsDesc,
                  style:
                      TextStyle(fontSize: 12, color: colors.textSecondary)),
            ),
            if (_autoMatch) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in const [0, 1, 2, 3, 5, 7])
                    ChoiceChip(
                      label: Text(d == 0
                          ? context.l10n.remindOnDueDay
                          : context.l10n.remindLeadDays(d)),
                      selected: _leadDays == d,
                      onSelected: (_) => setState(() => _leadDays = d),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _label(colors, context.l10n.endDateOptionalLabel),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEnd,
                    icon: const Icon(Icons.event_busy_outlined, size: 18),
                    label: Text(_endDate == null
                        ? context.l10n.pickADate
                        : DateFormat('d MMM yyyy').format(_endDate!)),
                  ),
                ),
                if (_endDate != null)
                  IconButton(
                    onPressed: () => setState(() => _endDate = null),
                    icon: Icon(Icons.clear_rounded, color: colors.textTertiary),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _valid ? _save : null,
                child: Text(widget.existing == null
                    ? context.l10n.addRecurring
                    : context.l10n.commonSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(AppColors colors, String t) => Text(
        t,
        style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: colors.textSecondary),
      );
}

/// Compact "Varies" pill that toggles fixed-vs-variable amount.
class _VariesToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _VariesToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: value ? colors.accent.withValues(alpha: 0.12) : colors.cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value ? colors.accent : colors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 16,
              color: value ? colors.accent : colors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.amountVariesShort,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value ? colors.accent : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _CategoryDropdown(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          dropdownColor: colors.surface,
          icon: Icon(Icons.keyboard_arrow_down, color: colors.textTertiary),
          items: [
            for (final c in items)
              DropdownMenuItem(
                value: c,
                child: Row(
                  children: [
                    Text(ExpenseCategories.getIcon(c),
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(context.l10n.categoryName(c),
                        style: TextStyle(color: colors.text)),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
