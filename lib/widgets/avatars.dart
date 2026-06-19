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
// A single hand-authored chibi sprite (capped character) recoloured into many
// distinct "people" via palette variants — actual pixel characters, drawn with
// a CustomPainter (no assets, fully offline).

// 16×16 sprite. Each glyph maps to a palette slot:
//   .  transparent   X outline      P cap   p cap-shadow
//   K  skin          k skin-shadow  W eye-white   I iris
//   J  jacket        j jacket-shadow
const List<String> _sprite = [
  '....XXXXXXXX....',
  '...XPPPPPPPPX...',
  '..XPPPPPPPPPPX..',
  '..XPppPPPPppPX..',
  '..XXXXXXXXXXXX..',
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

const Color _outline = Color(0xFF15171E);
const Color _eyeWhite = Color(0xFFF2F5F8);

/// A recolouring of the sprite — one distinct character.
class _Pal {
  final Color cap, capD, jacket, jacketD, skin, skinD, iris;
  const _Pal(this.cap, this.capD, this.jacket, this.jacketD, this.skin,
      this.skinD, this.iris);
}

const List<_Pal> _variants = [
  // Agent (dark cap + jacket, green eyes) — nods to the reference art.
  _Pal(Color(0xFF3A3F4A), Color(0xFF2A2E37), Color(0xFF2F343E), Color(0xFF21252D), Color(0xFFF2C9A0), Color(0xFFD9A87C), Color(0xFF5BD68A)),
  _Pal(Color(0xFFC0392B), Color(0xFF8E2B20), Color(0xFF7A2520), Color(0xFF591A16), Color(0xFFF2C9A0), Color(0xFFD9A87C), Color(0xFF2E323C)),
  _Pal(Color(0xFF2D6CDF), Color(0xFF1E4DA8), Color(0xFF24405E), Color(0xFF182D43), Color(0xFFE8B98C), Color(0xFFCE9B6E), Color(0xFF8FD0FF)),
  _Pal(Color(0xFF7E4FD6), Color(0xFF5A37A0), Color(0xFF3A2A5C), Color(0xFF281C42), Color(0xFFC98D5E), Color(0xFFA86E45), Color(0xFFCBA8FF)),
  _Pal(Color(0xFF2BB985), Color(0xFF1C8A62), Color(0xFF1E4636), Color(0xFF143026), Color(0xFFF2C9A0), Color(0xFFD9A87C), Color(0xFF7CE0B6)),
  _Pal(Color(0xFFF08A3C), Color(0xFFC76B26), Color(0xFF7A3B1E), Color(0xFF592A14), Color(0xFFC98D5E), Color(0xFFA86E45), Color(0xFFFFD27A)),
  _Pal(Color(0xFFE85C8A), Color(0xFFB83C66), Color(0xFF5C2A3C), Color(0xFF421E2A), Color(0xFFF2C9A0), Color(0xFFD9A87C), Color(0xFFFFB0C8)),
  _Pal(Color(0xFFE6C15A), Color(0xFFB8902F), Color(0xFF3A3220), Color(0xFF262014), Color(0xFFE8B98C), Color(0xFFCE9B6E), Color(0xFF6FD0FF)),
  _Pal(Color(0xFF4A5563), Color(0xFF333B45), Color(0xFF2A2F38), Color(0xFF1C2026), Color(0xFF8D5A3A), Color(0xFF6F4329), Color(0xFF9BE0C0)),
  _Pal(Color(0xFF5BC8F7), Color(0xFF2A8FC8), Color(0xFF234155), Color(0xFF172C3B), Color(0xFF8D5A3A), Color(0xFF6F4329), Color(0xFFCFF0FF)),
];

/// Number of distinct procedural pixel-character avatars offered.
final int kPixelAvatarCount = _variants.length;

/// Renders a user's avatar from its persisted `{kind, value, accent}`. Used in
/// the Home header, profile, share card and picker so they always match.
class AvatarView extends StatelessWidget {
  final String kind; // 'emoji' | 'pixel'
  final String value; // emoji glyph or pixel variant index
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
      // Pixel character on a soft "studio" backdrop so the sprite pops.
      inner = DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEDEFF3), Color(0xFFC9CFD8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.06),
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

/// Paints the chibi sprite for the chosen [seed] variant. Crisp pixel squares,
/// transparent background (the [AvatarView] supplies the backdrop).
class PixelAvatarPainter extends CustomPainter {
  final int seed;
  const PixelAvatarPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final pal = _variants[seed % _variants.length];
    final rows = _sprite.length;
    final cols = _sprite.first.length;
    final cell = size.width / cols;
    final paint = Paint()..isAntiAlias = false;

    Color? colorFor(String ch) => switch (ch) {
          'X' => _outline,
          'P' => pal.cap,
          'p' => pal.capD,
          'K' => pal.skin,
          'k' => pal.skinD,
          'W' => _eyeWhite,
          'I' => pal.iris,
          'J' => pal.jacket,
          'j' => pal.jacketD,
          _ => null,
        };

    for (var r = 0; r < rows; r++) {
      final line = _sprite[r];
      for (var c = 0; c < cols; c++) {
        final color = colorFor(line[c]);
        if (color == null) continue;
        paint.color = color;
        // +0.5 overscan to avoid hairline seams between cells.
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
