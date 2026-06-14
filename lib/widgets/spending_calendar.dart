import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/theme_provider.dart';
import '../screens/daily_analysis_screen.dart';
import '../services/database_service.dart';
import 'privacy_amount.dart';

/// A monthly spending heatmap: each day is a cell shaded by how much was
/// spent that day (relative to the month's busiest day). Tapping a day opens
/// the day's detailed analysis. Non-expense categories (self-transfer,
/// investments) are already excluded by [DatabaseService.getDailySpending].
class SpendingCalendar extends StatefulWidget {
  const SpendingCalendar({super.key});

  @override
  State<SpendingCalendar> createState() => _SpendingCalendarState();
}

class _SpendingCalendarState extends State<SpendingCalendar> {
  final DatabaseService _db = DatabaseService();
  late DateTime _month; // first day of the displayed month
  Map<DateTime, double> _daily = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final start = _month;
    final end = DateTime(_month.year, _month.month + 1, 0, 23, 59, 59);
    final daily = await _db.getDailySpending(startDate: start, endDate: end);
    if (!mounted) return;
    setState(() {
      _daily = daily;
      _loading = false;
    });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _month.isBefore(DateTime(now.year, now.month, 1));
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final maxSpend = _daily.values.fold<double>(0, (m, v) => v > m ? v : m);
    final monthTotal = _daily.values.fold<double>(0, (s, v) => s + v);
    final leadingBlanks = _month.weekday - 1; // Mon-first grid
    final today = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month switcher
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    PrivacyAmount(
                      '${fmt.format(monthTotal)} spent',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _canGoNext ? () => _shiftMonth(1) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weekday headers (Mon-first)
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var i = 0; i < leadingBlanks; i++) const SizedBox(),
                for (var day = 1; day <= daysInMonth; day++)
                  _buildDayCell(day, maxSpend, today, colors, fmt),
              ],
            ),

          const SizedBox(height: 16),
          _buildLegend(colors),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    int day,
    double maxSpend,
    DateTime today,
    AppColors colors,
    NumberFormat fmt,
  ) {
    final date = DateTime(_month.year, _month.month, day);
    final spend = _daily[date] ?? 0;
    final isToday =
        date.year == today.year && date.month == today.month && date.day == today.day;
    final isFuture = date.isAfter(today);

    // Heatmap intensity: 0 → faint, max → deep gold
    final ratio = maxSpend > 0 ? (spend / maxSpend) : 0.0;
    Color bg;
    Color fg;
    if (spend <= 0) {
      bg = colors.cardAlt;
      fg = colors.textTertiary;
    } else {
      final opacity = (0.18 + 0.62 * ratio).clamp(0.18, 0.85);
      bg = AppColors.gold.withOpacity(opacity);
      fg = ratio > 0.45 ? const Color(0xFF15110A) : colors.text;
    }

    return GestureDetector(
      onTap: isFuture ? null : () => _openDay(date),
      child: Opacity(
        opacity: isFuture ? 0.35 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? Border.all(color: AppColors.gold, width: 2)
                : Border.all(color: colors.border),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(AppColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Less',
            style: TextStyle(fontSize: 11, color: colors.textTertiary)),
        const SizedBox(width: 8),
        ...[0.18, 0.35, 0.55, 0.75, 0.85].map(
          (o) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(o),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('More',
            style: TextStyle(fontSize: 11, color: colors.textTertiary)),
      ],
    );
  }

  void _openDay(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DailyAnalysisScreen(date: date)),
    ).then((_) => _load());
  }
}
