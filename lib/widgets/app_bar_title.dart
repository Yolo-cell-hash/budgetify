import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// Shared premium AppBar title: a gold accent icon set in a soft tinted chip
/// beside a tightly-tracked title. Used across secondary screens so they all
/// read as part of the same premium system instead of a plain, bland default
/// text title.
class AppBarTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const AppBarTitle(this.text, {super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
          ),
          child: Icon(icon,
              size: 16, color: isDark ? AppColors.gold : AppColors.goldDeep),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 17.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: colors.text,
          ),
        ),
      ],
    );
  }
}
