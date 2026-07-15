import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_preferences.dart';
import '../services/app_events.dart';
import '../services/financial_health_service.dart';
import '../services/gamification_service.dart';
import '../services/notification_service.dart';
import 'royal_avatars.dart';
import 'royal_character.dart';

/// The "living court": pocket-size, full-body ROYALTY avatars that inhabit the
/// app. They emerge from the Home profile icon for the big moments — a welcome
/// parade at launch (with their royal ride), a weapon attack on the screen
/// when the user blows a budget, a cheer for good behaviour — and, between
/// moments, drop rare ambient CAMEOS anywhere in the app: strolling along the
/// bottom of whatever page is open, galloping across on their mount, peeking
/// in from a screen edge, or popping up at a random spot for a tiny
/// celebration.
///
/// The budget attack is per-royal — each weapon fights its own way and leaves
/// its own damage ([_ShatterPainter]): the Sovereign slashes an X with his
/// sword, the Prince slices a long gash with the lance, the Dark Prince's
/// club blows a full spiderweb crater, the Princess feathers the screen with
/// arrows, the Empress detonates hurled orbs, the Medic slams a shock pulse.
/// On the Budgets tab the strike lands on the MONTHLY BUDGET gauge
/// ([royalBudgetChartAnchorKey]) — the royal runs in from its anchor, jumps
/// up onto the ring, wrecks it and hops back down; elsewhere it plays out
/// near the profile anchor. Impacts also rumble the device (see
/// [_fireImpactHaptic]).
///
/// Strictly-additive QOL: everything renders as a transient overlay above the
/// app, ignores pointers, and never reads/writes core data or blocks a flow.
/// Silent unless a royal is equipped and Gamified Budgets is on; cameos also
/// respect the platform's reduce-motion setting and never interrupt a routine.
///
/// These full-body theatrics are OPT-IN: they only play when the "Enable Custom
/// Animations" preference ([AppPreferences.royalCustomAnimations]) is on (off by
/// default, toggled from the avatar picker). When it's off this whole host stays
/// dormant and the royal simply blinks and waves from the Home profile circle
/// (that idle loop lives in the circle avatar itself, not here).

const _ink = Color(0xFF15171E);

/// Anchor for the Home profile avatar, so the character can literally jump out
/// of and return into that circle. Attached by [HomeRewardsAvatar]. The circle
/// only counts while the Home tab is actually visible — on any other tab the
/// court's way home is the bottom bar's Home item instead (see
/// [_RoyalReactionHostState._anchorCenter]), so the royal never dives into a
/// corner that has no profile circle on the current screen.
final GlobalKey royalHomeAnchorKey = GlobalKey();

/// Anchor for the MONTHLY BUDGET gauge (the big progress ring on the Budgets
/// Overview tab, current month only). When the over-budget scold fires while
/// that ring is on screen, the royal runs in along the bottom, jumps up onto
/// the gauge and attacks IT — the thing that betrayed the budget — instead of
/// a generic spot near the bottom lane.
final GlobalKey royalBudgetChartAnchorKey = GlobalKey();

/// True while the character is "out" of the profile circle, so the Home avatar
/// can show an empty socket instead of doubling up. Cameos don't set this —
/// they wander in from off-screen, not out of the icon.
final ValueNotifier<bool> royalCharacterOut = ValueNotifier<bool>(false);

/// The ambient walk-on appearances the court makes between reactions.
enum RoyalCameo {
  /// A little stroll across the bottom of the current page, with a mid-way
  /// wave to the user.
  stroll,

  /// A full-tilt dash across the bottom on the royal's own ride.
  dash,

  /// Peeking in from a random screen edge, a look around, a wave, gone.
  peek,

  /// Popping up at a random safe spot for a two-hop celebration.
  twirl,
}

class _RoyalCameoEvent {
  final RoyalCameo cameo;
  final int nonce;
  const _RoyalCameoEvent(this.cameo, this.nonce);
}

final ValueNotifier<_RoyalCameoEvent?> _royalCameoRequest =
    ValueNotifier<_RoyalCameoEvent?>(null);
int _royalCameoNonce = 0;

/// Ask the court to play an ambient [cameo] now (subject to the same gates as
/// scheduled ones: royal equipped, gamified on, nothing already playing).
/// Fire-and-forget; used by the internal scheduler and by tests.
void requestRoyalCameo(RoyalCameo cameo) {
  _royalCameoRequest.value = _RoyalCameoEvent(cameo, ++_royalCameoNonce);
}

/// Watches financial-health snapshots and fires scold/cheer on meaningful
/// transitions (freshly over budget, or newly healthy). In-memory and
/// per-session; the first snapshot only sets the baseline, so nothing fires at
/// launch. Pure: it's fed a snapshot and never touches the database.
class RoyalMood {
  RoyalMood._();

  static bool? _wasOverBudget;
  static bool? _wasHealthy;

  static bool _launchCheerDone = false;

  static void observe(FinancialHealth health) {
    if (!health.hasScore) return;
    final overBudget =
        health.budgets.any((b) => b.limit > 0 && b.spent > b.limit);
    final band = health.band;
    final healthy = band == HealthBand.good || band == HealthBand.excellent;

    // First observation this session: adopt the state as the baseline. When
    // that baseline is already GOOD — budgets adhered to, healthy score — the
    // royal opens the session by celebrating the user (once per session; the
    // host holds it until the welcome routine finishes).
    if (_wasOverBudget == null) {
      _wasOverBudget = overBudget;
      _wasHealthy = healthy;
      if (!overBudget && healthy && !_launchCheerDone) {
        _launchCheerDone = true;
        requestRoyalReaction(RoyalReaction.cheer);
      }
      return;
    }
    if (overBudget && !_wasOverBudget!) {
      requestRoyalReaction(RoyalReaction.scold);
    } else if (!overBudget && healthy && !(_wasHealthy ?? false)) {
      requestRoyalReaction(RoyalReaction.cheer);
    }
    _wasOverBudget = overBudget;
    _wasHealthy = healthy;
  }

  @visibleForTesting
  static void reset() {
    _wasOverBudget = null;
    _wasHealthy = null;
    _launchCheerDone = false;
  }
}

/// The choreographed routines the character can perform. The first four are
/// icon-anchored reactions; the rest are ambient cameos.
enum _Routine { boot, smash, praise, strike, stroll, dash, peek, twirl }

/// One frame of a routine: where the character is, what it's doing, and what
/// damage/projectiles are live on screen this instant.
class _CharFrame {
  final Offset center;
  final double scale;
  final RoyalAction action;
  final double actionT;
  final double facing;
  final double shake; // 0..1+ screen-shake intensity
  final List<_ImpactFx> impacts; // live shatter sites
  final List<_ProjFx> projectiles; // arrows / orbs in flight
  const _CharFrame({
    required this.center,
    required this.scale,
    required this.action,
    required this.actionT,
    required this.facing,
    this.shake = 0,
    this.impacts = const [],
    this.projectiles = const [],
  });
}

/// One live shatter site: where the blow landed, the direction it came in
/// from (orients gashes and embedded arrows), how far its bloom has run
/// (age 0→1 over the first beat) and the late fade-out.
class _ImpactFx {
  final Offset at;
  final double dir; // radians of the incoming attack
  final double age; // 0..1 bloom
  final double fade; // 1 → 0 as the damage heals off screen
  final int index; // per-routine ordinal (varies the geometry)
  const _ImpactFx({
    required this.at,
    required this.dir,
    required this.age,
    required this.fade,
    required this.index,
  });
}

enum _ProjKind { arrow, orb }

/// A projectile mid-flight, host-driven so it stays in lockstep with the pose.
class _ProjFx {
  final Offset at;
  final double dir; // travel direction, radians
  final _ProjKind kind;
  const _ProjFx({required this.at, required this.dir, required this.kind});
}

// Character boxes. Standing is a chibi portrait; riding gets a wide stage.
const double _cw = 78;
const double _ch = 100;
const double _rw = 150;
const double _rh = 96;

/// Mounted in `MaterialApp.builder` (inside the app-lock gate). Loads the
/// equipped royal, plays a welcome routine once at launch, turns reaction
/// requests into full-body routines above the app, and schedules the rare
/// ambient cameos in between.
class RoyalReactionHost extends StatefulWidget {
  final Widget child;
  const RoyalReactionHost({super.key, required this.child});

  /// Test override for the ambient-cameo gap (defaults to minutes).
  @visibleForTesting
  static Duration? debugCameoGap;

  @visibleForTesting
  static void debugReset() {
    _RoyalReactionHostState._bootedThisSession = false;
    royalCharacterOut.value = false;
    debugCameoGap = null;
  }

  @override
  State<RoyalReactionHost> createState() => _RoyalReactionHostState();
}

class _RoyalReactionHostState extends State<RoyalReactionHost>
    with SingleTickerProviderStateMixin {
  RoyalAvatar? _royal;
  _Routine? _routine;
  _Routine? _pending; // one queued reaction, played after the current routine
  int _lastNonce = -1;
  int _lastCameoNonce = -1;
  double _durationMs = 1;
  static bool _bootedThisSession = false;

  final math.Random _rng = math.Random();
  Timer? _cameoTimer;
  DateTime _lastPlayEnd = DateTime.fromMillisecondsSinceEpoch(0);
  // Per-cameo randomness, rolled once when the cameo starts.
  double _camDir = 1;
  double _camA = 0.5;
  double _camB = 0.5;

  // Mirror of AppPreferences.royalCustomAnimations, so a mid-session toggle can
  // (re)start the parade/cameos when turned on and quiet them when turned off.
  bool _customAnimEnabled = false;

  // Attack bookkeeping, rolled fresh in _play: the normalized times each blow
  // lands (drives the haptics), how many have fired, the deterministic seed
  // the shatter geometry grows from, and — when the scold catches the user on
  // the Budgets tab — the category donut the attack should land on.
  List<double> _impactTimes = const [];
  int _impactsFired = 0;
  int _fxSeed = 0;
  Offset? _chartTarget;

  AppPreferences? _prefs;

  late final AnimationController _ctrl = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _endRoutine();
    })
    ..addListener(_tickImpactHaptics);

  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_loadRoyal);
    royalReactionRequest.addListener(_onReaction);
    _royalCameoRequest.addListener(_onCameoRequest);
    mainShellTabIndex.addListener(_onTabChange);
    _prefs = context.read<AppPreferences>()..addListener(_onPrefsChanged);
    _customAnimEnabled = _prefs!.royalCustomAnimations;
    _loadRoyal();
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_loadRoyal);
    royalReactionRequest.removeListener(_onReaction);
    _royalCameoRequest.removeListener(_onCameoRequest);
    mainShellTabIndex.removeListener(_onTabChange);
    _prefs?.removeListener(_onPrefsChanged);
    _cameoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Whether the equipped royal's full-body theatrics are enabled. The circle
  /// avatar's blink/wave is separate and always on — this only gates this host.
  bool get _customAnimations =>
      context.read<AppPreferences>().royalCustomAnimations;

  /// React to the "Enable Custom Animations" toggle flipping mid-session: on
  /// → run the welcome parade (if it hasn't yet) and resume ambient cameos;
  /// off → stop scheduling and drop any queued reaction (a routine already
  /// playing is left to finish on its own).
  void _onPrefsChanged() {
    if (!mounted) return;
    final on = _customAnimations;
    if (on == _customAnimEnabled) return;
    _customAnimEnabled = on;
    if (!on) {
      _cameoTimer?.cancel();
      _pending = null;
    } else if (_royal != null) {
      _scheduleBoot();
      _scheduleCameo();
    }
  }

  Future<void> _loadRoyal() async {
    final p = await GamificationService().loadProfile();
    final royal = royalAvatarAt(int.tryParse(p.avatarValue) ?? -1);
    if (!mounted) return;
    setState(() => _royal = royal);
    if (royal == null) {
      _cameoTimer?.cancel();
      return;
    }
    // A one-time welcome when a royal is equipped and gamified is on — but only
    // once the Home profile icon is actually on screen, so the royal really
    // does jump out of that circle (not out of a splash/onboarding screen).
    if (!_bootedThisSession && context.read<AppPreferences>().gamifiedMode) {
      _scheduleBoot();
    }
    _scheduleCameo();
  }

  void _scheduleBoot([int attempts = 0]) {
    if (_bootedThisSession || !mounted) return;
    // Custom animations off: no welcome parade. Leave _bootedThisSession false
    // so turning it on later still gets the entrance (see _onPrefsChanged).
    if (!_customAnimations) return;
    if (royalHomeAnchorKey.currentContext != null && _routine == null) {
      _bootedThisSession = true;
      if (!_reduceMotion) {
        _play(_Routine.boot);
      } else {
        _playPending();
      }
      return;
    }
    if (attempts >= 40) {
      // ~8s: user never reached Home — skip the parade, but let a reaction
      // that queued up behind it (e.g. the launch cheer) still play.
      _bootedThisSession = true;
      _playPending();
      return;
    }
    Future.delayed(
        const Duration(milliseconds: 200), () => _scheduleBoot(attempts + 1));
  }

  void _onReaction() {
    final ev = royalReactionRequest.value;
    if (ev == null || ev.nonce == _lastNonce || !mounted) return;
    _lastNonce = ev.nonce;
    if (_royal == null) return;
    if (!context.read<AppPreferences>().gamifiedMode) return;
    if (!_customAnimations) return;
    final routine = switch (ev.reaction) {
      RoyalReaction.scold => _Routine.smash,
      RoyalReaction.cheer => _Routine.praise,
      RoyalReaction.strike => _Routine.strike,
    };
    // A reaction that lands during another routine (or before the welcome
    // parade has run) waits its turn instead of being dropped — the launch
    // cheer always arrives while the boot is playing. Latest one wins.
    if (_routine != null || !_bootedThisSession) {
      _pending = routine;
      return;
    }
    _play(routine);
  }

  void _playPending() {
    final p = _pending;
    if (p == null || !mounted || _routine != null) return;
    _pending = null;
    // A short beat between routines, so they read as separate thoughts.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted && _routine == null) _play(p);
    });
  }

  // ── Ambient cameo scheduling ────────────────────────────────────────────

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  Duration get _cameoGap =>
      RoyalReactionHost.debugCameoGap ??
      Duration(seconds: 110 + _rng.nextInt(150));

  void _scheduleCameo([Duration? gap]) {
    _cameoTimer?.cancel();
    if (_royal == null || !_customAnimations) return;
    _cameoTimer = Timer(gap ?? _cameoGap, _fireScheduledCameo);
  }

  void _fireScheduledCameo() {
    if (!mounted || _royal == null) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final away =
        lifecycle != null && lifecycle != AppLifecycleState.resumed;
    final keyboardUp =
        (MediaQuery.maybeOf(context)?.viewInsets.bottom ?? 0) > 0;
    if (away ||
        keyboardUp ||
        _routine != null ||
        _reduceMotion ||
        !_customAnimations ||
        !context.read<AppPreferences>().gamifiedMode) {
      _scheduleCameo(const Duration(seconds: 45)); // try again soon
      return;
    }
    final roll = _rng.nextDouble();
    requestRoyalCameo(roll < 0.30
        ? RoyalCameo.stroll
        : roll < 0.55
            ? RoyalCameo.dash
            : roll < 0.80
                ? RoyalCameo.peek
                : RoyalCameo.twirl);
    _scheduleCameo();
  }

  /// Landing on another tab occasionally invites a cameo there — that's what
  /// makes the court feel at home on every page, not just Home.
  void _onTabChange() {
    if (!mounted || _royal == null || _routine != null) return;
    if (!_customAnimations) return;
    if (DateTime.now().difference(_lastPlayEnd) <
        const Duration(seconds: 75)) {
      return;
    }
    if (_rng.nextDouble() >= 0.25) return;
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _routine != null || _reduceMotion) return;
      requestRoyalCameo(
          _rng.nextBool() ? RoyalCameo.peek : RoyalCameo.stroll);
    });
  }

  void _onCameoRequest() {
    final ev = _royalCameoRequest.value;
    if (ev == null || ev.nonce == _lastCameoNonce || !mounted) return;
    _lastCameoNonce = ev.nonce;
    if (_royal == null || _routine != null) return;
    if (!context.read<AppPreferences>().gamifiedMode) return;
    if (!_customAnimations) return;
    _play(switch (ev.cameo) {
      RoyalCameo.stroll => _Routine.stroll,
      RoyalCameo.dash => _Routine.dash,
      RoyalCameo.peek => _Routine.peek,
      RoyalCameo.twirl => _Routine.twirl,
    });
  }

  void _play(_Routine r) {
    final weapon = _royal?.weapon ?? RoyalWeapon.sword;
    _durationMs = switch (r) {
      _Routine.boot => 5600,
      // Each weapon fights at its own tempo: the volley and the double-orb
      // barrage take longer than a single slam.
      _Routine.smash => _attackDurationMs(weapon),
      _Routine.praise => 3400, // cheer + victory twirl
      _Routine.strike => 2200,
      _Routine.stroll => 6500,
      _Routine.dash => 3000,
      _Routine.peek => 4200,
      _Routine.twirl => 3000,
    }
        .toDouble();
    _camDir = _rng.nextBool() ? 1 : -1;
    _camA = _rng.nextDouble();
    _camB = _rng.nextDouble();
    // Attack bookkeeping: when each blow lands (haptics), fresh shatter
    // geometry, and — resolved ONCE so mid-play scrolling can't drag the
    // damage around — the budget donut to aim at, when it's on screen.
    _impactTimes = switch (r) {
      _Routine.smash => _impactTimesFor(weapon),
      _Routine.strike => const [0.42],
      _ => const [],
    };
    _impactsFired = 0;
    _fxSeed = _rng.nextInt(1 << 30);
    _chartTarget = r == _Routine.smash ? _resolveChartTarget() : null;
    setState(() => _routine = r);
    if (!_isCameo(r)) royalCharacterOut.value = true;
    _ctrl
      ..duration = Duration(milliseconds: _durationMs.round())
      ..forward(from: 0);
  }

  /// How long each weapon's screen attack runs, in ms.
  static int _attackDurationMs(RoyalWeapon w) => switch (w) {
        RoyalWeapon.sword => 5200, // two crossing cuts
        RoyalWeapon.lance => 4800, // one driven slice
        RoyalWeapon.warClub => 5000, // slam + aftershock
        RoyalWeapon.bow => 5400, // three-arrow volley
        RoyalWeapon.orbs => 5400, // two hurled orbs
        RoyalWeapon.medKit => 4600, // kit slam + shock pulse
      };

  /// The normalized routine times each blow lands. MUST stay in lockstep with
  /// the segment maths in [_attack] — the same numbers drive crack bloom,
  /// screen shake and the haptic schedule.
  static List<double> _impactTimesFor(RoyalWeapon w) => switch (w) {
        RoyalWeapon.sword => const [0.272, 0.432],
        RoyalWeapon.lance => const [0.366],
        RoyalWeapon.warClub => const [0.393, 0.47],
        RoyalWeapon.bow => const [0.296, 0.416, 0.536],
        RoyalWeapon.orbs => const [0.35, 0.53],
        RoyalWeapon.medKit => const [0.373],
      };

  /// Fires the physical feedback for each blow exactly when it lands.
  void _tickImpactHaptics() {
    if (_impactsFired >= _impactTimes.length) return;
    final r = _routine;
    if (r != _Routine.smash && r != _Routine.strike) return;
    while (_impactsFired < _impactTimes.length &&
        _ctrl.value >= _impactTimes[_impactsFired]) {
      final i = _impactsFired++;
      _fireImpactHaptic(_royal?.weapon ?? RoyalWeapon.sword, i,
          full: r == _Routine.smash);
    }
  }

  /// One blow's physical rumble. Two layers, both fire-and-forget:
  /// the `budgetify/rumble` channel drives the Android vibrator service
  /// directly (works even when the system touch-feedback setting is off —
  /// the reason the old impact-only haptics felt dead), and HapticFeedback
  /// adds the crisp transient on devices with rich haptics. Per-weapon
  /// waveforms: the club thuds twice, the kit double-pulses like a defib,
  /// arrows are short thunks, orbs boom.
  Future<void> _fireImpactHaptic(RoyalWeapon w, int index,
      {required bool full}) async {
    if (!full) {
      _rumble(const [0, 45], const [180]);
      await HapticFeedback.mediumImpact();
      return;
    }
    switch (w) {
      case RoyalWeapon.warClub:
        _rumble(const [0, 95, 55, 120], const [255, 210]);
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 80));
        if (mounted) await HapticFeedback.heavyImpact();
      case RoyalWeapon.sword:
      case RoyalWeapon.lance:
        _rumble(const [0, 55, 40, 75], const [235, 160]);
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 60));
        if (mounted) await HapticFeedback.mediumImpact();
      case RoyalWeapon.orbs:
        _rumble(const [0, 85, 45, 60], const [255, 120]);
        await HapticFeedback.heavyImpact();
      case RoyalWeapon.bow:
        _rumble(const [0, 35], const [210]);
        await HapticFeedback.mediumImpact();
      case RoyalWeapon.medKit:
        _rumble(const [0, 60, 70, 60], const [230, 230]);
        await HapticFeedback.heavyImpact();
    }
  }

  static const MethodChannel _rumbleChannel = MethodChannel('budgetify/rumble');

  /// Best-effort vibrator-service rumble; silently a no-op off-Android and in
  /// tests (missing plugin), so it can never break a cosmetic flow.
  void _rumble(List<int> pattern, List<int> amps) {
    _rumbleChannel.invokeMethod<void>(
        'rumble', {'pattern': pattern, 'amps': amps}).catchError((_) {});
  }

  /// The monthly budget gauge's centre, when the scold should land on it:
  /// only while the Budgets tab is the visible tab, nothing is pushed over
  /// the shell, and the ring is actually within the viewport. Null otherwise.
  Offset? _resolveChartTarget() {
    if (mainShellTabIndex.value != 1) return null;
    if (NotificationService.navigatorKey.currentState?.canPop() ?? false) {
      return null; // a detail screen covers the chart
    }
    final ro = royalBudgetChartAnchorKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return null;
    final c = ro.localToGlobal(ro.size.center(Offset.zero));
    final visible = c.dx > 40 &&
        c.dx < mq.size.width - 40 &&
        c.dy > mq.padding.top + 80 &&
        c.dy <
            mq.size.height -
                mq.padding.bottom -
                kBottomNavigationBarHeight -
                40;
    return visible ? c : null;
  }

  bool _isCameo(_Routine r) =>
      r == _Routine.stroll ||
      r == _Routine.dash ||
      r == _Routine.peek ||
      r == _Routine.twirl;

  void _endRoutine() {
    royalCharacterOut.value = false;
    _lastPlayEnd = DateTime.now();
    if (mounted) setState(() => _routine = null);
    _playPending();
  }

  // ── Frame maths ─────────────────────────────────────────────────────────

  /// Where the royal emerges from and returns to — aware of what's actually
  /// on the current screen. On the Home tab it's the profile circle itself.
  /// On any other tab the circle isn't visible (the IndexedStack keeps Home
  /// mounted, so its RenderBox still reports top-right coords — using them
  /// made the court dive into an empty corner); the believable way home from
  /// there is the bottom bar's HOME item (leftmost of the five tabs). With a
  /// route pushed over the shell, neither exists — top-right corner fallback.
  Offset _anchorCenter(Size screen, EdgeInsets pad) {
    final pushed =
        NotificationService.navigatorKey.currentState?.canPop() ?? false;
    if (!pushed && mainShellTabIndex.value == 0) {
      final ro = royalHomeAnchorKey.currentContext?.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        final pos = ro.localToGlobal(Offset.zero);
        return pos + Offset(ro.size.width / 2, ro.size.height / 2);
      }
    } else if (!pushed) {
      // First of five bottom-nav slots = the Home tab icon.
      return Offset(screen.width * 0.1,
          screen.height - pad.bottom - kBottomNavigationBarHeight * 0.55);
    }
    return Offset(screen.width - 34, pad.top + 26);
  }

  double _cyc(double t, double periodMs) => (t * _durationMs / periodMs) % 1;

  _CharFrame _frame(
          _Routine r, double t, Offset icon, Size screen, EdgeInsets pad) =>
      switch (r) {
        _Routine.boot => _boot(t, icon, screen),
        _Routine.smash => _attack(t, icon, screen, pad),
        _Routine.praise => _praise(t, icon, screen, pad),
        _Routine.strike => _strike(t, icon, screen, pad),
        _Routine.stroll => _stroll(t, screen, pad),
        _Routine.dash => _dash(t, screen, pad),
        _Routine.peek => _peek(t, screen),
        _Routine.twirl => _twirl(t, screen),
      };

  double _clampX(double x, Size s, [double half = _cw * 0.5]) =>
      x.clamp(half, s.width - half);

  /// The floor line shared by standing and riding boxes near the icon, so a
  /// royal that mounts up mid-routine doesn't hop levels.
  double _groundY(Offset icon) => icon.dy + _ch * 0.92;

  _CharFrame _boot(double t, Offset icon, Size screen) {
    final ground = _groundY(icon);
    final standY = ground - _ch * 0.5;
    final rideY = ground - _rh * 0.5;
    final waveC = Offset(_clampX(icon.dx - 30, screen), standY);
    final rideHomeC = Offset(waveC.dx, rideY);
    final leftC = Offset(_rw * 0.45, rideY);

    if (t < 0.09) {
      // Pop out of the icon with a little hop.
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.09));
      final hop = -math.sin(_seg(t, 0, 0.09) * math.pi) * 16;
      return _CharFrame(
          center: _lerpO(icon, waveC, p.clamp(0.0, 1.0)).translate(0, hop),
          scale: p.clamp(0.0, 1.0),
          action: RoyalAction.idle,
          actionT: _cyc(t, 1400),
          facing: -1);
    }
    if (t < 0.24) {
      return _CharFrame(
          center: waveC,
          scale: 1,
          action: RoyalAction.wave,
          actionT: _seg(t, 0.09, 0.24),
          facing: -1);
    }
    if (t < 0.29) {
      // A beat before the mount appears.
      return _CharFrame(
          center: waveC, scale: 1, action: RoyalAction.idle, actionT: _cyc(t, 1400), facing: -1);
    }
    if (t < 0.50) {
      // Ride out across the screen on the royal ride.
      final p = Curves.easeInOut.transform(_seg(t, 0.29, 0.50));
      return _CharFrame(
          center: _lerpO(rideHomeC, leftC, p),
          scale: 1,
          action: RoyalAction.ride,
          actionT: _cyc(t, 420),
          facing: -1);
    }
    if (t < 0.55) {
      return _CharFrame(
          center: leftC, scale: 1, action: RoyalAction.ride, actionT: _cyc(t, 700), facing: 1);
    }
    if (t < 0.76) {
      final p = Curves.easeInOut.transform(_seg(t, 0.55, 0.76));
      return _CharFrame(
          center: _lerpO(leftC, rideHomeC, p),
          scale: 1,
          action: RoyalAction.ride,
          actionT: _cyc(t, 420),
          facing: 1);
    }
    if (t < 0.80) {
      // Dismount beat.
      return _CharFrame(
          center: waveC, scale: 1, action: RoyalAction.idle, actionT: _cyc(t, 1400), facing: -1);
    }
    if (t < 0.92) {
      return _CharFrame(
          center: waveC,
          scale: 1,
          action: RoyalAction.wave,
          actionT: _seg(t, 0.80, 0.92),
          facing: -1);
    }
    final p = _seg(t, 0.92, 1.0);
    final hop = -math.sin(p * math.pi) * 10;
    return _CharFrame(
        center: _lerpO(waveC, icon, Curves.easeIn.transform(p)).translate(0, hop),
        scale: (1 - p).clamp(0.0, 1.0),
        action: RoyalAction.idle,
        actionT: _cyc(t, 1400),
        facing: -1);
  }

  /// The stand line beside the anchor, kept on-screen even when the anchor is
  /// the bottom bar's Home slot (where the raw ground line would fall below
  /// the viewport).
  double _standYNear(Offset icon, Size screen, EdgeInsets pad) => math.min(
      _groundY(icon) - _ch * 0.5, _laneGround(screen, pad) - _ch * 0.5);

  /// Stage geometry for the screen attack: where the royal stands, where the
  /// blows land, and which way it faces. Locked to the monthly budget gauge
  /// when the scold caught the user in front of it (resolved once in
  /// [_play]); otherwise the classic spot along the anchor's stand line.
  ({Offset stage, Offset impact, double facing}) _arena(
      Offset icon, Size screen, EdgeInsets pad) {
    final w = _royal!.weapon;
    final ranged = w == RoyalWeapon.bow || w == RoyalWeapon.orbs;
    final target = _chartTarget;
    if (target != null) {
      final tgt = Offset(
        target.dx.clamp(70.0, screen.width - 70.0),
        target.dy.clamp(pad.top + 130.0, screen.height - pad.bottom - 190.0),
      );
      // Stand on the roomier side, facing the chart (+1 faces right).
      final side = tgt.dx >= screen.width * 0.5 ? -1.0 : 1.0;
      final stage = ranged
          ? Offset(_clampX(tgt.dx + side * 150, screen), tgt.dy + 26)
          : Offset(
              _clampX(tgt.dx + side * _cw * 0.42, screen), tgt.dy + _ch * 0.34);
      return (stage: stage, impact: tgt, facing: -side);
    }
    final standY = _standYNear(icon, screen, pad);
    if (ranged) {
      return (
        stage: Offset(_clampX(screen.width * 0.64, screen), standY),
        impact: Offset(screen.width * 0.30, standY + _ch * 0.06),
        facing: -1.0,
      );
    }
    final stage = Offset(_clampX(screen.width * 0.5, screen), standY);
    return (
      stage: stage,
      impact: stage + Offset(-_cw * 0.36, _ch * 0.34),
      facing: -1.0,
    );
  }

  /// The live shatter sites this frame: each blows in fast at its scheduled
  /// time and the whole damage heals off screen together late in the routine.
  List<_ImpactFx> _impactsFx(
      double t, List<double> times, List<Offset> at, List<double> dirs) {
    final fade = 1 - _seg(t, 0.76, 0.90);
    if (fade <= 0) return const [];
    final out = <_ImpactFx>[];
    for (var i = 0; i < times.length; i++) {
      final age = _seg(t, times[i], times[i] + 0.085);
      if (age <= 0) continue;
      out.add(
          _ImpactFx(at: at[i], dir: dirs[i], age: age, fade: fade, index: i));
    }
    return out;
  }

  /// Summed shake spikes, one per blow (heavier weapons hit harder).
  double _impactShake(double t, List<double> times, double amp) {
    var s = 0.0;
    for (final ti in times) {
      final k = _seg(t, ti, ti + 0.13);
      if (k > 0 && k < 1) s += 1 - Curves.easeOut.transform(k);
    }
    return (s * amp).clamp(0.0, 1.3);
  }

  /// The per-royal screen attack: same skeleton (pop out → close in → attack
  /// → fume → storm home), but every weapon fights its own way — the timings
  /// here MUST stay in lockstep with [_impactTimesFor].
  _CharFrame _attack(double t, Offset icon, Size screen, EdgeInsets pad) {
    final royal = _royal!;
    final w = royal.weapon;
    final arena = _arena(icon, screen, pad);
    final stage = arena.stage;
    final impact = arena.impact;
    final facing = arena.facing;
    final act = royalAttackActionFor(w);
    final times = _impactTimesFor(w);

    // Pop-out spot: beside the anchor, toward the stage, on a visible line.
    final outDir = (stage.dx - icon.dx).sign == 0 ? 1.0 : (stage.dx - icon.dx).sign;
    final outC = Offset(_clampX(icon.dx + 26 * outDir, screen),
        _standYNear(icon, screen, pad));
    final runFacing = (stage.dx - outC.dx).sign == 0 ? facing : (stage.dx - outC.dx).sign;

    // Blow sites + incoming directions, per weapon.
    final (List<Offset> pts, List<double> dirs) = switch (w) {
      RoyalWeapon.sword => (
          [impact, impact],
          [-0.62, 0.62], // two crossing diagonals → the X
        ),
      RoyalWeapon.lance => ([impact], [0.14]), // one near-horizontal gash
      RoyalWeapon.warClub => ([impact, impact], [math.pi / 2, math.pi / 2]),
      RoyalWeapon.bow => (
          [
            impact,
            impact + const Offset(-26, -18),
            impact + const Offset(24, 12),
          ],
          const [0.0, 0.0, 0.0], // filled in below from real flight paths
        ),
      RoyalWeapon.orbs => (
          [impact, impact + const Offset(30, -22)],
          const [0.0, 0.0],
        ),
      RoyalWeapon.medKit => ([impact], [math.pi / 2]),
    };

    // Ranged weapons: projectiles fly from the royal to each site.
    final muzzle = w == RoyalWeapon.bow
        ? stage + Offset(facing * _cw * 0.42, -_ch * 0.10)
        : stage + Offset(facing * _cw * 0.30, -_ch * 0.28);
    final resolvedDirs = (w == RoyalWeapon.bow || w == RoyalWeapon.orbs)
        ? [for (final p in pts) (p - muzzle).direction]
        : dirs;

    final proj = <_ProjFx>[];
    if (w == RoyalWeapon.bow) {
      const looses = [0.2664, 0.3864, 0.5064];
      for (var i = 0; i < 3; i++) {
        final p = _seg(t, looses[i], times[i]);
        if (p > 0 && p < 1) {
          proj.add(_ProjFx(
              at: _lerpO(muzzle, pts[i], p),
              dir: resolvedDirs[i],
              kind: _ProjKind.arrow));
        }
      }
    } else if (w == RoyalWeapon.orbs) {
      const releases = [0.29, 0.47];
      for (var i = 0; i < 2; i++) {
        final p = _seg(t, releases[i], times[i]);
        if (p > 0 && p < 1) {
          final arc = _lerpO(muzzle, pts[i], p)
              .translate(0, -math.sin(p * math.pi) * 70);
          proj.add(
              _ProjFx(at: arc, dir: resolvedDirs[i], kind: _ProjKind.orb));
        }
      }
    }

    final fx = _impactsFx(t, times, pts, resolvedDirs);
    final shakeAmp = switch (w) {
      RoyalWeapon.warClub => 1.0,
      RoyalWeapon.medKit => 0.8,
      RoyalWeapon.lance => 0.75,
      RoyalWeapon.sword => 0.7,
      RoyalWeapon.orbs => 0.6,
      RoyalWeapon.bow => 0.35,
    };
    final shake = _impactShake(t, times, shakeAmp);

    _CharFrame cf(Offset center,
            {double scale = 1,
            RoyalAction? action,
            double? actionT,
            double? face}) =>
        _CharFrame(
          center: center,
          scale: scale,
          action: action ?? RoyalAction.idle,
          actionT: actionT ?? _cyc(t, 1400),
          facing: face ?? facing,
          shake: shake,
          impacts: fx,
          projectiles: proj,
        );

    // Entrance: pop out of the anchor, close in on the stage.
    final (double closeEnd, RoyalAction closeAct) = switch (w) {
      RoyalWeapon.warClub => (0.24, RoyalAction.walk), // heavy, unhurried
      RoyalWeapon.bow => (0.18, RoyalAction.walk), // light skip to range
      RoyalWeapon.orbs => (0.20, RoyalAction.walk), // a glide, never a run
      RoyalWeapon.medKit || RoyalWeapon.sword => (0.20, RoyalAction.run),
      RoyalWeapon.lance => (0.22, RoyalAction.run),
    };
    // The lance charges THROUGH the target; everyone else fights on the spot.
    final preStage = w == RoyalWeapon.lance
        ? Offset(_clampX(stage.dx - facing * 120, screen), stage.dy)
        : stage;
    final postStage = w == RoyalWeapon.lance
        ? Offset(_clampX(stage.dx + facing * 140, screen), stage.dy)
        : stage;

    // When the attack targets the budget gauge, the stage floats mid-screen:
    // the royal runs in along the bottom lane and SPRINGS up onto the chart
    // (and hops back down after) instead of gliding through mid-air.
    final elevated = _chartTarget != null;
    final launch = Offset(
        _clampX(preStage.dx - runFacing * 46, screen), outC.dy);

    if (t < 0.07) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.07)).clamp(0.0, 1.0);
      return cf(_lerpO(icon, outC, p), scale: p, face: runFacing);
    }
    if (t < closeEnd) {
      if (elevated) {
        // Ground run to just under the chart, then the leap up onto it.
        final runEnd = 0.07 + (closeEnd - 0.07) * 0.55;
        if (t < runEnd) {
          final p = Curves.easeInOut.transform(_seg(t, 0.07, runEnd));
          return cf(_lerpO(outC, launch, p),
              action: RoyalAction.run,
              actionT: _cyc(t, 320),
              face: runFacing);
        }
        final p = _seg(t, runEnd, closeEnd);
        final rise = Curves.easeOutCubic.transform(p);
        // Parabolic overshoot above the straight path sells the spring.
        final hop = -math.sin(p * math.pi) *
            (52 + math.max(0, launch.dy - preStage.dy) * 0.18);
        return cf(_lerpO(launch, preStage, rise).translate(0, hop),
            face: facing);
      }
      final p = Curves.easeInOut.transform(_seg(t, 0.07, closeEnd));
      return cf(_lerpO(outC, preStage, p),
          action: closeAct,
          actionT: _cyc(t, closeAct == RoyalAction.run ? 320 : 480),
          face: runFacing);
    }

    // Attack + fume windows, per weapon.
    switch (w) {
      case RoyalWeapon.sword:
        if (t < 0.36) {
          return cf(stage, action: act, actionT: _seg(t, 0.20, 0.36));
        }
        if (t < 0.52) {
          return cf(stage, action: act, actionT: _seg(t, 0.36, 0.52));
        }
        if (t < 0.62) return cf(stage); // glare at the damage
        if (t < 0.80) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 720));
        }
      case RoyalWeapon.lance:
        if (t < 0.50) {
          final at = _seg(t, 0.22, 0.50);
          // Drive through the target during the pose's lunge (sub 0.30-0.60).
          final drive = _seg(at, 0.30, 0.60);
          return cf(_lerpO(preStage, postStage, Curves.easeInOut.transform(drive)),
              action: act, actionT: at);
        }
        if (t < 0.60) return cf(postStage); // skid, look back at the cut
        if (t < 0.80) {
          return cf(postStage,
              action: RoyalAction.fume, actionT: _cyc(t, 720));
        }
      case RoyalWeapon.warClub:
        if (t < 0.54) {
          return cf(stage, action: act, actionT: _seg(t, 0.24, 0.54));
        }
        if (t < 0.82) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 640));
        }
      case RoyalWeapon.bow:
        if (t < 0.30) {
          return cf(stage, action: act, actionT: _seg(t, 0.18, 0.30));
        }
        if (t < 0.42) {
          return cf(stage, action: act, actionT: _seg(t, 0.30, 0.42));
        }
        if (t < 0.54) {
          return cf(stage, action: act, actionT: _seg(t, 0.42, 0.54));
        }
        if (t < 0.64) return cf(stage); // lower the bow, admire the grouping
        if (t < 0.82) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 720));
        }
      case RoyalWeapon.orbs:
        if (t < 0.38) {
          return cf(stage, action: act, actionT: _seg(t, 0.20, 0.38));
        }
        if (t < 0.56) {
          return cf(stage, action: act, actionT: _seg(t, 0.38, 0.56));
        }
        if (t < 0.82) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 800));
        }
      case RoyalWeapon.medKit:
        if (t < 0.52) {
          return cf(stage, action: act, actionT: _seg(t, 0.22, 0.52));
        }
        if (t < 0.80) {
          return cf(stage, action: RoyalAction.fume, actionT: _cyc(t, 720));
        }
    }

    // Storm home: (hop off the chart, then) run back to the pop spot and
    // dive into the anchor — the same circle/slot the royal came out of.
    final backStart = switch (w) {
      RoyalWeapon.warClub || RoyalWeapon.bow || RoyalWeapon.orbs => 0.82,
      _ => 0.80,
    };
    final from = w == RoyalWeapon.lance ? postStage : stage;
    if (t < 0.93) {
      if (elevated) {
        // Hop down from the chart to the bottom lane...
        final land = Offset(
            _clampX(from.dx - runFacing * 52, screen), outC.dy);
        final downEnd = backStart + (0.93 - backStart) * 0.42;
        if (t < downEnd) {
          final p = _seg(t, backStart, downEnd);
          final drop = Curves.easeInCubic.transform(p);
          final hop = -math.sin(p * math.pi) * 30;
          return cf(_lerpO(from, land, drop).translate(0, hop),
              face: -runFacing);
        }
        // ...then run home along it.
        final p = Curves.easeInOut.transform(_seg(t, downEnd, 0.93));
        final backFacing =
            (outC.dx - land.dx).sign == 0 ? -runFacing : (outC.dx - land.dx).sign;
        return cf(_lerpO(land, outC, p),
            action: RoyalAction.run, actionT: _cyc(t, 320), face: backFacing);
      }
      final p = Curves.easeInOut.transform(_seg(t, backStart, 0.93));
      final backFacing = (outC.dx - from.dx).sign == 0 ? -facing : (outC.dx - from.dx).sign;
      return cf(_lerpO(from, outC, p),
          action: RoyalAction.run, actionT: _cyc(t, 320), face: backFacing);
    }
    final p = _seg(t, 0.93, 1.0);
    return cf(_lerpO(outC, icon, Curves.easeIn.transform(p)),
        scale: (1 - p).clamp(0.0, 1.0), face: -runFacing);
  }

  _CharFrame _praise(double t, Offset icon, Size screen, EdgeInsets pad) {
    final showC = Offset(
        _clampX(icon.dx - 28, screen), _standYNear(icon, screen, pad));
    if (t < 0.10) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.10)).clamp(0.0, 1.0);
      return _CharFrame(
          center: _lerpO(icon, showC, p), scale: p, action: RoyalAction.cheer, actionT: 0, facing: -1);
    }
    if (t < 0.42) {
      return _CharFrame(
          center: showC, scale: 1, action: RoyalAction.cheer, actionT: _cyc(t, 800), facing: -1);
    }
    if (t < 0.58) {
      // A victory twirl: the royal spins in place (rapid facing flips read as
      // a spin at chibi scale), arms and weapon still raised.
      final flips = (t * _durationMs / 130).floor();
      return _CharFrame(
          center: showC,
          scale: 1,
          action: RoyalAction.cheer,
          actionT: _cyc(t, 800),
          facing: flips.isEven ? -1 : 1);
    }
    if (t < 0.86) {
      return _CharFrame(
          center: showC, scale: 1, action: RoyalAction.cheer, actionT: _cyc(t, 800), facing: -1);
    }
    final p = _seg(t, 0.86, 1.0);
    return _CharFrame(
        center: _lerpO(showC, icon, Curves.easeIn.transform(p)),
        scale: (1 - p).clamp(0.0, 1.0),
        action: RoyalAction.idle,
        actionT: _cyc(t, 1400),
        facing: -1);
  }

  _CharFrame _strike(double t, Offset icon, Size screen, EdgeInsets pad) {
    final showC = Offset(
        _clampX(icon.dx - 28, screen), _standYNear(icon, screen, pad));
    // Each royal vanquishes with its own weapon verb (no screen damage here —
    // the deleted transaction is the victim, not the glass).
    final act = royalAttackActionFor(_royal?.weapon ?? RoyalWeapon.sword);
    if (t < 0.14) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.14)).clamp(0.0, 1.0);
      return _CharFrame(
          center: _lerpO(icon, showC, p), scale: p, action: RoyalAction.idle, actionT: 0, facing: -1);
    }
    if (t < 0.68) {
      final at = _seg(t, 0.14, 0.68);
      return _CharFrame(
          center: showC,
          scale: 1,
          action: act,
          actionT: at,
          facing: -1,
          shake: _seg(t, 0.36, 0.42) * (1 - _seg(t, 0.42, 0.58)) * 0.4);
    }
    final p = _seg(t, 0.68, 1.0);
    return _CharFrame(
        center: _lerpO(showC, icon, Curves.easeIn.transform(p)),
        scale: (1 - p).clamp(0.0, 1.0),
        action: RoyalAction.idle,
        actionT: _cyc(t, 1400),
        facing: -1);
  }

  /// The walking lane: just above the bottom navigation bar.
  double _laneGround(Size screen, EdgeInsets pad) =>
      screen.height - pad.bottom - kBottomNavigationBarHeight - 4;

  _CharFrame _stroll(double t, Size screen, EdgeInsets pad) {
    const scale = 0.85;
    final y = _laneGround(screen, pad) - _ch * scale * 0.5;
    final dir = _camDir;
    final fromX = dir > 0 ? -_cw * 0.6 : screen.width + _cw * 0.6;
    final toX = dir > 0 ? screen.width + _cw * 0.6 : -_cw * 0.6;
    // Walk 45% of the way, pause for a wave, walk off.
    final waveX = _lerp(fromX, toX, 0.45);
    if (t < 0.40) {
      final p = _seg(t, 0, 0.40);
      return _CharFrame(
          center: Offset(_lerp(fromX, waveX, p), y),
          scale: scale,
          action: RoyalAction.walk,
          actionT: _cyc(t, 480),
          facing: dir);
    }
    if (t < 0.58) {
      return _CharFrame(
          center: Offset(waveX, y),
          scale: scale,
          action: RoyalAction.wave,
          actionT: _seg(t, 0.40, 0.58),
          facing: dir);
    }
    final p = _seg(t, 0.58, 1.0);
    return _CharFrame(
        center: Offset(_lerp(waveX, toX, p), y),
        scale: scale,
        action: RoyalAction.walk,
        actionT: _cyc(t, 480),
        facing: dir);
  }

  _CharFrame _dash(double t, Size screen, EdgeInsets pad) {
    const scale = 0.9;
    final y = _laneGround(screen, pad) - _rh * scale * 0.5;
    final dir = _camDir;
    final fromX = dir > 0 ? -_rw * 0.6 : screen.width + _rw * 0.6;
    final toX = dir > 0 ? screen.width + _rw * 0.6 : -_rw * 0.6;
    final p = Curves.easeInOutSine.transform(t);
    return _CharFrame(
        center: Offset(_lerp(fromX, toX, p), y),
        scale: scale,
        action: RoyalAction.ride,
        actionT: _cyc(t, 400),
        facing: dir);
  }

  _CharFrame _peek(double t, Size screen) {
    final side = _camDir; // +1 = right edge, -1 = left edge
    final y = _lerp(screen.height * 0.24, screen.height * 0.58, _camA);
    final hiddenX =
        side > 0 ? screen.width + _cw * 0.55 : -_cw * 0.55;
    final shownX =
        side > 0 ? screen.width - _cw * 0.10 : _cw * 0.10;
    final facing = -side; // look into the screen
    double x;
    RoyalAction action = RoyalAction.idle;
    double actionT = _cyc(t, 1400);
    if (t < 0.15) {
      x = _lerp(hiddenX, shownX, Curves.easeOutCubic.transform(_seg(t, 0, 0.15)));
    } else if (t < 0.55) {
      x = shownX;
    } else if (t < 0.75) {
      x = shownX;
      action = RoyalAction.wave;
      actionT = _seg(t, 0.55, 0.75);
    } else if (t < 0.85) {
      x = shownX;
    } else {
      x = _lerp(shownX, hiddenX, Curves.easeInCubic.transform(_seg(t, 0.85, 1)));
    }
    return _CharFrame(
        center: Offset(x, y), scale: 1, action: action, actionT: actionT, facing: facing);
  }

  _CharFrame _twirl(double t, Size screen) {
    const scale = 0.8;
    final spot = Offset(_lerp(screen.width * 0.25, screen.width * 0.75, _camA),
        _lerp(screen.height * 0.30, screen.height * 0.52, _camB));
    final facing = _camDir;
    if (t < 0.14) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.14));
      return _CharFrame(
          center: spot, scale: scale * p.clamp(0.0, 1.15), action: RoyalAction.cheer, actionT: 0, facing: facing);
    }
    if (t < 0.86) {
      return _CharFrame(
          center: spot, scale: scale, action: RoyalAction.cheer, actionT: _cyc(t, 800), facing: facing);
    }
    final p = 1 - _seg(t, 0.86, 1.0);
    return _CharFrame(
        center: spot,
        scale: scale * Curves.easeIn.transform(p),
        action: RoyalAction.cheer,
        actionT: _cyc(t, 800),
        facing: facing);
  }

  Offset _shake(double s) {
    final e = _ctrl.value * _durationMs;
    return Offset(math.sin(e * 0.09) * 10, math.cos(e * 0.13) * 7) * s;
  }

  @override
  Widget build(BuildContext context) {
    final gamified = context.watch<AppPreferences>().gamifiedMode;
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final royal = _royal;
        final routine = _routine;
        if (routine == null || royal == null || !gamified) return child!;

        final mq = MediaQuery.of(context);
        final icon = _anchorCenter(mq.size, mq.padding);
        final f = _frame(routine, _ctrl.value, icon, mq.size, mq.padding);
        final shakeOff = f.shake > 0 ? _shake(f.shake) : Offset.zero;
        final wide = f.action == RoyalAction.ride;
        final boxW = wide ? _rw : _cw;
        final boxH = wide ? _rh : _ch;

        return Stack(
          children: [
            Transform.translate(offset: shakeOff, child: child),
            if (f.impacts.isNotEmpty || f.projectiles.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShatterPainter(
                      weapon: royal.weapon,
                      accent: royal.theme.accent,
                      impacts: f.impacts,
                      projectiles: f.projectiles,
                      seed: _fxSeed,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: f.center.dx - boxW / 2,
              top: f.center.dy - boxH / 2,
              width: boxW,
              height: boxH,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: f.scale,
                  child: CustomPaint(
                    painter: RoyalCharacterPainter(
                      royal: royal,
                      action: f.action,
                      t: f.actionT,
                      facing: f.facing,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _lerp(double a, double b, double x) => a + (b - a) * x;
Offset _lerpO(Offset a, Offset b, double x) =>
    Offset(_lerp(a.dx, b.dx, x), _lerp(a.dy, b.dy, x));

/// Full-screen damage for the royal attacks — the "they really shattered our
/// screen" pass. Layered per blow: an impact flash + shockwave ring, weapon-
/// specific fracture geometry (deterministic from [seed], so nothing flickers
/// between frames), glass shards thrown out with a touch of gravity, and a
/// light-loss vignette that gives the hit physical weight. Everything fades
/// out together late in the routine as the damage "heals".
///
/// Per weapon: the sword rips two crossing diagonal gashes (an X), the lance
/// drags one long near-horizontal gash with sparks, the war club blows a
/// full spiderweb crater that keeps propagating after the hit, arrows punch
/// small dense webs and stay embedded (quivering), orbs detonate in accent-
/// tinted shock rings with rising embers, the med kit slams a spiderweb plus
/// a defib-style double pulse ring.
class _ShatterPainter extends CustomPainter {
  final RoyalWeapon weapon;
  final Color accent;
  final List<_ImpactFx> impacts;
  final List<_ProjFx> projectiles;
  final int seed;

  const _ShatterPainter({
    required this.weapon,
    required this.accent,
    required this.impacts,
    required this.projectiles,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Pre-pass: flash + vignette follow the freshest live impact.
    var flash = 0.0, dim = 0.0;
    Offset? focus;
    for (final i in impacts) {
      final hot = (1 - i.age / 0.30).clamp(0.0, 1.0) * i.fade;
      if (hot >= flash) {
        flash = hot;
        focus = i.at;
      }
      dim = math.max(dim, math.min(1.0, i.age * 2.5) * i.fade);
    }
    final rect = Offset.zero & size;
    if (dim > 0 && impacts.isNotEmpty) {
      // The pane "loses light" around the damage: a soft radial darkening
      // anchored on the first blow.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              (impacts.first.at.dx / size.width) * 2 - 1,
              (impacts.first.at.dy / size.height) * 2 - 1,
            ),
            radius: 1.25,
            colors: [
              Colors.black.withValues(alpha: 0.05 * dim),
              Colors.black.withValues(alpha: 0.30 * dim),
            ],
          ).createShader(rect),
      );
    }
    if (flash > 0 && focus != null) {
      canvas.drawRect(rect,
          Paint()..color = Colors.white.withValues(alpha: 0.20 * flash));
    }

    for (final imp in impacts) {
      final rng = math.Random(seed + imp.index * 977);
      final alpha = math.min(1.0, imp.age * 2.5) * imp.fade;
      switch (weapon) {
        case RoyalWeapon.sword:
          _gash(canvas, imp.at, imp.dir, size.shortestSide * 0.42, alpha, rng);
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 7, speed: 75);
          _flashRing(canvas, size, imp.at, imp.age, imp.fade);
        case RoyalWeapon.lance:
          _gash(canvas, imp.at, imp.dir, size.shortestSide * 0.60, alpha, rng,
              splinters: 9);
          // Sparks skitter along the fresh cut.
          final dirV = Offset(math.cos(imp.dir), math.sin(imp.dir));
          for (var i = 0; i < 7; i++) {
            final d = (rng.nextDouble() * 2 - 1) * size.shortestSide * 0.5;
            final drift = imp.age * (14 + rng.nextDouble() * 22);
            final p = imp.at +
                dirV * d +
                Offset(rng.nextDouble() * 8 - 4, -drift);
            canvas.drawCircle(
                p,
                1.6 + rng.nextDouble() * 1.6,
                Paint()
                  ..color = accent.withValues(
                      alpha: (1 - imp.age) * 0.8 * imp.fade));
          }
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 6, speed: 65);
          _flashRing(canvas, size, imp.at, imp.age, imp.fade);
        case RoyalWeapon.warClub:
          if (imp.index == 0) {
            // The crater: a full spiderweb that keeps propagating outward
            // for a beat after the hit — cracks that GROW read as weight.
            final grow = 0.55 +
                0.45 * Curves.easeOut.transform(math.min(1.0, imp.age * 1.4));
            _web(canvas, imp.at, alpha, rng,
                radius: size.shortestSide * 0.36,
                radials: 13,
                rings: 3,
                grow: grow);
            _shards(canvas, imp.at, imp.age, imp.fade, rng,
                count: 12, speed: 115);
          } else {
            // Aftershock: a second pulse rolls out of the same crater.
            _flashRing(canvas, size, imp.at, imp.age, imp.fade, span: 0.5);
            _shards(canvas, imp.at, imp.age, imp.fade, rng,
                count: 5, speed: 60);
          }
          _flashRing(canvas, size, imp.at, imp.age, imp.fade);
        case RoyalWeapon.bow:
          _web(canvas, imp.at, alpha, rng,
              radius: size.shortestSide * 0.09, radials: 7, rings: 1);
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 4, speed: 40);
          // The arrow stays embedded — tip buried at the impact, shaft
          // trailing back along its flight path, quivering as it settles.
          final wobble = math.sin(imp.age * 26) * (1 - imp.age) * 0.22;
          _arrow(canvas, imp.at, imp.dir, imp.fade, wobble: wobble);
          _flashRing(canvas, size, imp.at, imp.age, imp.fade, span: 0.4);
        case RoyalWeapon.orbs:
          _burst(canvas, size, imp, alpha, rng);
        case RoyalWeapon.medKit:
          _web(canvas, imp.at, alpha, rng,
              radius: size.shortestSide * 0.18, radials: 9, rings: 2);
          _shards(canvas, imp.at, imp.age, imp.fade, rng, count: 7, speed: 80);
          // Defib double-pulse: two accent rings chasing each other out.
          for (var k = 0; k < 2; k++) {
            final p = (imp.age * 1.3 - k * 0.22).clamp(0.0, 1.0);
            if (p <= 0 || p >= 1) continue;
            canvas.drawCircle(
                imp.at,
                size.shortestSide * (0.05 + 0.20 * p),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3 * (1 - p) + 1
                  ..color =
                      accent.withValues(alpha: (1 - p) * 0.55 * imp.fade));
          }
          _flashRing(canvas, size, imp.at, imp.age, imp.fade);
      }
    }

    // Projectiles in flight, above the damage.
    for (final p in projectiles) {
      switch (p.kind) {
        case _ProjKind.arrow:
          // Speed ghosts trail the shaft.
          final v = Offset(math.cos(p.dir), math.sin(p.dir));
          for (var g = 1; g <= 2; g++) {
            _arrow(canvas, p.at - v * (10.0 * g), p.dir, 0.22 / g);
          }
          _arrow(canvas, p.at, p.dir, 1);
        case _ProjKind.orb:
          final v = Offset(math.cos(p.dir), math.sin(p.dir));
          for (var g = 1; g <= 3; g++) {
            canvas.drawCircle(
                p.at - v * (9.0 * g),
                7.0 - g * 1.6,
                Paint()..color = accent.withValues(alpha: 0.30 / g));
          }
          canvas.drawCircle(
              p.at,
              13,
              Paint()
                ..color = accent.withValues(alpha: 0.45)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
          canvas.drawCircle(p.at, 7, Paint()..color = accent);
          canvas.drawCircle(p.at.translate(-2, -2), 2.6,
              Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }
  }

  // ── Fracture primitives ──────────────────────────────────────────────────

  /// A jagged crack polyline wandering from [from] along [ang].
  Path _jag(Offset from, double ang, double len, math.Random rng,
      {int steps = 5, double wobble = 0.5}) {
    final path = Path()..moveTo(from.dx, from.dy);
    var p = from;
    var a = ang;
    final segLen = len / steps;
    for (var s = 0; s < steps; s++) {
      a += (rng.nextDouble() - 0.5) * wobble;
      p += Offset(math.cos(a), math.sin(a)) * segLen;
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// Three-layer crack stroke: accent under-glow, dark core, white glint —
  /// broken glass catches light on both lips of the fracture.
  void _strokeCrack(Canvas canvas, Path path, double alpha,
      {double core = 3.4}) {
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = core + 2.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..color = accent.withValues(alpha: 0.22 * alpha));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = core
          ..color = _ink.withValues(alpha: 0.60 * alpha));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = core * 0.36
          ..color = Colors.white.withValues(alpha: 0.55 * alpha));
  }

  /// The spiderweb: jagged radial cracks joined by jittered concentric rings.
  void _web(Canvas canvas, Offset at, double alpha, math.Random rng,
      {required double radius, int radials = 12, int rings = 3, double grow = 1}) {
    final angs = <double>[];
    final lens = <double>[];
    for (var i = 0; i < radials; i++) {
      final a = i / radials * 2 * math.pi + rng.nextDouble() * 0.5;
      final len = radius * (0.72 + rng.nextDouble() * 0.45) * grow;
      angs.add(a);
      lens.add(len);
      _strokeCrack(canvas, _jag(at, a, len, rng, steps: 4, wobble: 0.55),
          alpha, core: 3.0);
    }
    for (var r = 0; r < rings; r++) {
      final ring = Path();
      for (var i = 0; i <= radials; i++) {
        final k = i % radials;
        final rr = lens[k] * (0.28 + r * 0.27) *
            (1 + (rng.nextDouble() - 0.5) * 0.18);
        final p = at + Offset(math.cos(angs[k]), math.sin(angs[k])) * rr;
        if (i == 0) {
          ring.moveTo(p.dx, p.dy);
        } else {
          ring.lineTo(p.dx, p.dy);
        }
      }
      _strokeCrack(canvas, ring, alpha * 0.8, core: 2.0);
    }
  }

  /// A long ripped-through gash: two jagged halves out of the impact, short
  /// splinters branching off, and a parallel hairline glint (the lifted lip
  /// of the cut catching light).
  void _gash(Canvas canvas, Offset at, double ang, double halfLen,
      double alpha, math.Random rng,
      {int splinters = 6}) {
    _strokeCrack(canvas, _jag(at, ang, halfLen, rng, steps: 6, wobble: 0.26),
        alpha, core: 4.2);
    _strokeCrack(
        canvas,
        _jag(at, ang + math.pi, halfLen, rng, steps: 6, wobble: 0.26),
        alpha,
        core: 4.2);
    final dirV = Offset(math.cos(ang), math.sin(ang));
    for (var i = 0; i < splinters; i++) {
      final d = (rng.nextDouble() * 2 - 1) * halfLen * 0.8;
      final root = at + dirV * d;
      final branchA =
          ang + (rng.nextBool() ? 1 : -1) * (0.7 + rng.nextDouble() * 0.6);
      _strokeCrack(
          canvas,
          _jag(root, branchA, 14 + rng.nextDouble() * 26, rng,
              steps: 3, wobble: 0.5),
          alpha * 0.8,
          core: 1.9);
    }
    final perp = Offset(-dirV.dy, dirV.dx) * 2.8;
    canvas.drawLine(
        at - dirV * halfLen + perp,
        at + dirV * halfLen + perp,
        Paint()
          ..strokeWidth = 1.1
          ..color = Colors.white.withValues(alpha: 0.28 * alpha));
  }

  /// Glass slivers thrown from the blow, tumbling under a touch of gravity.
  void _shards(Canvas canvas, Offset at, double age, double fade,
      math.Random rng,
      {int count = 9, double speed = 90}) {
    if (age <= 0 || age >= 1) return;
    final a1 = (1 - age) * fade;
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.50 * a1);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _ink.withValues(alpha: 0.45 * a1);
    for (var i = 0; i < count; i++) {
      final a = rng.nextDouble() * 2 * math.pi;
      final v = speed * (0.5 + rng.nextDouble());
      final pos = at +
          Offset(math.cos(a), math.sin(a)) * v * age +
          Offset(0, 130 * age * age);
      final s = 3.0 + rng.nextDouble() * 5;
      final rot = a + age * 6;
      final path = Path()
        ..moveTo(pos.dx + math.cos(rot) * s, pos.dy + math.sin(rot) * s)
        ..lineTo(pos.dx + math.cos(rot + 2.3) * s * 0.7,
            pos.dy + math.sin(rot + 2.3) * s * 0.7)
        ..lineTo(pos.dx + math.cos(rot + 4.4) * s * 0.55,
            pos.dy + math.sin(rot + 4.4) * s * 0.55)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }
  }

  /// The moment of contact: a hot core + one shockwave ring racing out.
  void _flashRing(Canvas canvas, Size size, Offset at, double age, double fade,
      {double span = 0.30}) {
    if (age >= span) return;
    final p = age / span;
    canvas.drawCircle(
        at,
        size.shortestSide * (0.02 + 0.17 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1 - p) + 1
          ..color = Colors.white.withValues(alpha: (1 - p) * 0.65 * fade));
    canvas.drawCircle(
        at,
        size.shortestSide * 0.045 * (1 - p),
        Paint()..color = Colors.white.withValues(alpha: (1 - p) * 0.8 * fade));
  }

  /// An orb detonation: scorch blot, shock rings, a modest web, rising embers.
  void _burst(Canvas canvas, Size size, _ImpactFx imp, double alpha,
      math.Random rng) {
    canvas.drawCircle(
        imp.at,
        30 + 14 * imp.age,
        Paint()
          ..color = _ink.withValues(alpha: 0.22 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    _web(canvas, imp.at, alpha, rng,
        radius: size.shortestSide * 0.13, radials: 9, rings: 1);
    for (final k in const [0.0, 0.28]) {
      final p = (imp.age * 1.15 - k).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
          imp.at,
          size.shortestSide * (0.04 + 0.22 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - p) + 1
            ..color = accent.withValues(alpha: (1 - p) * 0.6 * imp.fade));
    }
    for (var i = 0; i < 6; i++) {
      final a = rng.nextDouble() * 2 * math.pi;
      final r = 10 + rng.nextDouble() * 26;
      final p = imp.at +
          Offset(math.cos(a) * r, math.sin(a) * r * 0.5 - imp.age * 46);
      canvas.drawCircle(
          p,
          1.8 + rng.nextDouble() * 1.6,
          Paint()
            ..color =
                accent.withValues(alpha: (1 - imp.age) * 0.75 * imp.fade));
    }
    _flashRing(canvas, size, imp.at, imp.age, imp.fade);
  }

  /// A fletched arrow with its tip at [at], flying/embedded along [dir].
  void _arrow(Canvas canvas, Offset at, double dir, double alpha,
      {double wobble = 0}) {
    if (alpha <= 0) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(dir + wobble);
    // Shaft behind the tip (tip at the origin, pointing +x).
    canvas.drawLine(
        const Offset(-34, 0),
        const Offset(-3, 0),
        Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF6E4A2A).withValues(alpha: alpha));
    // Steel head.
    final head = Path()
      ..moveTo(2.5, 0)
      ..lineTo(-6, -3.4)
      ..lineTo(-6, 3.4)
      ..close();
    canvas.drawPath(
        head,
        Paint()..color = const Color(0xFFD7DCE4).withValues(alpha: alpha));
    // Fletching.
    final fl = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.9 * alpha);
    for (final s in const [-1.0, 1.0]) {
      canvas.drawLine(
          const Offset(-34, 0), Offset(-39.5, 4.5 * s), fl);
      canvas.drawLine(
          const Offset(-29, 0), Offset(-34.5, 4.5 * s), fl);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShatterPainter old) =>
      old.impacts != impacts ||
      old.projectiles != projectiles ||
      old.seed != seed ||
      old.weapon != weapon;
}
