import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ledger_models.dart';
import '../providers/theme_provider.dart';
import '../services/ledger_service.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/person_avatar.dart';
import '../widgets/privacy_amount.dart';
import '../widgets/split_editor_sheet.dart';
import 'person_detail_screen.dart';

/// The offline split ledger: an at-a-glance "who owes whom" summary, the list
/// of people you share expenses with, and the entry point to add a split.
/// Everything here is your own private record — no accounts, nothing synced.
class SplitsScreen extends StatefulWidget {
  const SplitsScreen({super.key});

  @override
  State<SplitsScreen> createState() => _SplitsScreenState();
}

class _SplitsScreenState extends State<SplitsScreen> {
  final _ledger = LedgerService();
  LedgerSummary? _summary;
  Map<String, PersonContext> _context = const {};
  bool _loading = true;

  final _fmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _ledger.summary();
    final ctx = await _ledger.peopleContext();
    if (!mounted) return;
    setState(() {
      _summary = s;
      _context = ctx;
      _loading = false;
    });
  }

  Future<void> _openEditor({bool iOwe = false}) async {
    final saved = await showSplitEditor(context, startIOwe: iOwe);
    if (saved) _load();
  }

  /// Two clearly-labelled ways to add to the ledger, so recording what you owe
  /// is as discoverable as splitting a bill.
  Future<void> _showAddMenu() async {
    final colors = AppColors.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text('Add to ledger',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.text)),
              ),
              _addOption(
                colors,
                icon: Icons.call_split_rounded,
                accent: AppColors.successDark,
                title: 'Split an expense',
                subtitle: 'You paid or split a bill — others owe you their share',
                onTap: () => Navigator.pop(ctx, 'split'),
              ),
              const SizedBox(height: 10),
              _addOption(
                colors,
                icon: Icons.north_east_rounded,
                accent: AppColors.dangerDark,
                title: 'I owe someone',
                subtitle: 'Someone covered you — record what you owe them',
                onTap: () => Navigator.pop(ctx, 'iowe'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == 'split') {
      await _openEditor();
    } else if (choice == 'iowe') {
      await _openEditor(iOwe: true);
    }
  }

  Widget _addOption(
    AppColors colors, {
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
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
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 22, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: colors.text)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: colors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Future<void> _openPerson(String person) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PersonDetailScreen(person: person)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_split_rounded, size: 18, color: AppColors.gold),
            SizedBox(width: 8),
            Text('Splits',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: AmbientBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    FadeSlideIn(order: 0, child: _summaryCard(s!)),
                    const SizedBox(height: 18),
                    if (s.people.where((p) => !p.isSettled).isEmpty)
                      _emptyState(colors)
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'People',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      for (var i = 0; i < s.people.length; i++)
                        FadeSlideIn(
                          order: i + 1,
                          child: _personTile(colors, s.people[i]),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summaryCard(LedgerSummary s) {
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
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.net.abs() < personBalanceEps
                ? 'ALL SETTLED'
                : s.net > 0
                    ? "YOU'RE OWED OVERALL"
                    : 'YOU OWE OVERALL',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.gold.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          PrivacyAmount(
            _fmt.format(s.net.abs()),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _miniStat('Owed to you', s.owedToMe,
                      AppColors.successDark, Icons.south_west_rounded),
                ),
                Container(
                    width: 1, height: 38,
                    color: Colors.white.withValues(alpha: 0.12)),
                Expanded(
                  child: _miniStat('You owe', s.iOwe, AppColors.dangerDark,
                      Icons.north_east_rounded,
                      alignEnd: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value, Color color, IconData icon,
      {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!alignEnd) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
            if (alignEnd) ...[
              const SizedBox(width: 5),
              Icon(icon, size: 13, color: color),
            ],
          ],
        ),
        const SizedBox(height: 6),
        PrivacyAmount(
          _fmt.format(value),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _personTile(AppColors colors, PersonBalance p) {
    final (status, color) = p.owesMe
        ? ('owes you', colors.success)
        : p.iOwe
            ? ('you owe', colors.danger)
            : ('settled up', colors.textTertiary);

    final ctx = _context[p.person];
    final String subtitle;
    if (ctx?.latestExpense != null) {
      subtitle = ctx!.splitCount > 1
          ? '${ctx.latestExpense}  ·  +${ctx.splitCount - 1} more'
          : ctx.latestExpense!;
    } else {
      subtitle = 'Settled from payments';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        onTap: () => _openPerson(p.person),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              PersonAvatar(name: p.person, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.person,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 12, color: colors.textTertiary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            subtitle,
                            style: TextStyle(
                                fontSize: 12.5, color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!p.isSettled)
                    PrivacyAmount(
                      _fmt.format(p.net.abs()),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: color,
                      ),
                    )
                  else
                    Icon(Icons.check_circle_rounded, size: 18, color: color),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
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

  Widget _emptyState(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 40, 8, 0),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.gold.withValues(alpha: 0.20),
                  AppColors.gold.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.diversity_3_rounded,
                size: 30, color: AppColors.goldDeep),
          ),
          const SizedBox(height: 16),
          Text(
            'No splits yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Split a bill, or record what you owe someone — all on your device. '
            'Tap Add to get started. When you pay for a group, only your share '
            'counts as your spending.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
