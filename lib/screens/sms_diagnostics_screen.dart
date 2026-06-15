import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../providers/theme_provider.dart';
import '../services/sms_diagnostics_service.dart';
import '../services/sms_parser_service.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass.dart';

/// Hidden tester screen that lists bank SMS the parser couldn't turn into
/// transactions, with the reason it stopped — so undetected-transaction
/// reports can be reproduced and shared without prompting the user.
///
/// Reached by long-pressing the version row in Settings.
class SmsDiagnosticsScreen extends StatefulWidget {
  const SmsDiagnosticsScreen({super.key});

  @override
  State<SmsDiagnosticsScreen> createState() => _SmsDiagnosticsScreenState();
}

class _SmsDiagnosticsScreenState extends State<SmsDiagnosticsScreen> {
  List<SmsDiagnosticEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await SmsDiagnosticsService.all();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _copyAll() async {
    if (_entries.isEmpty) return;
    final buffer = StringBuffer()
      ..writeln('Budgetify SMS diagnostics (${_entries.length} entries)')
      ..writeln('Generated: ${DateTime.now()}')
      ..writeln();
    for (final e in _entries) {
      buffer
        ..writeln('[${_reasonLabel(e.reason)}]  ${e.sender}  '
            '${DateFormat('d MMM, h:mm a').format(e.time)}')
        ..writeln(e.body)
        ..writeln('---');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      showAppToast(
        context,
        message: 'Copied ${_entries.length} entries to clipboard',
        type: AppToastType.success,
      );
    }
  }

  Future<void> _clear() async {
    final confirm = await showAppDialog<bool>(
      context,
      builder: (ctx) => AppDialog(
        icon: Icons.delete_sweep_outlined,
        title: 'Clear diagnostics?',
        subtitle: 'This permanently removes the captured SMS log from this '
            'device. It cannot be undone.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await SmsDiagnosticsService.clear();
    await _load();
    if (mounted) {
      showAppToast(context, message: 'Diagnostics cleared',
          type: AppToastType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy all',
            onPressed: _entries.isEmpty ? null : _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: _entries.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AmbientBackground(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _entries.isEmpty
                    ? _buildEmpty(colors)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: _entries.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          if (i == 0) return _buildHeaderNote(colors);
                          return _buildEntryCard(_entries[i - 1], colors);
                        },
                      ),
              ),
            ),
    );
  }

  Widget _buildHeaderNote(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        'Bank messages that passed the sender check but could not be parsed '
        'into a transaction. Reproduce an undetected payment, then use Copy '
        'all to share the sample. Nothing is uploaded.',
        style: TextStyle(fontSize: 12.5, height: 1.4, color: colors.textSecondary),
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return ListView(
      // ListView so pull-to-refresh works even when empty.
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.fact_check_outlined, size: 56, color: colors.textTertiary),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'No unparsed bank messages',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'If a bank transaction went undetected, trigger a scan or wait for '
            'the SMS, then pull to refresh — it will show up here with the '
            'reason it was missed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: colors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(SmsDiagnosticEntry e, AppColors colors) {
    final (label, color) = _reasonStyle(e.reason, colors);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM, h:mm a').format(e.time),
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            e.sender,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            e.body,
            style: TextStyle(fontSize: 12.5, height: 1.35, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  (String, Color) _reasonStyle(SmsParseReason reason, AppColors colors) {
    switch (reason) {
      case SmsParseReason.noAmount:
        return ('NO AMOUNT', colors.danger);
      case SmsParseReason.noType:
        return ('NO TYPE', const Color(0xFFD79A3C));
      case SmsParseReason.nonTransaction:
        return ('FILTERED', colors.textSecondary);
      case SmsParseReason.notBank:
        return ('NOT BANK', colors.textTertiary);
      case SmsParseReason.promo:
        return ('PROMO', colors.textTertiary);
      case SmsParseReason.parsed:
        return ('PARSED', colors.success);
    }
  }

  String _reasonLabel(SmsParseReason reason) => _reasonStyle(reason,
          AppColors.of(context))
      .$1;
}
