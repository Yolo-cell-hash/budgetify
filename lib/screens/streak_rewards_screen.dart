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
import '../widgets/streak_save_sheet.dart';

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
  // The streak-save offer standing today, if any (broken streak + banked
  // freeze) — drives the restore banner.
  ({int previous, int freezes})? _saveOffer;
  Map<DateTime, int> _appTime = const {};
  int _monthSeconds = 0;
  GamiProfile _profile = const GamiProfile();
  Set<String> _unlockedRoyals = const {};
  // Streak-picked royals only — pick accounting must not count a royal
  // bought with money (unlockedRoyalIds unions purchases).
  int _royalPicksSpent = 0;
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
    // Catch up Road freeze packs first (e.g. a backup restore just raised the
    // longest streak), so the tray below reflects them.
    await _svc.syncFreezePacks();
    final info = await _svc.streakInfo();
    final freeze = await _svc.freezeInfo();
    final saveOffer = await _svc.streakSaveOffer();
    final appTime = await _svc.appTimeByDay();
    final monthSecs = await _svc.monthAppSeconds();
    final profile = await _svc.loadProfile();
    final unlockedRoyals = await _svc.unlockedRoyalIds();
    final picksSpent = (await _svc.streakPickedRoyalIds()).length;
    final royalPicks = await _svc.availableRoyalPicks();
    if (mounted) {
      setState(() {
        _streak = info;
        _freeze = freeze;
        _saveOffer = saveOffer;
        _appTime = appTime;
        _monthSeconds = monthSecs;
        _profile = profile;
        _unlockedRoyals = unlockedRoyals;
        _royalPicksSpent = picksSpent;
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
    if (edited != null && !await applyDevRoyalPreview(edited, _unlockedRoyals)) {
      await _svc.saveProfile(edited);
    }
    await _load();
  }

  Future<void> _armFreeze() async {
    final ok = await _svc.armFreeze();
    if (!mounted) return;
    if (ok) {
      showAppToast(
        context,
        message: context.l10nRead.freezeArmedToast,
        type: AppToastType.success,
      );
    }
    await _load();
  }

  /// Open the Streak Save dialog for the standing offer; on a restore, toast
  /// and refresh every live screen (the Home flame is watching too).
  Future<void> _openStreakSave() async {
    final offer = _saveOffer;
    if (offer == null) return;
    final restored = await showStreakSaveSheet(
      context,
      previous: offer.previous,
      available: offer.freezes,
    );
    if (!mounted) return;
    if (restored != null) {
      showAppToast(
        context,
        message: context.l10nRead.streakRestoredToast(restored),
        type: AppToastType.success,
      );
      notifyAppDataChanged();
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
                  if (_saveOffer != null) ...[
                    _StreakSaveBanner(
                      offer: _saveOffer!,
                      onRestore: _openStreakSave,
                      colors: colors,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _FreezeCard(
                    info: _freeze,
                    onArm: _armFreeze,
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
                    royalPicksSpent: _royalPicksSpent,
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

/// "Save your streak" banner — shown only while a streak-save offer stands
/// (broke yesterday, freeze banked, still the return day). Frosted, urgent,
/// and one tap from the Streak Save dialog.
class _StreakSaveBanner extends StatelessWidget {
  final ({int previous, int freezes}) offer;
  final Future<void> Function() onRestore;
  final AppColors colors;

  const _StreakSaveBanner({
    required this.offer,
    required this.onRestore,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRestore,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                kFreezeAccent.withValues(alpha: 0.18),
                kFreezeAccent.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border:
                Border.all(color: kFreezeAccent.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kFreezeAccent.withValues(alpha: 0.16),
                  border: Border.all(
                      color: kFreezeAccent.withValues(alpha: 0.5)),
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.restoreStreakTitle(offer.previous),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.streakSaveBannerBody,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => onRestore(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kFreezeAccent,
                  foregroundColor: const Color(0xFF06263A),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                child: Text(context.l10n.restoreCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Streak Freeze stash: a tray of [GamificationService.maxFreezes] slots
/// that fill as freezes are banked, an ARMED state, and the arm action. The
/// copy explains both protections — arm ahead, or save on the return day.
class _FreezeCard extends StatelessWidget {
  final ({int available, bool armed}) info;
  final Future<void> Function() onArm;
  final AppColors colors;

  const _FreezeCard({
    required this.info,
    required this.onArm,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7FDBFF), Color(0xFF0D3B66)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Text('🧊', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.streakFreezes,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$available / ${GamificationService.maxFreezes}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kFreezeAccent,
                      ),
                    ),
                  ],
                ),
              ),
              if (armed)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded,
                          size: 14, color: colors.success),
                      const SizedBox(width: 5),
                      Text(
                        context.l10n.freezeArmedChip,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: colors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _FreezeTray(available: available, colors: colors),
          const SizedBox(height: 12),
          Text(
            armed ? context.l10n.freezeArmedStatus : context.l10n.freezeHowItWorks,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
          if (!armed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: available > 0 ? () => onArm() : null,
                icon: const Icon(Icons.shield_outlined, size: 17),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kFreezeAccent,
                  side: BorderSide(
                      color: kFreezeAccent.withValues(
                          alpha: available > 0 ? 0.6 : 0.25)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                label: Text(context.l10n.armFreezeCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The stash itself: one slot per possible freeze, filled slots iced over.
class _FreezeTray extends StatelessWidget {
  final int available;
  final AppColors colors;

  const _FreezeTray({required this.available, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < GamificationService.maxFreezes; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.25,
              child: i < available
                  ? Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7FDBFF), Color(0xFF0D3B66)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                            color:
                                kFreezeAccent.withValues(alpha: 0.55)),
                      ),
                      child:
                          const Text('🧊', style: TextStyle(fontSize: 18)),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: colors.cardAlt,
                        border: Border.all(
                            color: colors.border.withValues(alpha: 0.8)),
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
