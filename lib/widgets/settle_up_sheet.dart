import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/ledger_models.dart';
import '../providers/theme_provider.dart';
import '../services/ledger_service.dart';
import 'app_toast.dart';

/// Record a repayment between you and [person]. [net] is their current balance
/// (>0 they owe you), used to pre-fill the amount and direction. Returns true
/// when a settlement was saved.
Future<bool> showSettleUpSheet(
  BuildContext context, {
  required String person,
  required double net,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF16181E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SettleUpSheet(person: person, net: net),
  );
  return result ?? false;
}

class _SettleUpSheet extends StatefulWidget {
  final String person;
  final double net;
  const _SettleUpSheet({required this.person, required this.net});

  @override
  State<_SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<_SettleUpSheet> {
  final _ledger = LedgerService();
  late final TextEditingController _amountCtrl;
  late bool _paidToMe; // they paid me
  final DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _paidToMe = widget.net >= 0; // they owe me → they pay me back
    final suggested = widget.net.abs();
    _amountCtrl = TextEditingController(
        text: suggested > 0 ? suggested.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      showAppToast(context,
          message: context.l10nRead.enterAmountAboveZero,
          type: AppToastType.warning);
      return;
    }
    setState(() => _saving = true);
    await _ledger.addSettlement(Settlement(
      person: widget.person,
      amount: amount,
      paidToMe: _paidToMe,
      date: _date,
      createdAt: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.successDark.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.handshake_rounded,
                      color: AppColors.successDark, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Settle up with ${widget.person}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Direction toggle
            Row(
              children: [
                _dirChip(colors, true, context.l10n.personPaidMe(widget.person)),
                const SizedBox(width: 8),
                _dirChip(colors, false, context.l10n.iPaidPerson(widget.person)),
              ],
            ),
            const SizedBox(height: 18),

            Text(context.l10n.amount,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(prefixText: '₹ ', hintText: '0'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                OutlinedButton(
                  onPressed:
                      _saving ? null : () => Navigator.pop(context, false),
                  child: Text(context.l10n.commonCancel),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successDark,
                        foregroundColor: const Color(0xFF0B1F17)),
                    onPressed: _saving ? null : _save,
                    child: Text(context.l10n.recordSettlement),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dirChip(AppColors colors, bool value, String label) {
    final sel = _paidToMe == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paidToMe = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.successDark : colors.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: sel ? AppColors.successDark : colors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: sel ? const Color(0xFF0B1F17) : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
