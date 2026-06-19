import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ledger_models.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/ledger_service.dart';
import 'app_toast.dart';
import 'person_avatar.dart';

/// Add or edit a shared expense. Returns `true` when something was saved.
///
/// The editor is built around two clear choices — **who paid** and **who's in
/// the split** — and shows a live outcome line ("You owe Rohan ₹500" /
/// "Priya owes you ₹400") so the direction of the debt is never ambiguous.
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

const String _me = '__me__';

/// One person in the editor, with whether they're part of the split and their
/// (exact-mode) share.
class _Party {
  final String name; // _me sentinel for the user
  final TextEditingController shareCtrl;
  bool sharing;
  _Party(this.name, {this.sharing = true, String share = ''})
      : shareCtrl = TextEditingController(text: share);
}

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

  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

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
      _method = SplitMethod.exact; // editing shows resolved amounts
      _parties.add(_Party(_me,
          sharing: e.myShare > 0, share: e.myShare.toStringAsFixed(0)));
      final parts = await _db.getParticipants(e.id!);
      for (final p in parts) {
        _parties.add(_Party(p.person,
            sharing: p.share > 0, share: p.share.toStringAsFixed(0)));
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
  int get _sharingCount => _parties.where((p) => p.sharing).length;
  String _label(String name) => name == _me ? 'You' : name;

  /// Resolved rupee share per party (index-aligned with [_parties]). Equal mode
  /// splits the total evenly among those in the split, handing the rounding
  /// remainder to the first one so the parts always add up.
  List<double> _resolvedShares() {
    final n = _parties.length;
    final out = List<double>.filled(n, 0);
    final sharing = [for (var i = 0; i < n; i++) if (_parties[i].sharing) i];
    if (sharing.isEmpty) return out;

    if (_method == SplitMethod.equal) {
      final per = (_total / sharing.length).floorToDouble();
      for (final i in sharing) {
        out[i] = per;
      }
      var distributed = per * sharing.length;
      var j = 0;
      while (distributed < _total - 0.001 && j < 100000) {
        out[sharing[j % sharing.length]] += 1;
        distributed += 1;
        j++;
      }
      return out;
    }
    for (final i in sharing) {
      out[i] = double.tryParse(_parties[i].shareCtrl.text.trim()) ?? 0;
    }
    return out;
  }

  double get _sumShares => _resolvedShares().fold<double>(0, (a, b) => a + b);

  void _addPerson(String name, {required bool sharing, required bool asPayer}) {
    final n = name.trim();
    if (n.isEmpty || n.toLowerCase() == 'you') return;
    if (!_parties.any((p) => p.name == n)) {
      _parties.add(_Party(n, sharing: sharing));
    }
    if (asPayer) _payer = n;
    setState(() {});
  }

  Future<void> _promptAddPerson({required bool asPayer}) async {
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
            Text(asPayer ? 'Who paid?' : 'Add a person',
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
                  for (final name
                      in known.where((k) => !_parties.any((p) => p.name == k)))
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
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (picked != null) {
      // A person added as the payer defaults to *not* sharing, so the common
      // "they covered it for me" case becomes a one-step "You owe them" IOU.
      _addPerson(picked, sharing: !asPayer, asPayer: asPayer);
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showAppToast(context,
          message: 'Give it a title', type: AppToastType.warning);
      return;
    }
    if (_total <= 0) {
      showAppToast(context,
          message: 'Enter an amount above ₹0', type: AppToastType.warning);
      return;
    }
    if (_parties.length < 2) {
      showAppToast(context,
          message: 'Add the other person involved',
          type: AppToastType.warning);
      return;
    }
    if (_sharingCount == 0) {
      showAppToast(context,
          message: 'Pick who the expense is split between',
          type: AppToastType.warning);
      return;
    }
    final shares = _resolvedShares();
    if ((_sumShares - _total).abs() > 1.0) {
      showAppToast(context,
          message: 'Shares must add up to ${_fmt.format(_total)}',
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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
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
                    _grip(colors),
                    const SizedBox(height: 18),
                    _header(colors),
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
                                    prefixText: '₹ ', hintText: '0'),
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

                    const SizedBox(height: 20),
                    _fieldLabel(colors, 'Paid by'),
                    const SizedBox(height: 10),
                    _payerSelector(colors),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _fieldLabel(colors, 'Split between'),
                        const Spacer(),
                        _methodToggle(colors),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _parties.length; i++)
                      _partyRow(colors, i, shares.isEmpty ? 0 : shares[i]),
                    const SizedBox(height: 4),
                    _addPersonButton(colors),

                    const SizedBox(height: 18),
                    _outcomeCard(colors, shares),

                    const SizedBox(height: 22),
                    _actions(colors),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _grip(AppColors colors) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(AppColors colors) => Row(
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
      );

  Widget _methodToggle(AppColors colors) {
    Widget chip(String label, SplitMethod m) {
      final sel = _method == m;
      return GestureDetector(
        onTap: () => setState(() => _method = m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? AppColors.gold : colors.cardAlt,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: sel ? AppColors.gold : colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
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

  Widget _payerSelector(AppColors colors) {
    Widget chip(String value, String label, {bool isMe = false}) {
      final sel = _payer == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _payer = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(7, 6, 14, 6),
            decoration: BoxDecoration(
              color: sel ? AppColors.gold : colors.cardAlt,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: sel ? AppColors.gold : colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PersonAvatar(name: isMe ? 'You' : value, isMe: isMe, size: 26),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        sel ? const Color(0xFF15110A) : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_me, 'You', isMe: true),
          for (final p in _parties.where((p) => p.name != _me))
            chip(p.name, p.name),
          _addChip(colors, 'Someone else', () => _promptAddPerson(asPayer: true)),
        ],
      ),
    );
  }

  Widget _addChip(AppColors colors, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.cardAlt,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: AppColors.goldDeep.withValues(alpha: 0.4),
              style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: AppColors.goldDeep),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldDeep)),
          ],
        ),
      ),
    );
  }

  Widget _partyRow(AppColors colors, int i, double share) {
    final p = _parties[i];
    final isMe = p.name == _me;
    final on = p.sharing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => p.sharing = !p.sharing),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.gold : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: on ? AppColors.gold : colors.textTertiary,
                    width: 1.6),
              ),
              child: on
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Color(0xFF15110A))
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          PersonAvatar(name: isMe ? 'You' : p.name, isMe: isMe, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _label(p.name),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: on ? colors.text : colors.textTertiary,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: !on
                ? Text('not in split',
                    textAlign: TextAlign.right,
                    style:
                        TextStyle(fontSize: 12, color: colors.textTertiary))
                : _method == SplitMethod.equal
                    ? Text(_fmt.format(share),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary))
                    : TextField(
                        controller: p.shareCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixText: '₹',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                        ),
                      ),
          ),
          if (!isMe)
            IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 18, color: colors.textTertiary),
              onPressed: () => setState(() {
                if (_payer == p.name) _payer = _me;
                p.shareCtrl.dispose();
                _parties.removeAt(i);
              }),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _addPersonButton(AppColors colors) {
    return InkWell(
      onTap: () => _promptAddPerson(asPayer: false),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded,
                size: 19, color: AppColors.goldDeep),
            const SizedBox(width: 9),
            Text('Add person to the split',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.goldDeep)),
          ],
        ),
      ),
    );
  }

  /// Plain-language preview of exactly who will owe whom once saved.
  Widget _outcomeCard(AppColors colors, List<double> shares) {
    final lines = <({bool owedToMe, String name, double amt})>[];
    if (_payer == _me) {
      for (var i = 0; i < _parties.length; i++) {
        if (_parties[i].name == _me) continue;
        if (shares.isNotEmpty && shares[i] > 0) {
          lines.add((owedToMe: true, name: _parties[i].name, amt: shares[i]));
        }
      }
    } else {
      final myIdx = _parties.indexWhere((p) => p.name == _me);
      final myShare = (myIdx >= 0 && shares.isNotEmpty) ? shares[myIdx] : 0.0;
      if (myShare > 0) {
        lines.add((owedToMe: false, name: _payer, amt: myShare));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded,
                  size: 15, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text('Result',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: colors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          if (lines.isEmpty)
            Text('Fill in the amount and who paid to see the result.',
                style: TextStyle(fontSize: 13, color: colors.textTertiary))
          else
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      l.owedToMe
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      size: 14,
                      color: l.owedToMe ? colors.success : colors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 13.5, color: colors.text),
                          children: l.owedToMe
                              ? [
                                  TextSpan(
                                      text: l.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const TextSpan(text: ' owes you '),
                                  TextSpan(
                                    text: _fmt.format(l.amt),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: colors.success),
                                  ),
                                ]
                              : [
                                  const TextSpan(
                                      text: 'You owe ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  TextSpan(
                                      text: l.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const TextSpan(text: ' '),
                                  TextSpan(
                                    text: _fmt.format(l.amt),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: colors.danger),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _actions(AppColors colors) {
    return Row(
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
            onPressed: _saving ? null : () => Navigator.pop(context, false),
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
