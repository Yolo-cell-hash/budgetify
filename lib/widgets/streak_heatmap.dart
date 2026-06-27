import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';
import '../services/gamification_service.dart';

/// "Don't break the chain" — a GitHub-style consistency heatmap driven by daily
/// time-in-app. Columns are weeks (oldest → this week), rows are weekdays; each
/// cell's intensity scales with that day's foreground minutes. Also surfaces the
/// playful [UsageTitle] earned from this month's time in the app.
class StreakHeatmap extends StatelessWidget {
  final Map<DateTime, int> secondsByDay; // date-only → seconds
  final int monthSeconds;
  final int weeks;

  const StreakHeatmap({
    super.key,
    required this.secondsByDay,
    required this.monthSeconds,
    this.weeks = 16,
  });

  static int _level(int seconds) {
    final m = seconds / 60.0;
    if (m <= 0) return 0;
    if (m < 5) return 1;
    if (m < 15) return 2;
    if (m < 30) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final start = startOfWeek.subtract(Duration(days: 7 * (weeks - 1)));

    Color cell(int lvl) => lvl == 0
        ? colors.cardAlt
        : colors.brandAccent.withValues(alpha: 0.16 + lvl * 0.20);

    final monthHours = monthSeconds / 3600.0;
    final title = usageTitleFor(monthHours);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded,
                  size: 17, color: colors.brandAccent),
              const SizedBox(width: 8),
              Text(
                'Consistency',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: colors.text,
                ),
              ),
              const Spacer(),
              if (title != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.brandAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${title.emoji} ${title.name}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: colors.brandAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title == null
                ? '${monthHours.toStringAsFixed(1)} h in the app this month — keep going to earn a title'
                : '${monthHours.toStringAsFixed(1)} h in the app this month',
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var wk = 0; wk < weeks; wk++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      children: [
                        for (var d = 0; d < 7; d++)
                          _Cell(
                            date: start.add(Duration(days: wk * 7 + d)),
                            today: today,
                            secondsByDay: secondsByDay,
                            cell: cell,
                            accent: colors.brandAccent,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Less',
                  style: TextStyle(fontSize: 11, color: colors.textTertiary)),
              const SizedBox(width: 6),
              for (var l = 0; l < 5; l++) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: cell(l),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 3),
              ],
              const SizedBox(width: 3),
              Text('More',
                  style: TextStyle(fontSize: 11, color: colors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final DateTime date;
  final DateTime today;
  final Map<DateTime, int> secondsByDay;
  final Color Function(int) cell;
  final Color accent;

  const _Cell({
    required this.date,
    required this.today,
    required this.secondsByDay,
    required this.cell,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final future = date.isAfter(today);
    final secs = secondsByDay[date] ?? 0;
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: future ? Colors.transparent : cell(StreakHeatmap._level(secs)),
        borderRadius: BorderRadius.circular(3),
        border: date == today ? Border.all(color: accent, width: 1.4) : null,
      ),
    );
  }
}
