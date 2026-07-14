import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_preferences.dart';
import '../services/app_events.dart';
import '../services/financial_health_service.dart';
import '../services/gamification_service.dart';
import 'royal_avatars.dart';

/// Cosmetic "living court" reactions for ROYALTY avatars. When a royal is
/// equipped, the app can ask it to briefly react to a moment — vanquish a
/// deleted transaction, scold an over-budget month, cheer a healthy score.
///
/// This is a strictly-additive QOL layer: it renders a transient overlay on
/// top of the UI and never reads or writes core data or blocks any flow. If no
/// royal is equipped (or Gamified Budgets is off), nothing renders.

const _gold = Color(0xFFF2C14E);
const _goldDeep = Color(0xFFC0912F);
const _steel = Color(0xFFEAF0F6);
const _ember = Color(0xFFFF5A3C);
const _heal = Color(0xFF4CE0A6);
const _ink = Color(0xFF15171E);

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

/// A top-level overlay that plays royal reactions above every route. Placed in
/// `MaterialApp.builder`, it loads the equipped royal, listens for reaction
/// requests, and shows a brief animated vignette in the top-right corner.
/// Silent unless a royal is equipped and Gamified Budgets is on.
class RoyalReactionHost extends StatefulWidget {
  final Widget child;
  const RoyalReactionHost({super.key, required this.child});

  @override
  State<RoyalReactionHost> createState() => _RoyalReactionHostState();
}

class _RoyalReactionHostState extends State<RoyalReactionHost> {
  RoyalAvatar? _royal;
  RoyalReactionEvent? _active;
  int _lastNonce = -1;

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
    super.dispose();
  }

  Future<void> _loadRoyal() async {
    // loadProfile also re-locks any un-earned royal, so this is always the
    // real, equippable avatar.
    final p = await GamificationService().loadProfile();
    final royal = royalAvatarAt(int.tryParse(p.avatarValue) ?? -1);
    if (mounted) setState(() => _royal = royal);
  }

  void _onReaction() {
    final ev = royalReactionRequest.value;
    if (ev == null || ev.nonce == _lastNonce || !mounted) return;
    _lastNonce = ev.nonce;
    if (_royal == null) return;
    // Gamified Budgets is the master switch for every royal flourish.
    if (!context.read<AppPreferences>().gamifiedMode) return;
    setState(() => _active = ev);
  }

  void _end(int nonce) {
    if (!mounted || _active?.nonce != nonce) return;
    setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    final ev = _active;
    final royal = _royal;
    final gamified = context.watch<AppPreferences>().gamifiedMode;
    final show = ev != null && royal != null && gamified;
    return Stack(
      children: [
        widget.child,
        if (show)
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 10,
            child: IgnorePointer(
              child: RoyalReactionView(
                key: ValueKey(ev.nonce),
                royal: royal,
                reaction: ev.reaction,
                size: 116,
                onDone: () => _end(ev.nonce),
              ),
            ),
          ),
      ],
    );
  }
}

/// Plays a single [reaction] for [royal] once, then calls [onDone]. Self-
/// contained (owns its ticker); give it a fresh key to replay.
class RoyalReactionView extends StatefulWidget {
  final RoyalAvatar royal;
  final RoyalReaction reaction;
  final double size;
  final VoidCallback? onDone;

  const RoyalReactionView({
    super.key,
    required this.royal,
    required this.reaction,
    this.size = 116,
    this.onDone,
  });

  @override
  State<RoyalReactionView> createState() => _RoyalReactionViewState();
}

class _RoyalReactionViewState extends State<RoyalReactionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _durationFor(widget.reaction))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  Duration _durationFor(RoyalReaction r) => switch (r) {
        RoyalReaction.strike => const Duration(milliseconds: 1100),
        RoyalReaction.scold => const Duration(milliseconds: 1350),
        RoyalReaction.cheer => const Duration(milliseconds: 1350),
      };

  @override
  void didUpdateWidget(RoyalReactionView old) {
    super.didUpdateWidget(old);
    // If this view is reused for a new reaction (or royal), replay from the
    // start. The Home host normally keys by nonce so the State is fresh, but
    // this keeps the widget correct if it's ever reused in place.
    if (old.reaction != widget.reaction || old.royal.id != widget.royal.id) {
      _c
        ..duration = _durationFor(widget.reaction)
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: RoyalReactionPainter(
            royal: widget.royal,
            reaction: widget.reaction,
            t: _c.value,
          ),
        ),
      ),
    );
  }
}

/// Paints one frame of a royal reaction: the velvet-backed sprite with a
/// reaction-specific motion + expression, its signature weapon effect, and
/// mood particles. [t] runs 0→1.
class RoyalReactionPainter extends CustomPainter {
  final RoyalAvatar royal;
  final RoyalReaction reaction;
  final double t;

  const RoyalReactionPainter({
    required this.royal,
    required this.reaction,
    required this.t,
  });

  static const double _spriteFrac = 0.72;

  @override
  void paint(Canvas canvas, Size size) {
    final env = _envelope(t);
    if (env <= 0) return;
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint()..color = Colors.white.withValues(alpha: env));

    // A brief elastic entrance scale about the centre.
    final c = size.center(Offset.zero);
    final entrance =
        0.72 + 0.28 * Curves.easeOutBack.transform((t / 0.16).clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(entrance);
    canvas.translate(-c.dx, -c.dy);

    _backdrop(canvas, size);
    switch (reaction) {
      case RoyalReaction.strike:
        _strike(canvas, size);
      case RoyalReaction.scold:
        _scold(canvas, size);
      case RoyalReaction.cheer:
        _cheer(canvas, size);
    }

    canvas.restore();
    canvas.restore();
  }

  // ── Reactions ──────────────────────────────────────────────────────────

  void _strike(Canvas canvas, Size size) {
    final lunge = _lunge(t);
    _sprite(canvas, size,
        offset: Offset(size.width * 0.10 * lunge, 0),
        scale: 1 + 0.03 * lunge.clamp(0.0, 1.0));
    _weaponStrike(canvas, size);
  }

  void _scold(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final shake = math.sin(t * math.pi * 11) * (1 - t) * size.width * 0.03;
    _sprite(canvas, size, offset: Offset(shake, 0), angryBrows: true);

    // Ember anger ring pulsing around the head.
    final pulse = _pulse(t);
    canvas.drawCircle(
      c.translate(0, -size.height * 0.02),
      size.width * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _ember.withValues(alpha: 0.22 * pulse),
    );

    _weaponSlam(canvas, size);

    // An angry "!" pops in.
    final bangFade = 1 - _seg(t, 0.72, 1.0);
    if (t > 0.16 && bangFade > 0) {
      _bang(canvas, c.translate(size.width * 0.30, -size.height * 0.30),
          size.height * 0.16, _ember.withValues(alpha: bangFade));
    }
  }

  void _cheer(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final beat = math.sin(t * math.pi * 2).abs();
    final hop = -beat * size.height * 0.08;
    _sprite(canvas, size,
        offset: Offset(0, hop),
        scale: 1 + 0.02 * beat,
        eyeRows: royal.eyesClosed);

    final fade = 1 - _seg(t, 0.74, 1.0);

    // Weapon raised in triumph, sparkling at the tip.
    final hand = c.translate(size.width * 0.12, size.height * 0.02 + hop);
    final tip = c.translate(size.width * 0.24, -size.height * 0.26 + hop);
    _shaft(canvas, hand, tip, size.width * 0.035, _gold.withValues(alpha: fade),
        _goldDeep.withValues(alpha: fade));
    _weaponMark(canvas, tip, size.width * 0.08, fade);
    _star(canvas, tip, size.width * 0.10 * _pulse(t),
        Colors.white.withValues(alpha: fade));

    // Rising sparkles + hearts.
    for (var i = 0; i < 5; i++) {
      final ph = (t * 1.2 + i * 0.2) % 1.0;
      final x = c.dx + math.sin(i * 1.7 + t * 6) * size.width * 0.26;
      final y = c.dy + size.height * 0.28 - ph * size.height * 0.52;
      final a = fade * (1 - ph) * 0.9;
      if (a <= 0) continue;
      if (i.isEven) {
        _heart(canvas, Offset(x, y), size.width * 0.032,
            royal.theme.accent.withValues(alpha: a));
      } else {
        _star(canvas, Offset(x, y), size.width * 0.026,
            _gold.withValues(alpha: a));
      }
    }

    // Warm glow ring.
    canvas.drawCircle(
      c,
      size.width * 0.40,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = royal.theme.accentSoft.withValues(alpha: 0.22 * fade),
    );
  }

  // ── Weapon effects ─────────────────────────────────────────────────────

  /// The outward attack that leads a [RoyalReaction.strike], flavored per
  /// weapon. Uses two phases from [t]: [q] extends/travels, [fade] eases out.
  void _weaponStrike(Canvas canvas, Size size) {
    final q = Curves.easeOut.transform(_seg(t, 0.34, 0.66));
    final fade = 1 - _seg(t, 0.7, 0.98);
    if (fade <= 0) return;
    final c = size.center(Offset.zero);
    final accent = royal.theme.accent;

    switch (royal.weapon) {
      case RoyalWeapon.lance:
        final base = c.translate(-size.width * 0.04, size.height * 0.04);
        final tip = c.translate(size.width * (0.08 + 0.34 * q), -size.height * 0.02);
        _shaft(canvas, base, tip, size.width * 0.045,
            _gold.withValues(alpha: fade), _goldDeep.withValues(alpha: fade));
        _triTip(canvas, tip, (tip - base).direction, size.width * 0.11,
            size.width * 0.05, _steel.withValues(alpha: fade));
        _star(canvas, tip, size.width * (0.09 * (1 - q) + 0.02),
            Colors.white.withValues(alpha: fade * 0.9));
      case RoyalWeapon.warClub:
        final a0 = -math.pi * 0.95, a1 = -math.pi * 0.18;
        final ang = a0 + (a1 - a0) * q;
        final r = size.width * 0.30;
        final head = c + Offset(math.cos(ang), math.sin(ang)) * r;
        _arcStroke(canvas, c, r, a0, (a1 - a0) * q, size.width * 0.05,
            accent.withValues(alpha: fade * 0.45));
        _shaft(canvas, c, head, size.width * 0.045, _ink.withValues(alpha: fade),
            const Color(0xFF3E2A1A).withValues(alpha: fade));
        _discHead(canvas, head, size.width * 0.095,
            const Color(0xFF4E525C).withValues(alpha: fade),
            const Color(0xFF9AA3B2).withValues(alpha: fade));
        if (q > 0.85) {
          _star(canvas, head, size.width * 0.13, _ember.withValues(alpha: fade));
        }
      case RoyalWeapon.bow:
        if (t < 0.5) {
          _bowArc(canvas, c.translate(-size.width * 0.16, 0), size.width * 0.15,
              _gold.withValues(alpha: fade));
        }
        final x = c.dx - size.width * 0.08 + size.width * 0.62 * q;
        final head = Offset(x, c.dy - size.height * 0.02);
        final tail = head.translate(-size.width * 0.20, 0);
        _shaft(canvas, tail, head, size.width * 0.02,
            _goldDeep.withValues(alpha: fade), _goldDeep.withValues(alpha: fade));
        _triTip(canvas, head, 0, size.width * 0.07, size.width * 0.035,
            _steel.withValues(alpha: fade));
        final fl = Paint()
          ..color = accent.withValues(alpha: fade)
          ..strokeWidth = 2;
        canvas.drawLine(tail, tail.translate(size.width * 0.05, -size.width * 0.04), fl);
        canvas.drawLine(tail, tail.translate(size.width * 0.05, size.width * 0.04), fl);
      case RoyalWeapon.medKit:
        for (var i = 0; i < 3; i++) {
          final tq = (q - i * 0.14).clamp(0.0, 1.0);
          if (tq <= 0) continue;
          final x = c.dx + size.width * (0.04 + 0.40 * tq);
          final y = c.dy - math.sin(tq * math.pi) * size.height * 0.16;
          final lead = i == 0;
          _crossMark(canvas, Offset(x, y), size.width * (lead ? 0.10 : 0.05),
              _heal.withValues(alpha: fade * (lead ? 1 : 0.5)));
        }
      case RoyalWeapon.orbs:
        for (var i = 0; i < 3; i++) {
          final oq = (q - i * 0.14).clamp(0.0, 1.0);
          if (oq <= 0) continue;
          final x = c.dx + size.width * (0.04 + 0.42 * oq);
          final y = c.dy + math.sin(oq * math.pi * 1.5 + i * 2) *
              size.height * 0.12 * (1 - oq * 0.5);
          _orb(canvas, Offset(x, y), size.width * 0.055 * (1 - oq * 0.3),
              accent.withValues(alpha: fade),
              royal.theme.accentSoft.withValues(alpha: fade));
        }
      case RoyalWeapon.staff:
        final base = c.translate(-size.width * 0.02, size.height * 0.16);
        final top = c.translate(size.width * 0.04, -size.height * 0.16);
        _shaft(canvas, base, top, size.width * 0.04,
            _gold.withValues(alpha: fade), _goldDeep.withValues(alpha: fade));
        _gem(canvas, top, size.width * 0.08, accent.withValues(alpha: fade));
        _bolt(canvas, top, top.translate(size.width * 0.40 * q, size.height * 0.14),
            accent.withValues(alpha: fade));
        _star(canvas, top, size.width * 0.10 * _pulse(t),
            Colors.white.withValues(alpha: fade * 0.8));
    }
  }

  /// A downward weapon slam that punctuates a [RoyalReaction.scold].
  void _weaponSlam(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final raise = _seg(t, 0.12, 0.42);
    final slam = _seg(t, 0.42, 0.56);
    final fade = 1 - _seg(t, 0.72, 1.0);
    if (fade <= 0) return;

    final headY =
        c.dy - size.height * (0.06 + 0.22 * raise) + size.height * 0.34 * slam;
    final headPos = Offset(c.dx + size.width * 0.24, headY);
    final hand = c.translate(size.width * 0.10, size.height * 0.06);
    _shaft(canvas, hand, headPos, size.width * 0.035,
        _gold.withValues(alpha: fade), _goldDeep.withValues(alpha: fade));
    _weaponMark(canvas, headPos, size.width * 0.085, fade);

    if (slam >= 1) {
      final imp = _seg(t, 0.56, 0.82);
      final ip = Offset(c.dx + size.width * 0.24, c.dy + size.height * 0.30);
      _ring(canvas, ip, size.width * (0.05 + 0.20 * imp), 2.5,
          _ember.withValues(alpha: (1 - imp) * fade));
      _star(canvas, ip, size.width * (0.09 * (1 - imp) + 0.02),
          Colors.white.withValues(alpha: (1 - imp) * fade));
    }
  }

  /// A small emblem of the royal's weapon head, for slam/cheer poses.
  void _weaponMark(Canvas canvas, Offset pos, double r, double fade) {
    switch (royal.weapon) {
      case RoyalWeapon.lance:
        _triTip(canvas, pos.translate(0, -r), -math.pi / 2, r * 1.5, r * 0.55,
            _steel.withValues(alpha: fade));
      case RoyalWeapon.warClub:
        _discHead(canvas, pos, r, const Color(0xFF4E525C).withValues(alpha: fade),
            const Color(0xFF9AA3B2).withValues(alpha: fade));
      case RoyalWeapon.bow:
        _bowArc(canvas, pos, r, _gold.withValues(alpha: fade));
      case RoyalWeapon.medKit:
        _bag(canvas, pos, r, fade);
      case RoyalWeapon.orbs:
        _orb(canvas, pos, r * 0.8, royal.theme.accent.withValues(alpha: fade),
            royal.theme.accentSoft.withValues(alpha: fade));
      case RoyalWeapon.staff:
        _gem(canvas, pos, r, royal.theme.accent.withValues(alpha: fade));
    }
  }

  // ── Sprite ─────────────────────────────────────────────────────────────

  void _sprite(
    Canvas canvas,
    Size size, {
    Offset offset = Offset.zero,
    double scale = 1,
    List<String>? eyeRows,
    bool angryBrows = false,
  }) {
    final box = size.width * _spriteFrac;
    final origin = Offset((size.width - box) / 2, (size.height - box) / 2) + offset;
    final rows = List<String>.from(royal.rows);
    if (eyeRows != null && eyeRows.length == 2) {
      rows[royal.eyeRowWhites] = eyeRows[0];
      rows[royal.eyeRowIris] = eyeRows[1];
    }
    canvas.save();
    final ctr = origin + Offset(box / 2, box / 2);
    canvas.translate(ctr.dx, ctr.dy);
    canvas.scale(scale);
    canvas.translate(-box / 2, -box / 2);
    paintRoyalGrid(canvas, Size(box, box), rows, royal.palette);
    if (angryBrows) {
      final cell = box / 16;
      final y = (royal.eyeRowWhites - 0.6) * cell;
      final p = Paint()
        ..color = _ink
        ..strokeWidth = cell * 0.9
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cell * 4.2, y - cell * 0.5),
          Offset(cell * 6.6, y + cell * 0.5), p);
      canvas.drawLine(Offset(cell * 11.8, y - cell * 0.5),
          Offset(cell * 9.4, y + cell * 0.5), p);
    }
    canvas.restore();
  }

  void _backdrop(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.36;
    canvas.drawCircle(
      c.translate(0, 3),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: royal.theme.backdrop)
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = royal.theme.accent.withValues(alpha: 0.5),
    );
  }

  // ── Primitives ─────────────────────────────────────────────────────────

  void _shaft(Canvas canvas, Offset a, Offset b, double w, Color main, Color edge) {
    canvas.drawLine(
        a, b, Paint()..color = edge ..strokeWidth = w + 2 ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        a, b, Paint()..color = main ..strokeWidth = w ..strokeCap = StrokeCap.round);
  }

  void _triTip(Canvas canvas, Offset tip, double dir, double len, double halfW,
      Color color) {
    final back = tip - Offset(math.cos(dir), math.sin(dir)) * len;
    final perp = Offset(-math.sin(dir), math.cos(dir)) * halfW;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + perp.dx, back.dy + perp.dy)
      ..lineTo(back.dx - perp.dx, back.dy - perp.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _discHead(Canvas canvas, Offset c, double r, Color fill, Color edge) {
    canvas.drawCircle(c, r, Paint()..color = fill);
    canvas.drawCircle(
        c, r, Paint()..style = PaintingStyle.stroke ..strokeWidth = r * 0.2 ..color = edge);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * r * 0.72, r * 0.14, Paint()..color = edge);
    }
  }

  void _orb(Canvas canvas, Offset c, double r, Color core, Color glow) {
    canvas.drawCircle(
      c,
      r * 1.9,
      Paint()
        ..color = glow.withValues(alpha: glow.a * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [Colors.white, core])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _gem(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.8, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.8, c.dy)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.2
          ..color = Colors.white.withValues(alpha: 0.7 * color.a));
  }

  void _crossMark(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    final t = r * 0.5;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: t, height: r * 2), Radius.circular(t * 0.3)),
        p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: r * 2, height: t), Radius.circular(t * 0.3)),
        p);
  }

  void _bag(Canvas canvas, Offset c, double r, double fade) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: r * 1.9, height: r * 1.6),
            Radius.circular(r * 0.3)),
        Paint()..color = const Color(0xFFF6F2EA).withValues(alpha: fade));
    _crossMark(canvas, c, r * 0.5, _heal.withValues(alpha: fade));
  }

  void _bowArc(Canvas canvas, Offset c, double r, Color color) {
    _arcStroke(canvas, c, r, -math.pi * 0.5, math.pi, 3, color);
    final top = c + Offset(math.cos(-math.pi * 0.5), math.sin(-math.pi * 0.5)) * r;
    final bot = c + Offset(math.cos(math.pi * 0.5), math.sin(math.pi * 0.5)) * r;
    canvas.drawLine(top, bot,
        Paint()..color = color.withValues(alpha: color.a * 0.7) ..strokeWidth = 1.2);
  }

  void _arcStroke(Canvas canvas, Offset c, double r, double start, double sweep,
      double w, Color color) {
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  void _bolt(Canvas canvas, Offset a, Offset b, Color color) {
    final path = Path()..moveTo(a.dx, a.dy);
    const n = 4;
    for (var i = 1; i <= n; i++) {
      final f = i / n;
      final x = a.dx + (b.dx - a.dx) * f;
      final y = a.dy + (b.dy - a.dy) * f + (i.isEven ? 6 : -6) * (1 - f);
      path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = color);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.8 * color.a));
  }

  void _star(Canvas canvas, Offset c, double r, Color color, {int points = 4}) {
    if (r <= 0) return;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final a = i * math.pi / points - math.pi / 2;
      final rad = i.isEven ? r : r * 0.38;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rad;
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _bang(Canvas canvas, Offset c, double h, Color color) {
    final w = h * 0.24;
    final p = Paint()..color = color;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(c.dx - w / 2, c.dy - h / 2, w, h * 0.6), Radius.circular(w / 2)),
        p);
    canvas.drawCircle(Offset(c.dx, c.dy + h * 0.38), w * 0.62, p);
  }

  void _ring(Canvas canvas, Offset c, double r, double w, Color color) {
    canvas.drawCircle(
        c, r, Paint()..style = PaintingStyle.stroke ..strokeWidth = w ..color = color);
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(c.dx - r * 1.4, c.dy - r * 0.2, c.dx - r * 0.4, c.dy - r * 1.2, c.dx,
          c.dy - r * 0.4)
      ..cubicTo(c.dx + r * 0.4, c.dy - r * 1.2, c.dx + r * 1.4, c.dy - r * 0.2, c.dx,
          c.dy + r * 0.9);
    canvas.drawPath(p, Paint()..color = color);
  }

  // ── Timing helpers ─────────────────────────────────────────────────────

  /// A fade in/out envelope applied to the whole frame.
  double _envelope(double t) {
    if (t < 0.12) return t / 0.12;
    if (t > 0.8) return (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);
    return 1;
  }

  /// Windup then lunge then settle, in [-0.35 .. 1 .. 0].
  double _lunge(double t) {
    if (t < 0.28) return -Curves.easeOut.transform(t / 0.28) * 0.35;
    if (t < 0.5) return -0.35 + Curves.easeIn.transform((t - 0.28) / 0.22) * 1.35;
    return 1 - Curves.easeOutCubic.transform(((t - 0.5) / 0.5).clamp(0.0, 1.0));
  }

  double _pulse(double t) => 0.6 + 0.4 * math.sin(t * math.pi * 6).abs();

  double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  bool shouldRepaint(RoyalReactionPainter old) =>
      old.t != t || old.reaction != reaction || old.royal != royal;
}
