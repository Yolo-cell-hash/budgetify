import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'royal_avatars.dart';

/// Full-body, flat-2D pixel renders of the ROYALTY avatars. Each character
/// reuses its ready-made pixel HEAD (from [RoyalAvatar]) and gets a themed body
/// — torso, arms, legs, boots and its signature weapon — coloured from the very
/// same palette so head and body always match. The body is a lightweight rig
/// (chunky chibi limbs) so one code path animates every royal: idle, walk, run,
/// wave, smash and cheer. Cosmetic only; never part of core logic.

/// What the character is doing this frame.
enum RoyalAction { idle, walk, run, wave, smash, cheer }

enum RoyalOutfit { robe, armor, coat }

const _gold = Color(0xFFF2C14E);

Color _darken(Color c, double amt) => Color.lerp(c, Colors.black, amt)!;

/// Body colours + silhouette for one royal, derived from its head palette so
/// the two never clash. Robed royals (Sovereign/Empress/Princess) glide on a
/// long gown; the princes wear armour with visible legs; the Medic a coat.
class RoyalBody {
  final Color main;
  final Color dark;
  final Color trim;
  final Color skin;
  final Color skinDark;
  final Color hair;
  final Color boot;
  final RoyalOutfit outfit;

  const RoyalBody({
    required this.main,
    required this.dark,
    required this.trim,
    required this.skin,
    required this.skinDark,
    required this.hair,
    required this.boot,
    required this.outfit,
  });

  factory RoyalBody.of(RoyalAvatar r) {
    Color pick(List<String> keys, Color fallback) {
      for (final k in keys) {
        final c = r.palette[k];
        if (c != null) return c;
      }
      return fallback;
    }

    final main = pick(['R', 'A', 'F'], r.theme.accentDeep);
    final skin = pick(['K'], const Color(0xFFE8B98C));
    final outfit = switch (r.id) {
      'prince' || 'darkprince' => RoyalOutfit.armor,
      'royalmedic' => RoyalOutfit.coat,
      _ => RoyalOutfit.robe,
    };
    return RoyalBody(
      main: main,
      dark: pick(['r', 'a', 'f'], _darken(main, 0.3)),
      trim: pick(['T'], _gold),
      skin: skin,
      skinDark: pick(['k'], _darken(skin, 0.15)),
      hair: pick(['H'], const Color(0xFF3A2E28)),
      boot: outfit == RoyalOutfit.armor ? pick(['a'], _darken(main, 0.4)) : _darken(main, 0.35),
      outfit: outfit,
    );
  }
}

/// One frame's skeleton, in fractions of the character box.
class _Pose {
  final double bob; // vertical body bob (× height)
  final double lean; // forward lean (radians)
  final double frontLeg; // hip angle from vertical (radians)
  final double backLeg;
  final double frontArm; // shoulder angle from vertical
  final double backArm;
  final double weaponArm; // the weapon arm's angle (from vertical)
  final double weaponSwing; // extra flourish on the weapon (radians)
  final bool blink;

  const _Pose({
    this.bob = 0,
    this.lean = 0,
    this.frontLeg = 0.12,
    this.backLeg = -0.12,
    this.frontArm = 0.12,
    this.backArm = -0.12,
    this.weaponArm = 0.35,
    this.weaponSwing = 0,
    this.blink = false,
  });
}

/// Paints a royal at full body for a given [action]/[t]. Pure and stateless —
/// the host drives [t] so choreography (position + action + effects) stays in
/// lockstep. [facing] is +1 (right) or -1 (left).
class RoyalCharacterPainter extends CustomPainter {
  final RoyalAvatar royal;
  final RoyalBody body;
  final RoyalAction action;
  final double t;
  final double facing;

  RoyalCharacterPainter({
    required this.royal,
    required this.action,
    required this.t,
    this.facing = 1,
  }) : body = RoyalBody.of(royal);

  @override
  void paint(Canvas canvas, Size size) {
    final pose = _poseFor(action, t);
    canvas.save();
    // Face left by mirroring about the centre.
    if (facing < 0) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    // Whole-body bob + a slight forward lean about the hips.
    final hip = Offset(size.width * 0.5, size.height * (0.62 + pose.bob));
    canvas.translate(0, size.height * pose.bob);
    canvas.save();
    canvas.translate(hip.dx, hip.dy);
    canvas.rotate(pose.lean);
    canvas.translate(-hip.dx, -hip.dy);

    _paintBody(canvas, size, pose);

    canvas.restore();
    canvas.restore();
  }

  // ── Rig ────────────────────────────────────────────────────────────────

  void _paintBody(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final hipY = h * 0.62;
    final shoulderY = h * 0.42;
    final limbW = w * 0.11;

    // Back arm + back leg first (behind the torso).
    _arm(canvas, Offset(cx - w * 0.02, shoulderY), pose.backArm, w, h, limbW,
        _darken(body.main, 0.12), behind: true);
    if (body.outfit != RoyalOutfit.robe) {
      _leg(canvas, Offset(cx - w * 0.09, hipY), pose.backLeg, w, h, limbW,
          _darken(body.main, 0.25));
    }

    // Torso / gown.
    _torso(canvas, size, pose);

    // Front leg (or peeking feet for a gown).
    if (body.outfit == RoyalOutfit.robe) {
      _gownFeet(canvas, size, pose);
    } else {
      _leg(canvas, Offset(cx + w * 0.09, hipY), pose.frontLeg, w, h, limbW,
          body.main);
    }

    // Head — the royal's own pixel sprite, sitting on the shoulders.
    _head(canvas, size, pose);

    // Front (weapon) arm + weapon, in front of everything.
    final shoulder = Offset(cx + w * 0.05, shoulderY);
    _arm(canvas, shoulder, pose.weaponArm, w, h, limbW, body.skin,
        behind: false, hand: true);
    _weapon(canvas, size, shoulder, pose);
  }

  void _torso(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final top = h * 0.40, bottom = h * 0.64;
    final path = Path();
    if (body.outfit == RoyalOutfit.robe) {
      // A gown flaring to the floor, with a subtle sway.
      final sway = math.sin(t * 2 * math.pi) * w * 0.02;
      final floor = h * 0.98;
      path
        ..moveTo(cx - w * 0.16, top)
        ..lineTo(cx + w * 0.16, top)
        ..lineTo(cx + w * 0.26 + sway, floor)
        ..lineTo(cx - w * 0.26 + sway, floor)
        ..close();
    } else {
      final halfTop = w * 0.16, halfBot = w * 0.13;
      path
        ..moveTo(cx - halfTop, top)
        ..lineTo(cx + halfTop, top)
        ..lineTo(cx + halfBot, bottom)
        ..lineTo(cx - halfBot, bottom)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = body.main);
    // A central trim stripe (sash / plackard) for a regal read.
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, (top + bottom) / 2),
          width: w * 0.05,
          height: bottom - top),
      Paint()..color = body.trim.withValues(alpha: 0.9),
    );
    // Shoulder shade.
    canvas.drawRect(Rect.fromLTWH(cx - w * 0.16, top, w * 0.32, h * 0.03),
        Paint()..color = _darken(body.main, 0.18));
  }

  void _gownFeet(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    // Two small boots shuffling under the hem.
    final shuffle = math.sin(t * 2 * math.pi) * w * 0.03;
    for (final s in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + s * w * 0.10 + shuffle * s, h * 0.965),
            width: w * 0.14,
            height: h * 0.05,
          ),
          Radius.circular(w * 0.04),
        ),
        Paint()..color = body.boot,
      );
    }
  }

  void _leg(Canvas canvas, Offset hip, double hipAngle, double w, double h,
      double limbW, Color color) {
    final thigh = h * 0.18, shin = h * 0.16;
    final knee = hip +
        Offset(math.sin(hipAngle), math.cos(hipAngle)) * thigh;
    final kneeBend = hipAngle * 0.4 - 0.05;
    final ankle = knee +
        Offset(math.sin(hipAngle + kneeBend), math.cos(hipAngle + kneeBend)) *
            shin;
    _seg(canvas, hip, knee, limbW, color);
    _seg(canvas, knee, ankle, limbW * 0.9, color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: ankle.translate(w * 0.03, w * 0.01),
            width: limbW * 1.7,
            height: limbW * 0.9),
        Radius.circular(limbW * 0.3),
      ),
      Paint()..color = body.boot,
    );
  }

  void _arm(Canvas canvas, Offset shoulder, double angle, double w, double h,
      double limbW,
      Color color,
      {required bool behind, bool hand = false}) {
    final upper = h * 0.15, fore = h * 0.14;
    final elbow =
        shoulder + Offset(math.sin(angle), math.cos(angle)) * upper;
    final foreAngle = angle + 0.15;
    final wrist =
        elbow + Offset(math.sin(foreAngle), math.cos(foreAngle)) * fore;
    final c = behind ? color : color;
    _seg(canvas, shoulder, elbow, limbW * 0.85, c);
    _seg(canvas, elbow, wrist, limbW * 0.75, hand ? color : c);
    if (hand) {
      canvas.drawCircle(wrist, limbW * 0.5, Paint()..color = body.skin);
    }
  }

  void _head(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final box = w * 0.62;
    final origin = Offset((w - box) / 2, h * 0.02 + h * 0.01 * math.sin(t * 2 * math.pi));
    final rows = List<String>.from(royal.rows);
    if (pose.blink) {
      rows[royal.eyeRowWhites] = royal.eyesClosed[0];
      rows[royal.eyeRowIris] = royal.eyesClosed[1];
    }
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    // The head sprite is authored facing the viewer; keep it upright even when
    // the body mirrors, so the face never reads back-to-front.
    if (facing < 0) {
      canvas.translate(box, 0);
      canvas.scale(-1, 1);
    }
    paintRoyalGrid(canvas, Size(box, box), rows, royal.palette);
    canvas.restore();
  }

  void _weapon(Canvas canvas, Size size, Offset shoulder, _Pose pose) {
    final w = size.width, h = size.height;
    final angle = pose.weaponArm + pose.weaponSwing;
    final grip =
        shoulder + Offset(math.sin(angle), math.cos(angle)) * (h * 0.28);
    final dir = angle; // weapon points along the arm
    final tipLen = h * 0.34;
    final tip = grip + Offset(math.sin(dir - math.pi), math.cos(dir - math.pi)) * tipLen;
    final accent = royal.theme.accent;
    switch (royal.weapon) {
      case RoyalWeapon.lance:
        _shaft(canvas, grip, tip, w * 0.05, _gold, _darken(_gold, 0.25));
        _triangle(canvas, tip, (tip - grip).direction, w * 0.12, w * 0.05,
            const Color(0xFFEAF0F6));
      case RoyalWeapon.warClub:
        _shaft(canvas, grip, tip, w * 0.055, const Color(0xFF3E2A1A),
            const Color(0xFF241608));
        canvas.drawCircle(tip, w * 0.11, Paint()..color = const Color(0xFF4E525C));
        canvas.drawCircle(tip, w * 0.11,
            Paint()..style = PaintingStyle.stroke ..strokeWidth = w * 0.02 ..color = const Color(0xFF9AA3B2));
      case RoyalWeapon.bow:
        // A proper bow: an arc opening along the aim, with a taut string chord.
        final br = h * 0.15;
        canvas.drawArc(
          Rect.fromCircle(center: grip, radius: br),
          dir + math.pi * 0.5,
          math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.03
            ..strokeCap = StrokeCap.round
            ..color = _gold,
        );
        final e1 = grip + Offset(math.cos(dir + math.pi * 0.5), math.sin(dir + math.pi * 0.5)) * br;
        final e2 = grip + Offset(math.cos(dir + math.pi * 1.5), math.sin(dir + math.pi * 1.5)) * br;
        canvas.drawLine(
            e1, e2, Paint()..color = const Color(0xFFEAF0F6).withValues(alpha: 0.85) ..strokeWidth = 1.3);
      case RoyalWeapon.medKit:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: grip, width: w * 0.20, height: h * 0.14),
              Radius.circular(w * 0.04)),
          Paint()..color = const Color(0xFFF6F2EA),
        );
        _plus(canvas, grip, w * 0.05, const Color(0xFF2BB985));
      case RoyalWeapon.orbs:
        for (var i = 0; i < 3; i++) {
          final a = t * 2 * math.pi + i * 2.1;
          final p = grip + Offset(math.cos(a), math.sin(a)) * w * 0.10;
          canvas.drawCircle(p, w * 0.045, Paint()..color = accent);
        }
      case RoyalWeapon.staff:
        _shaft(canvas, grip.translate(0, h * 0.14), tip, w * 0.045, _gold,
            _darken(_gold, 0.25));
        _gem(canvas, tip, w * 0.09, accent);
    }
  }

  // ── Poses ──────────────────────────────────────────────────────────────

  _Pose _poseFor(RoyalAction a, double t) {
    final blink = _blink(t);
    switch (a) {
      case RoyalAction.idle:
        final s = math.sin(t * 2 * math.pi);
        return _Pose(
          bob: s * 0.006,
          frontLeg: 0.05,
          backLeg: -0.05,
          frontArm: 0.12 + s * 0.03,
          backArm: -0.12 - s * 0.03,
          weaponArm: 0.16, // held upright at the side
          blink: blink,
        );
      case RoyalAction.walk:
      case RoyalAction.run:
        final run = a == RoyalAction.run;
        final amp = run ? 0.55 : 0.35;
        final s = math.sin(t * 2 * math.pi);
        return _Pose(
          bob: -(s.abs()) * (run ? 0.02 : 0.012),
          lean: run ? 0.16 : 0.06,
          frontLeg: s * amp,
          backLeg: -s * amp,
          frontArm: -s * amp * 0.9,
          backArm: s * amp * 0.9,
          weaponArm: 0.30 - s * amp * 0.5,
          blink: blink,
        );
      case RoyalAction.wave:
        final s = math.sin(t * 2 * math.pi * 3);
        return _Pose(
          bob: math.sin(t * 2 * math.pi) * 0.006,
          weaponArm: 2.3 + s * 0.22, // raised up and OUT to the side, clear of the face
          weaponSwing: s * 0.2,
          frontArm: 0.14,
          backArm: -0.14,
          blink: blink,
        );
      case RoyalAction.smash:
        // Wind the weapon up and overhead, then slam it down and forward.
        final wind = Curves.easeOut.transform((t / 0.42).clamp(0.0, 1.0));
        final slam = Curves.easeIn.transform(((t - 0.42) / 0.22).clamp(0.0, 1.0));
        final settle = ((t - 0.64) / 0.36).clamp(0.0, 1.0);
        final arm = -2.6 * wind + 3.4 * slam - 0.6 * settle;
        return _Pose(
          lean: -0.14 * wind + 0.34 * slam - 0.20 * settle,
          bob: 0.02 * slam,
          weaponArm: arm,
          frontLeg: 0.3 * slam,
          backLeg: -0.35 * slam,
          frontArm: 0.1,
          backArm: -0.1,
          blink: false,
        );
      case RoyalAction.cheer:
        final hop = math.sin(t * 2 * math.pi * 2).abs();
        return _Pose(
          bob: -hop * 0.05,
          weaponArm: -2.7, // weapon raised in triumph
          frontArm: -1.9,
          backArm: -1.9,
          frontLeg: 0.06,
          backLeg: -0.06,
          blink: _blink(t) || (t % 0.5 < 0.25 ? false : false),
        );
    }
  }

  bool _blink(double t) {
    final p = t % 1.0;
    return (p > 0.14 && p < 0.17) || (p > 0.62 && p < 0.65);
  }

  // ── Primitives ─────────────────────────────────────────────────────────

  void _seg(Canvas canvas, Offset a, Offset b, double w, Color color) {
    canvas.drawLine(
        a, b, Paint()..color = _darken(color, 0.28) ..strokeWidth = w + 2 ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        a, b, Paint()..color = color ..strokeWidth = w ..strokeCap = StrokeCap.round);
  }

  void _shaft(Canvas canvas, Offset a, Offset b, double w, Color main, Color edge) {
    canvas.drawLine(a, b, Paint()..color = edge ..strokeWidth = w + 2 ..strokeCap = StrokeCap.round);
    canvas.drawLine(a, b, Paint()..color = main ..strokeWidth = w ..strokeCap = StrokeCap.round);
  }

  void _triangle(Canvas canvas, Offset tip, double dir, double len, double halfW,
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

  void _plus(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    final t = r * 0.5;
    canvas.drawRect(Rect.fromCenter(center: c, width: t, height: r * 2), p);
    canvas.drawRect(Rect.fromCenter(center: c, width: r * 2, height: t), p);
  }

  void _gem(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.8, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.8, c.dy)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(RoyalCharacterPainter old) =>
      old.t != t ||
      old.action != action ||
      old.facing != facing ||
      old.royal != royal;
}

/// A convenience widget that loops [action] for a royal — handy for previews
/// and tests. The Home host drives the painter directly for tight choreography.
class RoyalCharacterView extends StatefulWidget {
  final RoyalAvatar royal;
  final RoyalAction action;
  final double facing;
  final Size size;

  const RoyalCharacterView({
    super.key,
    required this.royal,
    this.action = RoyalAction.idle,
    this.facing = 1,
    this.size = const Size(120, 180),
  });

  @override
  State<RoyalCharacterView> createState() => _RoyalCharacterViewState();
}

class _RoyalCharacterViewState extends State<RoyalCharacterView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: RoyalCharacterPainter(
            royal: widget.royal,
            action: widget.action,
            t: _c.value,
            facing: widget.facing,
          ),
        ),
      ),
    );
  }
}
