import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_preferences.dart';
import '../services/app_events.dart';
import '../services/financial_health_service.dart';
import '../services/gamification_service.dart';
import 'royal_avatars.dart';
import 'royal_character.dart';

/// The "living court": full-body ROYALTY avatars that emerge from the Home
/// profile icon to react to moments — smash the screen when the user blows a
/// budget, cheer good behaviour (adherence, bills paid, investments), and a
/// welcome routine at launch. Strictly-additive QOL: everything renders as a
/// transient overlay above the app and never reads/writes core data or blocks
/// a flow. Silent unless a royal is equipped and Gamified Budgets is on.

const _ink = Color(0xFF15171E);
const _crackTint = Color(0xFFFFD75E);

/// Anchor for the Home profile avatar, so the character can literally jump out
/// of and return into that circle. Attached by [HomeRewardsAvatar]; when it
/// isn't mounted (off Home) the character falls back to the top-right corner.
final GlobalKey royalHomeAnchorKey = GlobalKey();

/// True while the character is "out" of the profile circle, so the Home avatar
/// can show an empty socket instead of doubling up.
final ValueNotifier<bool> royalCharacterOut = ValueNotifier<bool>(false);

/// Watches financial-health snapshots and fires scold/cheer on meaningful
/// transitions (freshly over budget, or newly healthy). In-memory and
/// per-session; the first snapshot only sets the baseline, so nothing fires at
/// launch. Pure: it's fed a snapshot and never touches the database.
class RoyalMood {
  RoyalMood._();

  static bool? _wasOverBudget;
  static bool? _wasHealthy;

  static void observe(FinancialHealth health) {
    if (!health.hasScore) return;
    final overBudget =
        health.budgets.any((b) => b.limit > 0 && b.spent > b.limit);
    final band = health.band;
    final healthy = band == HealthBand.good || band == HealthBand.excellent;

    // First observation this session: adopt the state silently.
    if (_wasOverBudget == null) {
      _wasOverBudget = overBudget;
      _wasHealthy = healthy;
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
  }
}

/// The choreographed routines the character can perform.
enum _Routine { boot, smash, praise, strike }

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

const double _cw = 116;
const double _ch = 152;

/// Mounted in `MaterialApp.builder` (inside the app-lock gate). Loads the
/// equipped royal, plays a welcome routine once at launch, and turns reaction
/// requests into full-body routines above the app.
class RoyalReactionHost extends StatefulWidget {
  final Widget child;
  const RoyalReactionHost({super.key, required this.child});

  @visibleForTesting
  static void debugReset() {
    _RoyalReactionHostState._bootedThisSession = false;
    royalCharacterOut.value = false;
  }

  @override
  State<RoyalReactionHost> createState() => _RoyalReactionHostState();
}

class _RoyalReactionHostState extends State<RoyalReactionHost>
    with SingleTickerProviderStateMixin {
  RoyalAvatar? _royal;
  _Routine? _routine;
  int _lastNonce = -1;
  double _durationMs = 1;
  static bool _bootedThisSession = false;

  late final AnimationController _ctrl = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _endRoutine();
    });

  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_loadRoyal);
    royalReactionRequest.addListener(_onReaction);
    _loadRoyal();
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_loadRoyal);
    royalReactionRequest.removeListener(_onReaction);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoyal() async {
    final p = await GamificationService().loadProfile();
    final royal = royalAvatarAt(int.tryParse(p.avatarValue) ?? -1);
    if (!mounted) return;
    setState(() => _royal = royal);
    // A one-time welcome when a royal is equipped and gamified is on — but only
    // once the Home profile icon is actually on screen, so the royal really
    // does jump out of that circle (not out of a splash/onboarding screen).
    if (royal != null &&
        !_bootedThisSession &&
        context.read<AppPreferences>().gamifiedMode) {
      _scheduleBoot();
    }
  }

  void _scheduleBoot([int attempts = 0]) {
    if (_bootedThisSession || !mounted) return;
    if (royalHomeAnchorKey.currentContext != null && _routine == null) {
      _bootedThisSession = true;
      _play(_Routine.boot);
      return;
    }
    if (attempts >= 40) return; // ~8s: user never reached Home — skip it.
    Future.delayed(
        const Duration(milliseconds: 200), () => _scheduleBoot(attempts + 1));
  }

  void _onReaction() {
    final ev = royalReactionRequest.value;
    if (ev == null || ev.nonce == _lastNonce || !mounted) return;
    _lastNonce = ev.nonce;
    if (_royal == null) return;
    if (!context.read<AppPreferences>().gamifiedMode) return;
    // Don't interrupt an in-flight routine — reactions are rare.
    if (_routine != null) return;
    _play(switch (ev.reaction) {
      RoyalReaction.scold => _Routine.smash,
      RoyalReaction.cheer => _Routine.praise,
      RoyalReaction.strike => _Routine.strike,
    });
  }

  void _play(_Routine r) {
    _durationMs = switch (r) {
      _Routine.boot => 5200,
      _Routine.smash => 3200,
      _Routine.praise => 2600,
      _Routine.strike => 2100,
    }
        .toDouble();
    setState(() => _routine = r);
    royalCharacterOut.value = true;
    _ctrl
      ..duration = Duration(milliseconds: _durationMs.round())
      ..forward(from: 0);
  }

  void _endRoutine() {
    royalCharacterOut.value = false;
    if (mounted) setState(() => _routine = null);
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

  _CharFrame _frame(_Routine r, double t, Offset icon, Size screen) => switch (r) {
        _Routine.boot => _boot(t, icon, screen),
        _Routine.smash => _smashRoutine(t, icon, screen),
        _Routine.praise => _praise(t, icon, screen),
        _Routine.strike => _strike(t, icon, screen),
      };

  double _clampX(double x, Size s) => x.clamp(_cw * 0.5, s.width - _cw * 0.5);

  _CharFrame _boot(double t, Offset icon, Size screen) {
    final outY = icon.dy + _ch * 0.32;
    final waveC = Offset(_clampX(icon.dx - 34, screen), outY);
    final leftC = Offset(_cw * 0.55, outY);
    if (t < 0.14) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.14)).clamp(0.0, 1.2);
      final hop = -math.sin(_seg(t, 0, 0.14) * math.pi) * 18;
      return _CharFrame(
          center: _lerpO(icon, waveC, p.clamp(0.0, 1.0)).translate(0, hop),
          scale: p.clamp(0.0, 1.0),
          action: RoyalAction.idle,
          actionT: _cyc(t, 1400),
          facing: -1);
    }
    if (t < 0.32) {
      return _CharFrame(
          center: waveC, scale: 1, action: RoyalAction.wave, actionT: _seg(t, 0.14, 0.32), facing: -1);
    }
    if (t < 0.50) {
      final p = Curves.easeInOut.transform(_seg(t, 0.32, 0.50));
      return _CharFrame(
          center: _lerpO(waveC, leftC, p), scale: 1, action: RoyalAction.run, actionT: _cyc(t, 360), facing: -1);
    }
    if (t < 0.55) {
      return _CharFrame(center: leftC, scale: 1, action: RoyalAction.idle, actionT: _cyc(t, 1400), facing: 1);
    }
    if (t < 0.75) {
      final p = Curves.easeInOut.transform(_seg(t, 0.55, 0.75));
      return _CharFrame(
          center: _lerpO(leftC, waveC, p), scale: 1, action: RoyalAction.run, actionT: _cyc(t, 360), facing: 1);
    }
    if (t < 0.86) {
      return _CharFrame(
          center: waveC, scale: 1, action: RoyalAction.wave, actionT: _seg(t, 0.75, 0.86), facing: -1);
    }
    final p = _seg(t, 0.86, 1.0);
    final hop = -math.sin(p * math.pi) * 10;
    return _CharFrame(
        center: _lerpO(waveC, icon, Curves.easeIn.transform(p)).translate(0, hop),
        scale: (1 - p).clamp(0.0, 1.0),
        action: RoyalAction.idle,
        actionT: _cyc(t, 1400),
        facing: -1);
  }

  _CharFrame _smashRoutine(double t, Offset icon, Size screen) {
    final outY = icon.dy + _ch * 0.30;
    final marchC = Offset(_clampX(screen.width * 0.5, screen), outY);
    if (t < 0.12) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.12)).clamp(0.0, 1.0);
      return _CharFrame(
          center: _lerpO(icon, marchC, p), scale: p, action: RoyalAction.run, actionT: _cyc(t, 300), facing: -1);
    }
    if (t < 0.34) {
      final p = Curves.easeInOut.transform(_seg(t, 0.12, 0.34));
      return _CharFrame(
          center: _lerpO(icon, marchC, 1), scale: 1, action: RoyalAction.run, actionT: _cyc(t, 300), facing: -1)
          ._at(_lerpO(_lerpO(icon, marchC, 0.2), marchC, p));
    }
    if (t < 0.74) {
      // The overhead smash — impact ~mid; a shockwave shakes and cracks the UI.
      final at = _seg(t, 0.34, 0.74);
      final impact = _seg(t, 0.50, 0.58);
      final decay = 1 - _seg(t, 0.58, 0.74);
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
    if (t < 0.90) {
      final p = Curves.easeInOut.transform(_seg(t, 0.74, 0.90));
      return _CharFrame(
          center: _lerpO(marchC, icon, p), scale: 1, action: RoyalAction.run, actionT: _cyc(t, 300), facing: 1);
    }
    final p = _seg(t, 0.90, 1.0);
    return _CharFrame(
        center: _lerpO(marchC, icon, 1), scale: (1 - p).clamp(0.0, 1.0), action: RoyalAction.idle, actionT: _cyc(t, 1400), facing: 1)
        ._at(icon);
  }

  _CharFrame _praise(double t, Offset icon, Size screen) {
    final outY = icon.dy + _ch * 0.30;
    final showC = Offset(_clampX(icon.dx - 30, screen), outY);
    if (t < 0.16) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.16)).clamp(0.0, 1.0);
      return _CharFrame(center: _lerpO(icon, showC, p), scale: p, action: RoyalAction.cheer, actionT: 0, facing: -1);
    }
    if (t < 0.82) {
      return _CharFrame(center: showC, scale: 1, action: RoyalAction.cheer, actionT: _cyc(t, 900), facing: -1);
    }
    final p = _seg(t, 0.82, 1.0);
    return _CharFrame(
        center: _lerpO(showC, icon, Curves.easeIn.transform(p)), scale: (1 - p).clamp(0.0, 1.0), action: RoyalAction.idle, actionT: _cyc(t, 1400), facing: -1);
  }

  _CharFrame _strike(double t, Offset icon, Size screen) {
    final outY = icon.dy + _ch * 0.30;
    final showC = Offset(_clampX(icon.dx - 30, screen), outY);
    if (t < 0.18) {
      final p = Curves.easeOutBack.transform(_seg(t, 0, 0.18)).clamp(0.0, 1.0);
      return _CharFrame(center: _lerpO(icon, showC, p), scale: p, action: RoyalAction.idle, actionT: 0, facing: -1);
    }
    if (t < 0.70) {
      final at = _seg(t, 0.18, 0.70);
      return _CharFrame(
          center: showC, scale: 1, action: RoyalAction.smash, actionT: at, facing: -1, shake: _seg(t, 0.40, 0.46) * (1 - _seg(t, 0.46, 0.60)) * 0.5);
    }
    final p = _seg(t, 0.70, 1.0);
    return _CharFrame(
        center: _lerpO(showC, icon, Curves.easeIn.transform(p)), scale: (1 - p).clamp(0.0, 1.0), action: RoyalAction.idle, actionT: _cyc(t, 1400), facing: -1);
  }

  Offset _shake(double s) {
    final e = _ctrl.value * _durationMs;
    return Offset(math.sin(e * 0.09) * 11, math.cos(e * 0.13) * 8) * s;
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
        final f = _frame(routine, _ctrl.value, icon, mq.size);
        final shakeOff = f.shake > 0 ? _shake(f.shake) : Offset.zero;

        return Stack(
          children: [
            Transform.translate(offset: shakeOff, child: child),
            if (f.crack > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SmashOverlayPainter(
                        impact: f.center.translate(0, _ch * 0.24), crack: f.crack),
                  ),
                ),
              ),
            Positioned(
              left: f.center.dx - _cw / 2,
              top: f.center.dy - _ch / 2,
              width: _cw,
              height: _ch,
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

extension on _CharFrame {
  /// A copy repositioned to [c] (keeps everything else) — small helper for
  /// phases that recompute position after construction.
  _CharFrame _at(Offset c) => _CharFrame(
        center: c,
        scale: scale,
        action: action,
        actionT: actionT,
        facing: facing,
        shake: shake,
        crack: crack,
      );
}

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
