import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Premium accent gradients used for avatars (and as the profile's theme).
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

/// Number of distinct procedural pixel avatars offered.
const int kPixelAvatarCount = 12;

List<Color> accentOf(int index) =>
    kAvatarAccents[index % kAvatarAccents.length];

/// Renders a user's avatar from its persisted `{kind, value, accent}`. Used in
/// the Home header, profile, share card and picker so they always match.
class AvatarView extends StatelessWidget {
  final String kind; // 'emoji' | 'pixel'
  final String value; // emoji glyph or pixel seed index
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
    final grad = accentOf(accent);
    final border = ring
        ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: size * 0.03)
        : null;

    final Widget inner;
    if (kind == 'pixel') {
      inner = ClipOval(
        child: CustomPaint(
          size: Size.square(size),
          painter: PixelAvatarPainter(
            seed: int.tryParse(value) ?? 0,
            light: grad[0],
            dark: grad[1],
          ),
        ),
      );
    } else {
      inner = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: grad,
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

/// Deterministic, symmetric blocky avatar (identicon-style) drawn from a seed —
/// fully offline, no assets. Mirrors the left half so it always looks balanced.
class PixelAvatarPainter extends CustomPainter {
  final int seed;
  final Color light;
  final Color dark;

  const PixelAvatarPainter({
    required this.seed,
    required this.light,
    required this.dark,
  });

  static const int _grid = 7;

  @override
  void paint(Canvas canvas, Size size) {
    // Background wash.
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [dark.withValues(alpha: 0.35), dark.withValues(alpha: 0.6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final rng = math.Random(seed * 2654435761 & 0x7fffffff);
    final cell = size.width / _grid;
    final cols = (_grid / 2).ceil(); // mirror the rest
    final fill = Paint()..color = light;
    final fillSoft = Paint()..color = Color.lerp(light, dark, 0.35)!;

    for (var r = 0; r < _grid; r++) {
      for (var c = 0; c < cols; c++) {
        // Bias toward filled cells near the centre for a face-like mass.
        final on = rng.nextDouble() < 0.55;
        if (!on) continue;
        final paint = rng.nextBool() ? fill : fillSoft;
        final mirror = _grid - 1 - c;
        for (final cc in {c, mirror}) {
          final rect = Rect.fromLTWH(
            cc * cell + cell * 0.06,
            r * cell + cell * 0.06,
            cell * 0.88,
            cell * 0.88,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.22)),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(PixelAvatarPainter old) =>
      old.seed != seed || old.light != light || old.dark != dark;
}
