import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ledger_models.dart';
import '../providers/theme_provider.dart';
import '../services/ledger_service.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
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
    if (!mounted) return;
    setState(() {
      _summary = s;
      _loading = false;
    });
  }

  Future<void> _addSplit() async {
    final saved = await showSplitEditor(context);
    if (saved) _load();
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
        onPressed: _addSplit,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New split'),
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
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  p.person.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.person,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(status,
                        style:
                            TextStyle(fontSize: 12.5, color: colors.textTertiary)),
                  ],
                ),
              ),
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
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colors.textTertiary),
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
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('🤝', style: TextStyle(fontSize: 30)),
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
            'Split a bill with friends and track who owes whom — entirely on '
            'your device. When you pay for the group, only your share counts '
            'as your spending.',
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
