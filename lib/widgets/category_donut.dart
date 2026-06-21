import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../providers/theme_provider.dart';
import 'privacy_amount.dart';

/// A slim, decongested donut for category spending.
///
/// Fixes the "one slice is 90% and the rest are slivers" problem:
/// - at most [maxSlices] slices; everything under [minSliceShare] of the
///   total is grouped into a single neutral "Other" slice
/// - no labels crammed onto slices — the ring stays clean and the total
///   sits in the center; an optional legend carries names/amounts/percent
class CategoryDonut extends StatelessWidget {
  final Map<String, double> spending;
  final bool showLegend;
  final String centerLabel;

  static const int maxSlices = 5;
  static const double minSliceShare = 0.04;
  static const Color _otherColor = Color(0xFF8A8D96);

  const CategoryDonut({
    super.key,
    required this.spending,
    this.showLegend = true,
    this.centerLabel = 'Spent',
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fmt = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final total = spending.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();

    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Big slices keep their identity; the long tail becomes "Other"
    final main = <MapEntry<String, double>>[];
    double otherTotal = 0;
    for (final entry in sorted) {
      final share = entry.value / total;
      if (main.length < maxSlices && share >= minSliceShare) {
        main.add(entry);
      } else {
        otherTotal += entry.value;
      }
    }

    final slices = [
      for (final e in main)
        (
          name: e.key,
          value: e.value,
          color: ExpenseCategories.getColor(e.key),
        ),
      if (otherTotal > 0)
        (name: 'Other', value: otherTotal, color: _otherColor),
    ];

    return Column(
      children: [
        SizedBox(
          height: 208,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 68,
                  startDegreeOffset: -90,
                  sections: slices
                      .map(
                        (s) => PieChartSectionData(
                          value: s.value,
                          color: s.color,
                          showTitle: false,
                          radius: 26,
                        ),
                      )
                      .toList(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  PrivacyAmount(
                    fmt.format(total),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 18),
          ...slices.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(s.value / total * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 86,
                    child: PrivacyAmount(
                      fmt.format(s.value),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
