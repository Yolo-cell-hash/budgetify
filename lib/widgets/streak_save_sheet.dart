import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import '../services/gamification_service.dart';
import 'streak_flame.dart';

/// The icy accent shared by every freeze surface (matches the road's packs).
const Color kFreezeAccent = Color(0xFF27C0F5);

/// The Streak Save dialog: a broken streak can be revived for one freeze, on
/// the return day only. Mirrors the badge-unlock celebration's framing (same
/// radius, scale-in, letterspaced label) but frosted over. Pops with the
/// restored streak length when a freeze was spent, null when declined or the
/// offer lapsed mid-dialog.
Future<int?> showStreakSaveSheet(
  BuildContext context, {
  required int previous,
  required int available,
}) {
  final colors = AppColors.of(context);
  return showDialog<int>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (ctx) => Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: kFreezeAccent.withValues(alpha: 0.4)),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.7, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, v, child) => Transform.scale(
            scale: v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
        child: _StreakSaveContent(previous: previous, available: available),
      ),
    ),
  );
}

class _StreakSaveContent extends StatefulWidget {
  final int previous;
  final int available;

  const _StreakSaveContent({required this.previous, required this.available});

  @override
  State<_StreakSaveContent> createState() => _StreakSaveContentState();
}

class _StreakSaveContentState extends State<_StreakSaveContent> {
  bool _busy = false;

  Future<void> _restore() async {
    setState(() => _busy = true);
    final restored = await GamificationService().restoreStreak();
    if (!mounted) return;
    if (restored == null) {
      // Offer lapsed (e.g. day rolled over) — close without pretending.
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(restored);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.streakSaveLabel,
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: kFreezeAccent,
            ),
          ),
          const SizedBox(height: 18),
          _FrozenFlame(previous: widget.previous),
          const SizedBox(height: 18),
          Text(
            l10n.streakSaveTitle(widget.previous),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.streakSaveBody(widget.previous + 1),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🧊', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                l10n.freezesLeftLabel(widget.available),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _restore,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.local_fire_department_rounded, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: kFreezeAccent,
                foregroundColor: const Color(0xFF06263A),
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              label: Text(l10n.useFreezeCta),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(
              l10n.startFreshCta,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The living streak flame, frozen over: desaturated toward an icy blue by a
/// colour matrix (it still breathes underneath — cold, not dead), sitting in a
/// frosted ring with an ice-cube badge.
class _FrozenFlame extends StatelessWidget {
  final int previous;

  const _FrozenFlame({required this.previous});

  // Luminance-weighted grayscale, re-tinted cold: red dampened, blue boosted.
  static const List<double> _iceMatrix = <double>[
    0.16, 0.54, 0.05, 0, 20, //
    0.19, 0.64, 0.06, 0, 34, //
    0.21, 0.72, 0.07, 0, 64, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  kFreezeAccent.withValues(alpha: 0.20),
                  kFreezeAccent.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                color: kFreezeAccent.withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
          ),
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(_iceMatrix),
            child: StreakFlame(streak: previous, size: 52),
          ),
          const Positioned(
            right: 14,
            bottom: 12,
            child: Text('🧊', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}
