import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../models/ledger_models.dart';
import '../providers/theme_provider.dart';
import '../services/ledger_service.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/settle_up_sheet.dart';
import '../widgets/split_editor_sheet.dart';

/// One person's ledger: their net balance with you, a settle-up action, a
/// shareable summary, and the full activity feed of splits and settlements.
class PersonDetailScreen extends StatefulWidget {
  final String person;
  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  final _ledger = LedgerService();
  List<LedgerActivity> _activity = const [];
  double _net = 0;
  bool _loading = true;

  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await _ledger.summary();
    final match = summary.people.where((p) => p.person == widget.person);
    final activity = await _ledger.activityFor(widget.person);
    if (!mounted) return;
    setState(() {
      _net = match.isEmpty ? 0 : match.first.net;
      _activity = activity;
      _loading = false;
    });
  }

  Future<void> _settleUp() async {
    final saved =
        await showSettleUpSheet(context, person: widget.person, net: _net);
    if (saved) _load();
  }

  Future<void> _editSplit(SplitEntry s) async {
    final saved = await showSplitEditor(context, existing: s);
    if (saved) _load();
  }

  void _share() {
    Share.share(_ledger.shareSummary(widget.person, _net));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            tooltip: context.l10n.shareSummary,
            onPressed: _loading ? null : _share,
          ),
        ],
      ),
      body: AmbientBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    FadeSlideIn(order: 0, child: _balanceCard(colors)),
                    const SizedBox(height: 18),
                    if (_activity.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          context.l10n.activityLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      for (var i = 0; i < _activity.length; i++)
                        FadeSlideIn(
                          order: i + 1,
                          child: _activityTile(colors, _activity[i]),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _balanceCard(AppColors colors) {
    final settled = _net.abs() < personBalanceEps;
    final owesMe = _net > 0;
    final accent = settled
        ? AppColors.gold
        : owesMe
            ? AppColors.successDark
            : AppColors.dangerDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settled
                ? context.l10n.allSettledUp
                : owesMe
                    ? context.l10n.personOwesYou(widget.person)
                    : context.l10n.youOwePerson(widget.person),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          PrivacyAmount(
            settled ? '₹0' : _fmt.format(_net.abs()),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _heroButton(
                  Icons.handshake_rounded,
                  context.l10n.settleUp,
                  _settleUp,
                  filled: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _heroButton(
                  Icons.ios_share_rounded,
                  context.l10n.shareLabel,
                  _share,
                  filled: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroButton(IconData icon, String label, VoidCallback onTap,
      {required bool filled}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? AppColors.gold
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: filled
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: filled ? const Color(0xFF15110A) : Colors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: filled ? const Color(0xFF15110A) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityTile(AppColors colors, LedgerActivity a) {
    // delta > 0 ⇒ this entry increases what they owe you (good, green).
    final positive = a.delta > 0;
    final color = positive ? colors.success : colors.danger;
    final icon = a.isSettlement
        ? Icons.handshake_rounded
        : Icons.receipt_long_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: a.isSettlement ? null : () => _editSplit(a.split!),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMM yyyy').format(a.date),
                      style:
                          TextStyle(fontSize: 12, color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              PrivacyAmount(
                '${positive ? '+' : '−'} ${_fmt.format(a.delta.abs())}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
