import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/ledger_models.dart';
import '../models/transaction_model.dart';
import '../models/transaction_split_math.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/database_service.dart';
import '../services/ledger_service.dart';
import 'app_dialog.dart';
import 'app_toast.dart';
import 'person_avatar.dart';

/// Split a single transaction so only *your* share counts toward your budgets.
///
/// Leads with "your share" (with a quick equal-split helper). An optional
/// "track who owes you" toggle records the rest in the ledger so you can settle
/// up later — off by default for the fastest path. Returns `true` when the
/// transaction's split changed.
Future<bool> showSplitTransactionSheet(
  BuildContext context, {
  required TransactionModel transaction,
}) async {
  final colors = AppColors.of(context);
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SplitTransactionSheet(transaction: transaction),
  );
  return result ?? false;
}

class _SplitTransactionSheet extends StatefulWidget {
  final TransactionModel transaction;
  const _SplitTransactionSheet({required this.transaction});

  @override
  State<_SplitTransactionSheet> createState() => _SplitTransactionSheetState();
}

class _SplitTransactionSheetState extends State<_SplitTransactionSheet> {
  final _db = DatabaseService();
  final _ledger = LedgerService();
  final _shareCtrl = TextEditingController();

  bool _track = false;
  final List<String> _people = [];

  /// One amount field per person, and the names whose amount the user typed
  /// themselves. Everyone *not* in [_fixed] keeps absorbing whatever is left of
  /// the bill, so setting one person's figure realigns the others.
  final Map<String, TextEditingController> _amountCtrls = {};
  final Set<String> _fixed = {};

  bool _alreadySplit = false; // had a split when opened (enables Remove)
  bool _loading = true;
  bool _saving = false;

  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  double get _total => widget.transaction.amount;
  double get _share => double.tryParse(_shareCtrl.text.trim()) ?? 0;
  double get _remainder => (_total - _share).clamp(0, _total);
  bool get _reduces => TransactionSplitMath.reducesSpend(_total, _share);

  /// The hand-typed amounts, keyed by person.
  Map<String, double> get _fixedAmounts => {
        for (final name in _fixed)
          if (_amountCtrls[name] != null)
            name: double.tryParse(_amountCtrls[name]!.text.trim()) ?? 0,
      };

  /// What each person owes right now: the typed amounts as-is, the rest
  /// sharing what's left of the bill.
  List<({String person, double share})> get _owed =>
      TransactionSplitMath.owedShares(_total, _share, _people,
          fixed: _fixedAmounts);

  /// Non-zero once the parts stop adding up to the bill — only meaningful
  /// while tracking people. Positive ⇒ over, negative ⇒ still unassigned.
  double get _gap => TransactionSplitMath.allocationGap(
      _total, _share, _owed.map((o) => o.share));

  bool get _showsGap =>
      _track &&
      _people.isNotEmpty &&
      _gap.abs() > TransactionSplitMath.gapTolerance;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final txn = widget.transaction;
    final existing = txn.id == null
        ? null
        : await _ledger.splitForTransaction(txn.id!);
    if (existing != null) {
      _alreadySplit = true;
      _track = true;
      _shareCtrl.text = existing.myShare.toStringAsFixed(0);
      final parts = await _db.getParticipants(existing.id!);
      final saved = {for (final p in parts) p.person: p.share};
      _people.addAll(saved.keys);
      for (final e in saved.entries) {
        _amountCtrls[e.key] =
            TextEditingController(text: e.value.toStringAsFixed(0));
      }
      // An amount an even split wouldn't have produced was set by hand, so
      // hold on to it — reopening the sheet must not quietly round the group
      // back to equal shares.
      for (final o in TransactionSplitMath.owedShares(
          _total, existing.myShare, _people)) {
        if (((saved[o.person] ?? 0) - o.share).abs() > 0.5) {
          _fixed.add(o.person);
        }
      }
    } else if (txn.splitShare != null) {
      _alreadySplit = true;
      _shareCtrl.text = txn.splitShare!.toStringAsFixed(0);
    } else {
      // Sensible default: a 2-way even split, the most common case.
      _shareCtrl.text =
          TransactionSplitMath.equalShare(_total, 2).toStringAsFixed(0);
    }
    _syncAuto();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _shareCtrl.dispose();
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Push the freshly computed amounts into the fields of everyone the user
  /// hasn't typed over, so every row always shows what will actually be saved.
  void _syncAuto() {
    for (final o in _owed) {
      if (_fixed.contains(o.person)) continue;
      final ctrl = _amountCtrls[o.person];
      final text = o.share.toStringAsFixed(0);
      if (ctrl != null && ctrl.text != text) ctrl.text = text;
    }
  }

  void _setEqual(int people) {
    _shareCtrl.text =
        TransactionSplitMath.equalShare(_total, people).toStringAsFixed(0);
    _syncAuto();
    setState(() {});
  }

  /// Hand this row's amount back to the auto split and rebalance.
  void _release(String name) => setState(() {
        _fixed.remove(name);
        _syncAuto();
      });

  /// Drop every hand-set amount so the bill divides evenly again.
  void _evenOut() => setState(() {
        _fixed.clear();
        _syncAuto();
      });

  void _removePerson(String name) => setState(() {
        _people.remove(name);
        _fixed.remove(name);
        _amountCtrls.remove(name)?.dispose();
        _syncAuto();
      });

  Future<void> _addPerson() async {
    final picked = await _promptPerson();
    if (picked != null && picked.trim().isNotEmpty) {
      final name = picked.trim();
      if (!_people.contains(name)) {
        setState(() {
          _people.add(name);
          // New arrivals start on the auto split, absorbing what's unassigned.
          _amountCtrls[name] = TextEditingController();
          _syncAuto();
        });
      }
    }
  }

  Future<String?> _promptPerson() async {
    final ctrl = TextEditingController();
    final known = await _ledger.knownPeople();
    if (!mounted) return null;
    final colors = AppColors.of(context);
    final l10n = context.l10nRead;
    final res = await showModalBottomSheet<String>(
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
            Text(l10n.whoOwesYou,
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
            if (known.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in known.where((k) => !_people.contains(k)))
                    ActionChip(
                      avatar: PersonAvatar(name: name, size: 22),
                      label: Text(name),
                      onPressed: () => Navigator.pop(ctx, name),
                    ),
                ],
              ),
            ],
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
    return res;
  }

  Future<void> _save() async {
    final l10n = context.l10nRead;
    if (!TransactionSplitMath.isValidShare(_total, _share)) {
      showAppToast(context,
          message: l10n.shareCantExceedTotal, type: AppToastType.warning);
      return;
    }
    final txnId = widget.transaction.id;
    if (txnId == null) return;

    // Your share == the whole amount ⇒ it isn't really split; clear any split.
    if (!_reduces) {
      setState(() => _saving = true);
      await _ledger.clearTransactionSplit(txnId);
      notifyAppDataChanged();
      if (mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    if (_track && _people.isEmpty) {
      showAppToast(context,
          message: l10n.addSomeoneWhoOwes, type: AppToastType.warning);
      return;
    }

    // Amounts that don't add up are the user's call to make — warn, then
    // record exactly what they entered if they mean it.
    final owed = _owed;
    final owedBy = _track
        ? [
            for (final o in owed)
              SplitParticipant(person: o.person, share: o.share),
          ]
        : const <SplitParticipant>[];
    if (_showsGap && await _confirmMismatch(l10n) != true) return;
    if (!mounted) return;

    setState(() => _saving = true);

    final txn = widget.transaction;
    final title = (txn.merchantName?.trim().isNotEmpty ?? false)
        ? txn.merchantName!.trim()
        : (txn.category ?? l10n.splitTransactionTitle);

    await _ledger.setTransactionSplit(
      transactionId: txnId,
      title: title,
      total: _total,
      myShare: _share,
      date: txn.detectedAt,
      owedBy: owedBy,
    );
    notifyAppDataChanged();
    if (mounted) Navigator.pop(context, true);
  }

  /// The shares no longer add up to the bill. Say so plainly, then let the
  /// user go ahead — tracking a part of a bill is a legitimate thing to want.
  Future<bool?> _confirmMismatch(AppStrings l10n) {
    final allocated = _share + _owed.fold<double>(0, (a, o) => a + o.share);
    return showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.rule_rounded,
        accent: AppColors.of(ctx).warning,
        title: l10n.splitDoesntAddUp,
        subtitle: l10n.splitGapExplainer(
            _fmt.format(allocated), _fmt.format(_total)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.saveAnyway),
          ),
        ],
      ),
    );
  }

  Future<void> _remove() async {
    final txnId = widget.transaction.id;
    if (txnId == null) return;
    setState(() => _saving = true);
    await _ledger.clearTransactionSplit(txnId);
    notifyAppDataChanged();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
                  _grip(colors),
                  const SizedBox(height: 18),
                  _header(colors, l10n),
                  const SizedBox(height: 18),
                  _totalCard(colors, l10n),
                  const SizedBox(height: 18),
                  _shareField(colors, l10n),
                  const SizedBox(height: 12),
                  _quickSplit(colors, l10n),
                  const SizedBox(height: 16),
                  _resultCard(colors, l10n),
                  const SizedBox(height: 16),
                  if (_reduces) _trackSection(colors, l10n),
                  const SizedBox(height: 22),
                  _actions(colors, l10n),
                ],
              ),
            ),
    );
  }

  Widget _grip(AppColors c) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: c.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(AppColors c, AppStrings l10n) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.call_split_rounded, color: c.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _alreadySplit ? l10n.editSplit : l10n.splitTransactionTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(l10n.splitTagline,
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
              ],
            ),
          ),
        ],
      );

  Widget _totalCard(AppColors c, AppStrings l10n) {
    final txn = widget.transaction;
    final label = (txn.merchantName?.trim().isNotEmpty ?? false)
        ? txn.merchantName!.trim()
        : (txn.category != null
            ? l10n.categoryName(txn.category!)
            : txn.sender);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded, size: 18, color: c.danger),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.text)),
          ),
          Text(_fmt.format(_total),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: c.text)),
        ],
      ),
    );
  }

  Widget _shareField(AppColors c, AppStrings l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.yourShareLabel,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _shareCtrl,
            keyboardType: TextInputType.number,
            // Your share moves ⇒ everyone still on the auto split moves with it.
            onChanged: (_) => setState(_syncAuto),
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: c.text),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              hintText: '0',
            ),
          ),
        ],
      );

  Widget _quickSplit(AppColors c, AppStrings l10n) {
    Widget chip(int n) {
      final share = TransactionSplitMath.equalShare(_total, n);
      final selected = (_share - share).abs() < 0.5;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => _setEqual(n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? c.accent : c.cardAlt,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: selected ? c.accent : c.border),
            ),
            child: Text(
              '÷$n',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? (c.accent.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white)
                    : c.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Text(l10n.quickSplit,
            style: TextStyle(fontSize: 12.5, color: c.textTertiary)),
        const SizedBox(width: 10),
        chip(2),
        chip(3),
        chip(4),
        chip(5),
      ],
    );
  }

  Widget _resultCard(AppColors c, AppStrings l10n) {
    final good = _reduces ? c.success : c.textSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: good.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: good.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: good),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.countsToBudgets(_fmt.format(_share)),
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.text),
                ),
              ),
            ],
          ),
          if (_reduces) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                l10n.restNotYours(_fmt.format(_remainder)),
                style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trackSection(AppColors c, AppStrings l10n) {
    final owed = _owed;
    return Container(
      decoration: BoxDecoration(
        color: c.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          // Toggle row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.trackWhoOwes(_fmt.format(_remainder)),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.text),
                      ),
                      const SizedBox(height: 2),
                      Text(l10n.trackWhoOwesHint,
                          style: TextStyle(
                              fontSize: 11.5, color: c.textSecondary)),
                    ],
                  ),
                ),
                Switch(
                  value: _track,
                  onChanged: (v) => setState(() => _track = v),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                _track ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  Divider(color: c.border, height: 1),
                  const SizedBox(height: 10),
                  for (final o in owed) _personRow(c, o.person),
                  _addPersonRow(c, l10n),
                  if (_showsGap) _gapNotice(c, l10n),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// One person, with their share as a live field. Type over it and everyone
  /// still on the auto split takes up the slack; the ↺ hands it back.
  Widget _personRow(AppColors c, String name) {
    final fixed = _fixed.contains(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          PersonAvatar(name: name, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text)),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _amountCtrls[name],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {
                _fixed.add(name);
                _syncAuto();
              }),
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: c.success),
              decoration: InputDecoration(
                prefixText: '₹',
                prefixStyle: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.success),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              ),
            ),
          ),
          // Same footprint either way, so typing an amount doesn't shunt the
          // row sideways as the reset appears.
          SizedBox(
            width: 29,
            child: fixed
                ? GestureDetector(
                    onTap: () => _release(name),
                    child: Icon(Icons.restart_alt_rounded,
                        size: 16, color: c.textTertiary),
                  )
                : null,
          ),
          GestureDetector(
            onTap: () => _removePerson(name),
            child: Icon(Icons.close_rounded, size: 16, color: c.textTertiary),
          ),
        ],
      ),
    );
  }

  /// The parts stopped adding up to the bill. Say by how much and offer the
  /// one-tap fix, but never block: saving past it is allowed.
  Widget _gapNotice(AppColors c, AppStrings l10n) {
    final amount = _fmt.format(_gap.abs());
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(11, 9, 6, 9),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: c.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _gap > 0
                  ? l10n.splitOverAllocated(amount)
                  : l10n.splitUnallocated(amount),
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text),
            ),
          ),
          TextButton(
            onPressed: _evenOut,
            style: TextButton.styleFrom(
              foregroundColor: c.warning,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            child: Text(l10n.evenItOut),
          ),
        ],
      ),
    );
  }

  Widget _addPersonRow(AppColors c, AppStrings l10n) => InkWell(
        onTap: _addPerson,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, size: 18, color: c.accent),
              const SizedBox(width: 9),
              Text(l10n.addAPerson,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: c.accent)),
            ],
          ),
        ),
      );

  Widget _actions(AppColors c, AppStrings l10n) {
    return Column(
      children: [
        Row(
          children: [
            OutlinedButton(
              onPressed:
                  _saving ? null : () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.saveSplitCta),
              ),
            ),
          ],
        ),
        if (_alreadySplit) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _saving ? null : _remove,
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: c.danger),
            label: Text(l10n.removeSplit, style: TextStyle(color: c.danger)),
          ),
        ],
      ],
    );
  }
}
