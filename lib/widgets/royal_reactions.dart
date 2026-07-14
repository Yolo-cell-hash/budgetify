import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_preferences.dart';
import '../services/app_events.dart';
import '../services/financial_health_service.dart';
import '../services/gamification_service.dart';
import 'royal_avatars.dart';
import 'royal_character.dart';

/// The "living court": pocket-size, full-body ROYALTY avatars that inhabit the
/// app. They emerge from the Home profile icon for the big moments — a welcome
/// parade at launch (with their royal ride), a smash when the user blows a
/// budget, a cheer for good behaviour — and, between moments, drop rare
/// ambient CAMEOS anywhere in the app: strolling along the bottom of whatever
/// page is open, galloping across on their mount, peeking in from a screen
/// edge, or popping up at a random spot for a tiny celebration.
///
/// Strictly-additive QOL: everything renders as a transient overlay above the
/// app, ignores pointers, and never reads/writes core data or blocks a flow.
/// Silent unless a royal is equipped and Gamified Budgets is on; cameos also
/// respect the platform's reduce-motion setting and never interrupt a routine.

const _ink = Color(0xFF15171E);
const _crackTint = Color(0xFFFFD75E);

/// Anchor for the Home profile avatar, so the character can literally jump out
/// of and return into that circle. Attached by [HomeRewardsAvatar]; when it
/// isn't mounted (off Home) the character falls back to the top-right corner.
final GlobalKey royalHomeAnchorKey = GlobalKey();

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

/// One frame of a routine: where the character is, what it's doing, and how
/// strong the screen effects are.
class _CharFrame {
  final Offset center;
  final double scale;
  final RoyalAction action;
  final double actionT;
  final double facing;
  final double shake; // 0..1 screen-shake intensity
  final double crack; // 0..1 full-screen crack + flash
  const _CharFrame({
    required this.center,
    required this.scale,
    required this.action,
    required this.actionT,
    required this.facing,
    this.shake = 0,
    this.crack = 0,
  });
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

  late final AnimationController _ctrl = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _endRoutine();
    });

  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_loadRoyal);
    royalReactionRequest.addListener(_onReaction);
    _royalCameoRequest.addListener(_onCameoRequest);
    mainShellTabIndex.addListener(_onTabChange);
    _loadRoyal();
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_loadRoyal);
    royalReactionRequest.removeListener(_onReaction);
    _royalCameoRequest.removeListener(_onCameoRequest);
    mainShellTabIndex.removeListener(_onTabChange);
    _cameoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
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
    if (_royal == null) return;
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
    _play(switch (ev.cameo) {
      RoyalCameo.stroll => _Routine.stroll,
      RoyalCameo.dash => _Routine.dash,
      RoyalCameo.peek => _Routine.peek,
      RoyalCameo.twirl => _Routine.twirl,
    });
  }

  void _play(_Routine r) {
    _durationMs = switch (r) {
      _Routine.boot => 5600,
      _Routine.smash => 4600, // slam + a piece of the royal mind
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
    setState(() => _routine = r);
    if (!_isCameo(r)) royalCharacterOut.value = true;
    _ctrl
      ..duration = Duration(milliseconds: _durationMs.round())
      ..forward(from: 0);
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

  Offset _anchorCenter(Size screen, double topPad) {
    final ctx = royalHomeAnchorKey.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      final pos = ro.localToGlobal(Offset.zero);
      return pos + Offset(ro.size.width / 2, ro.size.height / 2);
    }
    return Offset(screen.width - 34, topPad + 26);
  }

  double _cyc(double t, double periodMs) => (t * _durationMs / periodMs) % 1;

  _CharFrame _frame(
          _Routine r, double t, Offset icon, Size screen, EdgeInsets pad) =>
      switch (r) {
        _Routine.boot => _boot(t, icon, screen),
        _Routine.smash => _smashRoutine(t, icon, screen),
        _Routine.praise => _praise(t, icon, screen),
        _Routine.strike => _strike(t, icon, screen),
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

  _CharFrame _smashRoutine(double t, Offset icon, Size screen) {
    final outC = Offset(_clampX(icon.dx - 26, screen), _groundY(icon) - _ch * 0.5);
    final marchC = Offset(_clampX(screen.width * 0.5, screen), outC.dy);
    if (t < 0.08) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.08)).clamp(0.0, 1.0);
      return _CharFrame(
          center: _lerpO(icon, outC, p), scale: p, action: RoyalAction.idle, actionT: 0, facing: -1);
    }
    if (t < 0.22) {
      final p = Curves.easeInOut.transform(_seg(t, 0.08, 0.22));
      return _CharFrame(
          center: _lerpO(outC, marchC, p), scale: 1, action: RoyalAction.run, actionT: _cyc(t, 320), facing: -1);
    }
    if (t < 0.52) {
      // The overhead smash — impact mid-swing; a shockwave cracks the UI.
      final at = _seg(t, 0.22, 0.52);
      final impact = _seg(t, 0.34, 0.40);
      final decay = 1 - _seg(t, 0.40, 0.52);
      return _CharFrame(
        center: marchC,
        scale: 1,
        action: RoyalAction.smash,
        actionT: at,
        facing: -1,
        shake: impact * decay,
        crack: impact * decay,
      );
    }
    if (t < 0.80) {
      // Then a piece of the royal mind: stomping, fist-shaking, head going
      // side to side — properly upset before storming home.
      return _CharFrame(
          center: marchC,
          scale: 1,
          action: RoyalAction.fume,
          actionT: _cyc(t, 720),
          facing: -1);
    }
    if (t < 0.93) {
      final p = Curves.easeInOut.transform(_seg(t, 0.80, 0.93));
      return _CharFrame(
          center: _lerpO(marchC, outC, p), scale: 1, action: RoyalAction.run, actionT: _cyc(t, 320), facing: 1);
    }
    final p = _seg(t, 0.93, 1.0);
    return _CharFrame(
        center: _lerpO(outC, icon, Curves.easeIn.transform(p)),
        scale: (1 - p).clamp(0.0, 1.0),
        action: RoyalAction.idle,
        actionT: _cyc(t, 1400),
        facing: 1);
  }

  _CharFrame _praise(double t, Offset icon, Size screen) {
    final showC = Offset(_clampX(icon.dx - 28, screen), _groundY(icon) - _ch * 0.5);
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

  _CharFrame _strike(double t, Offset icon, Size screen) {
    final showC = Offset(_clampX(icon.dx - 28, screen), _groundY(icon) - _ch * 0.5);
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
          action: RoyalAction.smash,
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
        final icon = _anchorCenter(mq.size, mq.padding.top);
        final f = _frame(routine, _ctrl.value, icon, mq.size, mq.padding);
        final shakeOff = f.shake > 0 ? _shake(f.shake) : Offset.zero;
        final wide = f.action == RoyalAction.ride;
        final boxW = wide ? _rw : _cw;
        final boxH = wide ? _rh : _ch;

        return Stack(
          children: [
            Transform.translate(offset: shakeOff, child: child),
            if (f.crack > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SmashOverlayPainter(
                        impact: f.center
                            .translate(-f.facing * _cw * 0.28, _ch * 0.42),
                        crack: f.crack),
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

/// A full-screen crack + flash for the budget smash. Deterministic (fixed
/// crack geometry) so it doesn't flicker between frames.
class _SmashOverlayPainter extends CustomPainter {
  final Offset impact;
  final double crack;

  const _SmashOverlayPainter({required this.impact, required this.crack});

  @override
  void paint(Canvas canvas, Size size) {
    // A quick white flash.
    canvas.drawRect(Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 0.28 * crack));

    // Jagged cracks radiating from the impact point to the screen edges.
    final rng = math.Random(7);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.55 * crack);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = _crackTint.withValues(alpha: 0.5 * crack);
    final reach = size.longestSide;
    for (var i = 0; i < 9; i++) {
      final baseAng = i / 9 * 2 * math.pi + rng.nextDouble() * 0.3;
      final path = Path()..moveTo(impact.dx, impact.dy);
      var p = impact;
      var ang = baseAng;
      final steps = 4 + rng.nextInt(2);
      final segLen = reach / steps;
      for (var s = 0; s < steps; s++) {
        ang += (rng.nextDouble() - 0.5) * 0.6;
        p = p + Offset(math.cos(ang), math.sin(ang)) * segLen * (1 + crack * 0.3);
        path.lineTo(p.dx, p.dy);
      }
      ink.strokeWidth = 3.2;
      glow.strokeWidth = 1.4;
      canvas.drawPath(path, ink);
      canvas.drawPath(path, glow);
    }
    // A bright impact core.
    canvas.drawCircle(impact, size.shortestSide * 0.05 * crack,
        Paint()..color = Colors.white.withValues(alpha: 0.7 * crack));
  }

  @override
  bool shouldRepaint(_SmashOverlayPainter old) =>
      old.crack != crack || old.impact != impact;
}
