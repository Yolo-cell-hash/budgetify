import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

enum AppToastType { success, error, info, warning }

/// App-themed toast: a floating dark "ink" card with a gold-accented icon
/// chip, matching the premium look of the rest of the app. Replaces the
/// default Material SnackBar everywhere user feedback is shown.
void showAppToast(
  BuildContext context, {
  required String message,
  AppToastType type = AppToastType.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final brand = AppColors.of(context).brandAccent;
  final (icon, accent) = switch (type) {
    AppToastType.success => (Icons.check_circle_rounded, AppColors.successDark),
    AppToastType.error => (Icons.error_rounded, AppColors.dangerDark),
    AppToastType.warning => (Icons.warning_amber_rounded, brand),
    AppToastType.info => (Icons.info_rounded, brand),
  };

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: _ToastCard(
          icon: icon,
          accent: accent,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
}

class _ToastCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToastCard({
    required this.icon,
    required this.accent,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        // Same ink gradient in both light and dark for a consistent,
        // premium feel that reads as a deliberate brand surface.
        gradient: const LinearGradient(
          colors: [Color(0xFF23273A), Color(0xFF14161F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFF2F2EF),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                onAction!();
              },
              style: TextButton.styleFrom(
                backgroundColor: accent.withOpacity(0.14),
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
