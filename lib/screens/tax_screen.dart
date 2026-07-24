import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/financial_year.dart';
import '../models/tax_bucket.dart';
import '../providers/theme_provider.dart';
import '../services/export_service.dart';
import '../services/tax_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_toast.dart';

final NumberFormat _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Tax Deductions — tag deductible spends and total them against statutory
/// caps for a financial year. An ORGANISER, never a tax advisor: it sums what
/// the user tagged and shows caps; it never computes liability or claims an
/// amount is deductible (see the standing disclaimer). Gated on the user's
/// regime — new-regime filers see an honest explainer instead of buckets.
class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});

  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  final TaxService _svc = TaxService();
  FinancialYear _year = FinancialYear.current();
  TaxYearSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Lazy "forever" sweep: catch any new transactions a user rule covers
    // before totalling, so a rule taught once keeps working over time.
    await _svc.applyRulesToUntagged();
    final summary = await _svc.summaryForYear(_year);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _pickRegime() async {
    final l10n = context.l10nRead;
    final current = _summary?.regime ?? TaxRegime.unsure;
    final chosen = await showModalBottomSheet<TaxRegime>(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.taxRegime,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.text)),
                ),
              ),
              for (final r in TaxRegime.values)
                ListTile(
                  onTap: () => Navigator.pop(ctx, r),
                  title: Text(_regimeLabel(l10n, r),
                      style: TextStyle(color: colors.text)),
                  trailing: r == current
                      ? Icon(Icons.check_rounded, color: colors.brandAccent)
                      : null,
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen != null && chosen != current) {
      await _svc.setRegime(chosen);
      await _load();
    }
  }

  String _regimeLabel(AppStrings l10n, TaxRegime r) => switch (r) {
        TaxRegime.old => l10n.taxRegimeOld,
        TaxRegime.newRegime => l10n.taxRegimeNew,
        TaxRegime.unsure => l10n.taxRegimeUnsure,
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: AppBarTitle(context.l10n.taxDeductions,
            icon: Icons.receipt_long_rounded),
        actions: [
          IconButton(
            tooltip: context.l10n.taxRegime,
            icon: const Icon(Icons.tune_rounded),
            onPressed: _loading ? null : _pickRegime,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _body(colors)),
      // Export only makes sense with buckets shown and something tagged.
      floatingActionButton: (!_loading &&
              (_summary?.regime.showsBuckets ?? false) &&
              (_summary?.hasAnyTagged ?? false))
          ? FloatingActionButton.extended(
              onPressed: _export,
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(context.l10n.taxExport),
            )
          : null,
    );
  }

  /// Pick a format, build the summary for the selected FY, and save it through
  /// the system file picker (SAF) — no storage permission, like every other
  /// export and the encrypted backup.
  Future<void> _export() async {
    final l10n = context.l10nRead;
    final format = await showModalBottomSheet<ExportFormat>(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.taxExport,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.text)),
                ),
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf_rounded, color: colors.accent),
                title: Text(l10n.taxExportPdf,
                    style: TextStyle(color: colors.text)),
                subtitle: Text(l10n.taxExportPdfDesc,
                    style: TextStyle(color: colors.textSecondary)),
                onTap: () => Navigator.pop(ctx, ExportFormat.pdf),
              ),
              ListTile(
                leading: Icon(Icons.table_chart_rounded, color: colors.accent),
                title: Text(l10n.taxExportExcel,
                    style: TextStyle(color: colors.text)),
                subtitle: Text(l10n.taxExportExcelDesc,
                    style: TextStyle(color: colors.textSecondary)),
                onTap: () => Navigator.pop(ctx, ExportFormat.excel),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (format == null || !mounted) return;

    try {
      final input = await _svc.buildTaxSummaryInput(_year);
      final bundle =
          await ExportService().buildTaxSummary(format: format, input: input);
      if (!mounted) return;
      if (bundle == null) {
        showAppToast(context, message: l10n.taxEmpty, type: AppToastType.info);
        return;
      }
      final path = await FilePicker.saveFile(
        dialogTitle: l10n.taxExport,
        fileName: bundle.filename,
        bytes: Uint8List.fromList(bundle.bytes),
      );
      if (path == null || !mounted) return; // cancelled
      showAppToast(
        context,
        message: l10n.taxExportSaved,
        type: AppToastType.success,
        actionLabel: l10n.open,
        onAction: () => OpenFilex.open(path),
      );
    } catch (e) {
      if (mounted) {
        showAppToast(context,
            message: l10n.exportFailed('$e'), type: AppToastType.error);
      }
    }
  }

  Widget _body(AppColors colors) {
    final summary = _summary!;
    if (!summary.regime.showsBuckets) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [_newRegimeCard(colors)],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _yearSelector(colors),
        const SizedBox(height: 12),
        _disclaimer(colors),
        const SizedBox(height: 12),
        if (!summary.hasAnyTagged) ...[
          _emptyHint(colors),
          const SizedBox(height: 12),
        ],
        for (final b in summary.buckets) ...[
          _bucketCard(colors, b),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _yearSelector(AppColors colors) {
    final years = FinancialYear.recent();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final y in years) ...[
            ChoiceChip(
              label: Text(y.label),
              selected: y == _year,
              showCheckmark: false,
              onSelected: (_) {
                if (y != _year) {
                  setState(() => _year = y);
                  _load();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _disclaimer(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.taxDisclaimer,
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(AppColors colors) {
    return Text(
      context.l10n.taxEmpty,
      style: TextStyle(fontSize: 13, height: 1.4, color: colors.textTertiary),
    );
  }

  Widget _bucketCard(AppColors colors, TaxBucketSummary s) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.bucket.section,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.text)),
                    const SizedBox(height: 2),
                    Text(s.bucket.shortLabel,
                        style: TextStyle(
                            fontSize: 12.5, color: colors.textSecondary)),
                  ],
                ),
              ),
              Text(_inr.format(s.total),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.text)),
            ],
          ),
          const SizedBox(height: 12),
          if (s.isCapped)
            _cappedFooter(colors, s, l10n)
          else
            _evidenceFooter(colors, s, l10n),
        ],
      ),
    );
  }

  Widget _cappedFooter(AppColors colors, TaxBucketSummary s, AppStrings l10n) {
    final frac = s.fillFraction ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            backgroundColor: colors.cardAlt,
            valueColor: AlwaysStoppedAnimation(
                s.isFull ? colors.success : colors.brandAccent),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.taxUsedOfCap(_inr.format(s.total), _inr.format(s.cap)),
              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
            ),
            Text(
              s.isFull
                  ? l10n.taxCapReached
                  : l10n.taxHeadroom(_inr.format(s.headroom ?? 0)),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: s.isFull ? colors.success : colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _evidenceFooter(AppColors colors, TaxBucketSummary s, AppStrings l10n) {
    // Evidence-only: total already shown above; here only the honest caption,
    // never a cap bar (the deductible figure is not the sum of payments).
    final caption =
        s.bucket.id == '80G' ? l10n.taxEvidenceDonation : l10n.taxEvidenceRent;
    return Text(
      caption,
      style: TextStyle(fontSize: 12, height: 1.4, color: colors.textTertiary),
    );
  }

  Widget _newRegimeCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.brandAccent),
          const SizedBox(height: 12),
          Text(
            context.l10n.taxNewRegimeExplainer,
            style: TextStyle(fontSize: 14, height: 1.5, color: colors.text),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _pickRegime,
              child: Text(context.l10n.taxRegime),
            ),
          ),
        ],
      ),
    );
  }
}
