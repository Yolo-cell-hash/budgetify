import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/achievement.dart';
import '../models/streak_reward.dart';
import '../providers/theme_provider.dart';
import '../services/app_events.dart';
import '../services/dev_mode.dart';
import '../services/gamification_service.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/avatars.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/badge_medallion.dart';
import '../widgets/profile_share_card.dart';
import '../widgets/royal_avatars.dart';
import '../widgets/royal_reactions.dart';
import '../widgets/streak_reward_road.dart';
import 'profile_screen.dart';
import 'trophy_room_screen.dart';

/// The Rewards hub (Gamified Budgets): a Profile tab (shareable card, showcase,
/// titles) and a Trophies tab (all badge ladders + progress). Loads and
/// persists everything via [GamificationService]; refreshes on data changes.
class RewardsHubScreen extends StatefulWidget {
  const RewardsHubScreen({super.key});

  @override
  State<RewardsHubScreen> createState() => _RewardsHubScreenState();
}

class _RewardsHubScreenState extends State<RewardsHubScreen> {
  final GamificationService _svc = GamificationService();

  GamiProfile _profile = const GamiProfile();
  GamiStats? _stats;
  Map<String, DateTime> _unlockDates = const {};
  Set<String> _unlockedRoyals = const {};
  int _royalPicks = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_reload);
    _load(celebrate: true);
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load(celebrate: true);

  Future<void> _load({bool celebrate = false}) async {
    // loadProfile() re-locks any royal that wasn't earned with a pick (e.g. one
    // restored from a pre-gating backup), so the profile here is already clean.
    final profile = await _svc.loadProfile();
    final stats = await _svc.computeStats();
    final dates = await _svc.unlockDates();
    final unlockedRoyals = await _svc.unlockedRoyalIds();
    final royalPicks = await _svc.availableRoyalPicks();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _stats = stats;
      _unlockDates = dates;
      _unlockedRoyals = unlockedRoyals;
      _royalPicks = royalPicks;
      _loading = false;
    });
    if (celebrate) {
      final fresh = await _svc.popNewlyUnlocked();
      final freshThemes = await _svc.popNewlyUnlockedStreakRewards();
      if (!mounted) return;
      // Show at most one celebration per load: a badge takes priority, else a
      // newly unlocked streak-reward theme.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (fresh.isNotEmpty) {
          _celebrate(fresh);
        } else if (freshThemes.isNotEmpty) {
          _celebrateThemes(freshThemes);
        }
      });
    }
  }

  void _celebrateThemes(List<String> ids) {
    StreakReward? best;
    for (final id in ids) {
      final r = streakRewardById(id);
      if (r == null) continue;
      if (best == null || r.rarity.index > best.rarity.index) best = r;
    }
    if (best != null && mounted) {
      showBadgeUnlock(
        context,
        rarity: best.rarity,
        emblem: best.emblem,
        groupName: context.l10nRead.streakRewardGroup,
        tierLabel: context.l10nRead.streakRewardName(best.id),
      );
    }
  }

  void _celebrate(List<String> ids) {
    AchievementGroup? group;
    int tierIndex = 0;
    for (final id in ids) {
      final b = badgeById(id);
      if (b == null) continue;
      if (group == null ||
          b.group.tiers[b.tierIndex].rarity.index >
              group.tiers[tierIndex].rarity.index) {
        group = b.group;
        tierIndex = b.tierIndex;
      }
    }
    if (group != null && mounted) {
      final tier = group.tiers[tierIndex];
      showBadgeUnlock(
        context,
        rarity: tier.rarity,
        emblem: group.emblem,
        groupName: context.l10nRead.achievementName(group.id),
        tierLabel: context.l10nRead.tierBadgeLabel(tier.label),
      );
    }
  }

  Future<void> _save(GamiProfile p) async {
    await _svc.saveProfile(p);
    if (mounted) setState(() => _profile = p);
  }

  /// Open the avatar picker (optionally scrolled straight to ROYALTY), then
  /// refresh the royal-unlock state — a pick may have been spent inside.
  /// Developer mode shows the whole court unlocked; equipping a royal the
  /// user hasn't actually earned becomes a session-only preview.
  Future<void> _openAvatarPicker({bool scrollToRoyalty = false}) async {
    final edited = await showAvatarPicker(
      context,
      _profile,
      unlockedRoyals: DevMode.isActive
          ? {for (final r in kRoyalAvatars) r.id}
          : _unlockedRoyals,
      royalPicksAvailable: _royalPicks,
      onUnlockRoyal: _svc.unlockRoyal,
      scrollToRoyalty: scrollToRoyalty,
    );
    if (edited != null) {
      if (applyDevRoyalPreview(edited, _unlockedRoyals)) {
        if (mounted) setState(() => _profile = edited);
      } else {
        await _save(edited);
      }
    }
    final unlockedRoyals = await _svc.unlockedRoyalIds();
    final royalPicks = await _svc.availableRoyalPicks();
    if (mounted) {
      setState(() {
        _unlockedRoyals = unlockedRoyals;
        _royalPicks = royalPicks;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final stats = _stats;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: AppBarTitle(context.l10n.rewardsTitle,
              icon: Icons.emoji_events_rounded),
          bottom: TabBar(
            tabs: [
              Tab(text: context.l10n.profileTab),
              Tab(text: context.l10n.trophiesTab),
              Tab(text: context.l10n.streaksTab),
            ],
          ),
        ),
        body: SafeArea(child: _loading || stats == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _profileTab(stats),
                  _trophyTab(stats),
                  _roadTab(stats),
                ],
              ),
        ),
      ),
    );
  }

  Widget _roadTab(GamiStats stats) {
    return SingleChildScrollView(
      child: StreakRewardRoad(
        currentStreak: stats.currentStreak,
        longestStreak: stats.longestStreak,
        royalPicksSpent: _unlockedRoyals.length,
        onChooseRoyal: () => _openAvatarPicker(scrollToRoyalty: true),
      ),
    );
  }

  Widget _profileTab(GamiStats stats) {
    final earnedIds = earnedBadgeIds(stats);
    final titleProgress = evaluateTitleProgress(stats);
    final earnedTitles = [for (final p in titleProgress) if (p.earned) p.title];
    final primary = titleById(_profile.primaryTitleId);
    final primaryStillEarned =
        primary != null && earnedTitles.any((t) => t.id == primary.id);

    // Resolve showcased ids → badges, keeping only those still earned.
    final showcased = <ShowcaseBadge>[];
    for (final id in _profile.showcasedBadgeIds) {
      if (showcased.length >= kMaxShowcase) break;
      if (!earnedIds.contains(id)) continue;
      final b = badgeById(id);
      if (b == null) continue;
      final tier = b.group.tiers[b.tierIndex];
      showcased.add((
        rarity: tier.rarity,
        emblem: b.group.emblem,
        label: context.l10n.tierBadgeLabel(tier.label),
        group: context.l10n.achievementName(b.group.id),
      ));
    }

    final allEarned = <EarnedBadge>[];
    for (final g in kAchievementGroups) {
      final p = evaluateGroup(g, stats);
      for (var i = 0; i < g.tiers.length; i++) {
        if (p.earned[i]) {
          allEarned.add((
            id: g.badgeId(i),
            group: context.l10n.achievementName(g.id),
            emblem: g.emblem,
            rarity: g.tiers[i].rarity,
            label: context.l10n.tierBadgeLabel(g.tiers[i].label),
          ));
        }
      }
    }

    return ProfileView(
      profile: _profile,
      currentStreak: stats.currentStreak,
      trophyCount: earnedIds.length,
      titleProgress: titleProgress,
      primaryTitle: primaryStillEarned ? primary : null,
      showcased: showcased,
      allEarned: allEarned,
      onEdit: () => _openAvatarPicker(),
      onUpdateShowcase: (ids) =>
          _save(_profile.copyWith(showcasedBadgeIds: ids)),
      onUpdatePrimaryTitle: (id) => _save(
        _profile.copyWith(primaryTitleId: id, clearPrimaryTitle: id == null),
      ),
    );
  }

  Widget _trophyTab(GamiStats stats) {
    return TrophyRoomView(
      groups: evaluateAchievements(stats),
      unlockDates: _unlockDates,
    );
  }
}

/// Tappable avatar shown in the Home header (only when Gamified Budgets is on)
/// that opens the Rewards hub. Self-contained: loads the profile and refreshes
/// after edits or any data change.
class HomeRewardsAvatar extends StatefulWidget {
  const HomeRewardsAvatar({super.key});

  @override
  State<HomeRewardsAvatar> createState() => _HomeRewardsAvatarState();
}

class _HomeRewardsAvatarState extends State<HomeRewardsAvatar> {
  GamiProfile? _profile;

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
    final p = await GamificationService().loadProfile();
    if (mounted) setState(() => _profile = p);
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    if (p == null) return const SizedBox(width: 38, height: 38);
    final isRoyal = royalAvatarAt(int.tryParse(p.avatarValue) ?? -1) != null;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RewardsHubScreen()),
        );
        _load();
      },
      // The anchor + empty-socket let a royal literally leave and return to this
      // circle during a reaction routine (see royal_reactions.dart).
      child: ValueListenableBuilder<bool>(
        valueListenable: royalCharacterOut,
        builder: (context, out, _) => SizedBox(
          key: royalHomeAnchorKey,
          width: 38,
          height: 38,
          child: (out && isRoyal)
              ? const _EmptyAvatarSocket()
              : AvatarView(kind: p.avatarKind, value: p.avatarValue, size: 38),
        ),
      ),
    );
  }
}

/// The vacated profile circle shown while a royal is out performing a routine.
class _EmptyAvatarSocket extends StatelessWidget {
  const _EmptyAvatarSocket();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.cardAlt.withValues(alpha: 0.6),
        border: Border.all(
          color: colors.brandAccent.withValues(alpha: 0.5),
          width: 1.4,
        ),
      ),
    );
  }
}
