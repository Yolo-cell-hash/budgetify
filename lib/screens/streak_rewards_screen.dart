import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/gamification_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/streak_reward_road.dart';

/// Standalone Streak Rewards Road, reachable from Settings → Appearance
/// regardless of whether Gamified Budgets mode is on. The streak itself is
/// always tracked, so themes can be unlocked and applied here either way.
class StreakRewardsScreen extends StatefulWidget {
  const StreakRewardsScreen({super.key});

  @override
  State<StreakRewardsScreen> createState() => _StreakRewardsScreenState();
}

class _StreakRewardsScreenState extends State<StreakRewardsScreen> {
  final GamificationService _svc = GamificationService();

  ({int current, int longest})? _streak;

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
    if (mounted) setState(() => _streak = info);
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
      body: streak == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: StreakRewardRoad(
                currentStreak: streak.current,
                longestStreak: streak.longest,
              ),
            ),
    );
  }
}
