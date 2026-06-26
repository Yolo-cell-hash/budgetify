import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// App-themed modal dialog matching the toast aesthetic: rounded surface,
/// a gold-accented icon chip in the header, tight premium typography.
/// Use via [showAppDialog].
class AppDialog extends StatelessWidget {
  final IconData icon;
  final Color? accent;
  final String title;
  final String? subtitle;
  final Widget? content;
  final List<Widget> actions;

  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.content,
    this.actions = const [],
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final a = accent ?? colors.brandAccent;

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: a.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: a, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: 18),
              content!,
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _spaced(actions),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _spaced(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) out.add(const SizedBox(width: 8));
    }
    return out;
  }
}

Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}

/// Show a themed, non-dismissible progress dialog with a gold spinner.
/// Returns nothing; dismiss with `Navigator.pop(context)`.
Future<void> showAppProgressDialog(BuildContext context, String message) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProgressDialog(message: message),
  );
}

class _ProgressDialog extends StatelessWidget {
  final String message;
  const _ProgressDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation(colors.brandAccent),
              ),
            ),
            const SizedBox(width: 18),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: colors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
