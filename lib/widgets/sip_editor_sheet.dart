import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/holding.dart';
import '../models/sip.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/sip_service.dart';
import 'app_dialog.dart';
import 'app_toast.dart';

/// Premium bottom sheet to create or edit an automated SIP / RD. Handles its
/// own persistence (holding + sip) and pops `true` when something changed so
/// the caller can refresh. Optionally pre-fills from a tagged holding the user
/// chose to automate.
Future<bool> showSipEditor(
  BuildContext context, {
  Sip? existing,
  String? prefillName,
  String? prefillCategory,
  double? prefillAmount,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF16181E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SipEditorSheet(
      existing: existing,
      prefillName: prefillName,
      prefillCategory: prefillCategory,
      prefillAmount: prefillAmount,
    ),
  );
  return result ?? false;
}

class _SipEditorSheet extends StatefulWidget {
  final Sip? existing;
  final String? prefillName;
  final String? prefillCategory;
  final double? prefillAmount;

  const _SipEditorSheet({
    this.existing,
    this.prefillName,
    this.prefillCategory,
    this.prefillAmount,
  });

  @override
  State<_SipEditorSheet> createState() => _SipEditorSheetState();
}

class _SipEditorSheetState extends State<_SipEditorSheet> {
  final _db = DatabaseService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  final _valueCtrl = TextEditingController(); // already-invested seed (create)

  late String _category;
  late bool _amountIsFixed;
  late int _dayOfMonth;
  late bool _autoDetect;
  DateTime? _startDate;
  DateTime? _endDate;
  int _priorInstallments = 0;
  bool _priorEdited = false;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? widget.prefillName ?? '');
    _amountCtrl = TextEditingController(
      text: (e?.amount ?? widget.prefillAmount)?.toStringAsFixed(0) ?? '',
    );
    _category = e?.category ??
        widget.prefillCategory ??
        (HoldingCategories.investments.contains('Mutual Fund')
            ? 'Mutual Fund'
            : HoldingCategories.investments.first);
    if (!HoldingCategories.investments.contains(_category)) {
      _category = 'Mutual Fund';
    }
    _amountIsFixed = e?.amountIsFixed ?? true;
    _dayOfMonth = e?.dayOfMonth ?? DateTime.now().day.clamp(1, 28);
    _autoDetect = e?.autoDetect ?? true;
    _startDate = e?.startDate;
    _endDate = e?.endDate;
    _priorInstallments = e?.priorInstallments ?? 0;
    _priorEdited = _editing;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  /// Whether to ask the "have you already paid past instalments?" question:
  /// only when a start date earlier than this month was given.
  bool get _showCatchUp {
    final s = _startDate;
    if (s == null) return false;
    final now = DateTime.now();
    return s.isBefore(DateTime(now.year, now.month, 1));
  }

  Sip _draftForSuggestion() => Sip(
        name: _nameCtrl.text,
        category: _category,
        dayOfMonth: _dayOfMonth,
        startDate: _startDate,
        endDate: _endDate,
        createdAt: DateTime.now(),
      );

  void _recomputePriorDefault() {
    if (_priorEdited) return;
    if (_showCatchUp) {
      _priorInstallments =
          SipService.suggestedPriorInstallments(_draftForSuggestion());
    } else {
      _priorInstallments = 0;
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? (_startDate ?? now).add(const Duration(days: 365)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 15),
      lastDate: DateTime(now.year + 30),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
      _recomputePriorDefault();
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty) {
      showAppToast(context, message: 'Give your plan a name', type: AppToastType.warning);
      return;
    }
    if (_amountIsFixed && (amt == null || amt <= 0)) {
      showAppToast(context,
          message: 'Enter the monthly amount', type: AppToastType.warning);
      return;
    }
    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      showAppToast(context,
          message: 'End date must be after the start date',
          type: AppToastType.warning);
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    var holdingId = widget.existing?.holdingId;

    // On creation, seed a backing holding with whatever is already invested so
    // it appears in net worth immediately. Otherwise the first instalment will
    // create the holding lazily.
    if (!_editing) {
      final seed = double.tryParse(_valueCtrl.text.trim()) ?? 0;
      if (seed > 0) {
        holdingId = await _db.insertHolding(Holding(
          name: name,
          kind: HoldingKind.asset,
          category: _category,
          amount: seed,
          updatedAt: now,
        ));
      }
    }

    final sip = Sip(
      id: widget.existing?.id,
      name: name,
      category: _category,
      amount: amt,
      amountIsFixed: _amountIsFixed,
      dayOfMonth: _dayOfMonth,
      startDate: _startDate,
      endDate: _endDate,
      autoDetect: _autoDetect,
      holdingId: holdingId,
      priorInstallments: _showCatchUp ? _priorInstallments : 0,
      lastReminderPeriod: widget.existing?.lastReminderPeriod,
      createdAt: widget.existing?.createdAt ?? now,
    );

    if (_editing) {
      await _db.updateSip(sip);
    } else {
      await _db.insertSip(sip);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        accent: AppColors.dangerLight,
        title: 'Delete this plan?',
        subtitle: 'Automation stops. The investment value already added to your '
            'net worth stays — only the recurring tracking is removed.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerLight),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (widget.existing?.id != null) {
      await _db.deleteSip(widget.existing!.id!);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
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
                    child: const Text('🔁', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editing ? 'Edit recurring plan' : 'Automate a SIP / RD',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Set it once — we\'ll track each instalment for you.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _label(colors, 'Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Parag Parikh Flexi Cap',
                ),
              ),
              const SizedBox(height: 16),

              _label(colors, 'Type'),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: HoldingCategories.investments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = HoldingCategories.investments[i];
                    final sel = c == _category;
                    return GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? AppColors.gold : colors.cardAlt,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: sel ? AppColors.gold : colors.border,
                          ),
                        ),
                        child: Text(
                          '${HoldingCategories.icon(c)}  $c',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? const Color(0xFF15110A)
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label(colors,
                            _amountIsFixed ? 'Monthly amount' : 'Typical amount'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            hintText: _amountIsFixed ? '5000' : 'optional',
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
                        _label(colors, 'On day'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _dayOfMonth,
                          isExpanded: true,
                          items: [
                            for (var d = 1; d <= 31; d++)
                              DropdownMenuItem(
                                value: d,
                                child: Text(_ordinal(d)),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _dayOfMonth = v ?? _dayOfMonth),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _switchTile(
                colors,
                title: 'Fixed amount each month',
                subtitle:
                    'Turn off if the amount varies (e.g. step-up SIP).',
                value: _amountIsFixed,
                onChanged: (v) => setState(() => _amountIsFixed = v),
              ),
              _switchTile(
                colors,
                title: 'Auto-detect from SMS',
                subtitle:
                    'Match the bank debit automatically when it\'s tagged as an investment.',
                value: _autoDetect,
                onChanged: (v) => setState(() => _autoDetect = v),
              ),
              const SizedBox(height: 16),

              _label(colors, 'Duration (optional)'),
              const SizedBox(height: 4),
              Text(
                'Add a start & end date to see a progress bar to your goal.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _dateField(colors, 'Start',
                        _startDate, () => _pickDate(isStart: true)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField(colors, 'End',
                        _endDate, () => _pickDate(isStart: false)),
                  ),
                ],
              ),

              if (!_editing) ...[
                const SizedBox(height: 16),
                _label(colors, 'Already invested so far (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'current value of this investment',
                  ),
                ),
              ],

              if (_showCatchUp) ...[
                const SizedBox(height: 16),
                _catchUpCard(colors),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  if (_editing)
                    OutlinedButton(
                      onPressed: _saving ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dangerLight,
                      ),
                      child: const Text('Delete'),
                    )
                  else
                    OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_editing ? 'Save plan' : 'Start automating'),
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

  Widget _catchUpCard(AppColors colors) {
    final fmtStart = _startDate != null
        ? DateFormat('MMM yyyy').format(_startDate!)
        : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🗓️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Catching up since $fmtStart',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'We can\'t verify past instalments, so just tell us how many you\'ve '
            'already completed — your progress will reflect them.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Instalments already paid',
                  style: TextStyle(fontSize: 13.5, color: colors.text),
                ),
              ),
              _stepperButton(colors, Icons.remove, () {
                setState(() {
                  _priorEdited = true;
                  if (_priorInstallments > 0) _priorInstallments--;
                });
              }),
              SizedBox(
                width: 40,
                child: Text(
                  '$_priorInstallments',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
              _stepperButton(colors, Icons.add, () {
                setState(() {
                  _priorEdited = true;
                  _priorInstallments++;
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(AppColors colors, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: colors.cardAlt,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, size: 18, color: colors.text),
      ),
    );
  }

  Widget _dateField(
    AppColors colors,
    String label,
    DateTime? value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
            Expanded(
              child: Text(
                value != null ? DateFormat('d MMM yyyy').format(value) : label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: value != null ? colors.text : colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(
    AppColors colors, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.text)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 12, color: colors.textSecondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _label(AppColors colors, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      );
}

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}
