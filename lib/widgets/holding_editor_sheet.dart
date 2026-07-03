import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/holding.dart';
import '../models/sip.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/sip_service.dart';
import '../services/tutorial_service.dart';
import 'app_dialog.dart';
import 'app_toast.dart';

/// One premium editor for every net-worth entry. Pick Asset/Liability and a
/// type; for **recurring** investment types (RD, Mutual Fund, Stocks, Bonds,
/// PPF, Crypto) an automation suite pops down so the holding and its SIP/RD
/// schedule live together. Fixed Deposit, savings, loans etc. stay simple.
///
/// Persists the holding and (when recurring) its 1:1 linked [Sip], and returns
/// `true` when something changed so the caller can refresh.
Future<bool> showHoldingEditor(
  BuildContext context, {
  Holding? existingHolding,
  Sip? existingSip,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF16181E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _HoldingEditorSheet(
      existingHolding: existingHolding,
      existingSip: existingSip,
    ),
  );
  return result ?? false;
}

class _HoldingEditorSheet extends StatefulWidget {
  final Holding? existingHolding;
  final Sip? existingSip;

  const _HoldingEditorSheet({this.existingHolding, this.existingSip});

  @override
  State<_HoldingEditorSheet> createState() => _HoldingEditorSheetState();
}

class _HoldingEditorSheetState extends State<_HoldingEditorSheet> {
  final _db = DatabaseService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _amountCtrl;

  late HoldingKind _kind;
  late String _category;
  late bool _recurring;
  late int _dayOfMonth;
  late bool _remindMe;
  DateTime? _startDate;
  DateTime? _endDate;
  int _priorInstallments = 0;
  bool _priorEdited = false;
  bool _saving = false;

  bool get _editing => widget.existingHolding != null;

  @override
  void initState() {
    super.initState();
    final h = widget.existingHolding;
    final s = widget.existingSip;
    _kind = h?.kind ?? HoldingKind.asset;
    _category = h?.category ?? HoldingCategories.assetCategories.first;
    _nameCtrl = TextEditingController(text: h?.name ?? '');
    _valueCtrl =
        TextEditingController(text: h == null ? '' : h.amount.toStringAsFixed(0));
    _amountCtrl =
        TextEditingController(text: s?.amount?.toStringAsFixed(0) ?? '');
    _recurring = s != null;
    _dayOfMonth = s?.dayOfMonth ?? DateTime.now().day.clamp(1, 28);
    _remindMe = s?.autoDetect ?? true;
    _startDate = s?.startDate;
    _endDate = s?.endDate;
    _priorInstallments = s?.priorInstallments ?? 0;
    _priorEdited = s != null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _canRecur =>
      _kind == HoldingKind.asset && HoldingCategories.supportsRecurring(_category);

  bool get _showAutomation => _canRecur && _recurring;

  /// Ask "have past instalments been paid?" only when a start date earlier
  /// than this month was given.
  bool get _showCatchUp {
    final s = _startDate;
    if (s == null) return false;
    final now = DateTime.now();
    return s.isBefore(DateTime(now.year, now.month, 1));
  }

  void _selectCategory(String c) {
    setState(() {
      _category = c;
      // The automation suite "pops down" automatically for recurring types.
      _recurring = HoldingCategories.supportsRecurring(c);
    });
  }

  void _selectKind(HoldingKind k) {
    setState(() {
      _kind = k;
      final cats = HoldingCategories.forKind(k);
      if (!cats.contains(_category)) _category = cats.first;
      if (!_canRecur) _recurring = false;
    });
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
    _priorInstallments = _showCatchUp
        ? SipService.suggestedPriorInstallments(_draftForSuggestion())
        : 0;
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
    final value = double.tryParse(_valueCtrl.text.trim()) ?? 0;
    final amount = double.tryParse(_amountCtrl.text.trim());

    if (name.isEmpty) {
      showAppToast(context,
          message: context.l10nRead.giveItAName, type: AppToastType.warning);
      return;
    }
    if (_showAutomation) {
      if (amount == null || amount <= 0) {
        showAppToast(context,
            message: context.l10nRead.enterMonthlyAmount,
            type: AppToastType.warning);
        return;
      }
      if (_startDate != null &&
          _endDate != null &&
          _endDate!.isBefore(_startDate!)) {
        showAppToast(context,
            message: context.l10nRead.endAfterStart,
            type: AppToastType.warning);
        return;
      }
    } else if (value <= 0) {
      showAppToast(context,
          message: context.l10nRead.enterValueAboveZero,
          type: AppToastType.warning);
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();

    // Upsert the holding (it's the source of truth for net worth).
    final holding = Holding(
      id: widget.existingHolding?.id,
      name: name,
      kind: _kind,
      category: _category,
      amount: value,
      updatedAt: now,
    );
    final int holdingId;
    if (_editing) {
      await _db.updateHolding(holding);
      holdingId = widget.existingHolding!.id!;
    } else {
      holdingId = await _db.insertHolding(holding);
    }

    if (_showAutomation) {
      final sip = Sip(
        id: widget.existingSip?.id,
        name: name,
        category: _category,
        amount: amount,
        amountIsFixed: true,
        dayOfMonth: _dayOfMonth,
        startDate: _startDate,
        endDate: _endDate,
        autoDetect: _remindMe,
        holdingId: holdingId,
        priorInstallments: _showCatchUp ? _priorInstallments : 0,
        lastReminderPeriod: widget.existingSip?.lastReminderPeriod,
        createdAt: widget.existingSip?.createdAt ?? now,
      );
      if (widget.existingSip != null) {
        await _db.updateSip(sip);
      } else {
        await _db.insertSip(sip);
      }
    } else if (widget.existingSip?.id != null) {
      // Recurring turned off (or category changed) → drop the plan, keep the
      // holding and the value already invested.
      await _db.deleteSip(widget.existingSip!.id!);
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final isInvestment =
        _kind == HoldingKind.asset && HoldingCategories.isInvestment(_category);
    final hasPlan = widget.existingSip != null;
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_outline_rounded,
        accent: AppColors.dangerLight,
        title: context.l10nRead.deleteHoldingTitle(isInvestment),
        subtitle: hasPlan
            ? context.l10nRead.deleteHoldingWithPlan(_nameCtrl.text.trim())
            : context.l10nRead.deleteHoldingSimple(_nameCtrl.text.trim()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10nRead.commonCancel),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.dangerLight),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10nRead.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (widget.existingSip?.id != null) {
      await _db.deleteSip(widget.existingSip!.id!);
    }
    if (widget.existingHolding?.id != null) {
      await _db.deleteHolding(widget.existingHolding!.id!);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cats = HoldingCategories.forKind(_kind);
    if (!cats.contains(_category)) _category = cats.first;
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
              // Guided tour: one-time explainer while the user is just
              // looking around — Cancel below moves the tour along.
              if (TutorialService.instance.isAt(TutorialStep.investEditor)) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.gold.withOpacity(0.45)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.school_outlined,
                          size: 18, color: AppColors.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.tutInvestEditorBanner,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: colors.brandAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance_wallet_rounded,
                        color: colors.brandAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _editing
                          ? context.l10n.editEntry
                          : context.l10n.addToNetWorth,
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

              // Asset / Liability toggle
              Row(
                children: [
                  _kindChip(context.l10n.assetKind, _kind == HoldingKind.asset,
                      () => _selectKind(HoldingKind.asset)),
                  const SizedBox(width: 8),
                  _kindChip(
                      context.l10n.liabilityKind,
                      _kind == HoldingKind.liability,
                      () => _selectKind(HoldingKind.liability)),
                ],
              ),
              const SizedBox(height: 16),

              _label(colors, context.l10n.typeLabel),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = cats[i];
                    final sel = c == _category;
                    return GestureDetector(
                      onTap: () => _selectCategory(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? colors.brandAccent : colors.cardAlt,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: sel ? colors.brandAccent : colors.border,
                          ),
                        ),
                        child: Text(
                          '${HoldingCategories.icon(c)}  ${context.l10n.holdingCategoryName(c)}',
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

              _label(colors, context.l10n.nameLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: context.l10n.holdingNameHint,
                ),
              ),
              const SizedBox(height: 16),

              _label(
                  colors,
                  _showAutomation
                      ? context.l10n.investedSoFar
                      : context.l10n.currentValue),
              const SizedBox(height: 8),
              TextField(
                controller: _valueCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: _showAutomation ? '0' : '',
                ),
              ),

              if (_canRecur) ...[
                const SizedBox(height: 8),
                _recurringToggle(colors),
              ],

              if (_showAutomation) _automationSection(colors),

              const SizedBox(height: 24),
              Row(
                children: [
                  if (_editing)
                    OutlinedButton(
                      onPressed: _saving ? null : _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dangerLight,
                      ),
                      child: Text(context.l10n.commonDelete),
                    )
                  else
                    OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      child: Text(context.l10n.commonCancel),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                          _editing ? context.l10n.commonSave : context.l10n.addLabel),
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

  Widget _recurringToggle(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.brandAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.brandAccent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Text('🔁', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.recurringSipRd,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: colors.text)),
                const SizedBox(height: 2),
                Text(context.l10n.trackEachInstalment,
                    style:
                        TextStyle(fontSize: 11.5, color: colors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
          ),
        ],
      ),
    );
  }

  Widget _automationSection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(colors, context.l10n.monthlyAmount),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: '5000',
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
                  _label(colors, context.l10n.onDay),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _dayOfMonth,
                    isExpanded: true,
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(
                            value: d, child: Text(context.l10n.dayOrdinal(d))),
                    ],
                    onChanged: (v) =>
                        setState(() => _dayOfMonth = v ?? _dayOfMonth),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _switchTile(
          colors,
          title: context.l10n.remindToLog,
          subtitle: context.l10n.remindToLogDesc,
          value: _remindMe,
          onChanged: (v) => setState(() => _remindMe = v),
        ),
        const SizedBox(height: 16),
        _label(colors, context.l10n.durationOptional),
        const SizedBox(height: 4),
        Text(
          context.l10n.durationDesc,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _dateField(colors, context.l10n.startLabel, _startDate,
                  () => _pickDate(isStart: true)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dateField(colors, context.l10n.endLabel, _endDate,
                  () => _pickDate(isStart: false)),
            ),
          ],
        ),
        if (_showCatchUp) ...[
          const SizedBox(height: 16),
          _catchUpCard(colors),
        ],
      ],
    );
  }

  Widget _catchUpCard(AppColors colors) {
    final fmtStart =
        _startDate != null ? context.l10n.monthYearShort(_startDate!) : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.brandAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.brandAccent.withValues(alpha: 0.30)),
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
                  context.l10n.catchingUpSince(fmtStart),
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
            context.l10n.catchUpDesc,
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
                child: Text(context.l10n.instalmentsAlreadyPaid,
                    style: TextStyle(fontSize: 13.5, color: colors.text)),
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

  Widget _kindChip(String label, bool selected, VoidCallback onTap) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.brandAccent : colors.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? colors.brandAccent : colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? const Color(0xFF15110A) : colors.textSecondary,
            ),
          ),
        ),
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
                value != null ? context.l10n.mediumDate(value) : label,
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
