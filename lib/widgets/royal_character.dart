import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'royal_avatars.dart';

/// Full-body chibi renders of the ROYALTY avatars — the "cute menacing" court.
///
/// Every royal is a bobblehead: the ready-made 16×16 pixel HEAD (from
/// [RoyalAvatar]) rides a squat, rounded body barely one head tall, inked with
/// the same outline + palette as the sprite so head and body read as one piece.
/// Menace comes from the regalia — planted staffs, shoulder-carried clubs,
/// battle helms and barded steeds — cuteness from the proportions, the mitten
/// hands and the squash-and-stretch in every move.
///
/// One parametric rig animates the whole court, but each royal keeps a
/// personality: motion timing ([_Motion]), outfit silhouette + detailing
/// ([RoyalOutfit] + per-id decoration), a signature weapon idle, its own royal
/// ride for [RoyalAction.ride] (the Prince's horse, the Dark Prince's barded
/// war horse, the Empress's floating palanquin, the Sovereign's lion, the
/// Princess's pegasus, the Medic's rolling supply cart), and a signature move
/// it signs off with ([RoyalAction.spell]/[RoyalAction.kiss]/
/// [RoyalAction.menace]/[RoyalAction.roar]). Cosmetic only; never core logic.

/// What the character is doing this frame. Besides the shared verbs, each
/// weapon has its own attack: [slash] (sword of state), [slice] (the knight's
/// lunging cut), [shoot] (bow), [hurl] (orbs) — [smash] stays the blunt
/// overhead slam (war club, med kit). Use [royalAttackActionFor] to pick the
/// right one.
///
/// The last five are SIGNATURE moves — one per royal, played at the end of the
/// launch entrance so each court member says hello in a way only they could
/// (see `_signatureActionFor` in royal_reactions.dart).
enum RoyalAction {
  idle,
  walk,
  run,
  wave,
  smash,
  slash,
  slice,
  shoot,
  hurl,
  cheer,
  fume,
  ride,

  /// The Empress conjures: a rune circle blooms, her orbs spiral up and burst,
  /// and she bows to the user through the falling light.
  spell,

  /// The Princess blows a kiss, hearts drifting out of the screen.
  kiss,

  /// The Dark Prince's parting threat: club planted, ember core flaring, head
  /// low under the helm.
  menace,

  /// The Sovereign's lion turns and roars at the viewer. A ride-time action —
  /// it goes through the mount pipeline, not the standing one.
  roar,

  /// The Royal Medic takes your vitals: the kit comes up open, a heartbeat
  /// traces itself across the air, and she signs off that you'll live.
  mend,

  /// The Prince's sword salute: blade up to the vertical, light running up the
  /// steel, then swept out and down into a bow.
  salute,

  /// The Sentinel plants the shield and BRACES — no flourish, no acknowledgement
  /// of the viewer. The one royal whose signature is refusing to perform.
  brace,

  /// The Huntress vaults: a run-up, a somersault through the air, and a
  /// crouched landing with both blades out. She is the only royal who leaves
  /// the ground under her own power.
  vault,

  /// The Sentinel's spear thrust: levelled over the shield rim, driven out
  /// from behind it, recovered to the guard. The one royal who fights from
  /// COVER rather than out in the open.
  thrust,

  // ── Huntress signature candidates (drafts) ────────────────────────────────

  /// Draft A. Feet planted, all wrists: both daggers spin in her fingers, she
  /// crosses them, reverses one into an ice-pick grip and settles to guard.
  bladeDance,

  /// Draft B. A leaping spin-kick: gather, launch, the lead boot snaps out
  /// horizontal at the apex, blades trailing, landing in a low crouch.
  flyKick,

  /// Draft C. She flips a dagger high and spinning, sweeps a low spin-kick
  /// underneath it, catches it reversed behind her back and levels it at you.
  daggerToss,
}

/// The attack verb a royal's weapon speaks: the Sovereign slashes, the Prince
/// lunges, the Princess shoots, the Empress hurls, the Dark Prince and the
/// Medic smash. Keeps host choreography and painter poses in agreement.
RoyalAction royalAttackActionFor(RoyalWeapon weapon) => switch (weapon) {
      RoyalWeapon.sword => RoyalAction.slash,
      RoyalWeapon.knightSword => RoyalAction.slice,
      RoyalWeapon.bow => RoyalAction.shoot,
      RoyalWeapon.orbs => RoyalAction.hurl,
      RoyalWeapon.warClub || RoyalWeapon.medKit => RoyalAction.smash,
      // The one royal who strikes from behind cover: the shield never leaves
      // the line, and the spear goes out over the top of it.
      RoyalWeapon.spear => RoyalAction.thrust,
      // She does not stand and swing — she closes the distance with her feet
      // and the blades arrive with her. Borrowing the Sovereign's slash made
      // the court's only acrobat fight like a man holding a sword of state.
      RoyalWeapon.daggers => RoyalAction.flyKick,
    };

/// [bodysuit] is the Huntress's: fitted, tapered to the waist and cut off at
/// the hip so the legs carry the movement. She was on [coat] first and it read
/// as a long robe — a garment you could not somersault in.
enum RoyalOutfit { robe, armor, coat, bodysuit }

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
      'prince' || 'darkprince' || 'sentinel' => RoyalOutfit.armor,
      // The Huntress takes the COAT rather than the robe: the robe is an
      // A-line gown, and an outlaw who somersaults across the screen cannot
      // be wearing one. Armour would over-dress her the other way.
      'huntress' => RoyalOutfit.bodysuit,
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
      // A man standing a post: the slowest breath in the court, almost no rock
      // at all, and heavy through a stride. He is the only one whose idle is
      // supposed to look like nothing is happening.
      'sentinel' => const _Motion(bobHz: 0.5, bobAmp: 0.005, sway: 0.008, bounce: 0.9),
      // Coiled and quick — a fast shallow breath, a low ready lean, and the
      // springiest stride here. Both of these were on the fallback _Motion(),
      // which is why the newest two royals moved like nobody in particular.
      'huntress' => const _Motion(
          bobHz: 1.6, bobAmp: 0.009, sway: 0.045, hunch: 0.04, bounce: 1.35),
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

  /// One leg thrown forward on its own, past anything the symmetric walk cycle
  /// can express. Radians; the NEAR leg only, so the far leg stays planted and
  /// the kick reads as weight on one foot rather than a jump.
  final double kick;

  /// Knees drawn up toward the chest, 0..1. A somersault needs the legs SHORT —
  /// a tumbling figure with its legs out is a falling plank, and the tuck is
  /// the whole difference between the two.
  final double tuck;

  /// Extra blade rotation about the hand, on top of the arm angle. Only the
  /// Huntress uses it: it is what lets a dagger spin in her fingers while the
  /// wrist itself barely moves.
  final double bladeSpin;

  /// How far the off-hand blade swings clear of the body, 0 (tucked behind the
  /// hip, the rest pose) to 1 (fully presented). At rest the paired daggers
  /// overlap into one shape; opening the second one is what makes her read as
  /// dual-wielding rather than carrying a single small sword.
  final double bladeOpen;

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
    this.kick = 0,
    this.tuck = 0,
    this.bladeSpin = 0,
    this.bladeOpen = 0,
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

  /// Whether this frame is drawn from the saddle. Weapons need it: the same
  /// arm angle means a very different reach once there is a horse's head in
  /// front of the hand.
  bool get _mounted =>
      action == RoyalAction.ride || action == RoyalAction.roar;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (facing < 0) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (action == RoyalAction.ride || action == RoyalAction.roar) {
      _paintRide(canvas, size);
    } else {
      _paintStanding(canvas, size, _poseFor(action, t));
    }
    canvas.restore();
  }

  // ── Standing figure ──────────────────────────────────────────────────────

  /// [as] overrides which action's accents are drawn. The painter's own
  /// [action] is what a frame is FOR, which is not always what the body is
  /// doing this instant: the Huntress's traversal is `ride`, but the figure
  /// inside it is running and then somersaulting, and without this the
  /// somersault came decorated with the generic cheer's stars and hearts.
  void _paintStanding(Canvas canvas, Size size, _Pose pose, {RoyalAction? as}) {
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

    _actionAccents(canvas, size, pose, as ?? action);
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
      case RoyalOutfit.bodysuit:
        _legs(canvas, size, pose);
        _torso(canvas, size, pose);
    }
    _decorate(canvas, size, pose);
    _head(canvas, size, pose);
    _headArmor(canvas, size, pose);
    if (royal.weapon == RoyalWeapon.spear) {
      // The Sentinel alone puts his shield UNDER the weapon: a spear levelled
      // over the rim is the whole idea of him, and in the shared order the
      // shield (drawn last, nearest) swallowed the shaft at exactly the frame
      // the thrust lands.
      _arm(canvas, nearShoulder, pose.armFree, pose.wiggle, size);
      _shield(canvas, size, nearShoulder, pose.armFree);
      _frontWeapon(canvas, size, farShoulder, pose);
      return;
    }
    _frontWeapon(canvas, size, farShoulder, pose);
    if (royal.weapon == RoyalWeapon.orbs) _orbs(canvas, size, front: true);
    _arm(canvas, nearShoulder, pose.armFree, pose.wiggle, size);
    _shield(canvas, size, nearShoulder, pose.armFree);
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
    final suit = body.outfit == RoyalOutfit.bodysuit;
    // The suit sits higher and runs longer: legs are most of her silhouette,
    // which is what sells "mobile" at this scale.
    final hipY = suit ? h * 0.735 : h * 0.76;
    final legLen = suit ? h * 0.180 : h * 0.145;
    final legColor = switch (body.outfit) {
      RoyalOutfit.coat => _darken(body.dark, 0.25),
      // One continuous suit rather than a torso over trousers.
      RoyalOutfit.bodysuit => _darken(body.main, 0.10),
      _ => _darken(body.main, 0.28),
    };
    for (final s in [-1.0, 1.0]) {
      // The near leg (s > 0) is the one that kicks; the far leg stays under
      // her so the weight reads as planted rather than both feet leaving.
      final kicking = s > 0 ? pose.kick : pose.kick * -0.18;
      // A tuck folds BOTH knees up in front together. The walk cycle swings
      // them in opposite directions, which is a stride however short you make
      // it — a tumbling figure with one leg forward and one back is falling
      // downstairs, not somersaulting.
      final walk = pose.legPhase * s * 0.9 * pose.stride;
      final swing = walk * (1 - pose.tuck) + 1.30 * pose.tuck + kicking;
      // ...and shortens the limb: knees to the chest. Held at full length the
      // spinning silhouette is a plank.
      final len = legLen * (1 - 0.62 * pose.tuck);
      final hip = Offset(cx + s * w * (suit ? 0.058 : 0.072),
          hipY - h * 0.055 * pose.tuck);
      final foot = hip +
          Offset(math.sin(swing) * len,
              math.cos(swing) * len - (s * pose.legPhase).clamp(0, 1) * h * 0.02);
      if (suit) {
        // Shorts, so the leg is bare from hip to knee and the boot runs the
        // whole calf. Two tones down one limb is what stops a bodysuit
        // reading as tights.
        //
        // Split at 0.62 rather than 0.52: at the halfway mark the thigh was a
        // token sliver between the belt and a boot that swallowed the rest of
        // the leg, and the whole lower half of her read as one dark block.
        final knee = Offset.lerp(hip, foot, 0.62)!;
        _capsule(canvas, hip, knee, w * 0.070, body.skin);
        _capsule(canvas, knee, foot, w * 0.078, body.boot);
        // A buckled thigh strap on the near leg with a spare blade sheathed in
        // it — the detail that makes bare leg read as WORKING gear rather than
        // as a missing trouser.
        if (s > 0) {
          final strapAt = Offset.lerp(hip, knee, 0.52)!;
          final along = (knee - hip) / (knee - hip).distance;
          final across = Offset(-along.dy, along.dx);
          canvas.drawLine(strapAt - across * (w * 0.044),
              strapAt + across * (w * 0.044),
              Paint()
                ..strokeWidth = h * 0.016
                ..strokeCap = StrokeCap.round
                ..color = _darken(body.dark, 0.20));
          canvas.drawLine(strapAt - across * (w * 0.044),
              strapAt + across * (w * 0.044),
              Paint()
                ..strokeWidth = h * 0.005
                ..strokeCap = StrokeCap.round
                ..color = body.trim.withValues(alpha: 0.8));
          final sheath = strapAt + across * (w * 0.030) + along * (h * 0.012);
          _shaft(canvas, sheath, sheath + along * (h * 0.042), w * 0.020,
              _darken(body.dark, 0.30), body.ink);
        }
        // Turned-down cuff: a slim band, NOT an accent disc. At w*0.048 in the
        // court colour these read as green knee-pads and took over the figure
        // — the same "accent as a big shape" failure the portrait hit.
        final cuff = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: knee, width: w * 0.088, height: h * 0.016),
            Radius.circular(w * 0.012));
        canvas.drawRRect(cuff, Paint()..color = _darken(body.boot, 0.28));
        canvas.drawRRect(cuff, _inkStroke..strokeWidth = 1.0);
        canvas.drawLine(
            knee.translate(-w * 0.040, -h * 0.008),
            knee.translate(w * 0.040, -h * 0.008),
            Paint()
              ..color = body.trim.withValues(alpha: 0.85)
              ..strokeWidth = 1.4);
      } else {
        _capsule(canvas, hip, foot, w * 0.085, legColor);
      }
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
    final suit = body.outfit == RoyalOutfit.bodysuit;
    // The coat FLARES (halfBot > halfTop) — that flare is the robe silhouette.
    // The bodysuit does the opposite: narrower shoulders, a waist that pulls
    // in, and a hem at the hip instead of past the knee.
    final top = h * 0.535,
        bottom = coat
            ? h * 0.82
            : suit
                ? h * 0.745
                : h * 0.79;
    final halfTop = w * (suit ? 0.132 : 0.150),
        halfBot = coat
            ? w * 0.165
            : suit
                ? w * 0.098
                : w * 0.118;
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

    if (body.outfit == RoyalOutfit.armor) {
      // Plate is SEGMENTED. Undetailed it reads as a smooth bathtub, which is
      // what the first pass looked like: two lame seams across the chest, a
      // three-band fauld at the hem, and a centre ridge catching the light.
      final span = bottom - top;
      for (final fy in [0.30, 0.50]) {
        final y = top + span * fy;
        canvas.drawLine(Offset(cx - halfTop, y), Offset(cx + halfTop, y),
            Paint()
              ..color = body.ink.withValues(alpha: 0.38)
              ..strokeWidth = 1.6);
        canvas.drawLine(
            Offset(cx - halfTop, y + 1.7), Offset(cx + halfTop, y + 1.7),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.20)
              ..strokeWidth = 1.3);
      }
      for (var i = 0; i < 3; i++) {
        final y = top + span * (0.64 + i * 0.12);
        final band = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, y),
                width: halfTop * 2 * (1 - i * 0.06),
                height: span * 0.11),
            Radius.circular(w * 0.02));
        canvas.drawRRect(band, Paint()..color = _darken(body.main, 0.10));
        canvas.drawRRect(band, _inkStroke..strokeWidth = 1.2);
      }
      canvas.drawLine(
          Offset(cx, top + span * 0.06), Offset(cx, top + span * 0.58),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.22)
            ..strokeWidth = w * 0.012);
      // Rivets down the outer edge.
      for (var i = 0; i < 3; i++) {
        final y = top + span * (0.16 + i * 0.18);
        for (final sx in [-1.0, 1.0]) {
          canvas.drawCircle(Offset(cx + sx * halfTop * 0.84, y), w * 0.011,
              Paint()..color = body.trim.withValues(alpha: 0.75));
        }
      }
    }

    if (suit) {
      final span = bottom - top;
      // The whole torso starts as SKIN, and the clothes are then laid on top of
      // it. The first pass did the reverse — a bare rectangle at the top, then
      // a tank hem painted from 20% down over the whole rest of it — so every
      // pixel of the "bare" shoulders was immediately covered again and all
      // that survived was a sliver of midriff. Painting the body first and
      // dressing it after means the exposed areas are the ones left alone.
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(cx - halfTop * 1.06, top - h * 0.006,
                  cx + halfTop * 1.06, bottom),
              Radius.circular(w * 0.05)),
          Paint()..color = body.skin);

      // Cropped top: it ends well above the waist, so the midriff between it
      // and the belt stays bare.
      final cropTop = top + span * 0.16;
      final cropBot = top + span * 0.56;
      final crop = Path()
        ..moveTo(cx - halfTop * 1.03, cropTop)
        // Scooped neckline between the straps.
        ..quadraticBezierTo(
            cx, cropTop + span * 0.20, cx + halfTop * 1.03, cropTop)
        ..lineTo(cx + halfTop * 1.00, cropBot)
        // A shallow V at the hem, following the ribs.
        ..quadraticBezierTo(cx, cropBot + span * 0.07, cx - halfTop * 1.00,
            cropBot)
        ..close();
      _fillInked(canvas, crop, body.main);
      // Shoulder straps, thin — they hold the top up and leave the shoulders.
      for (final sx in [-1.0, 1.0]) {
        final strap = RRect.fromRectAndRadius(
            Rect.fromLTRB(
                cx + sx * halfTop * 0.74 - w * 0.022,
                top - h * 0.006,
                cx + sx * halfTop * 0.74 + w * 0.022,
                cropTop + span * 0.10),
            Radius.circular(w * 0.012));
        canvas.drawRRect(strap, Paint()..color = body.main);
        canvas.drawRRect(strap, _inkStroke..strokeWidth = 1.0);
      }
      // Absinthe piping along the crop hem: the eye needs an edge to read the
      // skin below it as skin rather than as a lighting error.
      canvas.drawLine(
          Offset(cx - halfTop * 0.99, cropBot),
          Offset(cx + halfTop * 0.99, cropBot),
          Paint()
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = body.trim.withValues(alpha: 0.9));
      // A single strap crossing the bare midriff — a harness, not a garment.
      canvas.drawLine(
          Offset(cx - halfTop * 0.92, cropBot + span * 0.12),
          Offset(cx + halfTop * 0.86, cropBot + span * 0.26),
          Paint()
            ..strokeWidth = w * 0.020
            ..strokeCap = StrokeCap.round
            ..color = _darken(body.dark, 0.15));
      // Low-slung belt at the hip, sitting under the exposed waist.
      final belt = Rect.fromCenter(
          center: Offset(cx, bottom - h * 0.018),
          width: halfBot * 2.15,
          height: h * 0.026);
      canvas.drawRect(belt, Paint()..color = body.trim);
      canvas.drawRect(belt, _inkStroke..strokeWidth = 1.0);
      canvas.drawCircle(Offset(cx, bottom - h * 0.018), w * 0.020,
          Paint()..color = _darken(body.trim, 0.35));
      // The torso outline last, so the skin block has a contained edge.
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(cx - halfTop * 1.06, top - h * 0.006,
                  cx + halfTop * 1.06, bottom),
              Radius.circular(w * 0.05)),
          _inkStroke..strokeWidth = 1.1);
    }
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
      case 'sentinel':
        // He shipped with no detail layer at all, which is why a man in full
        // plate read as a smooth grey bell. Pauldrons, a gorget at the throat,
        // and a sapphire surcoat down the front so the one colour he owns is
        // on his chest rather than buried in a shield boss.
        _pauldrons(canvas, size, spiked: false);
        final sapphire = royal.palette['G'] ?? const Color(0xFF4A8CFF);
        // Gorget: a plate collar closing the gap under the great helm.
        final gorget = RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx, h * 0.552),
                width: w * 0.21,
                height: h * 0.036),
            Radius.circular(h * 0.018));
        canvas.drawRRect(gorget, Paint()..color = _lighten(body.main, 0.18));
        canvas.drawRRect(gorget, _inkStroke..strokeWidth = 1.2);
        // Surcoat panel, hanging from the gorget past the fauld.
        final surcoat = Path()
          ..moveTo(cx - w * 0.058, h * 0.575)
          ..lineTo(cx + w * 0.058, h * 0.575)
          ..lineTo(cx + w * 0.050, h * 0.800)
          ..quadraticBezierTo(cx, h * 0.828, cx - w * 0.050, h * 0.800)
          ..close();
        canvas.drawPath(surcoat, Paint()..color = sapphire.withValues(alpha: 0.92));
        canvas.drawPath(surcoat, _inkStroke..strokeWidth = 1.1);
        // The crown's chevron, repeated from the shield — a livery reads as
        // livery only when the same mark is in two places.
        canvas.drawPath(
            Path()
              ..moveTo(cx - w * 0.038, h * 0.680)
              ..lineTo(cx, h * 0.650)
              ..lineTo(cx + w * 0.038, h * 0.680),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.016
              ..strokeCap = StrokeCap.round
              ..color = body.trim);
        _belt(canvas, cx, h * 0.745, w);
      case 'huntress':
        // A working rogue's kit: a bandolier across the bare midriff, a hip
        // pouch, and a hood collar bunched at the shoulders. Without any of it
        // she was a figure in a vest — the straps are what say she is carrying
        // a job's worth of equipment.
        final leather = _darken(body.dark, 0.22);
        final cowl = Path()
          ..moveTo(cx - w * 0.185, h * 0.548)
          ..quadraticBezierTo(cx, h * 0.520, cx + w * 0.185, h * 0.548)
          ..quadraticBezierTo(
              cx + w * 0.140, h * 0.600, cx + w * 0.075, h * 0.588)
          ..quadraticBezierTo(cx, h * 0.565, cx - w * 0.075, h * 0.588)
          ..quadraticBezierTo(
              cx - w * 0.140, h * 0.600, cx - w * 0.185, h * 0.548)
          ..close();
        _fillInked(canvas, cowl, leather);
        // Two pouches on the belt line, one either side of the buckle.
        for (final sx in [-1.0, 1.0]) {
          final pouch = RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(cx + sx * w * 0.115, h * 0.755),
                  width: w * 0.070,
                  height: h * 0.050),
              Radius.circular(w * 0.018));
          canvas.drawRRect(pouch, Paint()..color = leather);
          canvas.drawRRect(pouch, _inkStroke..strokeWidth = 1.0);
          canvas.drawLine(
              Offset(cx + sx * w * 0.115 - w * 0.030, h * 0.744),
              Offset(cx + sx * w * 0.115 + w * 0.030, h * 0.744),
              Paint()
                ..strokeWidth = 1.2
                ..color = body.trim.withValues(alpha: 0.75));
        }
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
      // Bare: she is in a tank top, and the arm is most of what says so.
      RoyalOutfit.bodysuit => body.skin,
    };
    // A fitted sleeve on the bodysuit — the standard one is loose enough to
    // undo the tapering the torso is doing.
    _capsule(canvas, shoulder, hand,
        w * (body.outfit == RoyalOutfit.bodysuit ? 0.062 : 0.078), sleeve);
    if (body.outfit == RoyalOutfit.bodysuit) {
      // Wrapped forearms: the bare arm needs one break in it, or a limb this
      // long in flat skin reads as unfinished rather than as uncovered.
      final wrapFrom = Offset.lerp(shoulder, hand, 0.55)!;
      _capsule(canvas, wrapFrom, hand, w * 0.058, _darken(body.dark, 0.18));
      final axis = Offset(math.sin(angle), math.cos(angle));
      final across = Offset(-axis.dy, axis.dx);
      for (var i = 0; i < 2; i++) {
        final at = Offset.lerp(wrapFrom, hand, 0.28 + i * 0.34)!;
        canvas.drawLine(at - across * (w * 0.028), at + across * (w * 0.028),
            Paint()
              ..strokeWidth = 1.1
              ..color = body.ink.withValues(alpha: 0.45));
      }
    }
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
      case RoyalWeapon.sword:
        // The blade of state. At rest it stands point-down like a sceptre —
        // both hands may rest on the pommel, throne-room style. Swung, it
        // rides the arm: steel first, gold crossguard, gem pommel.
        final steel = royal.palette['S'] ?? const Color(0xFFD7DCE4);
        final Offset guard, tip;
        if (rest) {
          guard = Offset(hand.dx, hand.dy + h * 0.015);
          tip = Offset(hand.dx, h * 0.945);
        } else {
          guard = along(h * 0.03);
          tip = along(-h * 0.42);
        }
        final bladeDir = (tip - guard).direction;
        // Blade body + a bright fuller line down the middle.
        _shaft(canvas, guard, Offset.lerp(guard, tip, 0.90)!, w * 0.042,
            steel, _darken(steel, 0.4));
        canvas.drawLine(
            Offset.lerp(guard, tip, 0.08)!,
            Offset.lerp(guard, tip, 0.82)!,
            Paint()
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.75));
        _triangle(canvas, tip, bladeDir, w * 0.085, w * 0.030, steel);
        // Gold crossguard, perpendicular to the blade, + gem pommel.
        final perp =
            Offset(-math.sin(bladeDir), math.cos(bladeDir)) * (w * 0.062);
        canvas.drawLine(
            guard + perp,
            guard - perp,
            Paint()
              ..strokeWidth = w * 0.034
              ..strokeCap = StrokeCap.round
              ..color = _gold);
        _gemShape(canvas, guard - Offset(math.cos(bladeDir), math.sin(bladeDir)) * (h * 0.045),
            w * 0.038, body.gem);
      case RoyalWeapon.knightSword:
        // The heir's arming sword: sized to the man, not to the parade
        // ground. At rest it stands point-UP beside him (a lance planted
        // point-down needs a shaft taller than the character, which is what
        // made the old one read as scaffolding); swung, it rides the arm.
        final steel = royal.palette['S'] ?? const Color(0xFFD7DCE4);
        final Offset guard, tip;
        if (rest) {
          guard = Offset(hand.dx, hand.dy - h * 0.010);
          tip = Offset(hand.dx, h * 0.085);
        } else {
          guard = along(h * 0.025);
          tip = along(-h * 0.40);
        }
        final bladeDir = (tip - guard).direction;
        _shaft(canvas, guard, Offset.lerp(guard, tip, 0.88)!, w * 0.038, steel,
            _darken(steel, 0.42));
        // Fuller line down the middle of the blade.
        canvas.drawLine(
            Offset.lerp(guard, tip, 0.10)!,
            Offset.lerp(guard, tip, 0.80)!,
            Paint()
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.72));
        _triangle(canvas, tip, bladeDir, w * 0.080, w * 0.027, steel);
        // Winged crossguard: two swept quillons rather than a straight bar —
        // the detail that tells the heir's blade from the Sovereign's.
        final perp = Offset(-math.sin(bladeDir), math.cos(bladeDir));
        final back = Offset(math.cos(bladeDir), math.sin(bladeDir));
        for (final s in [-1.0, 1.0]) {
          final quillon = Path()
            ..moveTo(guard.dx, guard.dy)
            ..quadraticBezierTo(
                guard.dx + perp.dx * s * w * 0.048 - back.dx * h * 0.010,
                guard.dy + perp.dy * s * w * 0.048 - back.dy * h * 0.010,
                guard.dx + perp.dx * s * w * 0.062 - back.dx * h * 0.030,
                guard.dy + perp.dy * s * w * 0.062 - back.dy * h * 0.030)
            ..quadraticBezierTo(
                guard.dx + perp.dx * s * w * 0.036 + back.dx * h * 0.004,
                guard.dy + perp.dy * s * w * 0.036 + back.dy * h * 0.004,
                guard.dx + back.dx * h * 0.014,
                guard.dy + back.dy * h * 0.014)
            ..close();
          _fillInked(canvas, quillon, _gold);
        }
        // Wrapped grip + ruby pommel.
        _shaft(canvas, guard + back * (h * 0.012), guard + back * (h * 0.042),
            w * 0.026, _darken(_gold, 0.34), _darken(_gold, 0.55));
        _gemShape(canvas, guard + back * (h * 0.052), w * 0.030, body.gem);
      case RoyalWeapon.warClub:
        // Carried over the shoulder — casual, heavy, mildly threatening. On
        // the menace hold it goes the other way: driven into the ground and
        // leaned on, which is the pose the whole move is built around.
        final planted = action == RoyalAction.menace && rest;
        final overShoulder = rest && !planted;
        final from = hand;
        final to = planted
            ? Offset(hand.dx - w * 0.02, h * 0.90)
            : overShoulder
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
        final emerald = royal.palette['E'] ?? const Color(0xFF2BB985);
        final c = hand.translate(0, h * 0.012);
        // On the mend signature the case is OPEN — a hinged lid tipped back
        // with light coming out of it. A shut box held up says nothing.
        final open = action == RoyalAction.mend
            ? ((t - 0.14) / 0.18).clamp(0.0, 1.0) *
                (1 - ((t - 0.80) / 0.20).clamp(0.0, 1.0))
            : 0.0;
        if (open > 0) {
          canvas.save();
          canvas.translate(c.dx - w * 0.082, c.dy - h * 0.048);
          canvas.rotate(-open * 1.15); // lid swings back on its hinge
          final lid = RRect.fromRectAndRadius(
              Rect.fromLTWH(0, -h * 0.042, w * 0.165, h * 0.044),
              Radius.circular(w * 0.02));
          canvas.drawRRect(lid, Paint()..color = const Color(0xFFE4DED2));
          canvas.drawRRect(lid, _inkStroke..strokeWidth = 1.1);
          canvas.restore();
          // Contents glowing in the tray.
          canvas.drawRect(
              Rect.fromCenter(
                  center: c.translate(0, -h * 0.010),
                  width: w * 0.130,
                  height: h * 0.030),
              Paint()..color = emerald.withValues(alpha: 0.55 * open));
        }
        final kit = RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: w * 0.165, height: h * 0.10),
            Radius.circular(w * 0.03));
        canvas.drawRRect(kit, Paint()..color = const Color(0xFFF6F2EA));
        canvas.drawRRect(kit, _inkStroke..strokeWidth = 1.2);
        _plus(canvas, c, w * 0.036, emerald);
      case RoyalWeapon.spear:
        // A guard's spear: taller than he is, so at rest it is the vertical
        // line the whole silhouette hangs off — the thing a man on post
        // actually looks like. Levelled, it is the longest reach in the court.
        //
        // The shield is NOT here: it lives on the free arm (see [_shield]), so
        // it stops covering the breastplate it is supposed to be worn over.
        final steel = royal.palette['S'] ?? const Color(0xFFC9D2DE);
        final trim = royal.palette['T'] ?? const Color(0xFFEAF0F8);
        final gem = royal.palette['G'] ?? const Color(0xFF4A8CFF);
        final haft = royal.palette['a'] ?? const Color(0xFF64728A);
        final Offset butt, tip;
        if (rest) {
          // Planted: grounded beside him, standing well over the head.
          butt = Offset(hand.dx, h * 0.945);
          tip = Offset(hand.dx, h * 0.055);
        } else {
          // Couched from the saddle it has to clear the horse's HEAD, which is
          // drawn in front of the rider — at the on-foot length the whole
          // charge was a hand's width of steel hidden behind a chanfron.
          butt = along(h * (_mounted ? 0.22 : 0.16));
          tip = along(-h * (_mounted ? 1.05 : 0.52));
        }
        final spearDir = (tip - butt).direction;
        _shaft(canvas, butt, Offset.lerp(butt, tip, 0.86)!, w * 0.030, haft,
            _darken(haft, 0.35));
        // Butt-cap, so the grounded end reads as deliberate rather than cut.
        canvas.drawCircle(butt, w * 0.026, Paint()..color = trim);
        canvas.drawCircle(butt, w * 0.026, _inkStroke..strokeWidth = 1.1);
        // Sapphire collar where the head meets the haft, then a long leaf blade.
        final collar = Offset.lerp(butt, tip, 0.80)!;
        canvas.drawCircle(collar, w * 0.030, Paint()..color = gem);
        canvas.drawCircle(collar, w * 0.030, _inkStroke..strokeWidth = 1.0);
        final leafBase = Offset.lerp(butt, tip, 0.83)!;
        final perp = Offset(-math.sin(spearDir), math.cos(spearDir));
        final leaf = Path()
          ..moveTo(leafBase.dx, leafBase.dy)
          ..quadraticBezierTo(
              leafBase.dx + perp.dx * w * 0.055,
              leafBase.dy + perp.dy * w * 0.055,
              tip.dx,
              tip.dy)
          ..quadraticBezierTo(
              leafBase.dx - perp.dx * w * 0.055,
              leafBase.dy - perp.dy * w * 0.055,
              leafBase.dx,
              leafBase.dy)
          ..close();
        _fillInked(canvas, leaf, steel);
        canvas.drawLine(
            Offset.lerp(leafBase, tip, 0.12)!,
            Offset.lerp(leafBase, tip, 0.86)!,
            Paint()
              ..strokeWidth = 1.3
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.70));
        // Sapphire pennon under the collar — a guard's spear carries the
        // crown's colours, and it is the one piece of him that moves on its
        // own. A long swallow-tail streamer running DOWN the shaft, not a
        // little flag sticking out sideways: at pennant proportions it read as
        // a scrap of blue floating next to him rather than as anything flown.
        final ripple = math.sin(t * 2 * math.pi * 1.6);
        final rootA = Offset.lerp(butt, tip, 0.76)!;
        final rootB = Offset.lerp(butt, tip, 0.52)!;
        // Planted, `perp` points INBOARD — straight across his own helm. A
        // pennon hangs on the outside of a grounded spear; levelled, it
        // streams below the shaft, which is what `perp` already gives.
        final fly = rest ? -perp : perp;
        final outA = fly * (w * 0.115 + w * 0.014 * ripple);
        final outB = fly * (w * 0.085 - w * 0.010 * ripple);
        final flag = Path()
          ..moveTo(rootA.dx, rootA.dy)
          ..quadraticBezierTo(
              rootA.dx + outA.dx * 0.6,
              rootA.dy + outA.dy * 0.6,
              rootA.dx + outA.dx,
              rootA.dy + outA.dy)
          // The notch of the swallow tail, bitten back toward the shaft.
          ..lineTo(
              Offset.lerp(rootA, rootB, 0.5)!.dx + fly.dx * w * 0.048,
              Offset.lerp(rootA, rootB, 0.5)!.dy + fly.dy * w * 0.048)
          ..lineTo(rootB.dx + outB.dx, rootB.dy + outB.dy)
          ..quadraticBezierTo(rootB.dx + outB.dx * 0.5,
              rootB.dy + outB.dy * 0.5, rootB.dx, rootB.dy)
          ..close();
        _fillInked(canvas, flag, gem);
        canvas.drawLine(rootA, rootB,
            Paint()
              ..strokeWidth = 1.4
              ..color = _darken(gem, 0.35));
      case RoyalWeapon.daggers:
        // Paired blades, one forward and one reversed in an ice-pick grip —
        // the reversed one is what stops this reading as a single small sword.
        //
        // Both blades take [_Pose.bladeSpin] on top of the arm angle, which is
        // what lets her twirl them in her fingers while the wrist holds still;
        // [_Pose.bladeOpen] swings the off-hand one clear of the hip, because
        // at rest the two overlap into a single shape.
        final steel = royal.palette['S'] ?? const Color(0xFFC9D2DE);
        final wrap = royal.palette['h'] ?? const Color(0xFF221726);
        final edge = royal.theme.accent;
        void blade(Offset from, double dir, double len, {double glint = 0}) {
          final axis = Offset(math.sin(dir), -math.cos(dir));
          final tip = from + axis * -len;
          _shaft(canvas, from, tip, w * 0.026, steel, _darken(steel, 0.4));
          // A hair of absinthe down the edge — she is the only royal whose
          // steel is coloured, and it is what makes two small blades findable
          // against a dark body.
          canvas.drawLine(
              Offset.lerp(from, tip, 0.22)!,
              Offset.lerp(from, tip, 0.94)!,
              Paint()
                ..strokeWidth = 1.4
                ..strokeCap = StrokeCap.round
                ..color = edge.withValues(alpha: 0.55 + 0.45 * glint));
          // Short wrapped grip behind the hand, and a small pommel.
          final butt = from + axis * (len * 0.30);
          _shaft(canvas, from, butt, w * 0.030, wrap, _darken(wrap, 0.3));
          canvas.drawCircle(butt, w * 0.019, Paint()..color = _darken(steel, 0.2));
        }
        final spin = pose.bladeSpin;
        final open = pose.bladeOpen;
        // Lead hand: blade forward along the arm, spinning in the fingers.
        blade(hand, dir + spin, h * 0.20,
            glint: (math.sin(spin * 2) * 0.5 + 0.5) * 0.8);
        // Off hand: held reversed, tucked at the hip until `bladeOpen` swings
        // it clear of the body.
        final off = hand.translate(
            -w * (0.085 + 0.055 * open), h * (0.030 - 0.045 * open));
        blade(off, dir - spin + math.pi * (0.86 - 0.34 * open), h * 0.165,
            glint: (math.cos(spin * 2) * 0.5 + 0.5) * 0.8);
      case RoyalWeapon.orbs:
        break; // painted by _orbs
    }
  }

  /// The Empress's three arcane orbs, orbiting the body on a tilted ellipse.
  /// Split into a back and front pass so they truly circle her.
  void _orbs(Canvas canvas, Size size, {required bool front}) {
    final w = size.width, h = size.height;
    // Casting: the orbs wind in tight and fast, then are flung wide and high
    // as the spell breaks. Idling, they just circle her at the waist.
    final casting = action == RoyalAction.spell;
    final wind = casting ? Curves.easeIn.transform((t / 0.42).clamp(0.0, 1.0)) : 0.0;
    final fling =
        casting ? Curves.easeOutBack.transform(((t - 0.42) / 0.24).clamp(0.0, 1.0)) : 0.0;
    final c = Offset(w * 0.5, h * (0.66 - 0.22 * wind + 0.06 * fling));
    final spread = 1 - 0.55 * wind + 1.05 * fling;
    for (var i = 0; i < 3; i++) {
      final a = t * 2 * math.pi * (0.8 + 2.6 * wind) + i * (2 * math.pi / 3);
      final inFront = math.sin(a) > 0;
      if (inFront != front) continue;
      final p = c +
          Offset(math.cos(a) * w * 0.30 * spread,
              math.sin(a) * h * (0.055 + 0.10 * fling) * spread - h * 0.02);
      final r = w * (0.032 + 0.010 * math.sin(a)) * (1 + 0.35 * wind - 0.15 * fling);
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
      // The guard's cloak, and the largest piece of sapphire he owns. Steel
      // plate cannot carry a court colour — every surface on him wants to be
      // metal — so the colour has to come from cloth hung behind it.
      'sentinel' => royal.theme.accentDeep,
      _ => null,
    };
    if (capeColor == null) return;
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final flutter = math.sin(t * 2 * math.pi * 1.5) * w * 0.02 +
        pose.stride * w * 0.06;
    final hemY = h * switch (royal.id) {
      'sovereign' => 0.88,
      // A guard's cloak is short — it clears the knee so he can move in it.
      'sentinel' => 0.78,
      _ => 0.83,
    };
    // The Sentinel's hangs off BOTH shoulders and spreads wider than the body,
    // because it is the only sapphire he owns that is not the shield. At the
    // shared width it sat entirely behind the torso and showed one blue
    // triangle by his ankle.
    final guard = royal.id == 'sentinel';
    final path = Path()
      ..moveTo(cx - w * (guard ? 0.185 : 0.13), h * 0.555)
      ..lineTo(cx + w * (guard ? 0.165 : 0.10), h * 0.555)
      ..lineTo(cx + w * (guard ? 0.075 : -0.02) - flutter, hemY);
    if (royal.id == 'darkprince') {
      // Tattered hem: three ragged points.
      path
        ..lineTo(cx - w * 0.09 - flutter, hemY - h * 0.03)
        ..lineTo(cx - w * 0.15 - flutter, hemY + h * 0.01)
        ..lineTo(cx - w * 0.21 - flutter, hemY - h * 0.035);
    } else {
      path.lineTo(cx - w * (guard ? 0.285 : 0.24) - flutter, hemY);
    }
    path.close();
    _fillInked(canvas, path, capeColor);
    if (guard) {
      // Two clasps at the collar and a lit fold, so a wide flat panel of one
      // colour still reads as cloth rather than as a painted backdrop.
      canvas.drawLine(
          Offset(cx - w * 0.06, h * 0.575),
          Offset(cx - w * 0.155 - flutter * 0.7, hemY - h * 0.010),
          Paint()
            ..strokeWidth = 1.6
            ..color = _lighten(capeColor, 0.30).withValues(alpha: 0.75));
      for (final sx in [-1.0, 1.0]) {
        canvas.drawCircle(Offset(cx + sx * w * 0.155, h * 0.560), w * 0.022,
            Paint()..color = body.trim);
        canvas.drawCircle(Offset(cx + sx * w * 0.155, h * 0.560), w * 0.022,
            _inkStroke..strokeWidth = 1.1);
      }
    }
  }

  void _head(Canvas canvas, Size size, _Pose pose) {
    final w = size.width, h = size.height;
    final box = w * 0.66;
    final origin = Offset((w - box) / 2, h * 0.03);
    // headRows, not rows: the full body draws a real weapon in the hand, so
    // the sprite's own weapon lane would be a second copy of it hanging beside
    // the face.
    final rows = List<String>.from(royal.headRows);
    if (pose.blink) {
      rows[royal.eyeRowWhites] = royal.stripWeaponLane(royal.eyesClosed[0]);
      rows[royal.eyeRowIris] = royal.stripWeaponLane(royal.eyesClosed[1]);
    } else if (pose.gaze != 0) {
      final g = pose.gaze > 0 ? royal.eyesRight : royal.eyesLeft;
      rows[royal.eyeRowWhites] = royal.stripWeaponLane(g[0]);
      rows[royal.eyeRowIris] = royal.stripWeaponLane(g[1]);
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

  /// The Dark Prince's great helm, sealed over the head sprite.
  ///
  /// Full-body only — the avatar circle keeps his bare face, and this is him
  /// having put the helm ON to ride out. Drawn AFTER [_head] and under the same
  /// head tilt, so it moves as one piece with him.
  ///
  /// He is a knight, not a monster: no horns, and a man's eyes behind the
  /// visor rather than a glowing slit. The first pass had both and read as a
  /// demon — heavy plate does the intimidating on its own, and the moment a
  /// face stops looking human the character stops being the exiled brother and
  /// becomes something you fight.
  void _headArmor(Canvas canvas, Size size, _Pose pose) {
    if (royal.id != 'darkprince') return;
    final w = size.width, h = size.height;
    final cx = w * 0.5;
    final box = w * 0.66;
    // The sprite's head fills the middle ~10 of its 16 columns; the helm hugs
    // that, not the whole box.
    final half = box * 0.34;
    final top = h * 0.03 + box * 0.14;
    final chin = h * 0.03 + box * 0.80;
    const plate = Color(0xFF2A2E38);
    const plateDark = Color(0xFF16181F);
    const plateLit = Color(0xFF5C6474);

    canvas.save();
    final pivot = Offset(w * 0.5, h * 0.50);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(pose.headTilt);
    canvas.translate(-pivot.dx, -pivot.dy);

    // Skull: a domed bucket that flares out over the jaw.
    final skull = Path()
      ..moveTo(cx - half, top + h * 0.030)
      ..quadraticBezierTo(cx - half, top, cx - half * 0.55, top - h * 0.006)
      ..quadraticBezierTo(cx, top - h * 0.020, cx + half * 0.55, top - h * 0.006)
      ..quadraticBezierTo(cx + half, top, cx + half, top + h * 0.030)
      ..lineTo(cx + half * 0.95, chin - h * 0.030)
      ..quadraticBezierTo(cx, chin + h * 0.014, cx - half * 0.95, chin - h * 0.030)
      ..close();
    _fillInked(canvas, skull, plate);

    // Brow bevel — the lit edge that makes it plate instead of a hood.
    canvas.drawLine(
        Offset(cx - half * 0.86, top + h * 0.040),
        Offset(cx + half * 0.86, top + h * 0.040),
        Paint()
          ..strokeWidth = h * 0.009
          ..strokeCap = StrokeCap.round
          ..color = plateLit);

    // Visor: a sunken band across the eyes with a single ember slit. The brow
    // dips to a V in the middle, which is what reads as a scowl.
    final visorY = h * 0.03 + box * 0.42;
    final visor = Path()
      ..moveTo(cx - half * 0.92, visorY - h * 0.024)
      ..lineTo(cx, visorY - h * 0.004)
      ..lineTo(cx + half * 0.92, visorY - h * 0.024)
      ..lineTo(cx + half * 0.92, visorY + h * 0.026)
      ..lineTo(cx - half * 0.92, visorY + h * 0.026)
      ..close();
    canvas.drawPath(visor, Paint()..color = plateDark);

    // The sight: a shadowed opening with an ordinary pair of eyes set back in
    // it. Cool steel-blue irises, deliberately NOT the court's ember red —
    // glowing eyes in a slit is the single cue that turns a helmet into a
    // monster mask.
    final sight = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, visorY + h * 0.004),
            width: half * 1.50,
            height: h * 0.030),
        Radius.circular(h * 0.010));
    canvas.drawRRect(sight, Paint()..color = plateDark);
    for (final s in [-1.0, 1.0]) {
      final eye = Offset(cx + s * half * 0.44, visorY + h * 0.004);
      canvas.drawOval(
          Rect.fromCenter(center: eye, width: half * 0.42, height: h * 0.018),
          Paint()..color = const Color(0xFFE9E4DA));
      canvas.drawCircle(eye.translate(s * half * 0.03, 0), h * 0.0085,
          Paint()..color = const Color(0xFF3E5B7A));
      canvas.drawCircle(eye.translate(s * half * 0.03, 0), h * 0.004,
          Paint()..color = body.ink);
    }
    // A nasal bar down the middle of the sight.
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(cx, visorY + h * 0.026),
            width: w * 0.032,
            height: h * 0.068),
        Paint()..color = plate);

    // Breath grille under the visor.
    final grille = Paint()
      ..strokeWidth = h * 0.007
      ..strokeCap = StrokeCap.round
      ..color = plateDark;
    for (var i = 0; i < 3; i++) {
      final y = visorY + h * (0.046 + i * 0.018);
      final gw = half * (0.66 - i * 0.13);
      canvas.drawLine(Offset(cx - gw, y), Offset(cx + gw, y), grille);
    }

    // Cheek plates flaring off the jaw — the bulk that reads as heavy armour
    // now that there are no horns doing it.
    for (final s in [-1.0, 1.0]) {
      final cheek = Path()
        ..moveTo(cx + s * half * 0.94, visorY + h * 0.012)
        ..lineTo(cx + s * half * 1.16, visorY + h * 0.034)
        ..lineTo(cx + s * half * 1.02, chin - h * 0.014)
        ..lineTo(cx + s * half * 0.86, chin - h * 0.020)
        ..close();
      _fillInked(canvas, cheek, plateDark);
    }

    // Comb: the raised steel ridge along the crown of a knight's helm.
    final comb = Path()
      ..moveTo(cx - half * 0.62, top + h * 0.006)
      ..quadraticBezierTo(cx, top - h * 0.048, cx + half * 0.62, top + h * 0.006)
      ..quadraticBezierTo(cx, top - h * 0.014, cx - half * 0.62, top + h * 0.006)
      ..close();
    _fillInked(canvas, comb, plateLit);

    canvas.restore();
  }

  /// The Dark Prince's heater shield, strapped to his free arm.
  ///
  /// It rides the near hand and turns part-way with it, so raising the arm
  /// raises the shield — a knight with a club in one hand and nothing in the
  /// other was only half-equipped. Drawn last, over the arm, so the straps
  /// read as being on this side of it.
  void _shield(Canvas canvas, Size size, Offset shoulder, double armAngle) {
    if (royal.id == 'sentinel') {
      _towerShield(canvas, size, shoulder, armAngle);
      return;
    }
    if (royal.id != 'darkprince') return;
    final w = size.width, h = size.height;
    final hand =
        shoulder + Offset(math.sin(armAngle), math.cos(armAngle)) * (h * 0.125);
    final accent = royal.theme.accent;
    const face = Color(0xFF23262F);
    const rim = Color(0xFF5B6474);
    const rimLit = Color(0xFF8B95A8);

    canvas.save();
    canvas.translate(hand.dx + w * 0.055, hand.dy + h * 0.012);
    // Only part of the arm's swing carries into the shield: a shield hanging
    // off a forearm stays roughly upright however the elbow moves.
    canvas.rotate(armAngle * 0.32 - 0.08);

    final halfW = w * 0.135, top = -h * 0.085, tip = h * 0.105;
    final heater = Path()
      ..moveTo(-halfW, top + h * 0.012)
      ..quadraticBezierTo(0, top - h * 0.010, halfW, top + h * 0.012)
      ..cubicTo(halfW * 0.98, tip * 0.32, halfW * 0.66, tip * 0.78, 0, tip)
      ..cubicTo(-halfW * 0.66, tip * 0.78, -halfW * 0.98, tip * 0.32, -halfW,
          top + h * 0.012)
      ..close();
    _fillInked(canvas, heater, face);

    // Rim.
    canvas.drawPath(
        heater,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.026
          ..strokeJoin = StrokeJoin.round
          ..color = rim);
    canvas.drawPath(
        heater,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.026
          ..strokeJoin = StrokeJoin.round
          ..color = _inkStroke.color);
    canvas.drawLine(
        Offset(-halfW * 0.78, top + h * 0.016),
        Offset(halfW * 0.78, top + h * 0.016),
        Paint()
          ..strokeWidth = h * 0.008
          ..strokeCap = StrokeCap.round
          ..color = rimLit);

    // Blood-red chevron device + a steel boss.
    final chevron = Path()
      ..moveTo(-halfW * 0.70, -h * 0.018)
      ..lineTo(0, -h * 0.052)
      ..lineTo(halfW * 0.70, -h * 0.018)
      ..lineTo(halfW * 0.70, h * 0.010)
      ..lineTo(0, -h * 0.024)
      ..lineTo(-halfW * 0.70, h * 0.010)
      ..close();
    canvas.drawPath(chevron, Paint()..color = body.trim);
    canvas.drawCircle(Offset(0, h * 0.030), w * 0.030, Paint()..color = rim);
    canvas.drawCircle(
        Offset(0, h * 0.030), w * 0.030, _inkStroke..strokeWidth = 1.1);
    canvas.drawCircle(Offset(-w * 0.008, h * 0.024), w * 0.010,
        Paint()..color = accent.withValues(alpha: 0.85));

    canvas.restore();
  }

  /// The Sentinel's kite shield, strapped to the FREE forearm.
  ///
  /// It used to be his weapon, drawn from the weapon hand — which put it flat
  /// across his own chest and hid every piece of plate detail he has. On the
  /// free arm it sits where a shield is actually worn: outboard, covering the
  /// leading side, with the breastplate and the spear both still readable.
  void _towerShield(
      Canvas canvas, Size size, Offset shoulder, double armAngle) {
    final w = size.width, h = size.height;
    final hand =
        shoulder + Offset(math.sin(armAngle), math.cos(armAngle)) * (h * 0.125);
    final steel = royal.palette['S'] ?? const Color(0xFFC9D2DE);
    final trim = royal.palette['T'] ?? const Color(0xFFEAF0F8);
    final gem = royal.palette['G'] ?? const Color(0xFF4A8CFF);

    canvas.save();
    canvas.translate(hand.dx + w * 0.045, hand.dy + h * 0.010);
    // A strapped shield barely follows the elbow — it hangs off the forearm
    // and stays close to upright however the arm swings.
    canvas.rotate(armAngle * 0.30 - 0.06);

    final halfW = w * 0.165, top = -h * 0.155, tip = h * 0.150;
    final face = Path()
      ..moveTo(-halfW, top + h * 0.016)
      ..quadraticBezierTo(0, top - h * 0.012, halfW, top + h * 0.016)
      ..lineTo(halfW * 0.94, tip * 0.30)
      ..quadraticBezierTo(halfW * 0.60, tip * 0.86, 0, tip)
      ..quadraticBezierTo(-halfW * 0.60, tip * 0.86, -halfW * 0.94, tip * 0.30)
      ..close();
    // The FIELD is sapphire, not steel. A steel board on a steel man in steel
    // plate gave him one value and no colour at all — the shield is the only
    // flat surface big enough to carry his court shade to the front.
    _fillInked(canvas, face, gem);
    // A darker half sells the curve of the board without needing a gradient.
    canvas.save();
    canvas.clipPath(face);
    canvas.drawRect(
        Rect.fromLTWH(0, top - h * 0.02, halfW * 1.2, tip - top + h * 0.04),
        Paint()..color = _darken(gem, 0.28));
    canvas.restore();
    // Steel rim right round the board, so it still reads as a made object.
    canvas.drawPath(
        face,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.024
          ..strokeJoin = StrokeJoin.round
          ..color = steel);
    canvas.drawPath(face, _inkStroke..strokeWidth = 1.3);
    // Bright rim highlight along the top edge.
    canvas.drawLine(
        Offset(-halfW * 0.76, top + h * 0.024),
        Offset(halfW * 0.76, top + h * 0.024),
        Paint()
          ..strokeWidth = h * 0.008
          ..strokeCap = StrokeCap.round
          ..color = trim);
    // Steel boss and the crown's chevron above it, both now reading light-on-
    // dark rather than the other way round.
    canvas.drawCircle(Offset(0, h * 0.010), w * 0.040, Paint()..color = steel);
    canvas.drawCircle(
        Offset(0, h * 0.010), w * 0.040, _inkStroke..strokeWidth = 1.1);
    canvas.drawCircle(Offset(-w * 0.012, h * 0.002), w * 0.013,
        Paint()..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawPath(
        Path()
          ..moveTo(-halfW * 0.62, -h * 0.052)
          ..lineTo(0, -h * 0.082)
          ..lineTo(halfW * 0.62, -h * 0.052),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.016
          ..strokeCap = StrokeCap.round
          ..color = trim);
    canvas.restore();
  }

  /// Effects drawn unsquashed above the figure: impact sparks, cheer
  /// stars/hearts, fume anger-mark + steam.
  void _actionAccents(
      Canvas canvas, Size size, _Pose pose, RoyalAction action) {
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
      case RoyalAction.slash:
      case RoyalAction.slice:
        // A crescent motion-streak trailing the blade through the swing —
        // a white edge over an accent ghost, fading with the flourish.
        final c = Offset(w * 0.34, h * 0.55);
        final sweep = math.pi * (action == RoyalAction.slice ? 0.55 : 0.75);
        final start = action == RoyalAction.slice
            ? math.pi * 0.72
            : math.pi * 0.55; // slash arcs steeper, slice flatter
        for (final (rr, paintW, col) in [
          (w * 0.52, 5.0, accent.withValues(alpha: 0.30 * pose.flourish)),
          (w * 0.48, 2.2, Colors.white.withValues(alpha: 0.65 * pose.flourish)),
        ]) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: rr),
            start,
            sweep * pose.flourish.clamp(0.0, 1.0),
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = paintW
              ..color = col,
          );
        }
      case RoyalAction.shoot:
        // A release snap at the bow: three short sparks off the string line.
        final at = Offset(w * 0.16, h * 0.52);
        final sp = Paint()
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.8 * pose.flourish);
        for (var i = 0; i < 3; i++) {
          final a = math.pi * (0.85 + i * 0.12);
          final r0 = w * 0.03, r1 = w * (0.075 + 0.05 * pose.flourish);
          canvas.drawLine(at + Offset(math.cos(a), math.sin(a)) * r0,
              at + Offset(math.cos(a), math.sin(a)) * r1, sp);
        }
      case RoyalAction.hurl:
        // The casting gathers overhead: a pulsing glow + two orbiting motes.
        final at = Offset(w * 0.42, h * 0.10);
        canvas.drawCircle(
            at,
            w * (0.06 + 0.05 * pose.flourish),
            Paint()
              ..color = accent.withValues(alpha: 0.35 * pose.flourish)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        for (var i = 0; i < 2; i++) {
          final a = t * 2 * math.pi * 3 + i * math.pi;
          _star(
              canvas,
              at + Offset(math.cos(a), math.sin(a)) * w * 0.10,
              w * 0.022 * pose.flourish,
              Colors.white.withValues(alpha: 0.8 * pose.flourish));
        }
      case RoyalAction.spell:
        // A rune circle on the floor under her, seen almost edge-on, turning;
        // a rising column of motes; and the bloom of light she opens her hands
        // into. The circle is the anchor — sparkles alone read as "sparkly",
        // a drawn ring of glyphs reads as MAGIC.
        final spin = t * 2 * math.pi * 0.55;
        final ringR = w * (0.20 + 0.22 * pose.flourish);
        final ringC = Offset(w * 0.5, h * 0.925);
        for (final (rr, sw, al) in [
          (ringR, 2.4, 0.75),
          (ringR * 0.72, 1.4, 0.45),
        ]) {
          canvas.drawOval(
              Rect.fromCenter(
                  center: ringC, width: rr * 2, height: rr * 0.46),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = sw
                ..color = accent.withValues(alpha: al * pose.flourish));
        }
        // Glyph ticks around the circle, turning with it.
        for (var i = 0; i < 10; i++) {
          final a = spin + i * (2 * math.pi / 10);
          final p = ringC +
              Offset(math.cos(a) * ringR, math.sin(a) * ringR * 0.23);
          canvas.drawRect(
              Rect.fromCenter(
                  center: p, width: w * 0.016, height: h * 0.012),
              Paint()
                ..color = Color.lerp(Colors.white, accent, 0.4)!
                    .withValues(alpha: 0.8 * pose.flourish));
        }
        // Motes climbing the column of the spell.
        for (var i = 0; i < 7; i++) {
          final p = ((t * 1.15 + i * 0.143) % 1.0);
          final a = spin * 1.6 + i * 1.4;
          final rr = ringR * (0.85 - p * 0.45);
          final mp = Offset(ringC.dx + math.cos(a) * rr,
              ringC.dy - p * h * 0.72 + math.sin(a) * rr * 0.16);
          _star(canvas, mp, w * 0.020 * (1 - p * 0.5) * pose.flourish,
              Color.lerp(Colors.white, accent, 0.35)!
                  .withValues(alpha: 0.85 * (1 - p) * pose.flourish));
        }
        // The bloom overhead, at the moment her hands open. It sits ABOVE the
        // crown and is finished before the curtsy begins — centred on the head
        // it drew its rays straight across her face.
        final bloom = ((t - 0.42) / 0.16).clamp(0.0, 1.0) *
            (1 - ((t - 0.56) / 0.14).clamp(0.0, 1.0));
        if (bloom > 0) {
          final at = Offset(w * 0.5, h * 0.115);
          canvas.drawCircle(
              at,
              w * (0.10 + 0.26 * bloom),
              Paint()
                ..color = accent.withValues(alpha: 0.30 * bloom)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
          for (var i = 0; i < 8; i++) {
            final a = i * math.pi / 4 + spin;
            final r0 = w * 0.10 * bloom, r1 = w * (0.12 + 0.26 * bloom);
            canvas.drawLine(
                at + Offset(math.cos(a), math.sin(a)) * r0,
                at + Offset(math.cos(a), math.sin(a)) * r1,
                Paint()
                  ..strokeWidth = 2.2 * (1 - bloom * 0.5)
                  ..strokeCap = StrokeCap.round
                  ..color = Colors.white.withValues(alpha: 0.7 * (1 - bloom)));
          }
          _star(canvas, at, w * 0.05 * bloom,
              Colors.white.withValues(alpha: 0.9 * (1 - bloom * 0.4)));
        }
      case RoyalAction.kiss:
        // Hearts leaving her lips and drifting OUT of the screen: each grows
        // as it travels and fades at the end, which at this scale is the only
        // way to say "toward you" on a flat canvas.
        final lips = Offset(w * 0.56, h * 0.30);
        for (var i = 0; i < 3; i++) {
          final p = ((t - 0.40 - i * 0.11) / 0.55).clamp(0.0, 1.0);
          if (p <= 0) continue;
          // Out at roughly eye level, staying inside the box: hearts that leave
          // the character's frame get clipped by the host's positioned box, and
          // ones that climb steeply just tangle in her tiara.
          final drift = Offset(
              lips.dx + w * (0.24 + i * 0.05) * p,
              lips.dy - h * 0.06 * p + math.sin(p * math.pi * 1.5 + i) * h * 0.022);
          final grow = 0.7 + p * 2.4; // rushing at the viewer
          final fade = (1 - p * p * 0.85);
          canvas.save();
          canvas.translate(drift.dx, drift.dy);
          canvas.rotate(math.sin(p * 4 + i) * 0.22);
          _heart(canvas, Offset.zero, w * 0.030 * grow,
              accent.withValues(alpha: 0.9 * fade));
          _heart(canvas, Offset(-w * 0.008 * grow, -w * 0.008 * grow),
              w * 0.010 * grow, Colors.white.withValues(alpha: 0.7 * fade));
          canvas.restore();
        }
        // A little sparkle puff right at the lips as it leaves.
        final puff = pose.flourish;
        if (puff > 0) {
          for (var i = 0; i < 4; i++) {
            final a = -math.pi * 0.15 + i * 0.30;
            _star(
                canvas,
                lips + Offset(math.cos(a), math.sin(a)) * w * (0.05 + 0.06 * puff),
                w * 0.016 * puff,
                Colors.white.withValues(alpha: 0.75 * puff));
          }
        }
      case RoyalAction.menace:
        // The ground gives: a shock ring at the club's landing point, embers
        // climbing off him, and a dark aura that stays for the hold.
        final drop = (t / 0.22).clamp(0.0, 1.0);
        final at = Offset(w * 0.26, h * 0.945);
        if (drop >= 1 && t < 0.62) {
          final s = ((t - 0.22) / 0.40).clamp(0.0, 1.0);
          canvas.drawOval(
              Rect.fromCenter(
                  center: at,
                  width: w * (0.30 + 1.05 * s),
                  height: h * (0.030 + 0.075 * s)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.4 * (1 - s) + 0.6
                ..color = accent.withValues(alpha: 0.60 * (1 - s)));
          // Cracks skittering out from the strike.
          for (var i = 0; i < 5; i++) {
            final a = math.pi + (i - 2) * 0.42;
            final r0 = w * 0.06, r1 = w * (0.10 + 0.20 * s);
            canvas.drawLine(
                at + Offset(math.cos(a), math.sin(a) * 0.35) * r0,
                at + Offset(math.cos(a), math.sin(a) * 0.35) * r1,
                Paint()
                  ..strokeWidth = 2.0 * (1 - s)
                  ..strokeCap = StrokeCap.round
                  ..color = accent.withValues(alpha: 0.5 * (1 - s)));
          }
        }
        // Embers rising off the armour for the whole pose.
        for (var i = 0; i < 6; i++) {
          final p = ((t * 0.9 + i * 0.167) % 1.0);
          final x = w * (0.30 + (i % 3) * 0.20) +
              math.sin(p * 5 + i) * w * 0.035;
          final y = h * 0.90 - p * h * 0.62;
          canvas.drawCircle(
              Offset(x, y),
              w * 0.014 * (1 - p) + w * 0.004,
              Paint()
                ..color = Color.lerp(accent, const Color(0xFFFFC46B), p * 0.5)!
                    .withValues(alpha: 0.75 * (1 - p) * pose.flourish));
        }
        // A low aura pooling around his feet.
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(w * 0.5, h * 0.94),
                width: w * 0.78,
                height: h * 0.14),
            Paint()
              ..color = accent.withValues(alpha: 0.16 * pose.flourish)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      case RoyalAction.salute:
        // Light running up the held blade, then a gold arc trailing it as he
        // sweeps out. The glint is the whole move: a sword held still is a
        // prop, a sword catching the light is a salute.
        //
        // The blade's position is recomputed the way [_frontWeapon] does it.
        // These accents paint outside the figure's squash transform, so it is
        // off by the squash — under 6%, and invisible on a soft highlight.
        final shoulder = Offset(w * 0.5 - w * 0.14, h * 0.575);
        final arm = pose.armWeapon;
        final hand =
            shoulder + Offset(math.sin(arm), math.cos(arm)) * (h * 0.125);
        final upright = arm.abs() < 0.6; // matches _weapon's rest band

        final glint = ((t - 0.26) / 0.24).clamp(0.0, 1.0);
        if (upright && glint > 0 && glint < 1) {
          final guard = Offset(hand.dx, hand.dy - h * 0.010);
          final tip = Offset(hand.dx, h * 0.085);
          final at =
              Offset.lerp(guard, tip, Curves.easeInOut.transform(glint))!;
          final lum = math.sin(glint * math.pi);
          canvas.drawCircle(
              at,
              w * 0.055,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.50 * lum)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
          canvas.drawLine(
              at.translate(0, h * 0.028),
              at.translate(0, -h * 0.028),
              Paint()
                ..strokeWidth = 2.4
                ..strokeCap = StrokeCap.round
                ..color = Colors.white.withValues(alpha: 0.90 * lum));
          // A four-point star as the light leaves the point.
          if (glint > 0.74) {
            final k = (glint - 0.74) / 0.26;
            _star(canvas, tip, w * 0.055 * k,
                Colors.white.withValues(alpha: 0.95 * (1 - k)));
          }
        }

        // Two motes of gold drifting off the steel while it is held. Enough to
        // say "ceremonial", not enough to turn a salute into fireworks — his
        // is the disciplined one of the six and the restraint IS the character.
        if (upright && glint > 0) {
          for (var i = 0; i < 2; i++) {
            final p = ((t * 1.3 + i * 0.5) % 1.0);
            _star(
                canvas,
                Offset(hand.dx + (i.isEven ? w : -w) * 0.055,
                    h * 0.42 - p * h * 0.24),
                w * 0.020 * (1 - p) * pose.flourish,
                accent.withValues(alpha: 0.75 * (1 - p) * pose.flourish));
          }
        }
      case RoyalAction.mend:
        // A heartbeat writing itself across the air, a wash of green light out
        // of the open kit, and healing plus-signs rising. In a BUDGET app the
        // medic reading a pulse is the joke and the point at once — the whole
        // Financial Health score is a vital sign.
        final emerald = royal.palette['E'] ?? const Color(0xFF2BB985);
        final write = ((t - 0.26) / 0.38).clamp(0.0, 1.0);
        final held = 1 - ((t - 0.80) / 0.20).clamp(0.0, 1.0);

        // Light spilling out of the opened case.
        final open = ((t - 0.14) / 0.18).clamp(0.0, 1.0) * held;
        if (open > 0) {
          canvas.drawCircle(
              Offset(w * 0.36, h * 0.44),
              w * (0.10 + 0.14 * open),
              Paint()
                ..color = emerald.withValues(alpha: 0.26 * open)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        }

        if (write > 0 && held > 0) {
          _ecgTrace(canvas, size, write, emerald, held);
        }

        // Plus-signs drifting up out of the glow.
        for (var i = 0; i < 5; i++) {
          final p = ((t * 1.05 + i * 0.2) % 1.0);
          final x = w * (0.24 + (i % 3) * 0.19) + math.sin(p * 4 + i) * w * 0.03;
          final y = h * 0.60 - p * h * 0.50;
          _plus(canvas, Offset(x, y), w * 0.026 * (1 - p * 0.55) + w * 0.006,
              emerald.withValues(alpha: 0.72 * (1 - p) * held));
        }

        // The all-clear: a clean pulse ring and a scatter of sparks.
        final clearP = ((t - 0.68) / 0.26).clamp(0.0, 1.0);
        if (clearP > 0 && clearP < 1) {
          canvas.drawCircle(
              Offset(w * 0.5, h * 0.46),
              w * (0.18 + 0.42 * clearP),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.0 * (1 - clearP) + 0.8
                ..color = emerald.withValues(alpha: 0.55 * (1 - clearP)));
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3 - 0.4;
            _star(
                canvas,
                Offset(w * 0.5, h * 0.46) +
                    Offset(math.cos(a), math.sin(a)) * w * (0.20 + 0.22 * clearP),
                w * 0.020 * (1 - clearP),
                Color.lerp(Colors.white, emerald, 0.4)!
                    .withValues(alpha: 0.85 * (1 - clearP)));
          }
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
      case RoyalAction.brace:
        // Deliberately the quietest accent in the court: grit kicked up where
        // the shield rim meets the ground, and one cold glint travelling the
        // spear. No stars, no hearts — he is not saying hello. Before this he
        // fell through to the cheer case and braced inside a ring of little
        // pink hearts, which is the exact opposite of the character.
        final at = Offset(w * 0.30, h * 0.945);
        for (var i = 0; i < 5; i++) {
          final p = ((t * 1.6 + i * 0.21) % 1.0);
          final a = math.pi + 0.35 + i * 0.28;
          canvas.drawCircle(
              at + Offset(math.cos(a), math.sin(a) * 0.55) * (w * 0.16 * p),
              w * 0.014 * (1 - p) + w * 0.004,
              Paint()
                ..color = body.ink
                    .withValues(alpha: 0.22 * (1 - p) * pose.flourish));
        }
        final glintP = ((t - 0.36) / 0.5).clamp(0.0, 1.0);
        if (glintP > 0 && glintP < 1) {
          canvas.drawCircle(
              Offset(w * 0.30 + w * 0.42 * glintP, h * 0.47),
              w * 0.030 * math.sin(glintP * math.pi),
              Paint()
                ..color = Colors.white.withValues(
                    alpha: 0.55 * math.sin(glintP * math.pi))
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        }
      case RoyalAction.thrust:
        // A straight streak down the line of the point — a thrust is the one
        // attack in the court with no arc in it at all, and drawing it with
        // the shared crescent would file him in with the slashers.
        final y = h * 0.50;
        for (final (len, thick, col) in [
          (0.46, 6.0, accent.withValues(alpha: 0.28 * pose.flourish)),
          (0.40, 2.4, Colors.white.withValues(alpha: 0.60 * pose.flourish)),
        ]) {
          canvas.drawLine(
              Offset(w * 0.42, y),
              Offset(w * (0.42 + len * pose.flourish), y),
              Paint()
                ..strokeWidth = thick
                ..strokeCap = StrokeCap.round
                ..color = col);
        }
      case RoyalAction.vault:
      case RoyalAction.flyKick:
        // Twin ribbons trailing the blades through the arc. Two arcs at
        // different radii read as two blades; one reads as a swoosh.
        for (final (rr, sweepMul, paintW, col) in [
          (0.46, 1.00, 5.0, accent.withValues(alpha: 0.26 * pose.flourish)),
          (0.38, 0.82, 2.4, Colors.white.withValues(alpha: 0.55 * pose.flourish)),
        ]) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(w * 0.5, h * 0.56), radius: w * rr),
            math.pi * 0.30,
            math.pi * 1.05 * sweepMul * pose.flourish,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = paintW
              ..color = col,
          );
        }
        // Speed lines behind her, so the air reads as moving too.
        for (var i = 0; i < 3; i++) {
          final p = ((t * 2.4 + i * 0.3) % 1.0);
          canvas.drawLine(
              Offset(w * (0.10 - 0.10 * p), h * (0.36 + i * 0.16)),
              Offset(w * (0.30 - 0.14 * p), h * (0.36 + i * 0.16)),
              Paint()
                ..strokeWidth = 2.0
                ..strokeCap = StrokeCap.round
                ..color = accent.withValues(
                    alpha: 0.30 * (1 - p) * pose.flourish));
        }
      case RoyalAction.bladeDance:
        // The blades spinning in her fingers, drawn as the arc each edge is
        // sweeping right now — a trail, chasing the blade round.
        //
        // Closed circles were the first attempt and they read as two hoops
        // hanging off her wrists: a full ring is a drawn object, and only the
        // partial arc reads as something moving fast enough to blur.
        for (final (cx, cy, rr, phase) in [
          (0.36, 0.63, 0.115, 0.0),
          (0.64, 0.61, 0.095, math.pi),
        ]) {
          final c = Offset(w * cx, h * cy);
          for (final (span, thick, col) in [
            (0.90, 4.0, accent.withValues(alpha: 0.26 * pose.flourish)),
            (0.55, 2.2, Colors.white.withValues(alpha: 0.62 * pose.flourish)),
          ]) {
            canvas.drawArc(
              Rect.fromCircle(center: c, radius: w * rr),
              pose.bladeSpin + phase - span,
              span,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeCap = StrokeCap.round
                ..strokeWidth = thick
                ..color = col,
            );
          }
        }
      case RoyalAction.daggerToss:
        // The thrown blade, drawn here because it has LEFT her hand — nothing
        // in the rig can hold a weapon that is not attached to an arm. Up,
        // over, and back down into the catch.
        final fly = (t / 0.74).clamp(0.0, 1.0);
        if (t < 0.76) {
          final arc = math.sin(fly * math.pi);
          final c = Offset(w * (0.42 + 0.16 * fly), h * (0.62 - 0.62 * arc));
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(fly * 6 * math.pi); // end-over-end
          final steel = royal.palette['S'] ?? const Color(0xFFC9D2DE);
          _shaft(canvas, Offset(0, h * 0.045), Offset(0, -h * 0.055),
              w * 0.024, steel, _darken(steel, 0.4));
          canvas.drawLine(
              Offset(0, h * 0.030),
              Offset(0, -h * 0.048),
              Paint()
                ..strokeWidth = 1.4
                ..strokeCap = StrokeCap.round
                ..color = accent);
          canvas.restore();
          // A faint absinthe trail marking the path it has already flown.
          canvas.drawArc(
            Rect.fromCircle(
                center: Offset(w * 0.50, h * 0.62), radius: h * 0.62),
            -math.pi * 0.62,
            math.pi * 0.30 * fly,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8
              ..color = accent.withValues(alpha: 0.30),
          );
        }
        // The sweep-kick's ground arc.
        final sweep = math.sin(((t - 0.20) / 0.34).clamp(0.0, 1.0) * math.pi);
        if (sweep > 0.02) {
          canvas.drawArc(
            Rect.fromCenter(
                center: Offset(w * 0.5, h * 0.90),
                width: w * 0.90,
                height: h * 0.16),
            math.pi * 0.05,
            math.pi * 0.90 * sweep,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 3.0
              ..color = accent.withValues(alpha: 0.45 * sweep),
          );
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
      case _Mount.none:
        _rideOnFoot(canvas, size);
      case _Mount.destrier:
        // Barded like the Dark Prince's, but a pale grey warhorse under steel
        // rather than an onyx one, and a sapphire mane instead of ember.
        _rideBeast(canvas, size,
            coat: const Color(0xFF9AA6B6),
            coatDark: const Color(0xFF6B7A8D),
            mane: const Color(0xFF4A8CFF),
            style: _BeastStyle.horse,
            gait: _Gait.charge,
            barded: true);
      case _Mount.horse:
        _rideBeast(canvas, size,
            coat: const Color(0xFFF4EFE6),
            coatDark: const Color(0xFFD8D2C4),
            mane: _gold,
            style: _BeastStyle.horse,
            gait: _Gait.gallop);
      case _Mount.darkhorse:
        _rideBeast(canvas, size,
            coat: const Color(0xFF3A3F4C), // a shade above the onyx armour
            coatDark: const Color(0xFF20232C),
            mane: royal.theme.accent,
            style: _BeastStyle.horse,
            gait: _Gait.stomp,
            barded: true,
            emberEye: true);
      case _Mount.pegasus:
        _rideBeast(canvas, size,
            coat: const Color(0xFFF6F1E8),
            coatDark: const Color(0xFFDCD2C4),
            mane: royal.theme.accent,
            style: _BeastStyle.unicorn,
            gait: _Gait.flight,
            winged: true);
      case _Mount.lion:
        _rideBeast(canvas, size,
            coat: const Color(0xFFD4A72C),
            coatDark: const Color(0xFF9C7A16),
            mane: const Color(0xFF6E4A2A),
            style: _BeastStyle.lion,
            gait: _Gait.prowl,
            arcane: true,
            roaring: action == RoyalAction.roar);
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
    _headArmor(canvas, size, pose);
    if (royal.weapon == RoyalWeapon.spear) {
      // Same order swap as [_figure], and it matters more here: a COUCHED
      // spear lies across the horse's neck at exactly the height the shield
      // covers, so in the shared order the entire charge had no spear in it.
      _arm(canvas, nearShoulder, pose.armFree, 0, size);
      _shield(canvas, size, nearShoulder, pose.armFree);
      _frontWeapon(canvas, size, farShoulder, pose);
      return;
    }
    _frontWeapon(canvas, size, farShoulder, pose);
    if (royal.weapon == RoyalWeapon.orbs) _orbs(canvas, size, front: true);
    _arm(canvas, nearShoulder, pose.armFree, 0, size);
    _shield(canvas, size, nearShoulder, pose.armFree);
  }

  _Pose _riderPose(double cyc) => _Pose(
        // The Sentinel has no free hand for reins — the shield is on that arm
        // — so it comes forward and low instead, covering the horse's shoulder
        // the way a barded charge actually works.
        armFree: royal.weapon == RoyalWeapon.spear ? 0.50 : 0.95,
        armWeapon: switch (royal.weapon) {
          // Charge! — and on the roar the blade goes all the way up, so the
          // Sovereign is presenting his lion rather than riding past on it.
          RoyalWeapon.knightSword || RoyalWeapon.warClub || RoyalWeapon.sword =>
            action == RoyalAction.roar ? -2.6 : -2.1,
          // COUCHED. A spear carried upright on horseback is a man commuting;
          // levelled across the horse's neck it is a charge, and it is the one
          // thing this royal's whole silhouette is built to do. Well past the
          // 0.6rad rest band, so the shaft rides the arm instead of standing.
          RoyalWeapon.spear => 1.45 + 0.05 * math.sin(cyc),
          _ => -0.35,
        },
        gaze: action == RoyalAction.roar ? 0 : 1,
        blink: action == RoyalAction.roar ? false : _blink(t),
        // He leans into it slightly on the beat, which the others do not.
        lean: royal.weapon == RoyalWeapon.spear ? 0.06 : 0,
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
      required _Gait gait,
      bool winged = false,
      bool barded = false,
      bool arcane = false,
      bool emberEye = false,
      bool roaring = false}) {
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final cx = w * 0.5;
    final ground = h * 0.94;
    final cyc = t * 2 * math.pi;

    // ── Gait ────────────────────────────────────────────────────────────────
    // Where the four beasts stop being the same animal. Each supplies its own
    // vertical motion, pitch, ride height and leg timing; `strike` is the
    // sharp 0→1 spike at the moment of ground contact, which only the stomp
    // uses. See [_Gait] for what each is meant to feel like.
    final s01 = (math.sin(cyc) + 1) / 2; // 0 at the bottom, 1 at the top
    // Roaring is a HALT, not a gait: the beast plants, rocks back on its
    // haunches and holds. Running the prowl underneath would have the lion
    // bounding away while it bellows at the user.
    final (bob, pitch, lift, phases, legSwing, strike) = roaring
        ? (
            -math.sin(t * math.pi).abs() * h * 0.020,
            -0.10 * Curves.easeOut.transform((t / 0.24).clamp(0.0, 1.0)) +
                0.06 * Curves.easeIn.transform(((t - 0.76) / 0.24).clamp(0.0, 1.0)),
            0.0,
            const [0.0, 0.0, 0.5, 0.5],
            1.0, // full-length legs: a braced halt still stands on them
            0.0,
          )
        : switch (gait) {
            _Gait.gallop => (
                -math.sin(cyc).abs() * h * 0.032,
                math.sin(cyc + 0.7) * 0.045,
                0.0,
                const [0.0, 0.15, 0.5, 0.65],
                1.0,
                0.0,
              ),
            // Hangs at the top, then slams — a power curve down, both leg pairs
            // landing together instead of rolling through four beats.
            _Gait.stomp => (
                -math.pow(s01, 2.2).toDouble() * h * 0.055,
                math.sin(cyc + 0.5) * 0.075,
                0.0,
                const [0.0, 0.06, 0.5, 0.56],
                1.15,
                math.pow(1 - s01, 3).toDouble(),
              ),
            // Airborne: a smooth both-ways sine with no ground slam anywhere in
            // it, riding higher because nothing is holding it up.
            _Gait.flight => (
                math.sin(cyc) * h * 0.045,
                math.sin(cyc + 1.1) * 0.030,
                -h * 0.075,
                const [0.0, 0.25, 0.5, 0.75],
                // Full-length: at 0.45 the legs vanished inside the belly and
                // she flew as a legless swan.
                1.0,
                0.0,
              ),
            // Low and level: almost no lift, a permanent forward pitch, and
            // fore/hind splitting wide apart as it eats ground.
            _Gait.charge => (
                -math.pow(s01, 1.6).toDouble() * h * 0.016,
                0.15 + math.sin(cyc) * 0.022,
                h * 0.030, // positive = rides LOWER than the others
                const [0.0, 0.42, 0.08, 0.50],
                1.30,
                0.0,
              ),
            // A long bound with a float at the apex: sharp push, long hang.
            _Gait.prowl => (
                -math.pow(s01, 0.55).toDouble() * h * 0.048,
                math.sin(cyc + 0.9) * 0.060,
                -h * 0.012,
                const [0.0, 0.10, 0.46, 0.56],
                1.25,
                0.0,
              ),
          };

    // Airborne mounts cast a smaller, softer shadow further below them.
    _shadow(canvas, Offset(cx, ground),
        uw * (gait == _Gait.flight ? 0.20 : 0.27), _Pose(bob: bob / h));

    if (gait == _Gait.stomp && !roaring) _stompImpact(canvas, size, strike);

    // The Sovereign's zip: two trailing smears of the whole rig, drawn before
    // the real one so it reads as something outrunning its own image. A halted
    // beast has nothing to outrun, so the roar drops them.
    if (arcane && !roaring) {
      for (var g = 2; g >= 1; g--) {
        canvas.saveLayer(
            Offset.zero & size,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.26 / g));
        canvas.translate(-uw * 0.055 * g, h * 0.004 * g);
        _beastRig(canvas, size,
            coat: coat,
            coatDark: coatDark,
            mane: mane,
            style: style,
            bob: bob,
            pitch: pitch,
            lift: lift,
            phases: phases,
            legSwing: legSwing,
            folded: gait == _Gait.flight,
            winged: winged,
            barded: barded,
            emberEye: emberEye,
            planted: roaring);
        canvas.restore();
      }
    }

    _beastRig(canvas, size,
        coat: coat,
        coatDark: coatDark,
        mane: mane,
        style: style,
        bob: bob,
        pitch: pitch,
        lift: lift,
        phases: phases,
        legSwing: legSwing,
        folded: gait == _Gait.flight,
        winged: winged,
        barded: barded,
        emberEye: emberEye,
        planted: roaring,
        roaring: roaring);

    // Ground FX: dust for anything touching the ground, motes for the flier,
    // arcane sparks for the Sovereign. A halt kicks up nothing.
    if (roaring) return;
    switch (gait) {
      case _Gait.flight:
        _flightMotes(canvas, size);
      case _Gait.prowl:
        _arcaneStreaks(canvas, size, cyc);
        _dust(canvas, size, cyc);
      case _Gait.gallop:
      case _Gait.stomp:
      case _Gait.charge:
        _dust(canvas, size, cyc);
    }
  }

  /// One frame of the quadruped itself. Split out of [_rideBeast] so the
  /// Sovereign can draw it more than once for its afterimage trail.
  void _beastRig(Canvas canvas, Size size,
      {required Color coat,
      required Color coatDark,
      required Color mane,
      required _BeastStyle style,
      required double bob,
      required double pitch,
      required double lift,
      required List<double> phases,
      required double legSwing,
      required bool folded,
      required bool winged,
      required bool barded,
      required bool emberEye,
      bool planted = false,
      bool roaring = false}) {
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final cx = w * 0.5;
    final ground = h * 0.94;
    final cyc = t * 2 * math.pi;
    final lion = style == _BeastStyle.lion;

    canvas.save();
    canvas.translate(cx, ground);
    canvas.rotate(pitch);
    canvas.translate(-cx, -ground);
    canvas.translate(0, bob + lift);

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

    // The far wing, behind the body, so the near one can layer over the rider.
    if (winged) _wing(canvas, size, mane, coat, far: true);

    // Four stubby legs. [phases] and [legSwing] come from the gait: a rolling
    // four-beat for the gallop, paired for the stomp, folded for the flier,
    // braced and still for a roaring halt.
    //
    // Every leg is drawn as thigh + cannon over a knee, because the belly of
    // the body capsule reaches to ~0.74h: a single short capsule from the hip
    // at 0.63h simply disappears inside it, which is how the pegasus and the
    // roaring lion both ended up with no legs at all.
    final hipXs = [-0.135, -0.075, 0.065, 0.125];
    final legLen = h * 0.235 * legSwing;
    for (var i = 0; i < 4; i++) {
      final s = math.sin(cyc + phases[i] * 2 * math.pi);
      final hip = Offset(cx + uw * hipXs[i] - uw * 0.03, h * 0.63);
      final tuck = math.max(0.0, -s) * 0.30; // folds on the back-swing
      final Offset knee, foot;
      if (planted) {
        // A braced halt: hind legs gathered under the haunches, forelegs
        // straight and locked out in front.
        const brace = [-0.42, -0.26, 0.12, 0.26];
        final a = brace[i];
        knee = hip + Offset(math.sin(a) * legLen * 0.52, legLen * 0.50);
        foot = knee + Offset(math.sin(a * 0.3) * legLen * 0.44, legLen * 0.50);
      } else {
        // The flier does NOT get its own folded pose. Two attempts at one gave
        // four stubs in a row (wheels) and then four horizontal capsules
        // (rollers) — at this scale a tucked limb has too little of itself
        // showing past the belly to read as a limb at all. She canters through
        // the air instead: the ordinary leg cycle, swung shallower and raked
        // back, which is unmistakably legs and unmistakably not on the ground.
        final bias = folded ? -0.42 : 0.0;
        final a = s * (folded ? 0.45 : 0.75) + bias;
        knee = hip +
            Offset(math.sin(a) * legLen * 0.52,
                math.cos(a) * legLen * 0.52 * (1 - tuck));
        foot = knee +
            Offset(math.sin(a * 1.25) * legLen * 0.48,
                math.cos(a) * legLen * 0.48 * (1 - tuck));
      }
      final legColor = i < 2 ? coatDark : coat;
      final hoof = h * (folded ? 0.032 : 0.042);
      _capsule(canvas, hip, knee, h * 0.078, legColor);
      _capsule(canvas, knee, foot, h * 0.062, legColor);
      canvas.drawCircle(foot, hoof, Paint()..color = _darken(coatDark, 0.3));
      canvas.drawCircle(foot, hoof, _inkStroke..strokeWidth = 1.0);
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

    // Barding: plate over the caparison, so the Dark Prince's steed is armoured
    // like its rider rather than merely painted darker.
    if (barded) _barding(canvas, size, bodyC, uw, coatDark);

    // The rider, astride the caparison.
    final riderH = h * 0.66;
    final riderW = riderH * 0.78;
    canvas.save();
    canvas.translate(bodyC.dx - riderW / 2, h * 0.525 - riderH * 0.80);
    _figureSeated(canvas, Size(riderW, riderH), _riderPose(cyc));
    canvas.restore();

    // The near wing, over the rider — this is what sells "astride a flier"
    // rather than "standing behind a pair of wings".
    if (winged) _wing(canvas, size, mane, coat, far: false);

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

    // Head + neck armour goes on last, over the finished head.
    if (barded) _bardingHead(canvas, size, neckRoot, headC, muzzleC);

    // Rein, from the rider's rein hand to the muzzle.
    canvas.drawLine(
        Offset(bodyC.dx + riderW * 0.20, h * 0.46),
        muzzleC.translate(-h * 0.02, -h * 0.01),
        Paint()
          ..strokeWidth = 1.4
          ..color = _darken(body.main, 0.3));

    // The roar replaces the profile head with a front-facing one, so it is
    // aimed at the VIEWER rather than at whatever the lion is walking toward.
    if (roaring) _lionRoar(canvas, size, headC);

    canvas.restore();
  }

  /// The Sovereign's lion turning out of the ride to roar at the user: the
  /// muzzle swings around to face front, the jaws open, the mane flares, and
  /// the sound leaves as rings expanding toward the viewer.
  ///
  /// Drawn over the profile head rather than instead of it — a lion mid-turn
  /// keeps the near cheek and mane of the side view, so overpainting reads as
  /// the head rotating rather than as two heads.
  void _lionRoar(Canvas canvas, Size size, Offset headC) {
    final h = size.height;
    final accent = royal.theme.accent;
    const coat = Color(0xFFD4A72C);
    const coatDark = Color(0xFF9C7A16);
    const maneC = Color(0xFF6E4A2A);
    // One roar per action pass: wind up, blast, settle.
    final open = Curves.easeOutBack
        .transform(((t - 0.16) / 0.22).clamp(0.0, 1.0))
        .clamp(0.0, 1.15);
    final close = Curves.easeInOut.transform(((t - 0.74) / 0.26).clamp(0.0, 1.0));
    final gape = (open * (1 - close)).clamp(0.0, 1.15);
    final c = headC.translate(h * 0.045, h * 0.010);

    // Mane flares outward with the roar.
    final maneR = h * 0.205 * (1 + gape * 0.16);
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * 2 * math.pi;
      final spike = maneR * (1.06 + 0.16 * math.sin(i * 2.7 + t * 6));
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * spike * 0.72,
          h * 0.058, Paint()..color = i.isEven ? maneC : _darken(maneC, 0.18));
    }
    canvas.drawCircle(c, maneR * 0.80, Paint()..color = _lighten(maneC, 0.10));
    canvas.drawCircle(c, maneR * 0.80, _inkStroke..strokeWidth = 1.3);

    // Face.
    canvas.drawCircle(c, h * 0.135, Paint()..color = coat);
    canvas.drawCircle(c, h * 0.135, _inkStroke..strokeWidth = 1.2);
    // Brows down into a glare.
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(
          c + Offset(s * h * 0.088, -h * 0.070),
          c + Offset(s * h * 0.026, -h * 0.040),
          Paint()
            ..strokeWidth = h * 0.014
            ..strokeCap = StrokeCap.round
            ..color = body.ink);
      // Eyes: hot slits under the brow.
      canvas.drawOval(
          Rect.fromCenter(
              center: c + Offset(s * h * 0.055, -h * 0.022),
              width: h * 0.040,
              height: h * 0.028 * (1 - gape * 0.35)),
          Paint()..color = _lighten(accent, 0.25));
      canvas.drawCircle(c + Offset(s * h * 0.055, -h * 0.022), h * 0.010,
          Paint()..color = body.ink);
    }
    // Muzzle + open jaw.
    canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(0, h * 0.048),
            width: h * 0.130,
            height: h * 0.080),
        Paint()..color = _lighten(coat, 0.30));
    _triangle(canvas, c.translate(0, h * 0.030), math.pi / 2, h * 0.026,
        h * 0.020, body.ink);
    final jaw = Rect.fromCenter(
        center: c.translate(0, h * 0.090 + h * 0.030 * gape),
        width: h * 0.115 * (1 + gape * 0.18),
        height: h * 0.030 + h * 0.105 * gape);
    canvas.drawOval(jaw, Paint()..color = const Color(0xFF3A1418));
    canvas.drawOval(jaw, _inkStroke..strokeWidth = 1.2);
    if (gape > 0.15) {
      // Tongue + fangs, only once the jaw is genuinely open.
      canvas.drawOval(
          Rect.fromCenter(
              center: jaw.center.translate(0, jaw.height * 0.20),
              width: jaw.width * 0.46,
              height: jaw.height * 0.44),
          Paint()..color = const Color(0xFFCC5A66));
      for (final s in [-1.0, 1.0]) {
        _triangle(canvas, jaw.center + Offset(s * jaw.width * 0.26, -jaw.height * 0.10),
            math.pi / 2, jaw.height * 0.34, h * 0.014, Colors.white);
        _triangle(canvas, jaw.center + Offset(s * jaw.width * 0.24, jaw.height * 0.44),
            -math.pi / 2, jaw.height * 0.26, h * 0.012, Colors.white);
      }
    }
    // Whisker dots.
    for (final s in [-1.0, 1.0]) {
      for (var i = 0; i < 2; i++) {
        canvas.drawCircle(
            c + Offset(s * h * (0.042 + i * 0.018), h * 0.044),
            h * 0.005,
            Paint()..color = coatDark);
      }
    }

    // The sound: rings racing out of the muzzle toward the viewer, growing and
    // fading. Three staggered so it reads as a sustained roar, not one pop.
    for (var i = 0; i < 3; i++) {
      final p = ((t * 2.4 - i * 0.26) % 1.0);
      if (t < 0.16 || close >= 1) break;
      final rr = h * (0.16 + 0.62 * p);
      canvas.drawCircle(
          c,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = h * 0.026 * (1 - p) * gape
            ..color = Color.lerp(Colors.white, accent, 0.45)!
                .withValues(alpha: 0.42 * (1 - p) * gape));
    }
  }

  /// One feathered wing for the Princess's pegasus. The far wing is drawn
  /// behind the body and the near one over the rider; both beat on the same
  /// cycle, the near one leading slightly so they don't read as one flat pair.
  ///
  /// The wings are IVORY with accent-tinted tips, not the accent itself: tinted
  /// pink they landed on a pink gown over a pink caparison and vanished into
  /// her, which is why the first pegasus read as a plain unicorn. They also
  /// need a leading edge — a swept wing-arm with a covert row along it — or a
  /// fan of feathers alone reads as a cape.
  void _wing(Canvas canvas, Size size, Color feather, Color coat,
      {required bool far}) {
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final cyc = t * 2 * math.pi + (far ? 0.0 : 0.40);
    final beat = math.sin(cyc); // -1 down-stroke … +1 up-stroke

    // Rooted on the shoulder, ABOVE the body line, so the wing clears the
    // rider instead of fanning out beside the saddle.
    final root = Offset(w * 0.5 - uw * 0.035, h * (far ? 0.485 : 0.515));
    final span = uw * (far ? 0.36 : 0.42);
    // Ivory in front, dimmed toward the coat behind, so the pair reads as two
    // wings at different depths rather than one flat shape.
    final quill = far
        ? Color.lerp(const Color(0xFFF3ECFF), coat, 0.42)!
        : const Color(0xFFFDFAFF);
    final tipTint = far ? Color.lerp(feather, coat, 0.45)! : feather;

    canvas.save();
    canvas.translate(root.dx, root.dy);
    // Wings sweep forward on the down-stroke and rake back on the up-stroke;
    // the vertical squeeze on the down-beat is the "grab" that sells lift.
    canvas.rotate(beat * 0.46 - 0.06);
    canvas.scale(1.0, 1.0 - beat * 0.12);

    // ONE swept silhouette, then feather lines inside it. Drawing each primary
    // as its own quad radiating from the shoulder gave a spiky starburst — a
    // wing is a solid paddle whose trailing edge happens to be scalloped, and
    // the eye reads the outline long before it reads the feathers.
    final tip = Offset(-span * 0.97, -span * 0.30);
    final heel = Offset(-span * 0.06, span * 0.30);
    const scallops = 4;
    final notches = <Offset>[];
    final wing = Path()..moveTo(0, 0);
    // Leading edge: bows upward out to the tip.
    wing.quadraticBezierTo(-span * 0.42, -span * 0.50, tip.dx, tip.dy);
    // Trailing edge: comes home in scallops, one per primary.
    var prev = tip;
    for (var i = 1; i <= scallops; i++) {
      final p = Offset.lerp(tip, heel, i / scallops)!;
      final mid = Offset.lerp(prev, p, 0.5)!
          .translate(span * 0.05, span * 0.14);
      wing.quadraticBezierTo(mid.dx, mid.dy, p.dx, p.dy);
      notches.add(p);
      prev = p;
    }
    wing.close();

    canvas.drawPath(wing, Paint()..color = quill);
    // Accent wash gathering at the tip only.
    canvas.drawPath(
        wing,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(tip.dx * 0.30, tip.dy * 0.30),
            tip,
            [tipTint.withValues(alpha: 0), tipTint.withValues(alpha: 0.80)],
          ));
    canvas.drawPath(wing, _inkStroke..strokeWidth = 1.2);

    // Feather separation: a line from up near the leading edge down to each
    // scallop notch.
    final vane = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = body.ink.withValues(alpha: 0.55);
    for (var i = 0; i < notches.length; i++) {
      final k = (i + 1) / (notches.length + 1);
      final from = Offset.lerp(Offset(-span * 0.10, -span * 0.10), tip, k)!;
      canvas.drawLine(from, notches[i], vane);
    }

    // Covert row along the leading edge, hiding where the vanes meet the arm.
    // NO outline on these: ringed circles on a pale wing read as holes punched
    // through it. They are a texture, not a part.
    for (var i = 0; i < 4; i++) {
      final k = 0.10 + i * 0.20;
      final p = Offset.lerp(Offset.zero, tip, k)! +
          Offset(0, -span * 0.08 * math.sin(k * math.pi));
      final r = h * (0.044 - i * 0.005);
      canvas.drawCircle(
          p,
          r,
          Paint()
            ..color = Color.lerp(quill, tipTint, 0.16 + i * 0.10)!
                .withValues(alpha: 0.85));
    }
    // Shoulder covert.
    canvas.drawCircle(Offset.zero, h * 0.052, Paint()..color = quill);
    canvas.drawCircle(Offset.zero, h * 0.052, _inkStroke..strokeWidth = 1.0);
    canvas.restore();
  }

  /// Plate barding for the Dark Prince's steed: a chest peytral and a flank
  /// plate, both onyx with an accent rivet line.
  void _barding(
      Canvas canvas, Size size, Offset bodyC, double uw, Color coatDark) {
    final h = size.height;
    final accent = royal.theme.accent;
    // Deliberately NOT the coat's own dark: onyx plate on an onyx horse under
    // an onyx caparison is invisible. Gunmetal reads as armour against all
    // three, with a lit top edge to sell the metal.
    const plate = Color(0xFF5B6474);
    const plateLit = Color(0xFF8B95A8);

    // Flank plate over the caparison.
    final flank = Path()
      ..moveTo(bodyC.dx - uw * 0.075, h * 0.560)
      ..lineTo(bodyC.dx + uw * 0.070, h * 0.560)
      ..lineTo(bodyC.dx + uw * 0.058, h * 0.668)
      ..quadraticBezierTo(
          bodyC.dx, h * 0.700, bodyC.dx - uw * 0.062, h * 0.668)
      ..close();
    _fillInked(canvas, flank, plate);
    // Lit top edge — the bevel that makes it read as plate, not a patch.
    canvas.drawLine(
        Offset(bodyC.dx - uw * 0.072, h * 0.567),
        Offset(bodyC.dx + uw * 0.067, h * 0.567),
        Paint()
          ..strokeWidth = h * 0.011
          ..strokeCap = StrokeCap.round
          ..color = plateLit);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
          Offset(bodyC.dx - uw * 0.045 + i * uw * 0.045, h * 0.604),
          h * 0.011,
          Paint()..color = accent.withValues(alpha: 0.9));
    }

    // Peytral across the chest. Sits BELOW the neck root: the neck capsule is
    // painted after the barding, so anything up at the shoulder line is simply
    // covered over.
    final peytral = Path()
      ..moveTo(bodyC.dx + uw * 0.085, h * 0.628)
      ..lineTo(bodyC.dx + uw * 0.158, h * 0.640)
      ..lineTo(bodyC.dx + uw * 0.145, h * 0.716)
      ..quadraticBezierTo(bodyC.dx + uw * 0.112, h * 0.735,
          bodyC.dx + uw * 0.078, h * 0.706)
      ..close();
    _fillInked(canvas, peytral, plate);
    canvas.drawLine(
        Offset(bodyC.dx + uw * 0.090, h * 0.638),
        Offset(bodyC.dx + uw * 0.152, h * 0.650),
        Paint()
          ..strokeWidth = h * 0.010
          ..strokeCap = StrokeCap.round
          ..color = plateLit);
    canvas.drawCircle(Offset(bodyC.dx + uw * 0.118, h * 0.678), h * 0.013,
        Paint()..color = accent.withValues(alpha: 0.9));

    // Spiked crupper over the rump — the only piece visible from behind, and
    // the one that makes the silhouette read as armoured rather than draped.
    for (var i = 0; i < 3; i++) {
      final base = Offset(
          bodyC.dx - uw * (0.100 + i * 0.030), h * (0.516 + i * 0.004));
      _triangle(canvas, base.translate(-uw * 0.014, -h * 0.042),
          -math.pi / 2 - 0.35, h * 0.052, h * 0.016, plateLit);
    }
  }

  /// The war horse's head and neck armour: a spiked chanfron over the face and
  /// overlapping criniere lames down the crest.
  ///
  /// Painted AFTER the neck and head — [_barding] runs before them and anything
  /// it puts up at the shoulder line is simply covered over. The face plate is
  /// what does the intimidating: a barded body with a soft friendly horse head
  /// on the end of it reads as a horse in a costume.
  void _bardingHead(Canvas canvas, Size size, Offset neckRoot, Offset headC,
      Offset muzzleC) {
    final h = size.height;
    final accent = royal.theme.accent;
    const plate = Color(0xFF5B6474);
    const plateLit = Color(0xFF8B95A8);
    const plateDark = Color(0xFF343B47);

    // Criniere: five lames stepping down the neck, each overlapping the last.
    for (var i = 0; i < 5; i++) {
      final k = i / 4;
      final c = Offset.lerp(headC.translate(-h * 0.055, h * 0.030),
          neckRoot.translate(-h * 0.020, -h * 0.020), k)!;
      final lame = Path()
        ..moveTo(c.dx - h * 0.052, c.dy - h * 0.020)
        ..lineTo(c.dx + h * 0.052, c.dy - h * 0.034)
        ..lineTo(c.dx + h * 0.046, c.dy + h * 0.016)
        ..quadraticBezierTo(c.dx, c.dy + h * 0.034, c.dx - h * 0.050,
            c.dy + h * 0.012)
        ..close();
      _fillInked(canvas, lame, i.isEven ? plate : plateDark);
    }

    // Chanfron: the face plate, from between the ears down over the muzzle,
    // with a cut-out that leaves the ember eye glaring through.
    final chanfron = Path()
      ..moveTo(headC.dx - h * 0.070, headC.dy - h * 0.104)
      ..quadraticBezierTo(headC.dx + h * 0.070, headC.dy - h * 0.130,
          headC.dx + h * 0.104, headC.dy - h * 0.058)
      ..lineTo(muzzleC.dx + h * 0.046, muzzleC.dy - h * 0.026)
      ..quadraticBezierTo(muzzleC.dx + h * 0.052, muzzleC.dy + h * 0.030,
          muzzleC.dx - h * 0.006, muzzleC.dy + h * 0.034)
      ..lineTo(headC.dx - h * 0.010, headC.dy + h * 0.062)
      ..quadraticBezierTo(headC.dx - h * 0.078, headC.dy + h * 0.010,
          headC.dx - h * 0.070, headC.dy - h * 0.104)
      ..close();
    _fillInked(canvas, chanfron, plate);
    // Lit ridge down the centre of the face.
    canvas.drawLine(
        headC.translate(h * 0.014, -h * 0.096),
        muzzleC.translate(h * 0.010, -h * 0.010),
        Paint()
          ..strokeWidth = h * 0.010
          ..strokeCap = StrokeCap.round
          ..color = plateLit);
    // Eye cut-out, ember burning inside it.
    final eyeP = headC.translate(h * 0.022, -h * 0.022);
    canvas.drawOval(
        Rect.fromCenter(
            center: eyeP, width: h * 0.062, height: h * 0.040),
        Paint()..color = const Color(0xFF12141A));
    final glow = 0.72 + 0.28 * math.sin(t * 2 * math.pi * 2);
    canvas.drawCircle(
        eyeP,
        h * 0.040,
        Paint()
          ..color = accent.withValues(alpha: 0.34 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(
        eyeP, h * 0.017, Paint()..color = accent.withValues(alpha: glow));

    // The spike between the ears — a war horse's unicorn, and the single
    // clearest "this one is armoured" cue at a glance.
    _triangle(canvas, headC.translate(h * 0.030, -h * 0.250), -math.pi / 2 + 0.18,
        h * 0.130, h * 0.026, plateLit);
    // Ear guards.
    for (final s in [-1.0, 1.0]) {
      final ear = headC + Offset(s * h * 0.05 - h * 0.015, -h * 0.115);
      _triangle(canvas, ear.translate(0, -h * 0.012), -math.pi / 2,
          h * 0.070, h * 0.026, plateDark);
    }
  }

  /// The shock of the Dark Prince's hooves landing: a widening ground ring and
  /// a spray of grit, both keyed to [strike] (1 at the instant of contact).
  void _stompImpact(Canvas canvas, Size size, double strike) {
    if (strike < 0.02) return;
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final ground = h * 0.945;
    final accent = royal.theme.accent;

    // Ring, widening and fading as the shock spreads out.
    final spread = 1 - strike;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, ground),
            width: uw * (0.20 + spread * 0.42),
            height: h * (0.030 + spread * 0.055)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.012 * strike
          ..color = accent.withValues(alpha: 0.55 * strike));

    // Grit thrown out sideways along the ground.
    for (var i = 0; i < 5; i++) {
      final dir = i.isEven ? -1.0 : 1.0;
      final k = (i + 1) / 5;
      canvas.drawCircle(
          Offset(w * 0.5 + dir * uw * 0.10 * k * (1 + spread * 1.6),
              ground - h * 0.055 * strike * k),
          h * 0.016 * strike * (1 - k * 0.5),
          Paint()..color = body.ink.withValues(alpha: 0.22 * strike));
    }
  }

  /// The pegasus leaves motes of light where a galloping mount would leave
  /// dust — nothing it does touches the ground.
  void _flightMotes(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final accent = royal.theme.accent;
    for (var i = 0; i < 5; i++) {
      final p = ((t * 1.3 + i * 0.2) % 1.0);
      final drift = Offset(w * 0.26 - p * w * 0.22, h * 0.70 + p * h * 0.10);
      final fade = (1 - p);
      _star(canvas, drift, w * 0.016 * fade + w * 0.004,
          Color.lerp(Colors.white, accent, 0.5)!.withValues(alpha: 0.8 * fade));
    }
  }

  /// Speed smears behind the Sovereign — the drawn half of "zipping about".
  void _arcaneStreaks(Canvas canvas, Size size, double cyc) {
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final accent = royal.theme.accent;
    for (var i = 0; i < 4; i++) {
      final p = ((t * 2.2 + i * 0.25) % 1.0);
      final y = h * (0.50 + i * 0.085);
      final x0 = w * 0.44 - p * uw * 0.30;
      canvas.drawLine(
          Offset(x0, y),
          Offset(x0 - uw * 0.11 * (1 - p * 0.4), y),
          Paint()
            ..strokeWidth = h * 0.011 * (1 - p)
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(Colors.white, accent, 0.65)!
                .withValues(alpha: 0.45 * (1 - p)));
    }
    // A soft aura riding with the beast.
    canvas.drawCircle(
        Offset(w * 0.5, h * 0.60),
        uw * 0.24,
        Paint()
          ..color = accent.withValues(alpha: 0.10 + 0.04 * math.sin(cyc))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  }

  /// The Empress's ride: a floating gold palanquin drifting on a cushion of
  /// sparkles — no beast would presume to carry her.
  void _ridePalanquin(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final cx = w * 0.5;
    final cyc = t * 2 * math.pi;

    // Elegance is compound motion at different rates. A single sine reads as a
    // machine bobbing; a slow rise crossed with an even slower sway, plus a
    // roll that LAGS the rise the way a boat's does, reads as something being
    // carried. Nothing here is fast — that is the point.
    final rise = math.sin(cyc * 0.62) * h * 0.030;
    final sway = math.sin(cyc * 0.37 + 1.1) * uw * 0.012;
    final roll = math.sin(cyc * 0.62 - 0.85) * 0.030; // trails the rise
    final hover = rise - h * 0.05;

    _shadow(canvas, Offset(cx, h * 0.94), uw * 0.24, const _Pose(bob: -0.05));

    // Silk streamers off the rear poles, trailing the sway.
    for (var i = 0; i < 2; i++) {
      final anchor = Offset(cx - uw * 0.34, h * 0.700 + hover + i * h * 0.030);
      final drift = math.sin(cyc * 0.5 - i * 0.7) * h * 0.030;
      final silk = Path()
        ..moveTo(anchor.dx, anchor.dy)
        ..quadraticBezierTo(anchor.dx - uw * 0.09, anchor.dy + drift,
            anchor.dx - uw * 0.17, anchor.dy + drift * 1.7)
        ..quadraticBezierTo(anchor.dx - uw * 0.09,
            anchor.dy + drift + h * 0.020, anchor.dx, anchor.dy + h * 0.016)
        ..close();
      canvas.drawPath(
          silk,
          Paint()
            ..color = royal.theme.accent
                .withValues(alpha: i == 0 ? 0.55 : 0.35));
    }

    // Sparkle wake beneath the deck.
    for (var i = 0; i < 5; i++) {
      final p = (t * 1.5 + i * 0.2) % 1.0;
      final sp = Offset(cx + uw * (0.18 - p * 0.42),
          h * 0.80 + math.sin(p * 9 + i) * h * 0.03);
      _star(canvas, sp, h * 0.022 * (1 - p) + h * 0.006,
          royal.theme.accent.withValues(alpha: 0.55 * (1 - p)));
    }

    canvas.save();
    canvas.translate(sway, hover);
    // Roll about the deck's centre, so the whole litter tips as one.
    canvas.translate(cx, h * 0.66);
    canvas.rotate(roll);
    canvas.translate(-cx, -h * 0.66);

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
  /// The Huntress's traversal: no mount, so she crosses on her own legs.
  ///
  /// Run-up, launch, a full somersault through the middle of the span, then a
  /// crouched landing and a run-out. The rotation is applied to the whole
  /// standing figure rather than animated limb by limb — at this scale a
  /// tumbling silhouette reads as a somersault, and posing one frame by frame
  /// would fight the shared rig for no visible gain.
  void _rideOnFoot(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final uw = math.min(w, h * 1.7);
    final ground = h * 0.92;
    // Left-to-right across the usable span, matching the mounted rides.
    final x = w * 0.5 + (t - 0.5) * uw * 0.86;

    // The airborne window. Outside it she is simply running.
    //
    // 58% of the crossing rather than the original 44%: the rotation is one
    // full turn however long it is given, so a narrow window spins her fast
    // enough that the tumble reads as a flicker. Widening the window is what
    // slows the turn down — the run-up and run-out lose the time, and they are
    // the parts you least need to see.
    const a = 0.22, b = 0.80;
    final air = (t >= a && t < b) ? (t - a) / (b - a) : -1.0;

    if (air < 0) {
      final crouch = t < a
          ? Curves.easeIn.transform(((t - (a - 0.10)) / 0.10).clamp(0.0, 1.0))
          : Curves.easeOut.transform((1 - (t - b) / 0.12).clamp(0.0, 1.0));
      _onFootFigure(canvas, size,
          at: Offset(x, h * 0.045 * crouch),
          pose: _poseFor(RoyalAction.run, (t * 6) % 1.0),
          as: RoyalAction.run);
      return;
    }

    // Airborne: a parabola with one full rotation about her own centre.
    final lift = math.sin(air * math.pi);
    final rise = h * 0.36 * lift;
    // The shadow stays on the ground and shrinks as she leaves it.
    _shadow(canvas, Offset(x, ground), uw * 0.10 * (1 - 0.45 * lift),
        const _Pose());
    _onFootFigure(canvas, size,
        at: Offset(x, -rise),
        pose: _poseFor(RoyalAction.vault, air),
        as: RoyalAction.vault,
        // Rotation about her own middle, not the box's: the pivot has to ride
        // the figure or she orbits a point in space instead of tumbling.
        spin: air * 2 * math.pi);
  }

  /// Draws the STANDING figure inside a wide ride box, at the standing box's
  /// own proportions, centred on [at].dx and offset by [at].dy.
  ///
  /// The whole point is that `size` here is the 150x96 ride box while the
  /// figure is authored for a 78x100 portrait one. Handing the wide box
  /// straight to [_paintStanding] scales the head — which is `w * 0.66` — to
  /// 99px inside a 96px-tall frame: a head bigger than the entire cell, with
  /// the body somewhere underneath it. On a somersault that is all you see,
  /// and it is exactly what shipped: a giant head rolling across the screen.
  void _onFootFigure(Canvas canvas, Size size,
      {required Offset at,
      required _Pose pose,
      required RoyalAction as,
      double spin = 0}) {
    final h = size.height;
    // Same 0.78 aspect as the host's standing box.
    final box = Size(h * 0.78, h);
    canvas.save();
    canvas.translate(at.dx - box.width / 2, at.dy);
    if (spin != 0) {
      // Her middle: below the big head, above the hips.
      final pivot = Offset(box.width * 0.5, box.height * 0.62);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(spin);
      canvas.translate(-pivot.dx, -pivot.dy);
    }
    _paintStanding(canvas, box, pose, as: as);
    canvas.restore();
  }

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
      case RoyalAction.slash:
        // A cross-body cut: coil back-high, rip through the diagonal, follow
        // through low. Snappier than the overhead smash — all edge, no thud.
        final coil = Curves.easeOut.transform((t / 0.38).clamp(0.0, 1.0));
        final cut =
            Curves.easeIn.transform(((t - 0.38) / 0.14).clamp(0.0, 1.0));
        final follow =
            Curves.easeOut.transform(((t - 0.52) / 0.48).clamp(0.0, 1.0));
        return _Pose(
          lean: -0.08 * coil + 0.26 * cut - 0.16 * follow,
          squash: 1 + 0.06 * coil - 0.14 * cut + 0.09 * follow,
          armWeapon: -0.35 - 2.35 * coil + 3.6 * cut - 0.9 * follow,
          armFree: 0.15 + 0.25 * coil - 0.55 * cut + 0.3 * follow,
          legPhase: cut * 0.7 - follow * 0.5,
          stride: cut * 0.9,
          blink: false,
          gaze: 1,
          flourish: cut * (1 - follow),
        );
      case RoyalAction.slice:
        // A couched charge-cut: the lance drops level, a deep lunge drives it
        // clean through, then the knight straightens out of the follow-through.
        final couch = Curves.easeOut.transform((t / 0.30).clamp(0.0, 1.0));
        final drive =
            Curves.easeInOut.transform(((t - 0.30) / 0.30).clamp(0.0, 1.0));
        final recover =
            Curves.easeOut.transform(((t - 0.62) / 0.38).clamp(0.0, 1.0));
        return _Pose(
          lean: 0.10 * couch + 0.22 * drive - 0.24 * recover,
          squash: 1 - 0.05 * couch - 0.06 * drive + 0.08 * recover,
          armWeapon: -0.3 - 1.15 * couch + 2.75 * drive - 1.05 * recover,
          armFree: 0.2 + 0.5 * couch - 0.4 * drive,
          legPhase: drive * 0.8 - recover * 0.6,
          stride: 0.9,
          blink: false,
          gaze: 1,
          flourish: drive * (1 - recover),
        );
      case RoyalAction.shoot:
        // One arrow: the bow arm levels out at the shoulder, the string hand
        // draws to the cheek, the release snaps. The host repeats this action
        // per arrow and flies the projectile itself.
        final raise = Curves.easeOut.transform((t / 0.26).clamp(0.0, 1.0));
        final draw =
            Curves.easeInOut.transform(((t - 0.26) / 0.34).clamp(0.0, 1.0));
        final rel =
            Curves.easeOut.transform(((t - 0.72) / 0.28).clamp(0.0, 1.0));
        return _Pose(
          lean: 0.05 * raise - 0.05 * rel,
          squash: 1 + 0.02 * draw - 0.03 * rel,
          armWeapon: -0.25 + 1.75 * raise, // bow levels out forward
          armFree: 0.2 + 1.2 * raise - 0.75 * draw + 0.5 * rel,
          wiggle: t >= 0.72 ? (1 - rel) * 0.5 : 0,
          blink: false,
          gaze: 1,
          headTilt: -0.04 * draw,
          flourish: t >= 0.72 ? (1 - rel) : 0,
        );
      case RoyalAction.hurl:
        // Conjure overhead — both arms gather the casting — then a whipped
        // overhand throw. The thrown orb is the host's projectile.
        final gather = Curves.easeOut.transform((t / 0.42).clamp(0.0, 1.0));
        final throwP =
            Curves.easeIn.transform(((t - 0.42) / 0.16).clamp(0.0, 1.0));
        final settle =
            Curves.easeOut.transform(((t - 0.58) / 0.42).clamp(0.0, 1.0));
        return _Pose(
          bob: -0.02 * gather + 0.008 * throwP,
          lean: -0.06 * gather + 0.22 * throwP - 0.16 * settle,
          squash: 1 + 0.05 * gather - 0.10 * throwP + 0.07 * settle,
          armWeapon: -0.3 - 2.3 * gather + 3.8 * throwP - 1.2 * settle,
          armFree: 0.2 + 2.2 * gather - 2.6 * throwP + 0.6 * settle,
          blink: false,
          gaze: 1,
          headTilt: -0.03 * gather + 0.03 * throwP,
          flourish: math.max(gather * 0.6, throwP * (1 - settle)),
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
      case RoyalAction.spell:
        // The Empress's signature: gather the working with both hands, throw
        // it open into a bloom of light, then bow to the user through it.
        // She rises off her heels for the cast — the one time the serene float
        // becomes an actual levitation.
        final gather = Curves.easeInOut.transform((t / 0.42).clamp(0.0, 1.0));
        final bloom =
            Curves.easeOutBack.transform(((t - 0.42) / 0.16).clamp(0.0, 1.0));
        final bow =
            Curves.easeInOut.transform(((t - 0.66) / 0.34).clamp(0.0, 1.0));
        // The bow reads as a curtsy: fold forward, settle back down.
        final dip = math.sin(bow * math.pi);
        return _Pose(
          // The curtsy SINKS; it barely folds. Her gown is a bell, so a lean
          // hardly shows in it — tilt the head to match and the head alone
          // appears to slide off the body. Drop and squash instead, and keep
          // the tilt small enough to read as lowered eyes.
          bob: -0.055 * gather * (1 - bow) + 0.050 * dip,
          lean: 0.13 * dip,
          sway: math.sin(t * 2 * math.pi * 0.7) * 0.02,
          squash: 1 + 0.03 * gather - 0.15 * dip,
          // Hands come together low, then sweep wide open on the bloom, then
          // one settles across the waist for the bow.
          armFree: 0.55 - 0.30 * gather + 2.10 * bloom - 1.70 * bow,
          armWeapon: -0.55 + 0.30 * gather - 2.10 * bloom + 1.35 * bow,
          blink: bow > 0.35 && bow < 0.9, // eyes lowered through the curtsy
          headTilt: -0.10 * gather + 0.07 * dip,
          flourish: math.max(gather * 0.55, (1 - bow * 0.75)),
        );
      case RoyalAction.kiss:
        // The Princess's signature: fingers to the lips, then a wide sweep
        // out toward the user as the kiss leaves. The little hop at the end is
        // what stops it reading as a salute.
        final raise = Curves.easeOutCubic.transform((t / 0.34).clamp(0.0, 1.0));
        final blow =
            Curves.easeOutBack.transform(((t - 0.38) / 0.22).clamp(0.0, 1.0));
        final settle =
            Curves.easeInOut.transform(((t - 0.62) / 0.38).clamp(0.0, 1.0));
        final hop = math.sin(((t - 0.38) / 0.34).clamp(0.0, 1.0) * math.pi);
        return _Pose(
          bob: -0.030 * hop,
          sway: math.sin(t * 2 * math.pi) * 0.03,
          squash: 1 + 0.03 * hop,
          // 2.95 ≈ straight up: the mitten lands beside her mouth. Sweeping
          // down to 1.75 throws it out and forward.
          armFree: 0.20 + 2.75 * raise - 1.20 * blow + 0.35 * settle,
          armWeapon: -0.25 - 0.15 * raise,
          wiggle: blow * (1 - settle) * 0.55,
          blink: raise > 0.75 && blow < 0.4, // a happy squint as she kisses
          headTilt: 0.10 * raise - 0.05 * settle,
          flourish: blow * (1 - settle * 0.55),
        );
      case RoyalAction.menace:
        // The Dark Prince's parting shot: drop the club, let the shock roll
        // out, then rise into a low guard and hold it. All the weight is in
        // the hold — a pose is only badass if it stops moving.
        final drop = Curves.easeInCubic.transform((t / 0.22).clamp(0.0, 1.0));
        final rise =
            Curves.easeOutCubic.transform(((t - 0.22) / 0.20).clamp(0.0, 1.0));
        final breathe = math.sin(t * 2 * math.pi * 0.9);
        return _Pose(
          bob: 0.030 * drop - 0.022 * rise + 0.004 * breathe,
          // Hunched over the planted club, head down under the helm.
          lean: 0.26 * drop - 0.06 * rise,
          squash: 1 - 0.16 * drop + 0.13 * rise + 0.006 * breathe,
          // The club arm hauls up and then drives straight back down, ending
          // inside the rest band so [_weapon] plants the club in the ground
          // rather than leaving it waved out sideways at arm's length.
          armWeapon: -0.30 - 0.95 * drop + 1.05 * rise + 0.20 * drop * rise,
          armFree: 0.20 - 0.85 * drop + 0.25 * rise,
          legPhase: 0.55 * drop,
          stride: 0.7 * drop,
          blink: false,
          headTilt: 0.16 * drop - 0.06 * rise,
          flourish: math.max(drop * (1 - rise * 0.4), 0.45),
        );
      case RoyalAction.mend:
        // The Medic's signature: snap the kit up and open, read the heartbeat
        // it draws in the air, then a brisk all-clear. She is the busiest of
        // the six, so the whole thing keeps a bustle under it rather than
        // settling into a held pose the way the Dark Prince's does.
        final lift = Curves.easeOutBack
            .transform((t / 0.26).clamp(0.0, 1.0))
            .clamp(0.0, 1.12);
        final read =
            Curves.easeInOut.transform(((t - 0.26) / 0.38).clamp(0.0, 1.0));
        final clear = Curves.easeOutBack
            .transform(((t - 0.68) / 0.32).clamp(0.0, 1.0))
            .clamp(0.0, 1.10);
        final bustle = math.sin(t * 2 * math.pi * 2.2);
        final hop = math.sin(((t - 0.68) / 0.32).clamp(0.0, 1.0) * math.pi);
        return _Pose(
          bob: -0.012 * lift - 0.042 * hop + 0.004 * bustle,
          lean: 0.05 * read - 0.04 * clear,
          sway: bustle * 0.02,
          squash: 1 + 0.03 * lift - 0.02 * read + 0.05 * hop,
          // Kit arm swings up and FORWARD (positive), presenting the open case
          // across her chest where the light from it can be seen.
          armWeapon: -0.30 + 2.35 * lift - 0.20 * clear,
          // Free hand follows the trace out, then goes up on the all-clear.
          armFree: 0.20 + 0.60 * read + 0.95 * clear,
          wiggle: clear * 0.45 * math.sin(t * 2 * math.pi * 6),
          blink: read > 0.30 && read < 0.52, // a squint at the readout
          gaze: 1,
          headTilt: 0.06 * lift - 0.09 * clear,
          flourish: 0.35 + 0.65 * math.max(read, clear),
        );
      case RoyalAction.brace:
        // Shield down, spear levelled across the rim, and then nothing. He does
        // not look up and he does not wave: the guard's signature is that he
        // refuses to perform for you.
        //
        // The first pass leaned him 0.13rad and dropped the head, which on a
        // bobblehead does not read as "set" — it reads as toppling. The weight
        // now goes DOWN (squash + a wide stance) instead of forward, and the
        // stillness afterwards is the beat that carries it.
        final stamp = Curves.easeOutCubic.transform((t / 0.16).clamp(0.0, 1.0));
        final set =
            Curves.easeOutQuart.transform(((t - 0.14) / 0.22).clamp(0.0, 1.0));
        // A single slow breath over the hold. Anything faster and the stillness
        // stops looking deliberate and starts looking frozen.
        final breath = math.sin((t - 0.36).clamp(0.0, 1.0) * math.pi * 1.4);
        return _Pose(
          bob: 0.022 * set + 0.004 * breath,
          // Almost nothing. The weight goes DOWN, not forward.
          lean: 0.018 * set,
          squash: 1 - 0.055 * set + 0.006 * breath,
          // Feet apart and rooted, not mid-step.
          legPhase: -0.85,
          stride: 0.42 * stamp,
          // Shield arm drops to cover the leading side.
          armFree: 0.34 * set,
          // Spear levelled over the rim: from upright, down to the horizontal.
          armWeapon: -0.25 + 1.55 * set,
          headTilt: 0.04 * set,
          blink: blink,
          flourish: set,
        );
      case RoyalAction.vault:
        // The tumble itself is a canvas rotation (see _rideOnFoot); the pose's
        // job is to TUCK, so the silhouette spinning past reads as an athlete
        // and not a plank. The first pass did the opposite — legs thrown wide
        // and arms crossed over the belly — which is the shape of someone
        // falling off something.
        //
        // Three beats inside one rotation: throw the legs up into the tuck,
        // hold it tight through the spin, open out to spot the landing.
        final gather = Curves.easeOutCubic.transform((t / 0.22).clamp(0.0, 1.0));
        final open = Curves.easeInCubic
            .transform(((t - 0.66) / 0.34).clamp(0.0, 1.0));
        final tuck = (gather - open).clamp(0.0, 1.0);
        return _Pose(
          squash: 1 - 0.04 * tuck,
          // Knees together and drawn up, not scissored apart — see [_legs].
          legPhase: 0.55,
          stride: 0.35 + 0.95 * open,
          tuck: tuck,
          // Both blades held OUT through the spin. Tucking the arms in too
          // leaves a ball with nothing readable on it; the legs carry the
          // tuck, and the arms carry the fact that she is armed while she
          // does it. They open wider still to spot the ground on the way down.
          armFree: 0.22 - 1.55 * tuck - 0.55 * open,
          armWeapon: -0.22 + 1.45 * tuck + 0.65 * open,
          bladeOpen: 0.55 + 0.45 * open,
          bladeSpin: tuck * 0.8,
          headTilt: -0.20 * tuck,
          blink: false, // eyes open through it
          flourish: 0.4 + 0.6 * tuck,
        );
      case RoyalAction.thrust:
        // Levelled behind the rim, driven out, recovered. The lunge is carried
        // by the LEGS (a long front stride) rather than by leaning further, so
        // he never loses the upright guard that is the whole character.
        final level =
            Curves.easeOutCubic.transform((t / 0.30).clamp(0.0, 1.0));
        final drive =
            Curves.easeOutExpo.transform(((t - 0.30) / 0.16).clamp(0.0, 1.0));
        final back = Curves.easeInOutCubic
            .transform(((t - 0.52) / 0.48).clamp(0.0, 1.0));
        final out = drive * (1 - back);
        return _Pose(
          // Barely any lean. On a bobblehead a body rotated about the feet
          // swings the head furthest of anything, and past ~0.1rad a lunge
          // stops reading as a lunge and starts reading as a man falling over.
          lean: 0.02 * level + 0.07 * out,
          squash: 1 - 0.03 * level - 0.06 * out,
          // The spear comes down off the vertical to the horizontal and pushes.
          armWeapon: -0.25 + 1.35 * level + 0.45 * out - 1.55 * back,
          // The shield arm stays put: it is cover, and cover does not move.
          armFree: 0.10 - 0.10 * level,
          // The reach comes from the LEGS instead — a long front stride under
          // an upright guard, which is what a spearman actually does.
          legPhase: 0.35 * level + 0.85 * out - 0.30 * back,
          // Enough to be a lunge, not enough to be the splits: at 1.7 the rear
          // boot swung out past the shield and he read as sliding apart.
          stride: 0.55 + 0.55 * out,
          blink: false,
          gaze: 1,
          flourish: out,
        );

      // ── Huntress signature drafts ─────────────────────────────────────────
      case RoyalAction.bladeDance:
        // Draft A. Nothing leaves the ground. Two full spins of the blades in
        // her fingers, a cross in front of the chest, then a slow settle to
        // guard with one blade reversed. Weight shifts hip to hip underneath.
        final spin = Curves.easeInOutSine
            .transform((t / 0.52).clamp(0.0, 1.0)); // the twirl
        final cross = Curves.easeOutBack
            .transform(((t - 0.50) / 0.22).clamp(0.0, 1.0));
        final settle =
            Curves.easeOutCubic.transform(((t - 0.74) / 0.26).clamp(0.0, 1.0));
        final rock = math.sin(t * 2 * math.pi * 2);
        return _Pose(
          bob: rock * 0.010,
          sway: rock * 0.045,
          squash: 1 + rock * 0.012,
          // Both hands up and working, then drawn in to cross, then down.
          armWeapon: -0.25 - 1.25 * spin + 0.55 * cross + 0.35 * settle,
          armFree: 0.22 + 1.35 * spin - 0.60 * cross - 0.45 * settle,
          // Two and a bit rotations of the blades themselves while the wrists
          // barely travel — the trick is in the fingers, which is the point.
          bladeSpin: spin * 4 * math.pi + cross * 0.6 * math.pi,
          bladeOpen: 0.25 + 0.75 * spin - 0.30 * settle,
          wiggle: math.sin(t * 2 * math.pi * 4) * 0.5 * (1 - settle),
          headTilt: 0.06 * spin - 0.10 * cross,
          gaze: settle > 0.4 ? 0 : 1,
          blink: false,
          flourish: math.max(spin * (1 - cross * 0.5), cross * (1 - settle)),
        );
      case RoyalAction.flyKick:
        // Draft B. Gather low, launch, the near boot snaps out horizontal at
        // the apex with both blades streaming back, land in a deep crouch.
        final coil =
            Curves.easeOutCubic.transform((t / 0.20).clamp(0.0, 1.0));
        final rise =
            Curves.easeOutQuad.transform(((t - 0.18) / 0.26).clamp(0.0, 1.0));
        final fall =
            Curves.easeInQuad.transform(((t - 0.50) / 0.24).clamp(0.0, 1.0));
        final land =
            Curves.easeOutCubic.transform(((t - 0.72) / 0.28).clamp(0.0, 1.0));
        final airborne = (rise - fall).clamp(0.0, 1.0);
        // The snap is a short spike at the top, not the whole flight.
        final snap = math.sin(((t - 0.34) / 0.24).clamp(0.0, 1.0) * math.pi);
        return _Pose(
          bob: 0.055 * coil - 0.30 * airborne + 0.075 * land * (1 - land),
          // Kept under 0.2rad for the usual reason — the head is the furthest
          // thing from the pivot, so body lean moves it more than anything the
          // pose does on purpose.
          lean: 0.08 * coil + 0.18 * airborne - 0.10 * land,
          squash: 1 - 0.12 * coil + 0.06 * airborne - 0.14 * land * (1 - land),
          // The kicking leg: chambered on the coil, fired at the apex.
          kick: -0.55 * coil + 2.30 * snap - 0.30 * land,
          tuck: 0.55 * coil * (1 - rise) + 0.30 * airborne * (1 - snap),
          legPhase: 0.5,
          stride: 0.35 + 0.85 * airborne,
          // Blades streaming back behind the line of the kick.
          armWeapon: -0.30 - 1.55 * airborne - 0.35 * snap,
          armFree: 0.25 + 1.15 * airborne + 0.30 * snap,
          bladeOpen: 0.35 + 0.65 * airborne,
          bladeSpin: airborne * 0.9,
          headTilt: -0.12 * airborne,
          gaze: 1,
          blink: false,
          flourish: math.max(snap, land * (1 - land) * 2),
        );
      case RoyalAction.daggerToss:
        // Draft C. The showiest: one blade goes up spinning, she turns a low
        // sweep-kick underneath it, takes it back reversed behind her back and
        // levels it down the lens. The airborne dagger is drawn by the accents
        // (it has left her hand — nothing in the rig can hold it).
        final toss =
            Curves.easeOutCubic.transform((t / 0.16).clamp(0.0, 1.0));
        final sweep = math.sin(((t - 0.20) / 0.34).clamp(0.0, 1.0) * math.pi);
        final catch_ =
            Curves.easeOutBack.transform(((t - 0.58) / 0.18).clamp(0.0, 1.0));
        final present =
            Curves.easeOutCubic.transform(((t - 0.76) / 0.24).clamp(0.0, 1.0));
        return _Pose(
          bob: -0.02 * toss + 0.05 * sweep - 0.01 * present,
          lean: 0.20 * sweep - 0.06 * present,
          sway: -0.10 * sweep,
          squash: 1 - 0.16 * sweep + 0.04 * present,
          // Low sweep: the near leg scythes right round underneath her.
          kick: 2.85 * sweep,
          legPhase: 0.35,
          stride: 0.5 + 0.7 * sweep,
          // Throwing hand up, then behind the back for the catch, then out.
          armWeapon: -0.25 + 2.55 * toss - 2.10 * sweep - 1.25 * catch_ +
              2.05 * present,
          armFree: 0.22 - 0.85 * sweep + 0.55 * catch_ - 0.30 * present,
          bladeSpin: catch_ * math.pi + present * 0.35,
          bladeOpen: 0.30 + 0.70 * sweep + 0.40 * present,
          headTilt: -0.10 * toss + 0.14 * sweep - 0.05 * present,
          gaze: 1,
          blink: false,
          flourish: math.max(toss, math.max(sweep * 0.9, present)),
        );
      case RoyalAction.salute:
        // The heir's sword salute: blade to the vertical in front of the face,
        // a crisp hold, then swept out to present and a short sharp bow. It is
        // the most FORMAL of the six on purpose — he is the one royal whose
        // signature is a piece of drill rather than a personality, which is
        // exactly the joke about an eager heir showing off his new sword.
        final raise = Curves.easeOutCubic.transform((t / 0.28).clamp(0.0, 1.0));
        // Recover, not a flourish out to the side. The far shoulder sits left
        // of centre and the arm is only 0.125h long, so a blade swung outward
        // starts at his midriff and reads as running him through; bringing it
        // back down to the order keeps the hilt clear of the silhouette and is
        // the correct drill anyway.
        final recover = Curves.easeInOutCubic
            .transform(((t - 0.52) / 0.18).clamp(0.0, 1.0));
        final bow = ((t - 0.70) / 0.30).clamp(0.0, 1.0);
        final dip = math.sin(bow * math.pi);
        return _Pose(
          // Same lesson as the Empress's curtsy: on a bobblehead the head tilt
          // has to stay well under the body's, or the head reads as coming
          // loose. The bow is carried by the sink and the lean.
          bob: -0.012 * raise + 0.034 * dip,
          lean: 0.15 * dip,
          squash: 1 - 0.02 * raise - 0.10 * dip,
          // The whole move stays inside [_weapon]'s rest band (|angle| < 0.6),
          // so the blade is vertical throughout: it rises to the centre of his
          // face for the salute and slides back to his side for the order.
          armWeapon: -0.25 + 0.80 * raise - 0.80 * recover,
          // Heels-together stillness, then the free hand goes to the heart for
          // the bow.
          armFree: 0.20 + 0.15 * raise - 1.05 * bow,
          stride: 0,
          blink: bow > 0.25 && bow < 0.60, // eyes down through the bow
          gaze: 1,
          headTilt: -0.05 * raise + 0.10 * dip,
          flourish: raise * (1 - bow * 0.4),
        );
      case RoyalAction.roar:
      case RoyalAction.ride:
        return const _Pose(); // both go through the mount pipeline
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

  /// A cardiac trace that DRAWS ITSELF left to right as [write] runs 0→1, with
  /// a bright head at the pen.
  ///
  /// The reveal is the whole effect: a static zigzag is a decoration, a line
  /// being written is a reading being taken. Points are normalized (x across
  /// the span, y as a fraction of the amplitude, negative = up).
  void _ecgTrace(
      Canvas canvas, Size size, double write, Color color, double fade) {
    final w = size.width, h = size.height;
    const pts = <(double, double)>[
      (0.00, 0.0),
      (0.20, 0.0),
      (0.26, -0.18), // P wave
      (0.32, 0.0),
      (0.40, 0.0),
      (0.44, 0.22), // Q
      (0.50, -1.00), // R — the spike
      (0.56, 0.42), // S
      (0.62, 0.0),
      (0.72, 0.0),
      (0.80, -0.30), // T wave
      (0.88, 0.0),
      (1.00, 0.0),
    ];
    // A bobblehead is head from 0.03h to 0.55h and two-thirds of the width, so
    // there is no clear horizontal band to draw across — run the trace over
    // her and it reads as a scratch on her face. It lives in the top-right
    // corner, clear of everything but the shoulder of her cap.
    final x0 = w * 0.50, span = w * 0.47;
    final baseY = h * 0.105, amp = h * 0.062;
    Offset at(int i) =>
        Offset(x0 + span * pts[i].$1, baseY + amp * pts[i].$2);

    // Walk the polyline in x, stopping wherever the pen has reached.
    final penX = pts.first.$1 + (pts.last.$1 - pts.first.$1) * write;
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    var pen = at(0);
    for (var i = 1; i < pts.length; i++) {
      if (pts[i].$1 <= penX) {
        path.lineTo(at(i).dx, at(i).dy);
        pen = at(i);
        continue;
      }
      // Partial segment: interpolate to exactly where the pen is.
      final k = ((penX - pts[i - 1].$1) / (pts[i].$1 - pts[i - 1].$1))
          .clamp(0.0, 1.0);
      pen = Offset.lerp(at(i - 1), at(i), k)!;
      path.lineTo(pen.dx, pen.dy);
      break;
    }

    // Three passes, and the ORDER matters for theme-independence: a blurred
    // halo, a saturated emerald body that holds up against ivory, then a pale
    // hairline down the middle that holds up against midnight. A single
    // near-white stroke vanished on the light theme, and a backing panel to
    // fix that just read as a black sticker across her cap.
    Paint stroke(double width, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.drawPath(
        path,
        stroke(5.5, color.withValues(alpha: 0.34 * fade))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(path, stroke(2.6, color.withValues(alpha: 0.95 * fade)));
    canvas.drawPath(
        path,
        stroke(
            1.0,
            Color.lerp(Colors.white, color, 0.25)!
                .withValues(alpha: 0.85 * fade)));

    // The pen itself.
    if (write < 1) {
      canvas.drawCircle(pen, 3.4,
          Paint()..color = Colors.white.withValues(alpha: 0.9 * fade));
      canvas.drawCircle(
          pen,
          6.5,
          Paint()
            ..color = color.withValues(alpha: 0.5 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }

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
/// [none] is not "no ride" — it is a ride ON FOOT. The Huntress is the only
/// royal without a mount: where the others gallop across the page she sprints
/// it and somersaults through the middle.
enum _Mount { horse, darkhorse, pegasus, lion, palanquin, cart, destrier, none }

/// Beast flavour for the shared quadruped painter.
enum _BeastStyle { horse, unicorn, lion }

/// How a mount carries itself.
///
/// The quadruped chassis is shared; the gait is not, and the gait is what makes
/// a ride read as a different animal rather than a recolour. Four royals used
/// to share one four-beat gallop and differ only by coat colour, a horn and a
/// mane — which is why the Prince, Dark Prince, Princess and Sovereign all
/// looked like the same horse wearing different paint.
enum _Gait {
  /// The Prince's four-beat canter — the baseline, deliberately unchanged.
  gallop,

  /// The Dark Prince: a heavy two-beat where both pairs land together, hanging
  /// at the top and slamming down. Kicks up an impact ring on each strike.
  stomp,

  /// The Princess: airborne. Hooves tuck, the body rides a smooth sine instead
  /// of a ground-slam, and the wingbeat carries the rhythm.
  flight,

  /// The Sovereign: long low bounds with a float at the apex, trailing
  /// afterimages — a beast covering ground faster than it should.
  prowl,

  /// The Sentinel: a destrier under barding does not bound, it DRIVES. Head
  /// down, body pitched forward and held low, legs reaching front-to-back
  /// instead of rolling through four beats. Barding and a coat swap alone left
  /// it 2.6% different from the Prince's canter — a recolour, which the rides
  /// suite rejects outright. The gait is what makes it another animal.
  charge,
}

_Mount _mountOf(String id) => switch (id) {
      'prince' => _Mount.horse,
      'darkprince' => _Mount.darkhorse,
      'princess' => _Mount.pegasus,
      'sovereign' => _Mount.lion,
      'sentinel' => _Mount.destrier,
      'huntress' => _Mount.none,
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
