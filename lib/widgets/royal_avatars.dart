import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// The ROYALTY avatar tier — the court above Elite.
///
/// Royal characters are *living* avatars, not static sprites: they breathe,
/// blink, glance around and wave at the user on an idle loop, sit on their
/// own velvet backdrop inside the avatar circle, carry an orbiting-spark
/// aura, and play a spawn flourish when equipped. Each royal also brings a
/// full [RoyalTheme] that re-skins the profile card (canvas, border, ring,
/// aura, name glow) while keeping the card's structure — the same pattern as
/// the Master Budgeter mythic treatment, but per-character.
///
/// Art follows the roster's chibi pixel style (16×16 glyph grids) with a
/// richer vocabulary for regalia. Sprite indices are append-only and live
/// AFTER the elite block; `avatars.dart` routes those seeds here.

// ── Glyph art ───────────────────────────────────────────────────────────────
// Vocabulary (per-character palette maps a glyph → colour):
//   .  transparent   X outline      C crown/tiara  c crown shadow
//   G  gemstone      H hair/beard   h hair shadow  K skin   k skin shadow
//   W  eye white     I iris         R robe/gown    r robe shadow
//   T  gold trim     F ermine fur   f fur fleck

/// One royal character: identity, base art, animation frames and theme.
class RoyalAvatar {
  final String id;

  /// Slot in the global pixel-sprite index space (append-only, persisted).
  final int spriteIndex;

  final List<String> rows;
  final Map<String, Color> palette;

  /// Indices of the two eye rows (whites row, iris row) inside [rows].
  final int eyeRowWhites;
  final int eyeRowIris;

  /// Replacement pairs for the two eye rows, per gaze/blink state.
  final List<String> eyesClosed; // [whitesRow, irisRow]
  final List<String> eyesLeft;
  final List<String> eyesRight;

  final RoyalTheme theme;

  const RoyalAvatar({
    required this.id,
    required this.spriteIndex,
    required this.rows,
    required this.palette,
    required this.eyeRowWhites,
    required this.eyeRowIris,
    required this.eyesClosed,
    required this.eyesLeft,
    required this.eyesRight,
    required this.theme,
  });
}

/// The custom look a royal lends to surfaces that honour it (profile card).
class RoyalTheme {
  /// Card canvas gradient — replaces the hero/mythic gradient when equipped.
  final List<Color> cardGradient;

  /// Sweep colours for the avatar's revolving ring on the card.
  final List<Color> ringColors;

  /// Signature accent (sparks, glows, hairlines, stat tint).
  final Color accent;

  /// Softer companion for text glows.
  final Color accentSoft;

  /// Velvet backdrop inside the avatar circle (radial, centre → edge).
  final List<Color> backdrop;

  /// Halo pair for surfaces that expect a 2-stop gradient (pixelHaloOf).
  final List<Color> halo;

  const RoyalTheme({
    required this.cardGradient,
    required this.ringColors,
    required this.accent,
    required this.accentSoft,
    required this.backdrop,
    required this.halo,
  });

  /// Border colour that breathes between gold and the royal accent.
  Color borderAt(double t) {
    final wave = (math.sin(t * 2 * math.pi) + 1) / 2;
    return Color.lerp(const Color(0xFFF2C14E), accent, wave * 0.5)!;
  }

  /// This court as a [HeroStyle] — how the equipped royal takes over the
  /// app's hero surfaces (the Home balance card, SIP alert, insight heroes:
  /// everything that resolves `HeroStyle.of`). Court canvases are all dark,
  /// so a white-ink on-dark treatment works for every royal.
  HeroStyle courtHeroStyle() => HeroStyle(
        gradientColors: cardGradient,
        border: accent.withValues(alpha: 0.55),
        shadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 26),
        ],
        foreground: Colors.white,
        mutedForeground: Colors.white.withValues(alpha: 0.62),
        accent: accentSoft,
        innerFill: Colors.white.withValues(alpha: 0.07),
        innerBorder: Colors.white.withValues(alpha: 0.10),
        divider: Colors.white.withValues(alpha: 0.12),
        positive: AppColors.successDark,
        negative: AppColors.dangerDark,
        onDark: true,
      );
}

/// The hero-surface override for a persisted avatar, or null when the
/// avatar isn't royal. Takes the raw profile fields (not [GamiProfile]) so
/// this file stays import-cycle-free.
HeroStyle? courtHeroStyleFor(String avatarKind, String avatarValue) {
  if (avatarKind != 'pixel') return null;
  return royalAvatarAt(int.tryParse(avatarValue) ?? -1)?.theme.courtHeroStyle();
}

const Color _outline = Color(0xFF15171E);
const Color _eyeWhite = Color(0xFFF2F5F8);
const Color _gold = Color(0xFFF2C14E);
const Color _goldDeep = Color(0xFFC09232);

// ── The Sovereign (king): five-point ruby crown, walnut beard, ermine
// collar over a crimson robe with gold straps and a ruby clasp. ─────────────
const List<String> _kingRows = [
  '...G...GG...G...',
  '...C...CC...C...',
  '..XCCCCCCCCCCX..',
  '..XCGCCGGCCGCX..',
  '..XccccccccccX..',
  '...XKKKKKKKKX...',
  '...XKWWKKWWKX...',
  '...XKIIKKIIKX...',
  '...XKKKkkKKKX...',
  '...XHHKkkKHHX...',
  '....XHHHHHHX....',
  '.....XHhhHX.....',
  '...XFFfFFfFFX...',
  '..XRTRRRRRRTRX..',
  '..XRTRRGGRRTRX..',
  '..XXrRRRRRRrXX..',
];

const Map<String, Color> _kingPalette = {
  'X': _outline,
  'C': _gold,
  'c': _goldDeep,
  'G': Color(0xFFE23B4E), // ruby
  'H': Color(0xFF4A2E16), // walnut beard
  'h': Color(0xFF2E1C0E),
  'K': Color(0xFFE8B98C),
  'k': Color(0xFFCE9B6E),
  'W': _eyeWhite,
  'I': Color(0xFFB8742E), // bright amber — reads regal against the beard
  'R': Color(0xFF8E1F2F), // crimson robe
  'r': Color(0xFF5E1220),
  'T': _gold,
  'F': Color(0xFFF4EFE6), // ermine
  'f': Color(0xFF2A2530),
};

// ── The Empress (queen): sapphire tiara, raven hair framing the face,
// gold collar necklace with a sapphire pendant on a violet gown. ────────────
const List<String> _queenRows = [
  '.......GG.......',
  '....C..CC..C....',
  '...XCGCCCCGCX...',
  '..XHHHHHHHHHHX..',
  '..XHHHHHHHHHHX..',
  '..XHKKKKKKKKHX..',
  '..XHKWWKKWWKHX..',
  '..XHKIIKKIIKHX..',
  '..XHKKKKKKKKHX..',
  '..XHKKKkkKKKHX..',
  '..XHhXKKKKXhHX..',
  '...XhXKKKKXhX...',
  '...XXRTTTTRXX...',
  '..XRRRRGGRRRRX..',
  '..XRTRRRRRRTRX..',
  '..XXrRRRRRRrXX..',
];

const Map<String, Color> _queenPalette = {
  'X': _outline,
  'C': _gold,
  'c': _goldDeep,
  'G': Color(0xFF6FA8FF), // sapphire
  'H': Color(0xFF2E2A3C), // raven hair
  'h': Color(0xFF1C1926),
  'K': Color(0xFFF2C9A0),
  'k': Color(0xFFD9A87C),
  'W': _eyeWhite,
  'I': Color(0xFF4A78C8),
  'R': Color(0xFF5E2CA5), // royal violet gown
  'r': Color(0xFF3E1C70),
  'T': _gold,
  'F': Color(0xFFF4EFE6),
  'f': Color(0xFF2A2530),
};

// ── The Prince (heir): gold coronet over chestnut hair, gilded plate
// armour, and a steel-tipped lance held upright in the left hand. The
// waving right hand stays free. ─────────────────────────────────────────────
const List<String> _princeRows = [
  '.SS.............',
  '.SS.............',
  '.LL.............',
  '.LL.XCCGCCGCCX..',
  '.LL.XHHHHHHHHX..',
  '.LL.XKKKKKKKKX..',
  '.LL.XKWWKKWWKX..',
  '.LL.XKIIKKIIKX..',
  '.LL.XKKKKKKKKX..',
  '.LL.XKKKkkKKKX..',
  '.LL..XKKKKKKX...',
  '.LL.XXAAAAAAXX..',
  '.KKKXATAAAATAX..',
  '.LL.XATAAAATAX..',
  '.LL.XAaAGGAaAX..',
  '.LL.XXaAAAAaXX..',
];

const Map<String, Color> _princePalette = {
  'X': _outline,
  'S': Color(0xFFD7DCE4), // steel lance tip
  'L': Color(0xFFC09232), // gilded lance shaft
  'C': _gold,
  'c': _goldDeep,
  'G': Color(0xFFE23B4E), // ruby
  'H': Color(0xFF6B4423), // chestnut hair
  'h': Color(0xFF4A2E16),
  'K': Color(0xFFF2C9A0),
  'k': Color(0xFFD9A87C),
  'W': _eyeWhite,
  'I': Color(0xFF3E7DC8),
  'A': Color(0xFFD4A72C), // golden plate armour
  'a': Color(0xFF9C7A16),
  'T': Color(0xFFFFE9B0), // pale-gold trim
};

// ── The Dark Prince: iron coronet, black plate, ember eyes, and a studded
// war club in the left hand. Same body plan as the Prince — the palette and
// weapon tell the two brothers apart. ───────────────────────────────────────
const List<String> _darkPrinceRows = [
  'XMMMX...........',
  'XMSMX...........',
  'XMMMX...........',
  '.LL.XCCGGCCCCX..',
  '.LL.XHHHHHHHHX..',
  '.LL.XKKKKKKKKX..',
  '.LL.XKWWKKWWKX..',
  '.LL.XKIIKKIIKX..',
  '.LL.XKKKKKKKKX..',
  '.LL.XKKKkkKKKX..',
  '.LL..XKKKKKKX...',
  '.LL.XXAAAAAAXX..',
  '.KKKXATAAAATAX..',
  '.LL.XATAAAATAX..',
  '.LL.XAaAGGAaAX..',
  '.LL.XXaAAAAaXX..',
];

const Map<String, Color> _darkPrincePalette = {
  'X': _outline,
  'M': Color(0xFF4E525C), // iron club head
  'm': Color(0xFF33383F),
  'S': Color(0xFF9AA3B2), // steel stud
  'L': Color(0xFF3E2A1A), // dark-wood haft
  'C': Color(0xFF3A3F4A), // iron coronet
  'c': Color(0xFF26292F),
  'G': Color(0xFFFF4632), // ember gem
  'H': Color(0xFF1C1926), // black hair
  'h': Color(0xFF101018),
  'K': Color(0xFFE8D9C8), // pale skin
  'k': Color(0xFFC4B29E),
  'W': _eyeWhite,
  'I': Color(0xFFFF4632), // ember iris
  'A': Color(0xFF23262F), // black plate armour
  'a': Color(0xFF121418),
  'T': Color(0xFFB02838), // blood-red trim
};

// ── The Princess: tall blush-gem tiara, honey-gold hair framing the face,
// pearl necklace on a rose gown. ────────────────────────────────────────────
const List<String> _princessRows = [
  '.......GG.......',
  '......XGGX......',
  '....C.XCCX.C....',
  '...XCCCCCCCCX...',
  '..XHHHHHHHHHHX..',
  '..XHKKKKKKKKHX..',
  '..XHKWWKKWWKHX..',
  '..XHKIIKKIIKHX..',
  '..XHKKKKKKKKHX..',
  '..XHKKKkkKKKHX..',
  '..XHhXKKKKXhHX..',
  '...XhXKKKKXhX...',
  '...XXRPPPPRXX...',
  '..XRRRRGGRRRRX..',
  '..XRTRRRRRRTRX..',
  '..XXrRRRRRRrXX..',
];

const Map<String, Color> _princessPalette = {
  'X': _outline,
  'C': _gold,
  'c': _goldDeep,
  'G': Color(0xFFFF9EC8), // blush gem
  'H': Color(0xFFE6C15A), // honey-gold hair
  'h': Color(0xFFC09A38),
  'K': Color(0xFFF2C9A0),
  'k': Color(0xFFD9A87C),
  'W': _eyeWhite,
  'I': Color(0xFF5BA8D8),
  'R': Color(0xFFD4547E), // rose gown
  'r': Color(0xFFA83660),
  'T': _gold,
  'P': Color(0xFFF6F1E8), // pearls
};

// ── The Royal Medic: the court physician — white cap and coat, each
// carrying the emerald cross of life, gold court trim, kind green eyes. ─────
const List<String> _medicRows = [
  '.....XFFFFX.....',
  '....XFFEEFFX....',
  '...XFFFEEFFFX...',
  '..XHHFFFFFFHHX..',
  '..XHKKKKKKKKHX..',
  '..XHKWWKKWWKHX..',
  '..XHKIIKKIIKHX..',
  '..XHKKKKKKKKHX..',
  '..XHKKKkkKKKHX..',
  '...XXKKKKKKXX...',
  '.....XKKKKX.....',
  '...XXFFFFFFXX...',
  '..XFTFFEEFFTFX..',
  '..XFTFEEEEFTFX..',
  '..XFTFFEEFFTFX..',
  '..XXfFFFFFFfXX..',
];

const Map<String, Color> _medicPalette = {
  'X': _outline,
  'F': Color(0xFFF6F2EA), // white coat + cap
  'f': Color(0xFFD8D2C4),
  'E': Color(0xFF2BB985), // emerald cross of life
  'H': Color(0xFF6E4A2A), // warm brown hair
  'h': Color(0xFF4A2E16),
  'K': Color(0xFFE8B98C),
  'k': Color(0xFFCE9B6E),
  'W': _eyeWhite,
  'I': Color(0xFF2E8F6B), // green iris
  'T': _gold,
};

// Waving hand overlays, shared by both royals (drawn in FRONT of the body —
// nearer the viewer — so they simply paint over base cells). Two frames give
// the up/down beat of the wave.
const List<String> _waveFrameUp = [
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '.............XX.',
  '............XKKX',
  '............XKKX',
  '............XTTX',
  '................',
  '................',
  '................',
  '................',
];

const List<String> _waveFrameDown = [
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '................',
  '............XX..',
  '...........XKKX.',
  '...........XKKX.',
  '...........XTTX.',
  '................',
  '................',
  '................',
];

/// The royal roster. Sprite indices are append-only and sit directly after
/// the elite block (see kFreePixelAvatarCount/kEliteAvatars in avatars.dart).
const List<RoyalAvatar> kRoyalAvatars = [
  RoyalAvatar(
    id: 'sovereign',
    spriteIndex: 18,
    rows: _kingRows,
    palette: _kingPalette,
    eyeRowWhites: 6,
    eyeRowIris: 7,
    eyesClosed: ['...XKKKKKKKKX...', '...XKkkKKkkKX...'],
    eyesLeft: ['...XKWWKKWWKX...', '...XKIWKKIWKX...'],
    eyesRight: ['...XKWWKKWWKX...', '...XKWIKKWIKX...'],
    theme: RoyalTheme(
      cardGradient: [Color(0xFF4A121A), Color(0xFF260810), Color(0xFF100304)],
      ringColors: [_gold, Color(0xFFFFE9B0), Color(0xFFB02838), _gold],
      accent: Color(0xFFFFD75E),
      accentSoft: Color(0xFFFFE9B0),
      backdrop: [Color(0xFF5E1826), Color(0xFF1E060A)],
      halo: [Color(0xFFFFD75E), Color(0xFF7E1820)],
    ),
  ),
  RoyalAvatar(
    id: 'empress',
    spriteIndex: 19,
    rows: _queenRows,
    palette: _queenPalette,
    eyeRowWhites: 6,
    eyeRowIris: 7,
    eyesClosed: ['..XHKKKKKKKKHX..', '..XHKkkKKkkKHX..'],
    eyesLeft: ['..XHKWWKKWWKHX..', '..XHKIWKKIWKHX..'],
    eyesRight: ['..XHKWWKKWWKHX..', '..XHKWIKKWIKHX..'],
    theme: RoyalTheme(
      cardGradient: [Color(0xFF32175E), Color(0xFF1B0B3A), Color(0xFF0B0418)],
      ringColors: [_gold, Color(0xFFE8D9FF), Color(0xFF7E5CE8), _gold],
      accent: Color(0xFFB18CFF),
      accentSoft: Color(0xFFE8D9FF),
      backdrop: [Color(0xFF3E2470), Color(0xFF140A28)],
      halo: [Color(0xFFC9A2FF), Color(0xFF3E1C70)],
    ),
  ),
  // The heir in radiant gold — his court is molten bronze.
  RoyalAvatar(
    id: 'prince',
    spriteIndex: 20,
    rows: _princeRows,
    palette: _princePalette,
    eyeRowWhites: 6,
    eyeRowIris: 7,
    eyesClosed: ['.LL.XKKKKKKKKX..', '.LL.XKkkKKkkKX..'],
    eyesLeft: ['.LL.XKWWKKWWKX..', '.LL.XKIWKKIWKX..'],
    eyesRight: ['.LL.XKWWKKWWKX..', '.LL.XKWIKKWIKX..'],
    theme: RoyalTheme(
      cardGradient: [Color(0xFF4A3808), Color(0xFF241B03), Color(0xFF0E0A01)],
      ringColors: [_gold, Color(0xFFFFE9B0), Color(0xFFD4A72C), _gold],
      accent: Color(0xFFFFC93C),
      accentSoft: Color(0xFFFFE9B0),
      backdrop: [Color(0xFF5E4A10), Color(0xFF1E1602)],
      halo: [Color(0xFFFFC93C), Color(0xFF7A5E10)],
    ),
  ),
  // The exiled brother — onyx court, ember-red menace.
  RoyalAvatar(
    id: 'darkprince',
    spriteIndex: 21,
    rows: _darkPrinceRows,
    palette: _darkPrincePalette,
    eyeRowWhites: 6,
    eyeRowIris: 7,
    eyesClosed: ['.LL.XKKKKKKKKX..', '.LL.XKkkKKkkKX..'],
    eyesLeft: ['.LL.XKWWKKWWKX..', '.LL.XKIWKKIWKX..'],
    eyesRight: ['.LL.XKWWKKWWKX..', '.LL.XKWIKKWIKX..'],
    theme: RoyalTheme(
      cardGradient: [Color(0xFF1E1E26), Color(0xFF101014), Color(0xFF050507)],
      ringColors: [
        Color(0xFFFF4632),
        Color(0xFFFF9A8C),
        Color(0xFF23262F),
        Color(0xFFFF4632),
      ],
      accent: Color(0xFFFF4632),
      accentSoft: Color(0xFFFF9A8C),
      backdrop: [Color(0xFF2A2A34), Color(0xFF0A0A0E)],
      halo: [Color(0xFFFF4632), Color(0xFF26060A)],
    ),
  ),
  // Elegance itself — a blush-and-pearl court.
  RoyalAvatar(
    id: 'princess',
    spriteIndex: 22,
    rows: _princessRows,
    palette: _princessPalette,
    eyeRowWhites: 6,
    eyeRowIris: 7,
    eyesClosed: ['..XHKKKKKKKKHX..', '..XHKkkKKkkKHX..'],
    eyesLeft: ['..XHKWWKKWWKHX..', '..XHKIWKKIWKHX..'],
    eyesRight: ['..XHKWWKKWWKHX..', '..XHKWIKKWIKHX..'],
    theme: RoyalTheme(
      cardGradient: [Color(0xFF521431), Color(0xFF2E0A1D), Color(0xFF12040C)],
      ringColors: [_gold, Color(0xFFFFD1E4), Color(0xFFD4547E), _gold],
      accent: Color(0xFFFF9EC8),
      accentSoft: Color(0xFFFFD1E4),
      backdrop: [Color(0xFF6E1E3E), Color(0xFF240710)],
      halo: [Color(0xFFFF9EC8), Color(0xFF6E1E3E)],
    ),
  ),
  // The court physician — an emerald court of life.
  RoyalAvatar(
    id: 'royalmedic',
    spriteIndex: 23,
    rows: _medicRows,
    palette: _medicPalette,
    eyeRowWhites: 5,
    eyeRowIris: 6,
    eyesClosed: ['..XHKKKKKKKKHX..', '..XHKkkKKkkKHX..'],
    eyesLeft: ['..XHKWWKKWWKHX..', '..XHKIWKKIWKHX..'],
    eyesRight: ['..XHKWWKKWWKHX..', '..XHKWIKKWIKHX..'],
    theme: RoyalTheme(
      cardGradient: [Color(0xFF0E3A2C), Color(0xFF062318), Color(0xFF02110B)],
      ringColors: [_gold, Color(0xFFB8F5E0), Color(0xFF2BB985), _gold],
      accent: Color(0xFF3DD2A0),
      accentSoft: Color(0xFFB8F5E0),
      backdrop: [Color(0xFF14523E), Color(0xFF041E12)],
      halo: [Color(0xFF3DD2A0), Color(0xFF0E3A2C)],
    ),
  ),
];

/// The royal occupying [spriteIndex], or null.
RoyalAvatar? royalAvatarAt(int spriteIndex) {
  for (final r in kRoyalAvatars) {
    if (r.spriteIndex == spriteIndex) return r;
  }
  return null;
}

// ── Idle-loop timeline ──────────────────────────────────────────────────────
// One 8-second loop. Fixed windows read as natural because the loop is long:
// glance left, wave hello (looking at the viewer), glance right, and blink
// singles/doubles sprinkled between.

enum _Gaze { centre, left, right }

class _IdlePose {
  final bool blink;
  final _Gaze gaze;
  final bool waving;
  final bool waveUp;
  const _IdlePose(this.blink, this.gaze, this.waving, this.waveUp);
}

_IdlePose _poseAt(double t) {
  bool inAny(List<(double, double)> ws) {
    for (final (a, b) in ws) {
      if (t >= a && t < b) return true;
    }
    return false;
  }

  final blink = inAny(const [
    (0.135, 0.155),
    (0.455, 0.475),
    (0.495, 0.515), // double-blink pair
    (0.815, 0.835),
  ]);
  final gaze = t >= 0.20 && t < 0.30
      ? _Gaze.left
      : (t >= 0.62 && t < 0.72 ? _Gaze.right : _Gaze.centre);
  final waving = t >= 0.34 && t < 0.52;
  // Beat the hand up/down every 160ms of the 8s loop while waving.
  final waveUp = waving && (((t - 0.34) / 0.02).floor() % 2 == 0);
  return _IdlePose(blink, gaze, waving, waveUp);
}

// ── Painters ────────────────────────────────────────────────────────────────

/// Paints one frame of a royal: velvet backdrop, slow light rays, orbiting
/// sparks, then the sprite itself with the pose's eye rows + wave overlay and
/// a gentle breathing bob. With a fixed [t] this renders a rich static frame
/// (share captures, previews).
class RoyalAvatarPainter extends CustomPainter {
  final RoyalAvatar royal;
  final double t;
  final bool backdrop;

  const RoyalAvatarPainter({
    required this.royal,
    required this.t,
    this.backdrop = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    if (backdrop) {
      // Velvet radial canvas.
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(colors: royal.theme.backdrop)
              .createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
      // Slowly revolving light rays — the court spotlight.
      final rayPaint = Paint()
        ..color = royal.theme.accent.withValues(alpha: 0.07);
      for (var i = 0; i < 4; i++) {
        final a = t * 2 * math.pi * 0.25 + i * math.pi / 2;
        final path = Path()
          ..moveTo(centre.dx, centre.dy)
          ..arcTo(
            Rect.fromCircle(center: centre, radius: radius * 1.5),
            a,
            0.42,
            false,
          )
          ..close();
        canvas.drawPath(path, rayPaint);
      }
      _sparks(canvas, centre, radius);
    }

    // Sprite, with a sub-pixel breathing bob.
    final pose = _poseAt(t % 1.0);
    final bob = math.sin(t * 2 * math.pi * 2) * size.height * 0.008;
    canvas.save();
    canvas.translate(0, bob);
    _sprite(canvas, size, pose);
    canvas.restore();
  }

  void _sparks(Canvas canvas, Offset centre, double radius) {
    final spark = Paint();
    for (var i = 0; i < 6; i++) {
      final speed = 0.5 + (i % 3) * 0.25;
      final a = t * 2 * math.pi * speed + i * math.pi / 3;
      final r = radius * (0.80 + 0.12 * math.sin(a * 1.7 + i));
      final twinkle =
          (math.sin(t * 2 * math.pi * 3 + i * 1.9) + 1) / 2; // 0..1
      spark.color =
          royal.theme.accentSoft.withValues(alpha: 0.25 + twinkle * 0.55);
      canvas.drawCircle(
        centre + Offset(math.cos(a) * r, math.sin(a) * r),
        radius * (0.018 + twinkle * 0.014),
        spark,
      );
    }
  }

  void _sprite(Canvas canvas, Size size, _IdlePose pose) {
    final rows = List<String>.from(royal.rows);
    if (pose.blink) {
      rows[royal.eyeRowWhites] = royal.eyesClosed[0];
      rows[royal.eyeRowIris] = royal.eyesClosed[1];
    } else if (pose.gaze == _Gaze.left) {
      rows[royal.eyeRowWhites] = royal.eyesLeft[0];
      rows[royal.eyeRowIris] = royal.eyesLeft[1];
    } else if (pose.gaze == _Gaze.right) {
      rows[royal.eyeRowWhites] = royal.eyesRight[0];
      rows[royal.eyeRowIris] = royal.eyesRight[1];
    }

    _grid(canvas, size, rows);
    if (pose.waving) {
      _grid(canvas, size, pose.waveUp ? _waveFrameUp : _waveFrameDown);
    }
  }

  void _grid(Canvas canvas, Size size, List<String> rows) {
    final cols = rows.first.length;
    final cell = size.width / cols;
    final paint = Paint()..isAntiAlias = false;
    for (var r = 0; r < rows.length; r++) {
      final line = rows[r];
      for (var c = 0; c < line.length; c++) {
        final color = royal.palette[line[c]];
        if (color == null) continue;
        paint.color = color;
        // +0.5 overscan avoids hairline seams between cells.
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(RoyalAvatarPainter old) =>
      old.t != t || old.royal != royal || old.backdrop != backdrop;
}

/// Background aura for royal-themed cards: soft halo rings around a focus
/// point plus drifting sparks in the royal accent. Mirrors the mythic aura's
/// role so cards can swap one for the other.
class RoyalAuraPainter extends CustomPainter {
  final RoyalTheme theme;
  final double t;
  final Alignment focus;

  const RoyalAuraPainter({
    required this.theme,
    required this.t,
    this.focus = const Alignment(0, -0.55),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(
      size.width * (focus.x + 1) / 2,
      size.height * (focus.y + 1) / 2,
    );
    final breath = (math.sin(t * 2 * math.pi) + 1) / 2;

    // Halo rings breathing around the focus.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final r = size.width * (0.22 + i * 0.16) * (0.96 + breath * 0.06);
      ring.color = theme.accent.withValues(alpha: 0.10 - i * 0.025);
      canvas.drawCircle(centre, r, ring);
    }

    // Drifting sparks.
    final spark = Paint();
    for (var i = 0; i < 9; i++) {
      final speed = 0.35 + (i % 3) * 0.22;
      final a = t * 2 * math.pi * speed + i * 0.8;
      final r = size.width * (0.18 + (i % 4) * 0.10);
      final p = centre + Offset(math.cos(a) * r, math.sin(a) * r * 0.7);
      if (p.dx < 0 || p.dy < 0 || p.dx > size.width || p.dy > size.height) {
        continue;
      }
      final twinkle = (math.sin(t * 2 * math.pi * 2.4 + i * 2.1) + 1) / 2;
      spark.color =
          theme.accentSoft.withValues(alpha: 0.12 + twinkle * 0.30);
      canvas.drawCircle(p, 1.1 + twinkle * 1.2, spark);
    }
  }

  @override
  bool shouldRepaint(RoyalAuraPainter old) =>
      old.t != t || old.theme != theme || old.focus != focus;
}

/// One-shot spawn flourish painted OVER the avatar as it materialises:
/// an expanding ring flash and a burst of gold motes flying outward.
/// [p] runs 0→1.
class _SpawnBurstPainter extends CustomPainter {
  final RoyalTheme theme;
  final double p;

  const _SpawnBurstPainter({required this.theme, required this.p});

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0 || p >= 1) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final fade = (1 - p).clamp(0.0, 1.0);

    // Expanding ring flash.
    canvas.drawCircle(
      centre,
      radius * (0.5 + p * 0.62),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06 * fade
        ..color = theme.accent.withValues(alpha: 0.75 * fade),
    );

    // Radiating motes, easing outward and fading.
    final mote = Paint();
    final eased = Curves.easeOut.transform(p);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 + 0.4;
      final r = radius * (0.30 + eased * 0.75);
      mote.color = (i.isEven ? theme.accent : theme.accentSoft)
          .withValues(alpha: 0.85 * fade);
      canvas.drawCircle(
        centre + Offset(math.cos(a) * r, math.sin(a) * r),
        radius * 0.045 * fade + 0.6,
        mote,
      );
    }
  }

  @override
  bool shouldRepaint(_SpawnBurstPainter old) =>
      old.p != p || old.theme != theme;
}

// ── The living avatar widget ────────────────────────────────────────────────

/// A royal avatar that lives: breathes, blinks, glances, waves, and (when
/// [spawn] is true) materialises with an elastic scale-in, ring flash and
/// mote burst. Give it a fresh [Key] to replay the spawn (the picker keys the
/// preview by selection so equipping a royal always spawns it).
///
/// Set [animate] false for a rich static frame (share captures).
class AnimatedRoyalAvatar extends StatefulWidget {
  final RoyalAvatar royal;
  final double size;
  final bool spawn;
  final bool animate;

  const AnimatedRoyalAvatar({
    super.key,
    required this.royal,
    required this.size,
    this.spawn = true,
    this.animate = true,
  });

  @override
  State<AnimatedRoyalAvatar> createState() => _AnimatedRoyalAvatarState();
}

class _AnimatedRoyalAvatarState extends State<AnimatedRoyalAvatar>
    with TickerProviderStateMixin {
  AnimationController? _idle;
  AnimationController? _spawn;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _idle = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 8),
      )..repeat();
      if (widget.spawn) {
        _spawn = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 850),
        )..forward();
      }
    }
  }

  @override
  void dispose() {
    _idle?.dispose();
    _spawn?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idle = _idle;
    if (idle == null) {
      // Static frame — mid-loop pose looks best (eyes open, no wave).
      return _frame(0.05, 1.0, 0.0);
    }
    return AnimatedBuilder(
      animation: Listenable.merge([idle, if (_spawn != null) _spawn]),
      builder: (context, _) {
        final sp = _spawn?.value ?? 1.0;
        final scale = _spawn == null
            ? 1.0
            : (0.55 + Curves.elasticOut.transform(sp) * 0.45);
        return _frame(idle.value, scale, _spawn == null ? 0.0 : sp);
      },
    );
  }

  Widget _frame(double t, double scale, double spawnP) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: CustomPaint(
              painter: RoyalAvatarPainter(royal: widget.royal, t: t),
            ),
          ),
          if (spawnP > 0 && spawnP < 1)
            CustomPaint(
              painter:
                  _SpawnBurstPainter(theme: widget.royal.theme, p: spawnP),
            ),
        ],
      ),
    );
  }
}
