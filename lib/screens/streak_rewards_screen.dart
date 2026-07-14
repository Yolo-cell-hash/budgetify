import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/dev_mode.dart';
import '../services/gamification_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/app_toast.dart';
import '../widgets/royal_avatars.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/streak_heatmap.dart';
import '../widgets/streak_reward_road.dart';

/// Standalone Streak Rewards screen — the streak freeze, the consistency
/// heatmap and the Streak Reward Road. Reachable from Settings regardless of
/// whether Gamified Budgets mode is on; the streak itself is always tracked.
class StreakRewardsScreen extends StatefulWidget {
  const StreakRewardsScreen({super.key});

  @override
  State<StreakRewardsScreen> createState() => _StreakRewardsScreenState();
}

class _StreakRewardsScreenState extends State<StreakRewardsScreen> {
  final GamificationService _svc = GamificationService();

  ({int current, int longest})? _streak;
  ({int available, bool armed}) _freeze = (available: 0, armed: false);
  Map<DateTime, int> _appTime = const {};
  int _monthSeconds = 0;
  GamiProfile _profile = const GamiProfile();
  Set<String> _unlockedRoyals = const {};
  int _royalPicks = 0;

  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final info = await _svc.streakInfo();
    final freeze = await _svc.freezeInfo();
    final appTime = await _svc.appTimeByDay();
    final monthSecs = await _svc.monthAppSeconds();
    final profile = await _svc.loadProfile();
    final unlockedRoyals = await _svc.unlockedRoyalIds();
    final royalPicks = await _svc.availableRoyalPicks();
    if (mounted) {
      setState(() {
        _streak = info;
        _freeze = freeze;
        _appTime = appTime;
        _monthSeconds = monthSecs;
        _profile = profile;
        _unlockedRoyals = unlockedRoyals;
        _royalPicks = royalPicks;
      });
    }
  }

  /// "Unlock Now" from a royal-pick milestone: open the picker straight at the
  /// ROYALTY section so the user can choose their royal, then refresh.
  /// Developer mode shows the whole court unlocked; equipping an unearned
  /// royal becomes a session-only preview (never persisted).
  Future<void> _openRoyaltyPicker() async {
    final edited = await showAvatarPicker(
      context,
      _profile,
      unlockedRoyals: DevMode.isActive
          ? {for (final r in kRoyalAvatars) r.id}
          : _unlockedRoyals,
      royalPicksAvailable: _royalPicks,
      onUnlockRoyal: _svc.unlockRoyal,
      scrollToRoyalty: true,
    );
    if (edited != null && !applyDevRoyalPreview(edited, _unlockedRoyals)) {
      await _svc.saveProfile(edited);
    }
    await _load();
  }

  Future<void> _useFreeze() async {
    final ok = await _svc.armFreeze();
    if (!mounted) return;
    if (ok) {
      showAppToast(
        context,
        message: 'Streak freeze armed — your streak survives one missed day.',
        type: AppToastType.success,
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final streak = _streak;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: AppBarTitle(
          context.l10n.streakRewards,
          icon: Icons.local_fire_department_rounded,
        ),
      ),
      body: SafeArea(child: streak == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FreezeCard(
                    info: _freeze,
                    onUse: _useFreeze,
                    colors: colors,
                  ),
                  const SizedBox(height: 16),
                  StreakHeatmap(
                    secondsByDay: _appTime,
                    monthSeconds: _monthSeconds,
                  ),
                  StreakRewardRoad(
                    currentStreak: streak.current,
                    longestStreak: streak.longest,
                    royalPicksSpent: _unlockedRoyals.length,
                    onChooseRoyal: _openRoyaltyPicker,
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

/// "Streak Freeze" item card: shows how many freezes are banked and lets the
/// user arm one to protect against a single missed day. Earned every 5 days.
class _FreezeCard extends StatelessWidget {
  final ({int available, bool armed}) info;
  final Future<void> Function() onUse;
  final AppColors colors;

  const _FreezeCard({
    required this.info,
    required this.onUse,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final available = info.available;
    final armed = info.armed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: armed ? colors.success.withValues(alpha: 0.6) : colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF27C0F5).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Text('🧊', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Streak Freeze',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colors.text,
                      ),
                    ),
                    if (available > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.brandAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$available',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colors.brandAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  armed
                      ? 'Armed — your streak survives one missed day.'
                      : available > 0
                          ? 'Use one to protect a missed day. Earn one every 5 days.'
                          : 'Earn one for every 5-day stretch of your streak.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (armed)
            Icon(Icons.shield_rounded, color: colors.success, size: 26)
          else
            ElevatedButton(
              onPressed: available > 0 ? () => onUse() : null,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: const Text('Use'),
            ),
        ],
      ),
    );
  }
}
