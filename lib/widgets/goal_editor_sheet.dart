import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/savings_goal.dart';
import '../providers/theme_provider.dart';
import 'avatars.dart';

const List<String> _goalEmojis = [
  '🎯', '✈️', '🏖️', '🚗', '🏠', '💍', '🎓', '📱',
  '💻', '🎁', '🏝️', '🛵', '👶', '🐶', '💰', '🎮',
];

/// Create or edit a savings goal. Returns the built [SavingsGoal] (unsaved —
/// the caller persists it), or null if cancelled.
Future<SavingsGoal?> showGoalEditor(BuildContext context, {SavingsGoal? existing}) {
  return showModalBottomSheet<SavingsGoal>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GoalEditorSheet(existing: existing),
  );
}

class _GoalEditorSheet extends StatefulWidget {
  final SavingsGoal? existing;
  const _GoalEditorSheet({this.existing});

  @override
  State<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<_GoalEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _amount = TextEditingController(
      text: widget.existing == null ? '' : widget.existing!.targetAmount.toStringAsFixed(0));
  late String _emoji = widget.existing?.emoji ?? '🎯';
  late int _accent = widget.existing?.accent ?? 0;
  late DateTime? _deadline = widget.existing?.deadline;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && (double.tryParse(_amount.text.trim()) ?? 0) > 0;

  void _save() {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    Navigator.pop(
      context,
      (widget.existing ?? SavingsGoal(name: '', targetAmount: 0, createdAt: DateTime.now()))
          .copyWith(
        name: _name.text.trim(),
        emoji: _emoji,
        targetAmount: amt,
        accent: _accent,
        deadline: _deadline,
        clearDeadline: _deadline == null,
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime(now.year, now.month + 3, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
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
            Text(
                widget.existing == null
                    ? context.l10n.newSavingsGoal
                    : context.l10n.editGoal,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 40,
              decoration: InputDecoration(
                  labelText: context.l10n.goalNameLabel,
                  hintText: context.l10n.goalNameHint),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                  labelText: context.l10n.targetAmount, prefixText: '₹ '),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _label(colors, context.l10n.iconLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _goalEmojis)
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _emoji == e ? AppColors.gold.withValues(alpha: 0.16) : colors.cardAlt,
                        border: Border.all(color: _emoji == e ? AppColors.gold : colors.border),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label(colors, context.l10n.colourLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < kAvatarAccents.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _accent = i),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: accentOf(i)),
                        border: Border.all(
                            color: _accent == i ? AppColors.gold : Colors.transparent, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label(colors, context.l10n.deadlineOptionalLabel),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDeadline,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(_deadline == null
                        ? context.l10n.pickADate
                        : context.l10n.mediumDate(_deadline!)),
                  ),
                ),
                if (_deadline != null)
                  IconButton(
                    onPressed: () => setState(() => _deadline = null),
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
                    ? context.l10n.createGoal
                    : context.l10n.commonSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(AppColors colors, String t) => Text(t,
      style: TextStyle(
          fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: colors.textSecondary));
}
