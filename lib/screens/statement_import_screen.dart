import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/statement_import_models.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/statement_import_service.dart';
import '../widgets/app_bar_title.dart';

/// Three-step flow for importing a bank statement (CSV/XLSX):
/// 1. **Match the columns** — confirm/fix the auto-guessed mapping, name the
///    source. A confirmed mapping is remembered per header signature, so the
///    next statement from the same bank skips straight through.
/// 2. **Review** — new rows vs probable duplicates (excluded by default) vs
///    unreadable rows, with a date-range trim and an SMS-era note.
/// 3. **Done** — what was inserted, skipped and auto-tagged.
///
/// Pops with a [StatementImportResult] after a successful import, null when
/// abandoned.
class StatementImportScreen extends StatefulWidget {
  final List<List<String>> grid;
  final int headerRowIndex;
  final StatementMapping initialMapping;
  final String suggestedLabel;

  const StatementImportScreen({
    super.key,
    required this.grid,
    required this.headerRowIndex,
    required this.initialMapping,
    required this.suggestedLabel,
  });

  @override
  State<StatementImportScreen> createState() => _StatementImportScreenState();
}

class _StatementImportScreenState extends State<StatementImportScreen> {
  final StatementImportService _service = StatementImportService();

  static const int _maxListedRows = 200;

  int _step = 0;
  late Map<int, StatementColumnRole> _roles;
  late final TextEditingController _labelController;
  bool _busy = false;

  // Review state.
  StatementParseResult? _parsed;
  DateTime? _smsEraStart;
  DateTime? _rangeFrom;
  DateTime? _rangeTo;

  StatementImportResult? _result;

  List<String> get _header => widget.grid[widget.headerRowIndex];

  StatementMapping get _mapping => StatementMapping(roles: _roles);

  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  final DateFormat _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _roles = Map.of(widget.initialMapping.roles);
    _labelController = TextEditingController(text: widget.suggestedLabel);
    _applySavedTemplate();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  /// A previously confirmed mapping for this exact header overrides the
  /// fresh guess — the user already corrected it once.
  Future<void> _applySavedTemplate() async {
    final saved = await _service.loadTemplate(_header);
    if (saved == null || !mounted) return;
    setState(() {
      _roles = Map.of(saved.mapping.roles);
      if (saved.label.trim().isNotEmpty) {
        _labelController.text = saved.label;
      }
    });
  }

  // ── Step transitions ────────────────────────────────────────────────────

  Future<void> _continueToReview() async {
    if (!_mapping.isValid || _busy) return;
    setState(() => _busy = true);

    final parsed = StatementImportService.parseRows(
      widget.grid,
      widget.headerRowIndex,
      _mapping,
    );

    final importable = parsed.rows.where((r) => r.isImportable).toList();
    if (importable.isNotEmpty) {
      var min = importable.first.date!;
      var max = importable.first.date!;
      for (final r in importable) {
        if (r.date!.isBefore(min)) min = r.date!;
        if (r.date!.isAfter(max)) max = r.date!;
      }
      final existing = await _service.loadExistingKeys(min, max);
      StatementImportService.markDuplicates(parsed.rows, existing);
      _rangeFrom = min;
      _rangeTo = max;
    } else {
      _rangeFrom = null;
      _rangeTo = null;
    }
    _smsEraStart = await _service.smsEraStart();

    await _service.saveTemplate(
      _header,
      parsed.mapping,
      _labelController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _parsed = parsed;
      _busy = false;
      _step = 1;
    });
  }

  Future<void> _runImport() async {
    final parsed = _parsed;
    if (parsed == null || _busy) return;
    setState(() => _busy = true);
    final result = await _service.apply(
      _rowsInRange().toList(),
      sourceLabel: _labelController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
      _step = 2;
    });
  }

  // ── Row filtering helpers ───────────────────────────────────────────────

  bool _inRange(StatementRow row) {
    final d = row.date;
    if (d == null) return false;
    if (_rangeFrom != null && d.isBefore(_rangeFrom!)) return false;
    if (_rangeTo != null && d.isAfter(_rangeTo!)) return false;
    return true;
  }

  Iterable<StatementRow> _rowsInRange() =>
      (_parsed?.rows ?? const <StatementRow>[])
          .where((r) => r.isImportable && _inRange(r));

  int get _importCount =>
      _rowsInRange().where((r) => r.include).length;

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          context.l10n.stImportTitle,
          icon: Icons.account_balance_rounded,
        ),
      ),
      body: switch (_step) {
        0 => _buildMapStep(colors),
        1 => _buildReviewStep(colors),
        _ => _buildDoneStep(colors),
      },
    );
  }

  // ── Step 1: column mapping ──────────────────────────────────────────────

  Widget _buildMapStep(AppColors colors) {
    final l10n = context.l10n;
    final mappingValid = _mapping.isValid;

    // A quick trial parse powers the live preview under the mapping.
    StatementParseResult? trial;
    if (mappingValid) {
      trial = StatementImportService.parseRows(
        widget.grid,
        widget.headerRowIndex,
        _mapping,
      );
    }
    final sampleRows =
        trial?.rows.where((r) => r.isImportable).take(3).toList() ??
            const <StatementRow>[];
    final datesUnreadable = trial != null &&
        trial.mapping.dateFormat == null &&
        trial.rows.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.stStepMapTitle,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.stStepMapDesc,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _labelController,
          maxLength: 24,
          style: TextStyle(fontSize: 14.5, color: colors.text),
          decoration: InputDecoration(
            labelText: l10n.stSourceLabel,
            hintText: l10n.stSourceHint,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              for (var c = 0; c < _header.length; c++)
                if (_header[c].trim().isNotEmpty)
                  _ColumnMappingRow(
                    colors: colors,
                    header: _header[c].trim(),
                    sample: _sampleFor(c),
                    role: _roles[c] ?? StatementColumnRole.ignore,
                    onChanged: (role) => setState(() {
                      if (role == StatementColumnRole.ignore) {
                        _roles.remove(c);
                        return;
                      }
                      // A role can live on only one column.
                      _roles.removeWhere((_, r) => r == role);
                      _roles[c] = role;
                    }),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!mappingValid)
          _InfoBanner(
            colors: colors,
            icon: Icons.rule_rounded,
            tint: colors.danger,
            text: l10n.stMappingIncomplete,
          )
        else if (datesUnreadable)
          _InfoBanner(
            colors: colors,
            icon: Icons.event_busy_rounded,
            tint: colors.danger,
            text: l10n.stNoDateFormat,
          )
        else if (sampleRows.isNotEmpty) ...[
          Text(
            l10n.stSampleTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (final row in sampleRows)
                  _TransactionLine(colors: colors, row: row, money: _money),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                mappingValid && !datesUnreadable && !_busy && sampleRows.isNotEmpty
                    ? _continueToReview
                    : null,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(l10n.stContinue),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// First non-empty data value in column [c], as a mapping hint.
  String _sampleFor(int c) {
    for (var i = widget.headerRowIndex + 1;
        i < widget.grid.length && i < widget.headerRowIndex + 12;
        i++) {
      final row = widget.grid[i];
      if (c < row.length && row[c].trim().isNotEmpty) return row[c].trim();
    }
    return '';
  }

  // ── Step 2: review ──────────────────────────────────────────────────────

  Widget _buildReviewStep(AppColors colors) {
    final l10n = context.l10n;
    final parsed = _parsed!;

    final inRange = _rowsInRange().toList();
    final newRows = inRange
        .where((r) => r.status == StatementRowStatus.ready)
        .toList();
    final dupRows = inRange
        .where((r) => r.status == StatementRowStatus.probableDuplicate)
        .toList();
    final invalidRows = parsed.invalid.toList();

    final debits = inRange
        .where((r) => r.include && r.type == TransactionType.debit)
        .length;
    final credits = inRange
        .where((r) => r.include && r.type == TransactionType.credit)
        .length;

    final overlapsSmsEra = _smsEraStart != null &&
        inRange.any((r) => !r.date!.isBefore(_smsEraStart!));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _CountChip(
              colors: colors,
              tint: colors.success,
              label: l10n.stReadyCount(newRows.length),
            ),
            const SizedBox(width: 8),
            if (dupRows.isNotEmpty)
              _CountChip(
                colors: colors,
                tint: const Color(0xFFD79A3C),
                label: l10n.stDupCount(dupRows.length),
              ),
            const SizedBox(width: 8),
            if (invalidRows.isNotEmpty)
              _CountChip(
                colors: colors,
                tint: colors.textTertiary,
                label: l10n.stInvalidCount(invalidRows.length),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _DateRangeCard(
          colors: colors,
          title: l10n.stDateRangeTitle,
          from: _rangeFrom,
          to: _rangeTo,
          format: _dateFmt,
          onPick: (isFrom) => _pickRangeDate(isFrom),
        ),
        if (overlapsSmsEra) ...[
          const SizedBox(height: 12),
          _InfoBanner(
            colors: colors,
            icon: Icons.sms_rounded,
            tint: colors.brandAccent,
            text: l10n.stSmsEraNote(_dateFmt.format(_smsEraStart!)),
          ),
        ],
        const SizedBox(height: 16),
        if (newRows.isNotEmpty) ...[
          _SectionHeader(
            colors: colors,
            icon: Icons.playlist_add_check_rounded,
            tint: colors.success,
            title: l10n.stNewRowsTitle,
            subtitle: l10n.stDebitsCredits(debits, credits),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (final row in newRows.take(_maxListedRows))
                  _TransactionLine(colors: colors, row: row, money: _money),
                if (newRows.length > _maxListedRows)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      l10n.stMoreRows(newRows.length - _maxListedRows),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (dupRows.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            colors: colors,
            icon: Icons.copy_all_rounded,
            tint: const Color(0xFFD79A3C),
            title: l10n.stDuplicatesTitle,
            subtitle: l10n.stDuplicatesDesc,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (final row in dupRows.take(_maxListedRows))
                  _TransactionLine(
                    colors: colors,
                    row: row,
                    money: _money,
                    checkbox: true,
                    onToggle: (v) => setState(() => row.include = v),
                  ),
                if (dupRows.length > _maxListedRows)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      l10n.stMoreRows(dupRows.length - _maxListedRows),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (invalidRows.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            colors: colors,
            icon: Icons.error_outline_rounded,
            tint: colors.textTertiary,
            title: l10n.stInvalidTitle,
            subtitle: null,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.cardAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (final row in invalidRows.take(20))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.narration.isEmpty ? '—' : row.narration,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          row.invalidReason == 'date'
                              ? l10n.stInvalidDateReason
                              : l10n.stInvalidAmountReason,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (invalidRows.length > 20)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      l10n.stMoreRows(invalidRows.length - 20),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _importCount > 0 && !_busy ? _runImport : null,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(l10n.stImportButton(_importCount)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _pickRangeDate(bool isFrom) async {
    final initial = (isFrom ? _rangeFrom : _rangeTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _rangeFrom = DateTime(picked.year, picked.month, picked.day);
      } else {
        _rangeTo = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  // ── Step 3: done ────────────────────────────────────────────────────────

  Widget _buildDoneStep(AppColors colors) {
    final l10n = context.l10n;
    final result = _result!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle_rounded, size: 64, color: colors.success),
          const SizedBox(height: 18),
          Text(
            l10n.stResultTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 14),
          _ResultLine(
            colors: colors,
            icon: Icons.download_done_rounded,
            text: l10n.stResultInserted(result.inserted),
          ),
          if (result.skippedExisting > 0)
            _ResultLine(
              colors: colors,
              icon: Icons.skip_next_rounded,
              text: l10n.stResultSkipped(result.skippedExisting),
            ),
          if (result.autoTagged > 0)
            _ResultLine(
              colors: colors,
              icon: Icons.sell_rounded,
              text: l10n.stResultTagged(result.autoTagged),
            ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, result),
            child: Text(l10n.stDone),
          ),
        ],
      ),
    );
  }
}

// ── Small building blocks ─────────────────────────────────────────────────

class _ColumnMappingRow extends StatelessWidget {
  final AppColors colors;
  final String header;
  final String sample;
  final StatementColumnRole role;
  final ValueChanged<StatementColumnRole> onChanged;

  const _ColumnMappingRow({
    required this.colors,
    required this.header,
    required this.sample,
    required this.role,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  header,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                if (sample.isNotEmpty)
                  Text(
                    sample,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<StatementColumnRole>(
            value: role,
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            dropdownColor: colors.card,
            items: [
              for (final r in StatementColumnRole.values)
                DropdownMenuItem(
                  value: r,
                  child: Text(_roleName(l10n, r)),
                ),
            ],
            onChanged: (r) {
              if (r != null) onChanged(r);
            },
          ),
        ],
      ),
    );
  }

  static String _roleName(dynamic l10n, StatementColumnRole role) =>
      switch (role) {
        StatementColumnRole.date => l10n.stRoleDate,
        StatementColumnRole.description => l10n.stRoleDescription,
        StatementColumnRole.debit => l10n.stRoleDebit,
        StatementColumnRole.credit => l10n.stRoleCredit,
        StatementColumnRole.amount => l10n.stRoleAmount,
        StatementColumnRole.drCr => l10n.stRoleDrCr,
        StatementColumnRole.refNo => l10n.stRoleRefNo,
        StatementColumnRole.balance => l10n.stRoleBalance,
        StatementColumnRole.ignore => l10n.stRoleIgnore,
      };
}

/// One statement row rendered as date · payee/narration · signed amount,
/// optionally with an include checkbox (duplicate overrides).
class _TransactionLine extends StatelessWidget {
  final AppColors colors;
  final StatementRow row;
  final NumberFormat money;
  final bool checkbox;
  final ValueChanged<bool>? onToggle;

  const _TransactionLine({
    required this.colors,
    required this.row,
    required this.money,
    this.checkbox = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = row.type == TransactionType.debit;
    final title = (row.merchant?.isNotEmpty ?? false)
        ? row.merchant!
        : (row.narration.isEmpty ? '—' : row.narration);
    final line = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: checkbox ? 4 : 12,
        vertical: checkbox ? 0 : 7,
      ),
      child: Row(
        children: [
          if (checkbox)
            Checkbox(
              value: row.include,
              onChanged: (v) => onToggle?.call(v ?? false),
              visualDensity: VisualDensity.compact,
            ),
          SizedBox(
            width: 64,
            child: Text(
              row.date == null ? '—' : DateFormat('d MMM yy').format(row.date!),
              style: TextStyle(fontSize: 11.5, color: colors.textTertiary),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isDebit ? '−' : '+'}${money.format(row.amount ?? 0)}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDebit ? colors.danger : colors.success,
            ),
          ),
        ],
      ),
    );
    return line;
  }
}

class _CountChip extends StatelessWidget {
  final AppColors colors;
  final Color tint;
  final String label;

  const _CountChip({
    required this.colors,
    required this.tint,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.colors,
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: tint),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final Color tint;
  final String text;

  const _InfoBanner({
    required this.colors,
    required this.icon,
    required this.tint,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRangeCard extends StatelessWidget {
  final AppColors colors;
  final String title;
  final DateTime? from;
  final DateTime? to;
  final DateFormat format;
  final ValueChanged<bool> onPick;

  const _DateRangeCard({
    required this.colors,
    required this.title,
    required this.from,
    required this.to,
    required this.format,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(DateTime? value, bool isFrom) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onPick(isFrom),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.cardAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                value == null ? '—' : format.format(value),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          chip(from, true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('→', style: TextStyle(color: colors.textTertiary)),
          ),
          chip(to, false),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  final AppColors colors;
  final IconData icon;
  final String text;

  const _ResultLine({
    required this.colors,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: colors.brandAccent),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
