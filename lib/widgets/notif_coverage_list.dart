import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/notification_parser_service.dart';

/// The payment-app allowlist, grouped by how much of a user's money each
/// app's notifications can actually account for.
///
/// The grouping is the point. "Capture from payment apps" reads like a
/// complete second pipeline, and for PayZapp it is; for GPay, PhonePe & co.
/// it only ever catches money coming *in*, because those apps end a payment
/// on a success screen and never post a notification for it. Someone who
/// turns this on expecting their UPI spends to start appearing — and then
/// finds only credits — would reasonably conclude the reader is broken. So
/// the app says which is which, up front and again afterwards, rather than
/// letting "enabled" imply "complete".
///
/// Shown in the enable explainer (before the system permission screen) and
/// from the **Which apps are read** row on the settings tile.
class NotifCoverageList extends StatelessWidget {
  const NotifCoverageList({super.key, this.showFooter = true});

  /// Whether to close with the "everything else is ignored" promise. On in
  /// the enable dialog, where the privacy contract is the decision being
  /// made; off where the list is being re-read for reference.
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        isDark ? const Color(0xFF8A8D96) : const Color(0xFF6E727C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.notifCaptureOnlyTheseApps,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _CoverageGroup(
          icon: Icons.swap_vert_rounded,
          accent: const Color(0xFF2AA76F),
          heading: l10n.notifCoverageBothWays,
          note: l10n.notifCoverageBothWaysNote,
          apps: NotificationParserService.bothWaysApps,
          muted: muted,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _CoverageGroup(
          icon: Icons.south_west_rounded,
          accent: const Color(0xFFC98A2B),
          heading: l10n.notifCoverageCreditsOnly,
          note: l10n.notifCoverageCreditsOnlyNote,
          apps: NotificationParserService.creditsOnlyApps,
          muted: muted,
          isDark: isDark,
        ),
        if (showFooter) ...[
          const SizedBox(height: 14),
          Text(
            l10n.notifCaptureEverythingElse,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: muted),
          ),
        ],
      ],
    );
  }
}

/// One coverage band: what it means, then the apps in it.
class _CoverageGroup extends StatelessWidget {
  const _CoverageGroup({
    required this.icon,
    required this.accent,
    required this.heading,
    required this.note,
    required this.apps,
    required this.muted,
    required this.isDark,
  });

  final IconData icon;
  final Color accent;
  final String heading;
  final String note;
  final List<WatchedApp> apps;
  final Color muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 6),
            // The heading wraps rather than clipping: it is a full phrase,
            // and longer in every language the app ships in than in English.
            Expanded(
              child: Text(
                heading,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final app in apps)
              Chip(
                label: Text(
                  app.label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          note,
          style: TextStyle(fontSize: 12, height: 1.4, color: muted),
        ),
      ],
    );
  }
}
