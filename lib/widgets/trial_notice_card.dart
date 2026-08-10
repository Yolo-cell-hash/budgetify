import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import '../screens/plus_screen.dart';
import '../services/entitlement_service.dart';

/// The only warning a user gets before their free window closes.
///
/// Deliberately quiet: nothing at all for the first ~76 days, then this card
/// at 14 days left and again at 3, each dismissible. There is no countdown
/// anywhere else in the app — the decision was to hide the clock but not the
/// ending, so this card and the "alerts are paused" notification are the whole
/// of the disclosure.
///
/// Leads with what the user KEEPS. The free tier still holds the transaction
/// history, SMS capture, the overall budget, goals, splits and streaks, so the
/// honest framing is "some things pause", not "your app stops working".
class TrialNoticeCard extends StatefulWidget {
  const TrialNoticeCard({super.key});

  @override
  State<TrialNoticeCard> createState() => _TrialNoticeCardState();
}

class _TrialNoticeCardState extends State<TrialNoticeCard> {
  /// Resolved once per mount. The card must not reappear mid-session after a
  /// dismissal, and the underlying day count only moves at midnight anyway.
  int? _threshold = EntitlementService().pendingTrialNotice;

  Future<void> _dismiss() async {
    final threshold = _threshold;
    if (threshold == null) return;
    setState(() => _threshold = null);
    await EntitlementService().dismissTrialNotice(threshold);
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlusScreen()),
    );
    if (!mounted) return;
    // A purchase on that screen retires the notice for good.
    setState(() => _threshold = EntitlementService().pendingTrialNotice);
  }

  @override
  Widget build(BuildContext context) {
    if (_threshold == null) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final daysLeft = EntitlementService().trialDaysLeft;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brandAccentDeep.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded,
                  size: 18, color: colors.brandAccentDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.trialEndingTitle(daysLeft),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: Icon(Icons.close_rounded, color: colors.textTertiary),
                tooltip: l10n.dismiss,
                onPressed: _dismiss,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(29, 2, 8, 0),
            child: Text(
              l10n.trialEndingBody,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: TextButton(
              onPressed: _openPaywall,
              child: Text(
                l10n.trialEndingCta,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.brandAccentDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
