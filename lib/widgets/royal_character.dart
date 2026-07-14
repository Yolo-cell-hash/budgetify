import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'royal_avatars.dart';

/// Full-body chibi renders of the ROYALTY avatars — the "cute menacing" court.
///
/// Every royal is a bobblehead: the ready-made 16×16 pixel HEAD (from
/// [RoyalAvatar]) rides a squat, rounded body barely one head tall, inked with
/// the same outline + palette as the sprite so head and body read as one piece.
/// Menace comes from the regalia — planted staffs, shoulder-carried clubs,
/// lances taller than their owner — cuteness from the proportions, the mitten
/// hands and the squash-and-stretch in every move.
///
/// One parametric rig animates the whole court, but each royal keeps a
/// personality: motion timing ([_Motion]), outfit silhouette + detailing
/// ([RoyalOutfit] + per-id decoration), a signature weapon idle, and its own
/// royal ride for [RoyalAction.ride] (the princes' horses, the Empress's
/// floating palanquin, the Sovereign's lion, the Princess's unicorn, the
/// Medic's rolling supply cart). Cosmetic only; never part of core logic.

/// What the character is doing this frame.
enum RoyalAction { idle, walk, run, wave, smash, cheer, fume, ride }

enum RoyalOutfit { robe, armor, coat }

const _gold = Color(0xFFF2C14E);
const _ink = Color(0xFF1A151F);

Color _darken(Color c, double amt) => Color.lerp(c, Colors.black, amt)!;
Color _lighten(Color c, double amt) => Color.lerp(c, Colors.white, amt)!;

/// Body colours + silhouette for one royal, derived from its head palette so
/// the two never clash.
class RoyalBody {
  final Color main;
  final Color dark;
  final Color trim;
  final Color skin;
  final Color skinDark;
  final Color hair;
  final Color boot;
  final Color ink;
  final Color gem;
  final Color pale;
  final RoyalOutfit outfit;

  const RoyalBody({
    required this.main,
    required this.dark,
    required this.trim,
    required this.skin,
    required this.skinDark,
    required this.hair,
    required this.boot,
    required this.ink,
    required this.gem,
    required this.pale,
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
      boot: outfit == RoyalOutfit.armor
          ? pick(['a'], _darken(main, 0.4))
          : _darken(main, 0.35),
      ink: pick(['X'], _ink),
      gem: pick(['G'], _gold),
      pale: pick(['F', 'P', 'W'], const Color(0xFFF4EFE6)),
      outfit: outfit,
    );
  }
}

/// Per-royal motion personality: how the body carries itself.
class _Motion {
  final double bobHz; // idle breaths per loop
  final double bobAmp; // × height
  final double sway; // idle body rock (radians)
  final double hunch; // permanent forward lean (radians)
  final double bounce; // walk/run springiness multiplier
  const _Motion({
    this.bobHz = 1,
    this.bobAmp = 0.008,
    this.sway = 0.03,
    this.hunch = 0,
    this.bounce = 1,
  });
}

_Motion _motionOf(String id) => switch (id) {
      // Slow, weighty, unbothered — the crown does not hurry.
      'sovereign' => const _Motion(bobHz: 0.75, bobAmp: 0.007, sway: 0.02, bounce: 0.85),
      // Serene float; her gown never quite touches the floor.
      'empress' => const _Motion(bobHz: 0.6, bobAmp: 0.012, sway: 0.035, bounce: 0.7),
      // Peppy parade-ground energy.
      'prince' => const _Motion(bobHz: 1.3, bobAmp: 0.010, sway: 0.03, bounce: 1.25),
      // A low, coiled menace — heavier on his feet, always leaning in.
      'darkprince' => const _Motion(bobHz: 0.85, bobAmp: 0.006, sway: 0.02, hunch: 0.07, bounce: 1.1),
      // Light on her heels, skirt always half a beat behind.
      'princess' => const _Motion(bobHz: 1.1, bobAmp: 0.011, sway: 0.05, bounce: 1.15),
      // Busy, bustling bedside energy.
      'royalmedic' => const _Motion(bobHz: 1.45, bobAmp: 0.010, sway: 0.03, bounce: 1.2),
      _ => const _Motion(),
    };

/// One frame's skeleton, in fractions of the character box.
class _Pose {
  final double bob; // vertical offset (× height, negative = up)
  final double lean; // whole-body lean about the feet (radians)
  final double sway; // body rock (radians) — hem/frills lag it
  final double squash; // vertical squash(<1)/stretch(>1) about the ground
  final double legPhase; // -1..1 walk-cycle beat (front leg forward at +1)
  final double stride; // leg swing amplitude multiplier
  final double armFree; // near arm angle from straight-down (+ = forward)
  final double armWeapon; // far (weapon) arm angle from straight-down
  final double wiggle; // hand waggle for waves/cheers
  final bool blink;
  final int gaze; // -1 left, 0 centre, 1 right (pre-mirror)
  final double headTilt; // radians
  final double flourish; // 0..1 action accent (impact sparks, cheer stars)

  const _Pose({
    this.bob = 0,
    this.lean = 0,
    this.sway = 0,
    this.squash = 1,
    this.legPhase = 0,
    this.stride = 0,
    this.armFree = 0.22,
    this.armWeapon = -0.22,
    this.wiggle = 0,
    this.blink = false,
    this.gaze = 0,
    this.headTilt = 0,
    this.flourish = 0,
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
  final _Motion _motion;

  RoyalCharacterPainter({
    required this.royal,
    required this.action,
    required this.t,
    this.facing = 1,
  })  : body = RoyalBody.of(royal),
        _motion = _motionOf(royal.id);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (facing < 0) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (action == RoyalAction.ride) {
      _paintRide(canvas, size);
    } else {
      _paintStanding(canvas, size, _poseFor(action, t));
    }
    canvas.restore();
  }

  // ── Standing figure ──────────────────────────────────────────────────────

  void _paintStanding(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final ground = h * 0.955;

    _shadow(canvas, Offset(w * 0.5, ground), w * 0.27, pose);

    canvas.save();
    // Bob lifts the whole figure; lean + squash pivot about the ground.
    canvas.translate(0, h * pose.bob);
    canvas.translate(w * 0.5, ground);
    canvas.rotate(pose.lean + _motion.hunch);
    canvas.scale(2 - pose.squash, pose.squash);
    canvas.translate(-w * 0.5, -ground);

    _figure(canvas, size, pose);

    canvas.restore();

    _actionAccents(canvas, size, pose);
  }

  /// The figure itself, ground-relative. Draw order (far → near):
  /// cape → weapon arm → back orbs → legs/hem → torso → detailing → head →
  /// weapon (in front, so a planted staff/lance stays visible beside the big
  /// head) → grip mitten → front orbs → free arm.
  void _figure(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final shoulderY = h * 0.575;
    final farShoulder = Offset(cx - w * 0.14, shoulderY);
    final nearShoulder = Offset(cx + w * 0.14, shoulderY);

    _cape(canvas, size, pose);
    _arm(canvas, farShoulder, pose.armWeapon, 0, size);
    if (royal.weapon == RoyalWeapon.orbs) _orbs(canvas, size, front: false);

    switch (body.outfit) {
      case RoyalOutfit.robe:
        _gown(canvas, size, pose);
      case RoyalOutfit.armor:
      case RoyalOutfit.coat:
        _legs(canvas, size, pose);
        _torso(canvas, size, pose);
    }
    _decorate(canvas, size, pose);
    _head(canvas, size, pose);
    _frontWeapon(canvas, size, farShoulder, pose);
    if (royal.weapon == RoyalWeapon.orbs) _orbs(canvas, size, front: true);
    _arm(canvas, nearShoulder, pose.armFree, pose.wiggle, size);
  }

  /// The weapon + a fresh mitten over its grip, drawn in front of the head.
  void _frontWeapon(Canvas canvas, Size size, Offset shoulder, _Pose pose) {
    if (royal.weapon == RoyalWeapon.orbs) return;
    final hand = shoulder +
        Offset(math.sin(pose.armWeapon), math.cos(pose.armWeapon)) *
            (size.height * 0.125);
    _weapon(canvas, size, hand, pose.armWeapon, pose);
    canvas.drawCircle(
        hand, size.width * 0.047, Paint()..color = body.skin);
    canvas.drawCircle(
        hand, size.width * 0.047, _inkStroke..strokeWidth = 1.2);
  }

  // ── Body parts ───────────────────────────────────────────────────────────

  void _shadow(Canvas canvas, Offset at, double rx, _Pose pose) {
    final lift = (-pose.bob * 8).clamp(0.0, 0.75);
    canvas.drawOval(
      Rect.fromCenter(
          center: at, width: rx * 2 * (1 - lift * 0.35), height: rx * 0.42),
      Paint()..color = body.ink.withValues(alpha: 0.16 * (1 - lift * 0.6)),
    );
  }

  Paint get _inkStroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeJoin = StrokeJoin.round
    ..color = body.ink.withValues(alpha: 0.85);

  void _fillInked(Canvas canvas, Path path, Color fill) {
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(path, _inkStroke);
  }

  /// A bell-shaped gown from shoulders to floor, hem swaying half a beat
  /// behind the body, with two little boots peeking out.
  void _gown(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final top = h * 0.54, hem = h * 0.935;
    final swayPx = math.sin(pose.sway * 6) * w * 0.035 + pose.sway * w * 0.4;
    final shW = w * 0.125, hemW = w * 0.235;

    // Boots shuffle under the hem when moving.
    final shuffle = pose.legPhase * w * 0.05 * pose.stride;
    for (final s in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + s * w * 0.085 + shuffle * s, h * 0.938),
            width: w * 0.12,
            height: h * 0.040,
          ),
          Radius.circular(w * 0.03),
        ),
        Paint()..color = body.boot,
      );
    }

    final path = Path()
      ..moveTo(cx - shW, top)
      ..lineTo(cx + shW, top)
      ..cubicTo(cx + shW + w * 0.02, h * 0.70, cx + hemW + swayPx * 0.6,
          h * 0.82, cx + hemW + swayPx, hem)
      ..quadraticBezierTo(cx + swayPx * 0.5, hem + h * 0.022,
          cx - hemW + swayPx, hem)
      ..cubicTo(cx - hemW + swayPx * 0.6, h * 0.82, cx - shW - w * 0.02,
          h * 0.70, cx - shW, top)
      ..close();
    _fillInked(canvas, path, body.main);

    // Side shade gives the bell some roundness.
    final shade = Path()
      ..moveTo(cx - shW, top)
      ..cubicTo(cx - shW - w * 0.02, h * 0.70, cx - hemW + swayPx * 0.6,
          h * 0.82, cx - hemW + swayPx, hem)
      ..quadraticBezierTo(cx - hemW * 0.55 + swayPx, hem + h * 0.008,
          cx - hemW * 0.45 + swayPx, hem)
      ..cubicTo(cx - shW * 0.7 + swayPx * 0.4, h * 0.80, cx - shW * 0.6,
          h * 0.68, cx - shW * 0.55, top)
      ..close();
    canvas.drawPath(shade, Paint()..color = body.dark.withValues(alpha: 0.5));
  }

  /// Two stubby marching legs + round boots (armour and coat outfits).
  void _legs(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final hipY = h * 0.76;
    final legLen = h * 0.145;
    final legColor = body.outfit == RoyalOutfit.coat
        ? _darken(body.dark, 0.25)
        : _darken(body.main, 0.28);
    for (final s in [-1.0, 1.0]) {
      final swing = pose.legPhase * s * 0.9 * pose.stride;
      final hip = Offset(cx + s * w * 0.072, hipY);
      final foot = hip +
          Offset(math.sin(swing) * legLen,
              math.cos(swing) * legLen - (s * pose.legPhase).clamp(0, 1) * h * 0.02);
      _capsule(canvas, hip, foot, w * 0.085, legColor);
      // Round boot, toe pointing forward.
      final bootRect = Rect.fromCenter(
          center: foot.translate(w * 0.022, -h * 0.004),
          width: w * 0.125,
          height: h * 0.048);
      canvas.drawRRect(
          RRect.fromRectAndRadius(bootRect, Radius.circular(w * 0.032)),
          Paint()..color = body.boot);
      canvas.drawRRect(
          RRect.fromRectAndRadius(bootRect, Radius.circular(w * 0.032)),
          _inkStroke..strokeWidth = 1.2);
    }
  }

  /// Rounded cuirass / coat torso.
  void _torso(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final coat = body.outfit == RoyalOutfit.coat;
    final top = h * 0.535, bottom = coat ? h * 0.82 : h * 0.79;
    final halfTop = w * 0.150, halfBot = coat ? w * 0.165 : w * 0.118;
    final path = Path()
      ..moveTo(cx - halfTop, top + h * 0.015)
      ..quadraticBezierTo(cx - halfTop, top, cx - halfTop + w * 0.03, top)
      ..lineTo(cx + halfTop - w * 0.03, top)
      ..quadraticBezierTo(cx + halfTop, top, cx + halfTop, top + h * 0.015)
      ..quadraticBezierTo(cx + halfTop + (coat ? w * 0.012 : -w * 0.004),
          (top + bottom) / 2, cx + halfBot, bottom)
      ..quadraticBezierTo(cx, bottom + h * 0.018, cx - halfBot, bottom)
      ..quadraticBezierTo(cx - halfTop - (coat ? w * 0.012 : -w * 0.004),
          (top + bottom) / 2, cx - halfTop, top + h * 0.015)
      ..close();
    _fillInked(canvas, path, body.main);
    // Left-side shade for roundness.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
        Rect.fromLTWH(cx - halfTop - w * 0.02, top, w * 0.075, bottom - top),
        Paint()..color = body.dark.withValues(alpha: 0.45));
    canvas.restore();
  }

  /// Per-royal regalia layered on the base silhouette.
  void _decorate(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    switch (royal.id) {
      case 'sovereign':
        // Ermine stole: a fur crescent hugging the shoulders (not a bib —
        // the crimson chest stays visible), flecked, with a gold clasp.
        final mantle = Path()
          ..moveTo(cx - w * 0.165, h * 0.545)
          ..lineTo(cx + w * 0.165, h * 0.545)
          ..quadraticBezierTo(
              cx + w * 0.155, h * 0.635, cx + w * 0.085, h * 0.655)
          ..quadraticBezierTo(cx, h * 0.60, cx - w * 0.085, h * 0.655)
          ..quadraticBezierTo(
              cx - w * 0.155, h * 0.635, cx - w * 0.165, h * 0.545)
          ..close();
        _fillInked(canvas, mantle, body.pale);
        final fleck = Paint()..color = const Color(0xFF2A2530);
        for (final p in [
          Offset(cx - w * 0.105, h * 0.60),
          Offset(cx + w * 0.105, h * 0.60),
        ]) {
          canvas.drawRect(
              Rect.fromCenter(center: p, width: w * 0.020, height: h * 0.020),
              fleck);
        }
        canvas.drawCircle(
            Offset(cx, h * 0.565), w * 0.026, Paint()..color = body.trim);
        canvas.drawCircle(
            Offset(cx, h * 0.565), w * 0.026, _inkStroke..strokeWidth = 1.1);
        _beltGem(canvas, cx, h * 0.75, w);
      case 'empress':
        // Gold hem band + a pearl choker sitting at the collar.
        final swayPx =
            math.sin(pose.sway * 6) * w * 0.035 + pose.sway * w * 0.4;
        final hemBand = Path()
          ..moveTo(cx - w * 0.225 + swayPx, h * 0.905)
          ..quadraticBezierTo(
              cx + swayPx * 0.5, h * 0.928, cx + w * 0.225 + swayPx, h * 0.905)
          ..lineTo(cx + w * 0.235 + swayPx, h * 0.935)
          ..quadraticBezierTo(cx + swayPx * 0.5, h * 0.957,
              cx - w * 0.235 + swayPx, h * 0.935)
          ..close();
        canvas.drawPath(hemBand, Paint()..color = body.trim);
        canvas.drawCircle(Offset(cx, h * 0.56), w * 0.024,
            Paint()..color = const Color(0xFFF4EFE6));
        canvas.drawCircle(
            Offset(cx, h * 0.56), w * 0.024, _inkStroke..strokeWidth = 1.1);
      case 'prince':
        // Round pauldrons, a pale-trim collar V and a chest sheen: parade
        // armour that catches the light.
        _pauldrons(canvas, size, spiked: false);
        final vPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.024
          ..strokeCap = StrokeCap.round
          ..color = body.trim;
        canvas.drawLine(Offset(cx - w * 0.11, h * 0.55),
            Offset(cx, h * 0.635), vPaint);
        canvas.drawLine(Offset(cx + w * 0.11, h * 0.55),
            Offset(cx, h * 0.635), vPaint);
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(cx - w * 0.03, h * 0.685),
              width: w * 0.15,
              height: h * 0.085),
          -2.6,
          1.5,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.018
            ..strokeCap = StrokeCap.round
            ..color = _lighten(body.main, 0.55).withValues(alpha: 0.95),
        );
        _belt(canvas, cx, h * 0.735, w);
      case 'darkprince':
        // Spiked pauldrons + a pulsing ember core: the menace half of cute.
        _pauldrons(canvas, size, spiked: true);
        final pulse = 0.75 + 0.25 * math.sin(t * 2 * math.pi * 2);
        canvas.drawCircle(
            Offset(cx, h * 0.635),
            w * 0.045,
            Paint()
              ..color = royal.theme.accent.withValues(alpha: 0.35 * pulse)
              ..maskFilter =
                  const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(Offset(cx, h * 0.635), w * 0.028,
            Paint()..color = royal.theme.accent.withValues(alpha: pulse));
        _belt(canvas, cx, h * 0.735, w);
      case 'princess':
        // Three scalloped frill tiers that lag the sway — the skirt dances.
        final swayPx =
            math.sin(pose.sway * 6) * w * 0.035 + pose.sway * w * 0.4;
        for (var tier = 0; tier < 3; tier++) {
          final y = h * (0.70 + tier * 0.082);
          final half = w * (0.145 + tier * 0.032);
          final lag = swayPx * (0.35 + tier * 0.3);
          final frill = Path()..moveTo(cx - half + lag, y);
          const scallops = 4;
          for (var s = 0; s < scallops; s++) {
            final x0 = cx - half + lag + (2 * half / scallops) * s;
            frill.quadraticBezierTo(x0 + half / scallops, y + h * 0.045,
                x0 + 2 * half / scallops, y);
          }
          frill
            ..lineTo(cx + half + lag, y - h * 0.05)
            ..lineTo(cx - half + lag, y - h * 0.05)
            ..close();
          canvas.drawPath(
              frill,
              Paint()
                ..color = tier.isEven
                    ? _lighten(body.main, 0.22)
                    : body.main);
          canvas.drawPath(frill, _inkStroke..strokeWidth = 1.1);
        }
        // Wine bodice band + tiny heart brooch.
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(cx, h * 0.60), width: w * 0.25, height: h * 0.055),
            Paint()..color = body.dark);
        canvas.drawCircle(Offset(cx - w * 0.016, h * 0.598), w * 0.016,
            Paint()..color = body.gem);
        canvas.drawCircle(Offset(cx + w * 0.016, h * 0.598), w * 0.016,
            Paint()..color = body.gem);
      case 'royalmedic':
        // Emerald tunic panel under the open coat, chest cross, hip satchel.
        final cross = royal.palette['E'] ?? const Color(0xFF2BB985);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx, h * 0.675),
                  width: w * 0.085,
                  height: h * 0.27),
              Radius.circular(w * 0.02)),
          Paint()..color = cross.withValues(alpha: 0.9),
        );
        _plus(canvas, Offset(cx - w * 0.095, h * 0.60), w * 0.030,
            const Color(0xFFF6F2EA));
        // Satchel on a cross-strap.
        canvas.drawLine(
            Offset(cx - w * 0.13, h * 0.555),
            Offset(cx + w * 0.14, h * 0.73),
            Paint()
              ..strokeWidth = w * 0.022
              ..color = const Color(0xFF6E4A2A));
        final satchel = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx + w * 0.15, h * 0.755),
                width: w * 0.13,
                height: h * 0.075),
            Radius.circular(w * 0.025));
        canvas.drawRRect(satchel, Paint()..color = const Color(0xFF6E4A2A));
        canvas.drawRRect(satchel, _inkStroke..strokeWidth = 1.1);
    }
  }

  void _pauldrons(Canvas canvas, Size size, {required bool spiked}) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    for (final s in [-1.0, 1.0]) {
      final c = Offset(cx + s * w * 0.155, h * 0.565);
      if (spiked) {
        for (final a in [-0.5, 0.0, 0.5]) {
          final dir = -math.pi / 2 + a + s * 0.25;
          final tip = c + Offset(math.cos(dir), math.sin(dir)) * w * 0.085;
          _triangle(canvas, tip, dir, w * 0.05, w * 0.022, body.trim);
        }
      }
      canvas.drawCircle(c, w * 0.062, Paint()..color = _lighten(body.main, 0.12));
      canvas.drawCircle(c, w * 0.062, _inkStroke..strokeWidth = 1.3);
    }
  }

  void _belt(Canvas canvas, double cx, double y, double w) {
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, y), width: w * 0.24, height: w * 0.05),
        Paint()..color = _darken(body.dark, 0.2));
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, y), width: w * 0.055, height: w * 0.055),
        Paint()..color = body.trim);
  }

  void _beltGem(Canvas canvas, double cx, double y, double w) {
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, y), width: w * 0.20, height: w * 0.045),
        Paint()..color = body.trim);
    _gemShape(canvas, Offset(cx, y), w * 0.030, body.gem);
  }

  /// A stubby capsule arm with a mitten hand. [wiggle] waggles the mitten.
  void _arm(Canvas canvas, Offset shoulder, double angle, double wiggle,
      Size size) {
    final w = size.width, h = size.height;
    final len = h * 0.125;
    final hand =
        shoulder + Offset(math.sin(angle), math.cos(angle)) * len;
    final sleeve = switch (body.outfit) {
      RoyalOutfit.robe => body.main,
      RoyalOutfit.armor => _darken(body.main, 0.12),
      RoyalOutfit.coat => body.main,
    };
    _capsule(canvas, shoulder, hand, w * 0.078, sleeve);
    final mitten = hand + Offset(math.sin(angle), math.cos(angle)) * (w * 0.02);
    canvas.save();
    canvas.translate(mitten.dx, mitten.dy);
    canvas.rotate(wiggle);
    canvas.drawCircle(Offset.zero, w * 0.047, Paint()..color = body.skin);
    canvas.drawCircle(Offset.zero, w * 0.047, _inkStroke..strokeWidth = 1.2);
    canvas.restore();
  }

  void _weapon(
      Canvas canvas, Size size, Offset hand, double armAngle, _Pose pose) {
    final w = size.width, h = size.height;
    // Weapon direction: along the arm when swung, upright when at rest.
    final rest = armAngle.abs() < 0.6;
    final dir = rest ? math.pi : armAngle; // pi = straight up from the hand
    Offset along(double d) =>
        hand + Offset(math.sin(dir), -math.cos(dir)) * -d;
    switch (royal.weapon) {
      case RoyalWeapon.staff:
        // Planted like a sceptre of office: butt on the ground, gem at crown
        // height, pulsing softly.
        final base = rest ? Offset(hand.dx, h * 0.945) : along(h * 0.16);
        final top = rest ? Offset(hand.dx, h * 0.30) : along(-h * 0.42);
        _shaft(canvas, base, top, w * 0.042, _gold, _darken(_gold, 0.3));
        final pulse = 0.8 + 0.2 * math.sin(t * 2 * math.pi * 1.5);
        canvas.drawCircle(
            top,
            w * 0.075 * pulse,
            Paint()
              ..color = body.gem.withValues(alpha: 0.30)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        _gemShape(canvas, top, w * 0.055, body.gem);
      case RoyalWeapon.lance:
        // Taller than its owner, steel tip, pennant snapping in the wind.
        final base = rest ? Offset(hand.dx, h * 0.945) : along(h * 0.18);
        final tip = rest ? Offset(hand.dx, h * 0.10) : along(-h * 0.52);
        _shaft(canvas, base, tip, w * 0.040,
            royal.palette['L'] ?? _gold, _darken(_gold, 0.3));
        final d = (tip - base).direction;
        _triangle(canvas, tip, d, w * 0.10, w * 0.040,
            royal.palette['S'] ?? const Color(0xFFD7DCE4));
        final flagBase = Offset.lerp(base, tip, 0.82)!;
        final flap = math.sin(t * 2 * math.pi * 2) * w * 0.02;
        final flag = Path()
          ..moveTo(flagBase.dx, flagBase.dy)
          ..lineTo(flagBase.dx - w * 0.115, flagBase.dy + h * 0.023 + flap)
          ..lineTo(flagBase.dx, flagBase.dy + h * 0.05)
          ..close();
        canvas.drawPath(flag, Paint()..color = royal.theme.accent);
        canvas.drawPath(flag, _inkStroke..strokeWidth = 1.0);
      case RoyalWeapon.warClub:
        // Carried over the shoulder — casual, heavy, mildly threatening.
        final overShoulder = rest;
        final from = overShoulder
            ? hand
            : hand;
        final to = overShoulder
            ? hand + Offset(-w * 0.10, -h * 0.30)
            : along(-h * 0.34);
        _shaft(canvas, from, to, w * 0.050, royal.palette['L'] ?? const Color(0xFF3E2A1A),
            const Color(0xFF241608));
        final headC = to + (to - from) * 0.12;
        canvas.drawCircle(headC, w * 0.088,
            Paint()..color = royal.palette['M'] ?? const Color(0xFF4E525C));
        canvas.drawCircle(headC, w * 0.088, _inkStroke..strokeWidth = 1.4);
        for (var i = 0; i < 3; i++) {
          final a = -math.pi / 2 + (i - 1) * 0.9;
          canvas.drawCircle(
              headC + Offset(math.cos(a), math.sin(a)) * w * 0.088,
              w * 0.016,
              Paint()..color = royal.palette['S'] ?? const Color(0xFF9AA3B2));
        }
      case RoyalWeapon.bow:
        // Held upright at her side — the arc bows outward, string inboard.
        final c = rest ? hand.translate(-w * 0.03, 0) : along(-h * 0.10);
        final br = h * 0.105;
        final axis = rest ? math.pi : dir;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: br),
          axis - math.pi * 0.42,
          math.pi * 0.84,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.028
            ..strokeCap = StrokeCap.round
            ..color = _gold,
        );
        final e1 = c + Offset(math.cos(axis - math.pi * 0.42), math.sin(axis - math.pi * 0.42)) * br;
        final e2 = c + Offset(math.cos(axis + math.pi * 0.42), math.sin(axis + math.pi * 0.42)) * br;
        canvas.drawLine(
            e1,
            e2,
            Paint()
              ..color = body.pale.withValues(alpha: 0.9)
              ..strokeWidth = 1.2);
      case RoyalWeapon.medKit:
        final kit = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: hand.translate(0, h * 0.012),
                width: w * 0.165,
                height: h * 0.10),
            Radius.circular(w * 0.03));
        canvas.drawRRect(kit, Paint()..color = const Color(0xFFF6F2EA));
        canvas.drawRRect(kit, _inkStroke..strokeWidth = 1.2);
        _plus(canvas, hand.translate(0, h * 0.012), w * 0.036,
            royal.palette['E'] ?? const Color(0xFF2BB985));
      case RoyalWeapon.orbs:
        break; // painted by _orbs
    }
  }

  /// The Empress's three arcane orbs, orbiting the body on a tilted ellipse.
  /// Split into a back and front pass so they truly circle her.
  void _orbs(Canvas canvas, Size size, {required bool front}) {
    final w = size.width, h = size.height;
    final c = Offset(w * 0.5, h * 0.66);
    for (var i = 0; i < 3; i++) {
      final a = t * 2 * math.pi * 0.8 + i * (2 * math.pi / 3);
      final inFront = math.sin(a) > 0;
      if (inFront != front) continue;
      final p = c + Offset(math.cos(a) * w * 0.30, math.sin(a) * h * 0.055 - h * 0.02);
      final r = w * (0.032 + 0.010 * math.sin(a));
      canvas.drawCircle(
          p,
          r * 2.1,
          Paint()
            ..color = royal.theme.accent.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(p, r, Paint()..color = royal.theme.accent);
      canvas.drawCircle(p.translate(-r * 0.3, -r * 0.3), r * 0.4,
          Paint()..color = Colors.white.withValues(alpha: 0.8));
    }
  }

  void _cape(Canvas canvas, Size size, _Pose pose) {
    final capeColor = switch (royal.id) {
      'prince' => _darken(body.main, 0.35),
      'darkprince' => const Color(0xFF17181E),
      'sovereign' => body.dark,
      _ => null,
    };
    if (capeColor == null) return;
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final flutter = math.sin(t * 2 * math.pi * 1.5) * w * 0.02 +
        pose.stride * w * 0.06;
    final hemY = h * (royal.id == 'sovereign' ? 0.88 : 0.83);
    final path = Path()
      ..moveTo(cx - w * 0.13, h * 0.555)
      ..lineTo(cx + w * 0.10, h * 0.555)
      ..lineTo(cx - w * 0.02 - flutter, hemY);
    if (royal.id == 'darkprince') {
      // Tattered hem: three ragged points.
      path
        ..lineTo(cx - w * 0.09 - flutter, hemY - h * 0.03)
        ..lineTo(cx - w * 0.15 - flutter, hemY + h * 0.01)
        ..lineTo(cx - w * 0.21 - flutter, hemY - h * 0.035);
    } else {
      path.lineTo(cx - w * 0.24 - flutter, hemY);
    }
    path.close();
    _fillInked(canvas, path, capeColor);
  }

  void _head(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final box = w * 0.66;
    final origin = Offset((w - box) / 2, h * 0.03);
    final rows = List<String>.from(royal.rows);
    if (pose.blink) {
      rows[royal.eyeRowWhites] = royal.eyesClosed[0];
      rows[royal.eyeRowIris] = royal.eyesClosed[1];
    } else if (pose.gaze != 0) {
      final g = pose.gaze > 0 ? royal.eyesRight : royal.eyesLeft;
      rows[royal.eyeRowWhites] = g[0];
      rows[royal.eyeRowIris] = g[1];
    }
    canvas.save();
    final pivot = Offset(w * 0.5, h * 0.50);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(pose.headTilt);
    canvas.translate(-pivot.dx, -pivot.dy);
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

  /// Effects drawn unsquashed above the figure: impact sparks, cheer
  /// stars/hearts, fume anger-mark + steam.
  void _actionAccents(Canvas canvas, Size size, _Pose pose) {
    if (pose.flourish <= 0) return;
    final w = size.width, h = size.height;
    final accent = royal.theme.accent;
    switch (action) {
      case RoyalAction.smash:
        // Radial impact sparks at the strike point.
        final at = Offset(w * 0.22, h * 0.93);
        final sp = Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: pose.flourish);
        for (var i = 0; i < 5; i++) {
          final a = math.pi + i * 0.42 - 0.4;
          final r0 = w * 0.05 + w * 0.09 * (1 - pose.flourish);
          final r1 = r0 + w * 0.085 * pose.flourish;
          canvas.drawLine(at + Offset(math.cos(a), math.sin(a)) * r0,
              at + Offset(math.cos(a), math.sin(a)) * r1, sp);
        }
      case RoyalAction.fume:
        // The classic anger cross-vein, pulsing beside the crown, plus two
        // little steam puffs rising off the royal head.
        final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi * 5);
        final markC = Offset(w * 0.80, h * 0.10);
        final mark = Paint()
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFFF4632)
              .withValues(alpha: 0.95 * pose.flourish);
        final r = w * 0.052 * pulse;
        for (final q in const [
          (0.35, 0.35),
          (-0.35, 0.35),
          (0.35, -0.35),
          (-0.35, -0.35),
        ]) {
          final dir = Offset(q.$1, q.$2);
          canvas.drawArc(
            Rect.fromCircle(center: markC + dir * r * 2.1, radius: r),
            dir.direction + math.pi * 0.75,
            math.pi * 0.5,
            false,
            mark,
          );
        }
        for (var i = 0; i < 2; i++) {
          final p = (t * 1.6 + i * 0.5) % 1.0;
          final puff = Offset(w * (0.24 - i * 0.06), h * (0.10 - p * 0.075));
          canvas.drawCircle(
              puff,
              w * (0.020 + 0.014 * p),
              Paint()
                ..color = Colors.white
                    .withValues(alpha: 0.38 * (1 - p) * pose.flourish));
        }
      default:
        // Cheer: stars and hearts popping around the head.
        for (var i = 0; i < 4; i++) {
          final a = i * 1.6 + t * 2 * math.pi;
          final p = Offset(w * 0.5, h * 0.28) +
              Offset(math.cos(a) * w * 0.36, math.sin(a) * h * 0.10 - h * 0.06);
          if (i.isOdd) {
            _heart(canvas, p, w * 0.026 * pose.flourish,
                accent.withValues(alpha: 0.9 * pose.flourish));
          } else {
            _star(canvas, p, w * 0.030 * pose.flourish,
                accent.withValues(alpha: 0.85 * pose.flourish));
          }
        }
    }
  }

  // ── Ride ─────────────────────────────────────────────────────────────────

  /// A royal on its royal ride, moving toward +x. Designed for a WIDE box
  /// (the host uses ~3:2) but degrades gracefully to portrait: horizontal
  /// spans use `min(width, height × 1.7)` so nothing stretches.
  void _paintRide(Canvas canvas, Size size) {
    switch (_mountOf(royal.id)) {
      case _Mount.palanquin:
        _ridePalanquin(canvas, size);
      case _Mount.cart:
        _rideCart(canvas, size);
      case _Mount.horse:
        _rideBeast(canvas, size,
            coat: const Color(0xFFF4EFE6),
            coatDark: const Color(0xFFD8D2C4),
            mane: _gold,
            style: _BeastStyle.horse);
      case _Mount.darkhorse:
        _rideBeast(canvas, size,
            coat: const Color(0xFF3A3F4C), // a shade above the onyx armour
            coatDark: const Color(0xFF20232C),
            mane: royal.theme.accent,
            style: _BeastStyle.horse,
            emberEye: true);
      case _Mount.unicorn:
        _rideBeast(canvas, size,
            coat: const Color(0xFFF6F1E8),
            coatDark: const Color(0xFFDCD2C4),
            mane: royal.theme.accent,
            style: _BeastStyle.unicorn);
      case _Mount.lion:
        _rideBeast(canvas, size,
            coat: const Color(0xFFD4A72C),
            coatDark: const Color(0xFF9C7A16),
            mane: const Color(0xFF6E4A2A),
            style: _BeastStyle.lion);
    }
  }

  /// The seated rider used on every mount: the standing figure minus legs,
  /// with a seat skirt (robes) or flank-hugging bent legs (armour/coat).
  void _figureSeated(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final shoulderY = h * 0.575;
    final farShoulder = Offset(cx - w * 0.14, shoulderY);
    final nearShoulder = Offset(cx + w * 0.14, shoulderY);

    _cape(canvas, size, pose);
    _arm(canvas, farShoulder, pose.armWeapon, 0, size);
    if (royal.weapon == RoyalWeapon.orbs) _orbs(canvas, size, front: false);

    // Seat: a shortened torso/skirt ending at the saddle line.
    if (body.outfit == RoyalOutfit.robe) {
      final skirt = Path()
        ..moveTo(cx - w * 0.125, h * 0.54)
        ..lineTo(cx + w * 0.125, h * 0.54)
        ..quadraticBezierTo(cx + w * 0.19, h * 0.72, cx + w * 0.175, h * 0.88)
        ..quadraticBezierTo(cx, h * 0.95, cx - w * 0.175, h * 0.88)
        ..quadraticBezierTo(cx - w * 0.19, h * 0.72, cx - w * 0.125, h * 0.54)
        ..close();
      _fillInked(canvas, skirt, body.main);
    } else {
      _torso(canvas, size, pose);
      // Bent little legs hugging the mount's flank.
      for (final s in [-1.0, 1.0]) {
        final hip = Offset(cx + s * w * 0.10, h * 0.76);
        final foot = hip + Offset(s * w * 0.05 + w * 0.03, h * 0.115);
        _capsule(canvas, hip, foot, w * 0.075, _darken(body.main, 0.28));
        canvas.drawCircle(foot, w * 0.045, Paint()..color = body.boot);
      }
    }
    _decorate(canvas, size, pose);
    _head(canvas, size, pose);
    _frontWeapon(canvas, size, farShoulder, pose);
    if (royal.weapon == RoyalWeapon.orbs) _orbs(canvas, size, front: true);
    _arm(canvas, nearShoulder, pose.armFree, 0, size);
  }

  _Pose _riderPose(double cyc) => _Pose(
        armFree: 0.95, // reins hand forward
        armWeapon: royal.weapon == RoyalWeapon.lance ||
                royal.weapon == RoyalWeapon.warClub
            ? -2.1 // charge!
            : -0.35,
        gaze: 1,
        blink: _blink(t),
        headTilt: 0.03 * math.sin(cyc),
      );

  /// Chibi quadruped, side view: a fat low body on four stubby galloping
  /// legs, a big round head on a short neck IN FRONT of the rider, so the
  /// rider reads as truly astride. Layering: tail → legs → body → caparison →
  /// rider → neck/head → reins.
  void _rideBeast(Canvas canvas, Size size,
      {required Color coat,
      required Color coatDark,
      required Color mane,
      required _BeastStyle style,
      bool emberEye = false}) {
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final cx = w * 0.5;
    final ground = h * 0.94;
    final cyc = t * 2 * math.pi;
    final lion = style == _BeastStyle.lion;

    final bob = -math.sin(cyc).abs() * h * 0.032;
    final pitch = math.sin(cyc + 0.7) * 0.045;

    _shadow(canvas, Offset(cx, ground), uw * 0.27, _Pose(bob: bob / h));

    canvas.save();
    canvas.translate(cx, ground);
    canvas.rotate(pitch);
    canvas.translate(-cx, -ground);
    canvas.translate(0, bob);

    final bodyC = Offset(cx - uw * 0.03, h * 0.605);
    final halfLen = uw * 0.150;
    final bodyR = h * 0.135;

    // Tail streams behind.
    if (lion) {
      final tip = Offset(bodyC.dx - halfLen - uw * 0.10,
          h * 0.48 + math.sin(cyc) * h * 0.02);
      _capsule(canvas, bodyC.translate(-halfLen, -h * 0.02), tip, h * 0.030,
          coatDark);
      canvas.drawCircle(tip, h * 0.042, Paint()..color = mane);
      canvas.drawCircle(tip, h * 0.042, _inkStroke..strokeWidth = 1.1);
    } else {
      final root = bodyC.translate(-halfLen + uw * 0.01, -h * 0.03);
      final tail = Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(
            root.dx - uw * 0.09,
            h * 0.50 + math.sin(cyc) * h * 0.035,
            root.dx - uw * 0.115,
            h * 0.70)
        ..quadraticBezierTo(root.dx - uw * 0.05, h * 0.66, root.dx, root.dy + h * 0.06)
        ..close();
      canvas.drawPath(tail, Paint()..color = mane);
      canvas.drawPath(tail, _inkStroke..strokeWidth = 1.1);
    }

    // Four stubby legs, rotary gallop.
    final hipXs = [-0.135, -0.075, 0.065, 0.125];
    final phases = [0.0, 0.15, 0.5, 0.65];
    final legLen = h * 0.235;
    for (var i = 0; i < 4; i++) {
      final s = math.sin(cyc + phases[i] * 2 * math.pi);
      final hip = Offset(cx + uw * hipXs[i] - uw * 0.03, h * 0.63);
      final tuck = math.max(0.0, -s) * 0.30; // folds on the back-swing
      final foot = hip +
          Offset(math.sin(s * 0.75) * legLen,
              math.cos(s * 0.75) * legLen * (1 - tuck));
      _capsule(canvas, hip, foot, h * 0.075, i < 2 ? coatDark : coat);
      canvas.drawCircle(
          foot, h * 0.042, Paint()..color = _darken(coatDark, 0.3));
    }

    // Fat capsule body.
    _capsule(canvas, bodyC.translate(-halfLen, 0), bodyC.translate(halfLen, 0),
        bodyR * 2, coat);
    // Belly shade.
    canvas.drawLine(
        bodyC.translate(-halfLen * 0.7, bodyR * 0.62),
        bodyC.translate(halfLen * 0.55, bodyR * 0.62),
        Paint()
          ..strokeWidth = bodyR * 0.55
          ..strokeCap = StrokeCap.round
          ..color = coatDark.withValues(alpha: 0.55));

    // Caparison (saddle blanket) in the royal's colour, gold-hemmed.
    final blanket = Path()
      ..moveTo(bodyC.dx - uw * 0.105, h * 0.505)
      ..lineTo(bodyC.dx + uw * 0.105, h * 0.505)
      ..lineTo(bodyC.dx + uw * 0.09, h * 0.70)
      ..quadraticBezierTo(bodyC.dx, h * 0.735, bodyC.dx - uw * 0.09, h * 0.70)
      ..close();
    _fillInked(canvas, blanket, body.main);
    canvas.drawLine(Offset(bodyC.dx - uw * 0.088, h * 0.685),
        Offset(bodyC.dx + uw * 0.088, h * 0.685),
        Paint()
          ..strokeWidth = h * 0.018
          ..color = _gold);

    // The rider, astride the caparison.
    final riderH = h * 0.66;
    final riderW = riderH * 0.78;
    canvas.save();
    canvas.translate(bodyC.dx - riderW / 2, h * 0.525 - riderH * 0.80);
    _figureSeated(canvas, Size(riderW, riderH), _riderPose(cyc));
    canvas.restore();

    // Neck + head, in front of the rider's leading leg.
    final neckRoot = Offset(cx + uw * 0.10, h * 0.56);
    final headC = Offset(cx + uw * 0.20,
        h * 0.385 + math.sin(cyc + 1.2) * h * 0.018);
    _capsule(canvas, neckRoot, headC, h * 0.115, coat);
    if (lion) {
      canvas.drawCircle(headC, h * 0.170, Paint()..color = mane);
      canvas.drawCircle(headC, h * 0.170, _inkStroke..strokeWidth = 1.3);
      // Round lion ears poking from the mane.
      for (final s in [-1.0, 1.0]) {
        final ear = headC + Offset(s * h * 0.105 - h * 0.01, -h * 0.14);
        canvas.drawCircle(ear, h * 0.040, Paint()..color = coatDark);
        canvas.drawCircle(ear, h * 0.040, _inkStroke..strokeWidth = 1.0);
      }
    } else {
      // Ears + (for the unicorn) a little gold horn.
      for (final s in [-1.0, 1.0]) {
        final ear = headC + Offset(s * h * 0.05 - h * 0.015, -h * 0.115);
        _triangle(canvas, ear, -math.pi / 2, h * 0.065, h * 0.028, coat);
      }
      if (style == _BeastStyle.unicorn) {
        _triangle(canvas, headC.translate(h * 0.015, -h * 0.21), -math.pi / 2,
            h * 0.115, h * 0.023, _gold);
      }
      // Mane: a run of soft scallops down the back of the neck.
      for (var i = 0; i < 4; i++) {
        final p = Offset.lerp(headC.translate(-h * 0.075, -h * 0.065),
            neckRoot.translate(-h * 0.045, -h * 0.02), i / 3)!;
        final r = h * (0.052 - i * 0.006) +
            math.sin(cyc + i) * h * 0.004; // breathes with the gallop
        canvas.drawCircle(p, r, Paint()..color = mane);
      }
      // Forelock tuft between the ears.
      canvas.drawCircle(headC.translate(-h * 0.01, -h * 0.10), h * 0.045,
          Paint()..color = mane);
    }
    final headPath = Path()
      ..addOval(Rect.fromCircle(center: headC, radius: h * 0.118));
    _fillInked(canvas, headPath, coat);
    // Muzzle.
    final muzzleC = headC.translate(h * 0.105, h * 0.032);
    final muzzleRect =
        Rect.fromCenter(center: muzzleC, width: h * 0.125, height: h * 0.088);
    canvas.drawOval(muzzleRect,
        Paint()..color = lion ? coatDark : Color.lerp(coat, coatDark, 0.35)!);
    canvas.drawOval(muzzleRect, _inkStroke..strokeWidth = 1.0);
    canvas.drawCircle(muzzleC.translate(h * 0.028, -h * 0.012), h * 0.012,
        Paint()..color = body.ink);
    // Eye — a big friendly dot (ember-lit for the dark prince's steed).
    final eyeP = headC.translate(h * 0.022, -h * 0.022);
    if (emberEye) {
      canvas.drawCircle(
          eyeP,
          h * 0.045,
          Paint()
            ..color = royal.theme.accent.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    canvas.drawCircle(eyeP, h * 0.021,
        Paint()..color = emberEye ? royal.theme.accent : body.ink);
    canvas.drawCircle(eyeP.translate(-h * 0.006, -h * 0.006), h * 0.007,
        Paint()..color = Colors.white.withValues(alpha: 0.9));

    // Rein, from the rider's rein hand to the muzzle.
    canvas.drawLine(
        Offset(bodyC.dx + riderW * 0.20, h * 0.46),
        muzzleC.translate(-h * 0.02, -h * 0.01),
        Paint()
          ..strokeWidth = 1.4
          ..color = _darken(body.main, 0.3));

    canvas.restore();

    _dust(canvas, size, cyc);
  }

  /// The Empress's ride: a floating gold palanquin drifting on a cushion of
  /// sparkles — no beast would presume to carry her.
  void _ridePalanquin(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final cx = w * 0.5;
    final cyc = t * 2 * math.pi;
    final hover = math.sin(cyc) * h * 0.025 - h * 0.05;

    _shadow(canvas, Offset(cx, h * 0.94), uw * 0.24, const _Pose(bob: -0.05));

    // Sparkle wake beneath the deck.
    for (var i = 0; i < 5; i++) {
      final p = (t * 1.5 + i * 0.2) % 1.0;
      final sp = Offset(cx + uw * (0.18 - p * 0.42),
          h * 0.80 + math.sin(p * 9 + i) * h * 0.03);
      _star(canvas, sp, h * 0.022 * (1 - p) + h * 0.006,
          royal.theme.accent.withValues(alpha: 0.55 * (1 - p)));
    }

    canvas.save();
    canvas.translate(0, hover);

    // Carry poles.
    canvas.drawLine(Offset(cx - uw * 0.40, h * 0.715),
        Offset(cx + uw * 0.40, h * 0.715),
        Paint()
          ..strokeWidth = h * 0.028
          ..strokeCap = StrokeCap.round
          ..color = _darken(_gold, 0.35));
    // Deck.
    final deck = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, h * 0.70), width: uw * 0.56, height: h * 0.070),
        Radius.circular(h * 0.03));
    canvas.drawRRect(deck, Paint()..color = _gold);
    canvas.drawRRect(deck, _inkStroke..strokeWidth = 1.3);
    // Cushion.
    final cushion = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, h * 0.645), width: uw * 0.28, height: h * 0.055),
        Radius.circular(h * 0.03));
    canvas.drawRRect(cushion, Paint()..color = body.dark);
    canvas.drawRRect(cushion, _inkStroke..strokeWidth = 1.1);
    // Canopy rail + swaying curtains at both ends, behind the rider. The rail
    // sits above the rider's crown so it never crosses her face.
    final railY = h * 0.065;
    canvas.drawLine(Offset(cx - uw * 0.26, railY), Offset(cx + uw * 0.26, railY),
        Paint()..strokeWidth = h * 0.022 ..color = _gold);
    for (final s in [-1.0, 1.0]) {
      final x = cx + s * uw * 0.245;
      final swing = math.sin(cyc + s) * uw * 0.012;
      final curtain = Path()
        ..moveTo(x - uw * 0.026, railY)
        ..lineTo(x + uw * 0.026, railY)
        ..quadraticBezierTo(x + uw * 0.030 + swing, h * 0.42,
            x + uw * 0.018 + swing * 2, h * 0.60)
        ..lineTo(x - uw * 0.038 + swing * 2, h * 0.60)
        ..quadraticBezierTo(x - uw * 0.038 + swing, h * 0.42, x - uw * 0.026, railY)
        ..close();
      canvas.drawPath(curtain, Paint()..color = body.main);
      canvas.drawPath(curtain, _inkStroke..strokeWidth = 1.1);
    }
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(
          Offset(cx + s * uw * 0.245, railY),
          Offset(cx + s * uw * 0.255, h * 0.70),
          Paint()
            ..strokeWidth = h * 0.014
            ..color = _darken(_gold, 0.3));
    }
    _gemShape(canvas, Offset(cx, railY - h * 0.030), h * 0.032, body.gem);

    // The Empress, seated serenely.
    final riderH = h * 0.60;
    final riderW = riderH * 0.78;
    canvas.save();
    canvas.translate(cx - riderW / 2, h * 0.645 - riderH * 0.95);
    _figureSeated(
        canvas,
        Size(riderW, riderH),
        _Pose(
          armFree: 0.35,
          armWeapon: -0.35,
          blink: _blink(t),
          headTilt: 0.04 * math.sin(cyc * 0.5),
        ));
    canvas.restore();

    canvas.restore();
  }

  /// The Medic's ride: a rolling emerald supply cart — half chariot, half
  /// hospital trolley — with spinning spoked wheels and a white cross plate.
  void _rideCart(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final cx = w * 0.5;
    final cyc = t * 2 * math.pi;
    final emerald = royal.palette['E'] ?? const Color(0xFF2BB985);
    final bump = math.sin(cyc * 2) * h * 0.008;

    _shadow(canvas, Offset(cx, h * 0.94), uw * 0.26, const _Pose());

    canvas.save();
    canvas.translate(0, bump);

    // Deck.
    final deckY = h * 0.745;
    final deck = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - uw * 0.02, deckY),
            width: uw * 0.44,
            height: h * 0.055),
        Radius.circular(h * 0.02));
    // Front rail the medic grips, chariot-style.
    final railTop = Offset(cx + uw * 0.195, h * 0.455);
    canvas.drawLine(
        Offset(cx + uw * 0.155, deckY),
        railTop,
        Paint()
          ..strokeWidth = h * 0.030
          ..strokeCap = StrokeCap.round
          ..color = _darken(emerald, 0.35));
    canvas.drawLine(
        railTop.translate(-uw * 0.035, 0),
        railTop.translate(uw * 0.012, 0),
        Paint()
          ..strokeWidth = h * 0.026
          ..strokeCap = StrokeCap.round
          ..color = _darken(emerald, 0.35));
    canvas.drawRRect(deck, Paint()..color = emerald);
    canvas.drawRRect(deck, _inkStroke..strokeWidth = 1.3);
    // Cross plate on the side.
    final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - uw * 0.02, deckY + h * 0.055),
            width: uw * 0.16,
            height: h * 0.075),
        Radius.circular(h * 0.02));
    canvas.drawRRect(plate, Paint()..color = const Color(0xFFF6F2EA));
    canvas.drawRRect(plate, _inkStroke..strokeWidth = 1.1);
    _plus(canvas, Offset(cx - uw * 0.02, deckY + h * 0.055), h * 0.026, emerald);

    // The Medic stands on the deck, leaning into the ride.
    final figH = h * 0.70;
    final figW = figH * 0.78;
    canvas.save();
    canvas.translate(cx - uw * 0.04 - figW / 2, deckY - figH * 0.955 + h * 0.01);
    _figure(
        canvas,
        Size(figW, figH),
        _Pose(
          lean: 0.10,
          armFree: 1.30, // gripping the front rail
          armWeapon: -0.30,
          gaze: 1,
          blink: _blink(t),
          bob: math.sin(cyc * 2) * 0.004,
        ));
    canvas.restore();

    // Wheels (in front of the figure's feet).
    for (final s in [-1.0, 1.0]) {
      final c = Offset(cx - uw * 0.02 + s * uw * 0.13, h * 0.855);
      canvas.drawCircle(c, h * 0.098, Paint()..color = const Color(0xFF3A3F4A));
      canvas.drawCircle(c, h * 0.098, _inkStroke..strokeWidth = 1.3);
      final spoke = Paint()
        ..strokeWidth = 1.6
        ..color = const Color(0xFF9AA3B2);
      for (var i = 0; i < 3; i++) {
        final a = cyc * 2.4 + i * math.pi / 3;
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * h * 0.078,
            c - Offset(math.cos(a), math.sin(a)) * h * 0.078, spoke);
      }
      canvas.drawCircle(c, h * 0.022, Paint()..color = _gold);
    }

    canvas.restore();

    _dust(canvas, size, cyc);
  }

  void _dust(Canvas canvas, Size size, double cyc) {
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 3; i++) {
      final p = ((t * 2 + i * 0.33) % 1.0);
      final x = w * 0.16 - p * w * 0.14;
      final y = h * 0.92 - p * h * 0.05;
      canvas.drawCircle(
          Offset(x, y),
          w * 0.028 * (1 - p) + w * 0.006,
          Paint()
            ..color = body.ink.withValues(alpha: 0.10 * (1 - p)));
    }
  }

  // ── Poses ────────────────────────────────────────────────────────────────

  _Pose _poseFor(RoyalAction a, double t) {
    final blink = _blink(t);
    final m = _motion;
    switch (a) {
      case RoyalAction.idle:
        final s = math.sin(t * 2 * math.pi * m.bobHz);
        return _Pose(
          bob: s * m.bobAmp,
          sway: s * m.sway,
          squash: 1 + s * 0.008,
          armFree: 0.20 + s * 0.05,
          armWeapon: -0.20 - s * 0.04,
          blink: blink,
          headTilt: s * m.sway * 0.8,
        );
      case RoyalAction.walk:
      case RoyalAction.run:
        final run = a == RoyalAction.run;
        final s = math.sin(t * 2 * math.pi);
        final stride = (run ? 1.0 : 0.62) * m.bounce.clamp(0.8, 1.2);
        final glide = body.outfit == RoyalOutfit.robe;
        return _Pose(
          bob: glide
              ? s * 0.008 * m.bounce
              : -s.abs() * (run ? 0.022 : 0.010) * m.bounce,
          lean: run ? 0.10 : 0.035,
          sway: glide ? s * (run ? 0.09 : 0.05) : s * 0.02,
          legPhase: s,
          stride: stride,
          squash: 1 - s.abs() * (run ? 0.025 : 0.012),
          armFree: -s * stride * 0.55 + 0.1,
          armWeapon: -0.25 + s * stride * 0.25,
          blink: blink,
          gaze: 1,
        );
      case RoyalAction.wave:
        final s = math.sin(t * 2 * math.pi * 3);
        final b = math.sin(t * 2 * math.pi);
        return _Pose(
          bob: b * 0.006,
          sway: b * 0.02,
          armFree: 2.45 + s * 0.18, // near arm raised up-and-OUT, face clear
          wiggle: s * 0.45,
          armWeapon: -0.20,
          blink: blink,
          headTilt: 0.05 + b * 0.02,
        );
      case RoyalAction.smash:
        // Wind up (stretch tall, weapon behind-overhead) → slam down-forward
        // (deep squash) → settle back to rest.
        final wind = Curves.easeOut.transform((t / 0.42).clamp(0.0, 1.0));
        final slam =
            Curves.easeIn.transform(((t - 0.42) / 0.18).clamp(0.0, 1.0));
        final settle =
            Curves.easeOut.transform(((t - 0.60) / 0.40).clamp(0.0, 1.0));
        final arm = -0.25 - 2.55 * wind + 3.9 * slam - 1.1 * settle;
        final impact = slam * (1 - settle);
        return _Pose(
          lean: -0.10 * wind + 0.30 * slam - 0.20 * settle,
          squash: 1 + 0.07 * wind - 0.19 * slam + 0.12 * settle,
          bob: 0,
          armWeapon: arm,
          armFree: 0.3 * wind - 0.5 * slam + 0.2 * settle + 0.2,
          legPhase: slam * 0.6 - settle * 0.6,
          stride: slam * 0.8,
          blink: false,
          flourish: impact,
        );
      case RoyalAction.cheer:
        final hop = math.sin(t * 2 * math.pi * 2).abs();
        final land = hop < 0.25;
        return _Pose(
          bob: -hop * 0.05 * _motion.bounce,
          squash: land ? 0.94 : 1.03,
          armFree: 2.55 - hop * 0.2, // both arms up-and-out in a V
          armWeapon: -2.55 - hop * 0.2,
          wiggle: math.sin(t * 2 * math.pi * 4) * 0.3,
          blink: hop > 0.85, // happy squint at the top of the hop
          flourish: 0.5 + hop * 0.5,
          headTilt: math.sin(t * 2 * math.pi) * 0.04,
        );
      case RoyalAction.fume:
        // Post-smash scolding: leaning right into the user, stomping in
        // place, fists pumping, head shaking a firm royal "no".
        final stomp = math.sin(t * 2 * math.pi * 2);
        final shake = math.sin(t * 2 * math.pi * 5);
        return _Pose(
          bob: -stomp.abs() * 0.012,
          lean: 0.10,
          squash: 1 - stomp.abs() * 0.02,
          legPhase: stomp * 0.5,
          stride: 0.8,
          armFree: 0.55 + stomp * 0.07, // fists down-out, pumping
          armWeapon: -0.55 - stomp * 0.07,
          wiggle: shake * 0.2,
          blink: false, // glaring
          headTilt: shake * 0.055,
          flourish: 1,
        );
      case RoyalAction.ride:
        return const _Pose(); // ride has its own pipeline
    }
  }

  bool _blink(double t) {
    final p = t % 1.0;
    return (p > 0.14 && p < 0.17) || (p > 0.62 && p < 0.65);
  }

  // ── Primitives ───────────────────────────────────────────────────────────

  void _capsule(Canvas canvas, Offset a, Offset b, double width, Color color) {
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = body.ink.withValues(alpha: 0.85)
          ..strokeWidth = width + 2.4
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round);
  }

  void _shaft(Canvas canvas, Offset a, Offset b, double w, Color main, Color edge) {
    canvas.drawLine(a, b,
        Paint()..color = edge ..strokeWidth = w + 2.2 ..strokeCap = StrokeCap.round);
    canvas.drawLine(a, b,
        Paint()..color = main ..strokeWidth = w ..strokeCap = StrokeCap.round);
  }

  void _triangle(
      Canvas canvas, Offset tip, double dir, double len, double halfW, Color color) {
    final back = tip - Offset(math.cos(dir), math.sin(dir)) * len;
    final perp = Offset(-math.sin(dir), math.cos(dir)) * halfW;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + perp.dx, back.dy + perp.dy)
      ..lineTo(back.dx - perp.dx, back.dy - perp.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, _inkStroke..strokeWidth = 1.0);
  }

  void _plus(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    final th = r * 0.62;
    canvas.drawRect(Rect.fromCenter(center: c, width: th, height: r * 2), p);
    canvas.drawRect(Rect.fromCenter(center: c, width: r * 2, height: th), p);
  }

  void _gemShape(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.8, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.8, c.dy)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
    canvas.drawPath(p, _inkStroke..strokeWidth = 1.0);
    canvas.drawCircle(c.translate(-r * 0.2, -r * 0.25), r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy + r)
      ..cubicTo(c.dx + r * 1.5, c.dy + r * 0.1, c.dx + r * 0.9,
          c.dy - r * 1.2, c.dx, c.dy - r * 0.35)
      ..cubicTo(c.dx - r * 0.9, c.dy - r * 1.2, c.dx - r * 1.5,
          c.dy + r * 0.1, c.dx, c.dy + r)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rad = i.isEven ? r : r * 0.38;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rad;
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(RoyalCharacterPainter old) =>
      old.t != t ||
      old.action != action ||
      old.facing != facing ||
      old.royal != royal;
}

/// The royal ride each character mounts for [RoyalAction.ride].
enum _Mount { horse, darkhorse, unicorn, lion, palanquin, cart }

/// Beast flavour for the shared quadruped painter.
enum _BeastStyle { horse, unicorn, lion }

_Mount _mountOf(String id) => switch (id) {
      'prince' => _Mount.horse,
      'darkprince' => _Mount.darkhorse,
      'princess' => _Mount.unicorn,
      'sovereign' => _Mount.lion,
      'empress' => _Mount.palanquin,
      _ => _Mount.cart,
    };

/// A convenience widget that loops [action] for a royal — handy for previews
/// and tests. The reaction host drives the painter directly for tight
/// choreography.
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
    this.size = const Size(92, 118),
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
