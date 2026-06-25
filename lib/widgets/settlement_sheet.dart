import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/ledger_service.dart';
import 'app_toast.dart';
import 'person_avatar.dart';

/// Mark a transaction as a **settlement** so it stops counting as income/spend.
///
/// Optionally attribute it to a person (defaults to [suggestedPerson]), which
/// records a ledger settle-up and clears their balance. Returns `true` when the
/// transaction changed.
Future<bool> showSettlementSheet(
  BuildContext context, {
  required TransactionModel transaction,
  String? suggestedPerson,
}) async {
  final colors = AppColors.of(context);
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SettlementSheet(
      transaction: transaction,
      suggestedPerson: suggestedPerson,
    ),
  );
  return result ?? false;
}

class _SettlementSheet extends StatefulWidget {
  final TransactionModel transaction;
  final String? suggestedPerson;
  const _SettlementSheet({required this.transaction, this.suggestedPerson});

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  final _ledger = LedgerService();

  String? _person; // selected person, or null = neutral (no ledger entry)
  List<String> _owers = []; // people who owe you (suggested first)
  final Map<String, double> _owedBy = {}; // person → outstanding balance
  List<String> _others = []; // other known people
  bool _alreadySettlement = false;
  bool _loading = true;
  bool _saving = false;

  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final txn = widget.transaction;
    _alreadySettlement = txn.category == 'Settlement';

    final existing = txn.id == null
        ? null
        : await _ledger.settlementForTransaction(txn.id!);
    final summary = await _ledger.summary();
    final known = await _ledger.knownPeople();

    final owers = summary.people.where((p) => p.owesMe).toList();
    for (final p in owers) {
      _owedBy[p.person] = p.net;
    }
    _owers = owers.map((p) => p.person).toList();
    _others = known.where((k) => !_owers.contains(k)).toList();

    _person = existing?.person ?? widget.suggestedPerson;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addPerson() async {
    final ctrl = TextEditingController();
    final colors = AppColors.of(context);
    final l10n = context.l10nRead;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.addAPerson,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: Text(l10n.addAPerson),
              ),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    final name = picked?.trim();
    if (name != null && name.isNotEmpty) {
      setState(() {
        if (!_owers.contains(name) && !_others.contains(name)) {
          _others.add(name);
        }
        _person = name;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _ledger.setTransactionSettlement(
      txn: widget.transaction,
      person: _person,
    );
    notifyAppDataChanged();
    if (mounted) {
      showAppToast(context,
          message: context.l10nRead.settlementSavedToast,
          type: AppToastType.success);
      Navigator.pop(context, true);
    }
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    await _ledger.clearTransactionSettlement(widget.transaction);
    notifyAppDataChanged();
    if (mounted) {
      showAppToast(context,
          message: context.l10nRead.settlementRemovedToast,
          type: AppToastType.info);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isCredit = widget.transaction.type == TransactionType.credit;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: _loading
          ? const SizedBox(
              height: 220, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
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
                          color: colors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.handshake_rounded,
                            color: colors.accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.markAsSettlement,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: colors.text)),
                            const SizedBox(height: 2),
                            Text(_fmt.format(widget.transaction.amount),
                                style: TextStyle(
                                    fontSize: 13, color: colors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Explainer
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: colors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: colors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(l10n.settlementExplainer,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: colors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    isCredit ? l10n.whoPaidYouBack : l10n.settlementFromOptional,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  _peoplePicker(colors),

                  if (_person != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 15, color: colors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.clearsBalance(_person!,
                                _fmt.format(widget.transaction.amount)),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: colors.success),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 22),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        child: Text(l10n.commonCancel),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: Text(l10n.markAsSettlement),
                        ),
                      ),
                    ],
                  ),
                  if (_alreadySettlement) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: _saving ? null : _remove,
                      icon: Icon(Icons.undo_rounded,
                          size: 18, color: colors.danger),
                      label: Text(l10n.removeSettlement,
                          style: TextStyle(color: colors.danger)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _peoplePicker(AppColors c) {
    Widget chip(String name, {double? owed}) {
      final sel = _person == name;
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: GestureDetector(
          onTap: () => setState(() => _person = sel ? null : name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
            decoration: BoxDecoration(
              color: sel ? c.accent : c.cardAlt,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: sel ? c.accent : c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PersonAvatar(name: name, size: 24),
                const SizedBox(width: 7),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sel
                        ? (c.accent.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white)
                        : c.textSecondary,
                  ),
                ),
                if (owed != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    _fmt.format(owed),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? (c.accent.computeLuminance() > 0.5
                              ? Colors.black54
                              : Colors.white70)
                          : c.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      children: [
        for (final name in _owers) chip(name, owed: _owedBy[name]),
        for (final name in _others) chip(name),
        // Add-person chip
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: _addPerson,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.cardAlt,
                borderRadius: BorderRadius.circular(30),
                border:
                    Border.all(color: c.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: c.accent),
                  const SizedBox(width: 5),
                  Text(context.l10n.addAPerson,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.accent)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
