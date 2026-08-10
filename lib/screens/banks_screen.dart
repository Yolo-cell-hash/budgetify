import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/bank_summary.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/custom_tag_service.dart';
import '../services/database_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/bank_chips.dart';
import '../widgets/export_options_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/merchant_bar.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/rename_bank_sheet.dart';
import 'transactions_screen.dart';

/// "Which bank did the spending" for one month at a time.
///
/// The month strip cycles: each month lists only the banks that actually saw
/// activity in it, so three accounts with one card in use reads as a single
/// row, and the month a dormant account wakes up it appears on its own.
/// Self-transfers, investments and settlements are reported as *moved*, never
/// as spend.
class BanksScreen extends StatefulWidget {
  /// Month to open on (defaults to the current one).
  final DateTime? initialMonth;

  const BanksScreen({super.key, this.initialMonth});

  @override
  State<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends State<BanksScreen> {
  final DatabaseService _db = DatabaseService();
  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  late DateTime _month;
  BankBreakdown _breakdown = BankBreakdown.empty;
  bool _loading = true;

  /// The oldest month worth stepping back to — the month of the first
  /// transaction on record, or this month when there are none. Null only
  /// until the first load finishes.
  DateTime? _earliest;

  DateTime get _start => DateTime(_month.year, _month.month, 1);
  DateTime get _end => DateTime(_month.year, _month.month + 1, 0, 23, 59, 59);

  @override
  void initState() {
    super.initState();
    final base = widget.initialMonth ?? DateTime.now();
    _month = DateTime(base.year, base.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final txns = await _db.getTransactionsByDateRange(_start, _end);
    final earliest = _earliest ?? await _earliestMonth();
    if (!mounted) return;
    setState(() {
      _breakdown = BankBreakdown.fromTransactions(txns);
      _earliest = earliest;
      _loading = false;
    });
  }

  Future<DateTime> _earliestMonth() async {
    final now = DateTime.now();
    final all = await _db.getAllTransactions();
    // Nothing on record: don't offer an endless walk back through empty
    // months.
    if (all.isEmpty) return DateTime(now.year, now.month);
    var oldest = all.first.detectedAt;
    for (final t in all) {
      if (t.detectedAt.isBefore(oldest)) oldest = t.detectedAt;
    }
    return DateTime(oldest.year, oldest.month);
  }

  bool get _canGoBack {
    final earliest = _earliest;
    return earliest == null || _month.isAfter(earliest);
  }

  bool get _canGoForward {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month));
  }

  void _step(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
    _load();
  }

  /// Hands the month on screen to the export sheet, so "export what I'm
  /// looking at" starts from the right dates; the sheet's bank chips pick
  /// which accounts go in.
  Future<void> _export() => showExportSheet(
        context,
        initialDateRange: DateTimeRange(start: _start, end: _end),
      );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(context.l10n.banksTitle,
            icon: Icons.account_balance_rounded),
        actions: [
          if (_breakdown.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: context.l10n.exportThisBank,
              onPressed: () => _export(),
            ),
        ],
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            _monthStrip(colors),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _breakdown.isEmpty
                      ? _emptyState(colors)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            children: [
                              FadeSlideIn(order: 0, child: _header(colors)),
                              const SizedBox(height: 16),
                              FadeSlideIn(order: 1, child: _list(colors)),
                              const SizedBox(height: 12),
                              Text(
                                '${context.l10n.banksUsedHint}\n'
                                '${context.l10n.renameBankTip}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.5,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Month strip ─────────────────────────────────────────────────────
  Widget _monthStrip(AppColors colors) {
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: colors.textSecondary,
            onPressed: _canGoBack ? () => _step(-1) : null,
          ),
          Expanded(
            child: Text(
              isCurrent
                  ? context.l10n.thisMonth
                  : context.l10n.monthYear(_month),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            color: colors.textSecondary,
            onPressed: _canGoForward ? () => _step(1) : null,
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────
  Widget _header(AppColors colors) {
    final top = _breakdown.topSpender;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colors.brandAccent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.spentAcrossBanks(_breakdown.bankCount),
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: colors.brandAccent.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          PrivacyAnimatedAmount(
            value: _breakdown.totalSpent,
            formatter: _fmt,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: Colors.white,
            ),
          ),
          if (_breakdown.totalMoved > 0) ...[
            const SizedBox(height: 4),
            PrivacyAmount(
              context.l10n.movedNotCounted(_fmt.format(_breakdown.totalMoved)),
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
          if (top != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.topBankLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          bankDisplayLabel(context, top),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          context.l10n.pctOfBankSpend(
                              (_breakdown.share(top) * 100).round()),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_breakdown.totalReceived > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          context.l10n.receivedLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 3),
                        PrivacyAmount(
                          _fmt.format(_breakdown.totalReceived),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Ranked list ─────────────────────────────────────────────────────
  Widget _list(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _breakdown.banks.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _bankRow(_breakdown.banks[i], i),
          ],
        ],
      ),
    );
  }

  Widget _bankRow(BankActivity bank, int index) {
    final colors = AppColors.of(context);
    final label = bankDisplayLabel(context, bank);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: MerchantBar(
            rank: index + 1,
            name: label,
            amountLabel: _fmt.format(bank.spent),
            count: bank.transactionCount,
            fraction: _breakdown.barFraction(bank),
            shareOfTotal: _breakdown.share(bank),
            color: CustomTagService.colorFromName(bank.id),
            isTop: index == 0 && bank.spent > 0,
            captionSuffix: bank.moved > 0
                ? context.l10n.movedNotCounted(_fmt.format(bank.moved))
                : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionsScreen(
                  initialBankId: bank.id,
                  initialBankLabel: label,
                  initialStartDate: _start,
                  initialEndDate: _end,
                ),
              ),
            ).then((_) => _load()),
          ),
        ),
        // The rename affordance lives here rather than behind a long-press:
        // for a header like "ZZZTOP" the whole point is that the user can see
        // it needs a name.
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 16),
          color: colors.textTertiary,
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.renameBank,
          onPressed: () async {
            if (await renameBankAndReport(context, bank)) {
              notifyAppDataChanged();
              await _load();
            }
          },
        ),
      ],
    );
  }

  Widget _emptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_outlined,
              size: 56, color: colors.textTertiary),
          const SizedBox(height: 12),
          Text(context.l10n.noBankActivity,
              style: TextStyle(color: colors.textSecondary)),
        ],
      ),
    );
  }
}
