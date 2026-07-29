import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../l10n/l10n.dart';
import '../models/bank_summary.dart';
import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import '../services/export_service.dart';
import 'app_dialog.dart';
import 'app_toast.dart';
import 'bank_chips.dart';

/// What the export sheet returns when the user taps Export.
class ExportRequest {
  final ExportFormat format;
  final ExportFilter filter;
  const ExportRequest(this.format, this.filter);
}

/// Opens the export sheet and, if the user goes through with it, runs the
/// export. Returns when the file has been saved or the user backed out.
///
/// [initialBanks] / [initialDateRange] pre-tick the sheet, which is how a
/// screen hands off "export what I'm looking at".
Future<void> showExportSheet(
  BuildContext context, {
  Set<String> initialBanks = const {},
  DateTimeRange? initialDateRange,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final request = await showModalBottomSheet<ExportRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF16181E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ExportOptionsSheet(
      initialBanks: initialBanks,
      initialDateRange: initialDateRange,
    ),
  );
  if (request == null || !context.mounted) return;
  await runExport(context, request);
}

/// Builds an export and saves it through the system file picker, reporting
/// every outcome as a toast.
///
/// Saving via the picker (SAF on Android) means the user chooses the
/// destination and the app needs no storage permission — the same route
/// encrypted backups take. Shared by Settings and the Banks screen so both
/// behave identically.
Future<void> runExport(BuildContext context, ExportRequest request) async {
  final l10n = context.l10nRead;
  showAppProgressDialog(context, l10n.exporting);

  ExportBundle? bundle;
  try {
    bundle = await ExportService()
        .buildExport(format: request.format, filter: request.filter);
  } catch (e) {
    if (context.mounted) Navigator.pop(context); // dismiss loading
    if (context.mounted) {
      showAppToast(context,
          message: l10n.exportFailed('$e'), type: AppToastType.error);
    }
    return;
  }

  if (context.mounted) Navigator.pop(context); // dismiss loading
  if (!context.mounted) return;

  if (bundle == null) {
    showAppToast(context,
        message: l10n.noTxnMatchFilters, type: AppToastType.warning);
    return;
  }

  String? path;
  try {
    path = await FilePicker.saveFile(
      dialogTitle: l10n.exportData,
      fileName: bundle.filename,
      bytes: Uint8List.fromList(bundle.bytes),
    );
  } catch (e) {
    if (context.mounted) {
      showAppToast(context,
          message: l10n.exportFailed('$e'), type: AppToastType.error);
    }
    return;
  }

  if (path == null || !context.mounted) return; // user cancelled the save
  final savedPath = path;
  showAppToast(
    context,
    message: l10n.exportSavedAs(savedPath.split(RegExp(r'[\\/]')).last),
    type: AppToastType.success,
    actionLabel: l10n.open,
    onAction: () => OpenFilex.open(savedPath),
  );
}

/// Bottom sheet for choosing an export format and filters (date range,
/// type, banks, categories, merchant/payee). Pops an [ExportRequest] or null.
class ExportOptionsSheet extends StatefulWidget {
  /// Banks to start with ticked — how the Banks screen hands off "export
  /// this one".
  final Set<String> initialBanks;

  /// Date range to start with, for the same hand-off.
  final DateTimeRange? initialDateRange;

  const ExportOptionsSheet({
    super.key,
    this.initialBanks = const {},
    this.initialDateRange,
  });

  @override
  State<ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<ExportOptionsSheet> {
  ExportFormat _format = ExportFormat.excel;
  DateTimeRange? _dateRange;
  final Set<TransactionType> _types = {};
  final Set<String> _categories = {};
  final Set<String> _banks = {};
  final TextEditingController _merchant = TextEditingController();

  /// Banks with stored transactions, ranked by spend. Empty until loaded —
  /// the section stays hidden rather than flashing an empty row.
  List<BankActivity> _availableBanks = const [];

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialDateRange;
    _banks.addAll(widget.initialBanks);
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    final breakdown = await ExportService().usedBanks();
    if (!mounted) return;
    setState(() => _availableBanks = breakdown.banks);
  }

  @override
  void dispose() {
    _merchant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final categories = [...ExpenseCategories.allCategories, 'Uncategorized'];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  color: colors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.exportData,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 18),

            _label(context.l10n.formatLabel),
            const SizedBox(height: 8),
            Row(
              children: [
                _formatChip(ExportFormat.excel, 'Excel', Icons.grid_on, colors),
                const SizedBox(width: 8),
                _formatChip(
                    ExportFormat.csv, 'CSV', Icons.description_outlined, colors),
                const SizedBox(width: 8),
                _formatChip(
                    ExportFormat.text, context.l10n.textFormat, Icons.notes, colors),
                const SizedBox(width: 8),
                _formatChip(ExportFormat.pdf, 'PDF',
                    Icons.picture_as_pdf_outlined, colors),
              ],
            ),
            const SizedBox(height: 20),

            _label(context.l10n.dateRangeLabel),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: colors.cardAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dateRange == null
                            ? context.l10n.allTime
                            : '${DateFormat('dd MMM yyyy').format(_dateRange!.start)}  →  '
                                '${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
                        style: TextStyle(color: colors.text, fontSize: 14),
                      ),
                    ),
                    if (_dateRange != null)
                      GestureDetector(
                        onTap: () => setState(() => _dateRange = null),
                        child: Icon(Icons.close, size: 18, color: colors.textTertiary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _label(context.l10n.typeLabel),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip(null, context.l10n.allFilter, colors),
                const SizedBox(width: 8),
                _typeChip(TransactionType.debit, context.l10n.commonExpenses, colors),
                const SizedBox(width: 8),
                _typeChip(TransactionType.credit, context.l10n.commonIncome, colors),
              ],
            ),
            const SizedBox(height: 20),

            if (_availableBanks.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _label(context.l10n.bankLabel),
                  if (_banks.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(_banks.clear),
                      child: Text(
                        context.l10n.clearLabel,
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableBanks.map((bank) {
                  final selected = _banks.contains(bank.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _banks.remove(bank.id);
                      } else {
                        _banks.add(bank.id);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.accent.withOpacity(0.14)
                            : colors.cardAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? colors.accent : colors.border,
                        ),
                      ),
                      child: Text(
                        bankDisplayLabel(context, bank),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color:
                              selected ? colors.accent : colors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            _label(context.l10n.payeeMerchantContains),
            const SizedBox(height: 8),
            TextField(
              controller: _merchant,
              decoration: InputDecoration(
                hintText: context.l10n.merchantQueryHint,
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label(_categories.isEmpty
                    ? context.l10n.categoriesAll
                    : context.l10n.categoriesSelected(_categories.length)),
                if (_categories.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(_categories.clear),
                    child: Text(
                      context.l10n.clearLabel,
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final selected = _categories.contains(c);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _categories.remove(c);
                    } else {
                      _categories.add(c);
                    }
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.accent.withOpacity(0.14)
                          : colors.cardAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? colors.accent : colors.border,
                      ),
                    ),
                    child: Text(
                      context.l10n.categoryName(c),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? colors.accent : colors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  ExportRequest(
                    _format,
                    ExportFilter(
                      dateRange: _dateRange,
                      types: Set.of(_types),
                      categories: Set.of(_categories),
                      banks: Set.of(_banks),
                      merchantQuery: _merchant.text,
                    ),
                  ),
                ),
                icon: const Icon(Icons.ios_share, size: 18),
                label: Text(context.l10n.exportLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    final colors = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: colors.textSecondary,
      ),
    );
  }

  Widget _formatChip(
      ExportFormat fmt, String label, IconData icon, AppColors colors) {
    final selected = _format == fmt;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _format = fmt),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.accent.withOpacity(0.14) : colors.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20, color: selected ? colors.accent : colors.textSecondary),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.accent : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(TransactionType? type, String label, AppColors colors) {
    final selected =
        type == null ? _types.isEmpty : (_types.length == 1 && _types.contains(type));
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _types.clear();
          if (type != null) _types.add(type);
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.accent.withOpacity(0.14) : colors.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? colors.accent : colors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.accent : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }
}
