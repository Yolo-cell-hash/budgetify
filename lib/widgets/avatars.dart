import 'package:flutter/material.dart';

/// Premium accent gradients used for emoji avatars and as the profile's theme.
/// Index is persisted in the profile, so keep this list append-only.
const List<List<Color>> kAvatarAccents = [
  [Color(0xFFE6C15A), Color(0xFFB8902F)], // champagne gold
  [Color(0xFF4F8DF7), Color(0xFF2456C8)], // ocean
  [Color(0xFF9B5DE5), Color(0xFF5E2CA5)], // grape
  [Color(0xFFF76E8E), Color(0xFFC8325B)], // rose
  [Color(0xFF3DD2A0), Color(0xFF1E8F6B)], // mint
  [Color(0xFFFF8A5B), Color(0xFFE0453C)], // sunset
  [Color(0xFF5BC8F7), Color(0xFF2A8FC8)], // sky
  [Color(0xFF3A4055), Color(0xFF1B1E28)], // ink
];

/// Curated emoji avatars (append-only).
const List<String> kEmojiAvatars = [
  '🦊', '🐼', '🦁', '🐯', '🐶', '🐱', '🦉', '🐧',
  '🐢', '🐝', '🦄', '🐙', '🚀', '🌟', '🔥', '👑',
];

List<Color> accentOf(int index) =>
    kAvatarAccents[index % kAvatarAccents.length];

// ── Pixel character avatars ────────────────────────────────────────────────
// Distinct hand-authored chibi characters (different hair / headwear / gender,
// male and female), each with its own palette — drawn with a CustomPainter, no
// assets, fully offline. Pixel avatars carry their own colours, so the accent
// picker doesn't apply to them.

const Color _outline = Color(0xFF15171E);
const Color _eyeWhite = Color(0xFFF2F5F8);

/// Glyph → palette slot:
///   .  transparent   X outline    C headwear  c headwear-shadow
///   H  hair          h hair-shadow  K skin     k skin-shadow
///   W  eye-white     I iris        J top       j top-shadow
class _Pal {
  final Color hair, hairD, cap, capD, jacket, jacketD, skin, skinD, iris;
  const _Pal({
    required this.hair, required this.hairD, required this.cap, required this.capD,
    required this.jacket, required this.jacketD, required this.skin,
    required this.skinD, required this.iris,
  });
}

class _Sprite {
  final List<String> rows;
  final _Pal pal;
  final List<Color> halo; // coordinating gradient for the profile card
  const _Sprite(this.rows, this.pal, this.halo);
}

// Shared face + neck + body for the head-up (no side-hair) characters.
const List<String> _face = [
  '...XKKKKKKKKX...',
  '...XKWWKKWWKX...',
  '...XKIIKKIIKX...',
  '...XKKKKKKKKX...',
  '...XKKKkkKKKX...',
  '....XKKKKKKX....',
  '.....XKKKKX.....',
  '...XXJJJJJJXX...',
  '..XJjJJJJJJjJX..',
  '..XJjJJJJJJjJX..',
  '..XXJJJJJJJJXX..',
];

const List<String> _capHead = [
  '....XXXXXXXX....',
  '...XCCCCCCCCX...',
  '..XCCCCCCCCCCX..',
  '..XCccccccccCX..',
  '..XXXXXXXXXXXX..',
];
const List<String> _shortHead = [
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHhhhhhhhhHX..',
  '..XHKKKKKKKKHX..',
];
const List<String> _beanieHead = [
  '....XXXXXXXX....',
  '...XCCCCCCCCX...',
  '..XCCCCCCCCCCX..',
  '..XCCCCCCCCCCX..',
  '..XCCCCCCCCCCX..',
];
const List<String> _bunHead = [
  '.....XHHX.......',
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHKKKKKKKKHX..',
];
const List<String> _afroHead = [
  '..XHHHHHHHHHHX..',
  '.XHHHHHHHHHHHHX.',
  '.XHHHHHHHHHHHHX.',
  '.XHHHHHHHHHHHHX.',
  '..XHKKKKKKKKHX..',
];
// Long hair frames the face and falls past the neck.
const List<String> _longHair = [
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHHHHHHHHHHX..',
  '..XHHHHHHHHHHX..',
  '..HXKKKKKKKKXH..',
  '..HXKWWKKWWKXH..',
  '..HXKIIKKIIKXH..',
  '..HXKKKKKKKKXH..',
  '..HXKKKkkKKKXH..',
  '..HXKKKKKKKKXH..',
  '..HhXKKKKXhH....',
  '...XXJJJJJJXX...',
  '..XJjJJJJJJjJX..',
  '..XJjJJJJJJjJX..',
  '..XXJJJJJJJJXX..',
];

const List<String> _mohawkHead = [
  '......XHHX......',
  '....XXKHHKXX....',
  '...XKKKHHKKKX...',
  '..XKKKKHHKKKKX..',
  '..XKKKKHHKKKKX..',
];
const List<String> _topknotHead = [
  '......XHX.......',
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHKKKKKKKKHX..',
];
// Chin-length bob (hair frames the face, ends at the jaw).
const List<String> _bob = [
  '....XXXXXXXX....',
  '...XHHHHHHHHX...',
  '..XHHHHHHHHHHX..',
  '..XHHHHHHHHHHX..',
  '..XHHHHHHHHHHX..',
  '..HXKKKKKKKKXH..',
  '..HXKWWKKWWKXH..',
  '..HXKIIKKIIKXH..',
  '..HXKKKKKKKKXH..',
  '..HXKKKkkKKKXH..',
  '....XKKKKKKX....',
  '.....XKKKKX.....',
  '...XXJJJJJJXX...',
  '..XJjJJJJJJjJX..',
  '..XJjJJJJJJjJX..',
  '..XXJJJJJJJJXX..',
];

List<String> _stack(List<String> head) => [...head, ..._face];

const _skinLight = Color(0xFFF2C9A0);
const _skinLightD = Color(0xFFD9A87C);
const _skinMed = Color(0xFFE8B98C);
const _skinMedD = Color(0xFFCE9B6E);
const _skinDark = Color(0xFF8D5A3A);
const _skinDarkD = Color(0xFF6F4329);

final List<_Sprite> _sprites = [
  // Capped (masc) — the agent look.
  _Sprite(_stack(_capHead),
      const _Pal(hair: Color(0xFF3A3F4A), hairD: Color(0xFF2A2E37), cap: Color(0xFF3A3F4A), capD: Color(0xFF2A2E37), jacket: Color(0xFF2F343E), jacketD: Color(0xFF21252D), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF5BD68A)),
      const [Color(0xFF4A5160), Color(0xFF2A2E37)]),
  // Short hair (masc).
  _Sprite(_stack(_shortHead),
      const _Pal(hair: Color(0xFF6B4423), hairD: Color(0xFF4A2E16), cap: Color(0xFF6B4423), capD: Color(0xFF4A2E16), jacket: Color(0xFF2D6CDF), jacketD: Color(0xFF1E4DA8), skin: _skinMed, skinD: _skinMedD, iris: Color(0xFF7A4B28)),
      const [Color(0xFF4F8DF7), Color(0xFF2456C8)]),
  // Beanie (unisex).
  _Sprite(_stack(_beanieHead),
      const _Pal(hair: Color(0xFFA23B4A), hairD: Color(0xFF74222E), cap: Color(0xFFA23B4A), capD: Color(0xFF74222E), jacket: Color(0xFF4A5563), jacketD: Color(0xFF333B45), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF3A3F4A)),
      const [Color(0xFFC0566A), Color(0xFF74222E)]),
  // Long hair (fem).
  _Sprite(_longHair,
      const _Pal(hair: Color(0xFF2E2A33), hairD: Color(0xFF1C1A20), cap: Color(0xFF2E2A33), capD: Color(0xFF1C1A20), jacket: Color(0xFFE05C86), jacketD: Color(0xFFB23C64), skin: _skinMed, skinD: _skinMedD, iris: Color(0xFF6B4A2E)),
      const [Color(0xFFF076A0), Color(0xFFB23C64)]),
  // Top bun (fem), blonde.
  _Sprite(_stack(_bunHead),
      const _Pal(hair: Color(0xFFE6C15A), hairD: Color(0xFFC09A38), cap: Color(0xFFE6C15A), capD: Color(0xFFC09A38), jacket: Color(0xFF2BB9A0), jacketD: Color(0xFF1C8A78), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF5B8FE0)),
      const [Color(0xFF3DD2B8), Color(0xFF1C8A78)]),
  // Afro (unisex), dark skin.
  _Sprite(_stack(_afroHead),
      const _Pal(hair: Color(0xFF2A2530), hairD: Color(0xFF18151C), cap: Color(0xFF2A2530), capD: Color(0xFF18151C), jacket: Color(0xFFF0883C), jacketD: Color(0xFFC76B26), skin: _skinDark, skinD: _skinDarkD, iris: Color(0xFF3A2E28)),
      const [Color(0xFFFF9E55), Color(0xFFC76B26)]),
  // Bob cut (fem), dark-brown hair.
  _Sprite(_bob,
      const _Pal(hair: Color(0xFF4A2E16), hairD: Color(0xFF2E1C0E), cap: Color(0xFF4A2E16), capD: Color(0xFF2E1C0E), jacket: Color(0xFF2BB9A0), jacketD: Color(0xFF1C8A78), skin: _skinMed, skinD: _skinMedD, iris: Color(0xFF6B4A2E)),
      const [Color(0xFF3DD2B8), Color(0xFF1C8A78)]),
  // Mohawk (masc), electric-blue.
  _Sprite(_stack(_mohawkHead),
      const _Pal(hair: Color(0xFF2D6CDF), hairD: Color(0xFF1E4DA8), cap: Color(0xFF2D6CDF), capD: Color(0xFF1E4DA8), jacket: Color(0xFF2A2E37), jacketD: Color(0xFF1C1F26), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF3A3F4A)),
      const [Color(0xFF4F8DF7), Color(0xFF2456C8)]),
  // Top-knot (unisex), black hair.
  _Sprite(_stack(_topknotHead),
      const _Pal(hair: Color(0xFF2E2A33), hairD: Color(0xFF1C1A20), cap: Color(0xFF2E2A33), capD: Color(0xFF1C1A20), jacket: Color(0xFF7E4FD6), jacketD: Color(0xFF5A37A0), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF6B4A2E)),
      const [Color(0xFF9B5DE5), Color(0xFF5E2CA5)]),
  // Long hair (fem), blonde.
  _Sprite(_longHair,
      const _Pal(hair: Color(0xFFE6C15A), hairD: Color(0xFFC09A38), cap: Color(0xFFE6C15A), capD: Color(0xFFC09A38), jacket: Color(0xFFE05C86), jacketD: Color(0xFFB23C64), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF5BD68A)),
      const [Color(0xFFF076A0), Color(0xFFB23C64)]),
  // Short hair (masc), dark skin.
  _Sprite(_stack(_shortHead),
      const _Pal(hair: Color(0xFF2A2530), hairD: Color(0xFF18151C), cap: Color(0xFF2A2530), capD: Color(0xFF18151C), jacket: Color(0xFF2BB985), jacketD: Color(0xFF1C8A62), skin: _skinDark, skinD: _skinDarkD, iris: Color(0xFF3A2E28)),
      const [Color(0xFF3DD2A0), Color(0xFF1E8F6B)]),
  // Afro (unisex), brown hair + light skin.
  _Sprite(_stack(_afroHead),
      const _Pal(hair: Color(0xFF6B4423), hairD: Color(0xFF4A2E16), cap: Color(0xFF6B4423), capD: Color(0xFF4A2E16), jacket: Color(0xFF2D6CDF), jacketD: Color(0xFF1E4DA8), skin: _skinLight, skinD: _skinLightD, iris: Color(0xFF6B4A2E)),
      const [Color(0xFF4F8DF7), Color(0xFF2456C8)]),
];

/// Number of distinct pixel-character avatars offered.
final int kPixelAvatarCount = _sprites.length;

/// Coordinating halo gradient for a pixel avatar (used on the profile card).
List<Color> pixelHaloOf(int seed) => _sprites[seed % _sprites.length].halo;

/// Renders a user's avatar from its persisted `{kind, value, accent}`. Used in
/// the Home header, profile, share card and picker so they always match.
/// (Accent applies to emoji avatars only — pixel characters carry own colours.)
class AvatarView extends StatelessWidget {
  final String kind; // 'emoji' | 'pixel'
  final String value; // emoji glyph or pixel sprite index
  final int accent;
  final double size;
  final bool ring;

  const AvatarView({
    super.key,
    required this.kind,
    required this.value,
    required this.accent,
    this.size = 48,
    this.ring = true,
  });

  @override
  Widget build(BuildContext context) {
    final border = ring
        ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: size * 0.03)
        : null;

    final Widget inner;
    if (kind == 'pixel') {
      inner = DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEDEFF3), Color(0xFFC9CFD8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.05),
          child: CustomPaint(
            size: Size.square(size),
            painter: PixelAvatarPainter(seed: int.tryParse(value) ?? 0),
          ),
        ),
      );
    } else {
      inner = Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: accentOf(accent),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Text(value, style: TextStyle(fontSize: size * 0.52)),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: border),
      child: ClipOval(child: inner),
    );
  }
}

/// Paints the chibi character for the chosen [seed] sprite. Crisp pixel squares,
/// transparent background (the [AvatarView] supplies the backdrop).
class PixelAvatarPainter extends CustomPainter {
  final int seed;
  const PixelAvatarPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final sprite = _sprites[seed % _sprites.length];
    final pal = sprite.pal;
    final rows = sprite.rows;
    final cols = rows.first.length;
    final cell = size.width / cols;
    final paint = Paint()..isAntiAlias = false;

    Color? colorFor(String ch) => switch (ch) {
          'X' => _outline,
          'C' => pal.cap,
          'c' => pal.capD,
          'H' => pal.hair,
          'h' => pal.hairD,
          'K' => pal.skin,
          'k' => pal.skinD,
          'W' => _eyeWhite,
          'I' => pal.iris,
          'J' => pal.jacket,
          'j' => pal.jacketD,
          _ => null,
        };

    for (var r = 0; r < rows.length; r++) {
      final line = rows[r];
      for (var c = 0; c < line.length; c++) {
        final color = colorFor(line[c]);
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
  bool shouldRepaint(PixelAvatarPainter old) => old.seed != seed;
}
