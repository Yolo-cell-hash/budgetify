import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ledger_models.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/ledger_service.dart';
import 'app_toast.dart';

/// Add or edit a shared expense. Returns `true` when something was saved.
///
/// [linkTxn] pre-fills the sheet from a detected/manual transaction and links
/// it, so the split reduces that transaction's contribution to spending totals
/// down to the user's own share.
Future<bool> showSplitEditor(
  BuildContext context, {
  SplitEntry? existing,
  TransactionModel? linkTxn,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF16181E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SplitEditorSheet(existing: existing, linkTxn: linkTxn),
  );
  return result ?? false;
}

/// One row in the editor: a person and their controllable share.
class _Party {
  final String name; // _me sentinel for the user
  final TextEditingController shareCtrl;
  _Party(this.name, [String share = '']) : shareCtrl = TextEditingController(text: share);
}

const String _me = '__me__';

class _SplitEditorSheet extends StatefulWidget {
  final SplitEntry? existing;
  final TransactionModel? linkTxn;
  const _SplitEditorSheet({this.existing, this.linkTxn});

  @override
  State<_SplitEditorSheet> createState() => _SplitEditorSheetState();
}

class _SplitEditorSheetState extends State<_SplitEditorSheet> {
  final _db = DatabaseService();
  final _ledger = LedgerService();

  final _titleCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();

  SplitMethod _method = SplitMethod.equal;
  final List<_Party> _parties = [];
  String _payer = _me; // _me or a person's name
  DateTime _date = DateTime.now();
  int? _linkedTxnId;
  String? _linkedTxnLabel;
  bool _loading = true;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _totalCtrl.text = e.totalAmount.toStringAsFixed(0);
      _date = e.date;
      _payer = e.payer ?? _me;
      _linkedTxnId = e.transactionId;
      _method = SplitMethod.exact; // editing always shows resolved amounts
      _parties.add(_Party(_me, e.myShare.toStringAsFixed(0)));
      final parts = await _db.getParticipants(e.id!);
      for (final p in parts) {
        _parties.add(_Party(p.person, p.share.toStringAsFixed(0)));
      }
    } else {
      _parties.add(_Party(_me));
      final t = widget.linkTxn;
      if (t != null) {
        _linkedTxnId = t.id;
        _linkedTxnLabel = t.merchantName ?? t.category ?? 'Transaction';
        _titleCtrl.text = t.merchantName ?? t.category ?? '';
        _totalCtrl.text = t.amount.toStringAsFixed(0);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalCtrl.dispose();
    for (final p in _parties) {
      p.shareCtrl.dispose();
    }
    super.dispose();
  }

  double get _total => double.tryParse(_totalCtrl.text.trim()) ?? 0;

  /// In equal mode, each participant's share is the total split evenly with the
  /// rounding remainder handed to "You", so the parts always sum to the total.
  List<double> _resolvedShares() {
    final n = _parties.length;
    if (n == 0) return const [];
    if (_method == SplitMethod.equal) {
      final per = (_total / n);
      final rounded = List<double>.filled(n, per.floorToDouble());
      var distributed = rounded.fold<double>(0, (a, b) => a + b);
      var i = 0;
      // Spread the leftover rupees one at a time starting from "You".
      while (distributed < _total - 0.001 && i < 10000) {
        rounded[i % n] += 1;
        distributed += 1;
        i++;
      }
      return rounded;
    }
    return [
      for (final p in _parties) double.tryParse(p.shareCtrl.text.trim()) ?? 0,
    ];
  }

  double get _sumShares =>
      _resolvedShares().fold<double>(0, (a, b) => a + b);

  void _addPerson(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    if (n.toLowerCase() == 'you' || _parties.any((p) => p.name == n)) return;
    setState(() => _parties.add(_Party(n)));
  }

  Future<void> _promptAddPerson() async {
    final ctrl = TextEditingController();
    final known = await _ledger.knownPeople();
    if (!mounted) return;
    final colors = AppColors.of(context);
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
            Text('Add a person',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Name'),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            if (known.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in known.where(
                      (k) => !_parties.any((p) => p.name == k)))
                    ActionChip(
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
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (picked != null) _addPerson(picked);
  }

  String _label(String party) => party == _me ? 'You' : party;

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showAppToast(context, message: 'Give it a title', type: AppToastType.warning);
      return;
    }
    if (_total <= 0) {
      showAppToast(context,
          message: 'Enter an amount above ₹0', type: AppToastType.warning);
      return;
    }
    if (_parties.length < 2) {
      showAppToast(context,
          message: 'Add at least one other person', type: AppToastType.warning);
      return;
    }
    final shares = _resolvedShares();
    if ((_sumShares - _total).abs() > 1.0) {
      showAppToast(context,
          message: 'Shares must add up to ₹${_total.toStringAsFixed(0)}',
          type: AppToastType.warning);
      return;
    }

    final myIdx = _parties.indexWhere((p) => p.name == _me);
    final myShare = shares[myIdx];
    final participants = <SplitParticipant>[
      for (var i = 0; i < _parties.length; i++)
        if (_parties[i].name != _me)
          SplitParticipant(person: _parties[i].name, share: shares[i]),
    ];

    setState(() => _saving = true);
    final split = SplitEntry(
      id: widget.existing?.id,
      title: title,
      totalAmount: _total,
      myShare: myShare,
      payer: _payer == _me ? null : _payer,
      date: _date,
      note: null,
      transactionId: _linkedTxnId,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    if (_editing) {
      await _ledger.updateSplit(split, participants);
    } else {
      await _ledger.addSplit(split, participants);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (widget.existing?.id == null) return;
    setState(() => _saving = true);
    await _ledger.deleteSplit(widget.existing!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final shares = _loading ? const <double>[] : _resolvedShares();
    final remaining = _total - _sumShares;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _loading
            ? const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                controller: scrollController,
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
                            color: AppColors.gold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.call_split_rounded,
                              color: AppColors.gold, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _editing ? 'Edit split' : 'New split',
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

                    _fieldLabel(colors, 'What for'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Dinner at Barbeque Nation',
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel(colors, 'Total amount'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _totalCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  prefixText: '₹ ',
                                  hintText: '0',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel(colors, 'Date'),
                              const SizedBox(height: 8),
                              _dateField(colors),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_linkedTxnLabel != null) ...[
                      const SizedBox(height: 12),
                      _linkedChip(colors),
                    ],

                    const SizedBox(height: 18),
                    _fieldLabel(colors, 'Paid by'),
                    const SizedBox(height: 8),
                    _payerSelector(colors),

                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _fieldLabel(colors, 'Split'),
                        const Spacer(),
                        _methodToggle(colors),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _parties.length; i++)
                      _partyRow(colors, i, shares.isEmpty ? 0 : shares[i]),
                    const SizedBox(height: 6),
                    _addPersonButton(colors),

                    if (_method == SplitMethod.exact) ...[
                      const SizedBox(height: 10),
                      _reconcileHint(colors, remaining),
                    ],

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (_editing)
                          OutlinedButton(
                            onPressed: _saving ? null : _delete,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.dangerLight),
                            child: const Text('Delete'),
                          )
                        else
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_editing ? 'Save' : 'Add split'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _methodToggle(AppColors colors) {
    Widget chip(String label, SplitMethod m) {
      final sel = _method == m;
      return GestureDetector(
        onTap: () => setState(() => _method = m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? AppColors.gold : colors.cardAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppColors.gold : colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: sel ? const Color(0xFF15110A) : colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      chip('Equally', SplitMethod.equal),
      const SizedBox(width: 8),
      chip('Exact ₹', SplitMethod.exact),
    ]);
  }

  Widget _partyRow(AppColors colors, int i, double share) {
    final p = _parties[i];
    final isMe = p.name == _me;
    final canRemove = !isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isMe
                  ? AppColors.gold.withValues(alpha: 0.16)
                  : colors.cardAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isMe
                      ? AppColors.gold.withValues(alpha: 0.4)
                      : colors.border),
            ),
            child: Text(
              isMe ? '🙂' : _label(p.name).characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: isMe ? 15 : 14,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? 'You' : _label(p.name),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: _method == SplitMethod.equal
                ? Text(
                    '₹${share.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  )
                : TextField(
                    controller: p.shareCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixText: '₹',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
          ),
          if (canRemove)
            IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 18, color: colors.textTertiary),
              onPressed: () {
                setState(() {
                  if (_payer == p.name) _payer = _me;
                  p.shareCtrl.dispose();
                  _parties.removeAt(i);
                });
              },
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _addPersonButton(AppColors colors) {
    return InkWell(
      onTap: _promptAddPerson,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 20, color: AppColors.goldDeep),
            const SizedBox(width: 8),
            Text('Add person',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldDeep)),
          ],
        ),
      ),
    );
  }

  Widget _payerSelector(AppColors colors) {
    Widget chip(String value, String label) {
      final sel = _payer == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _payer = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? AppColors.gold : colors.cardAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? AppColors.gold : colors.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: sel ? const Color(0xFF15110A) : colors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_me, 'You'),
          for (final p in _parties.where((p) => p.name != _me))
            chip(p.name, _label(p.name)),
        ],
      ),
    );
  }

  Widget _reconcileHint(AppColors colors, double remaining) {
    final ok = remaining.abs() <= 1.0;
    final c = ok ? colors.success : AppColors.gold;
    return Row(
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 15, color: c),
        const SizedBox(width: 6),
        Text(
          ok
              ? 'Adds up to ₹${_total.toStringAsFixed(0)}'
              : remaining > 0
                  ? '₹${remaining.toStringAsFixed(0)} left to assign'
                  : '₹${(-remaining).toStringAsFixed(0)} over',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c),
        ),
      ],
    );
  }

  Widget _linkedChip(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, size: 16, color: AppColors.goldDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Linked to $_linkedTxnLabel — only your share counts as spending',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(AppColors colors) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 1),
        );
        if (picked != null) setState(() => _date = picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 15, color: colors.textSecondary),
            const SizedBox(width: 8),
            Text(DateFormat('d MMM').format(_date),
                style: TextStyle(fontSize: 13.5, color: colors.text)),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(AppColors colors, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      );
}
