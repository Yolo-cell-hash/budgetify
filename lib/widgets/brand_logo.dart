import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// The Budgetify brand mark — a champagne-gold line-art wallet with a ₹ face,
/// a clasp, and a sprout growing out of it — drawn as a vector so it stays
/// crisp at any size, tints to any color, and needs no bundled bitmap.
///
/// This is the single source of truth for the logo: the splash badge, the
/// shareable cards and the PDF export (via [renderBrandLogoPng]) all draw the
/// same geometry.
class BrandLogo extends StatelessWidget {
  final double size;
  final Color color;

  /// Optional filled backdrop (the icon's midnight-navy tile). When null the
  /// mark renders on whatever is behind it.
  final Color? background;

  const BrandLogo({
    super.key,
    this.size = 48,
    this.color = AppColors.gold,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: BrandLogoPainter(color: color, background: background),
    );
  }
}

/// The icon's midnight-navy tile color (used behind the gold mark on
/// light surfaces like the PDF).
const Color kBrandNavy = Color(0xFF14264F);

/// Paints the wallet-and-sprout mark on a 100×100 design grid, scaled to the
/// canvas. Stroke-based with rounded caps, matching the launcher icon.
class BrandLogoPainter extends CustomPainter {
  final Color color;
  final Color? background;

  const BrandLogoPainter({required this.color, this.background});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;

    if (background != null) {
      final bg = Paint()..color = background!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.shortestSide * 0.22),
        ),
        bg,
      );
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(x * s, y * s);

    // ── Wallet body ──────────────────────────────────────────────────────
    // One open path so the top edge has a gap for the sprout stem, and the
    // right edge has a gap where the clasp sits (the clasp occludes it).
    final wallet = Path()
      ..moveTo(42 * s, 42 * s) // top edge, left of the stem gap
      ..lineTo(25 * s, 42 * s)
      ..arcToPoint(p(16, 51), radius: Radius.circular(9 * s), clockwise: false)
      ..lineTo(16 * s, 79 * s)
      ..arcToPoint(p(25, 88), radius: Radius.circular(9 * s), clockwise: false)
      ..lineTo(63 * s, 88 * s)
      ..arcToPoint(p(72, 79), radius: Radius.circular(9 * s), clockwise: false)
      ..lineTo(72 * s, 75 * s) // right edge, below the clasp
      ..moveTo(72 * s, 55 * s) // right edge, above the clasp
      ..lineTo(72 * s, 51 * s)
      ..arcToPoint(p(63, 42), radius: Radius.circular(9 * s), clockwise: false)
      ..lineTo(56 * s, 42 * s); // top edge, right of the stem gap
    canvas.drawPath(wallet, stroke);

    // ── Clasp tab + button ───────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(64 * s, 55 * s, 88 * s, 75 * s),
        Radius.circular(8 * s),
      ),
      stroke,
    );
    canvas.drawCircle(p(77.5, 65), 3.6 * s, stroke);

    // ── ₹ face ───────────────────────────────────────────────────────────
    final rupee = Path()
      ..moveTo(30 * s, 56 * s) // top bar
      ..lineTo(48 * s, 56 * s)
      ..moveTo(30 * s, 63 * s) // second bar
      ..lineTo(48 * s, 63 * s)
      ..moveTo(41 * s, 56 * s) // half-loop joining the bars
      ..cubicTo(45.5 * s, 56.5 * s, 47 * s, 59 * s, 45.5 * s, 63 * s)
      ..moveTo(45 * s, 63 * s) // descending leg
      ..lineTo(33.5 * s, 78 * s);
    canvas.drawPath(rupee, stroke);

    // ── Sprout: stem + two leaves with veins ─────────────────────────────
    final sprout = Path()
      // Stem rises through the top-edge gap, curving right.
      ..moveTo(49 * s, 43 * s)
      ..cubicTo(49 * s, 35 * s, 50 * s, 30 * s, 55.5 * s, 25 * s)
      // Right leaf (larger).
      ..moveTo(55.5 * s, 25 * s)
      ..cubicTo(59 * s, 16.5 * s, 68 * s, 12 * s, 78.5 * s, 12.5 * s)
      ..cubicTo(78 * s, 22 * s, 71 * s, 29 * s, 60.5 * s, 29.5 * s)
      ..cubicTo(57.5 * s, 29.5 * s, 55.5 * s, 27.5 * s, 55.5 * s, 25 * s)
      // Left leaf (smaller).
      ..moveTo(50 * s, 33.5 * s)
      ..cubicTo(46.5 * s, 26.5 * s, 39.5 * s, 22.5 * s, 31 * s, 23 * s)
      ..cubicTo(31.5 * s, 31 * s, 37.5 * s, 36.5 * s, 45.5 * s, 36.5 * s)
      ..cubicTo(47.5 * s, 36.5 * s, 49.5 * s, 35.5 * s, 50 * s, 33.5 * s);
    canvas.drawPath(sprout, stroke);

    final vein = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(59.5 * s, 26.5 * s)
        ..cubicTo(63.5 * s, 22 * s, 68 * s, 18.5 * s, 72.5 * s, 17 * s),
      vein,
    );
    canvas.drawPath(
      Path()
        ..moveTo(46.5 * s, 33 * s)
        ..cubicTo(43 * s, 29.5 * s, 39 * s, 27 * s, 35.5 * s, 26 * s),
      vein,
    );
  }

  @override
  bool shouldRepaint(BrandLogoPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.background != background;
}

/// Render the mark to PNG bytes (for the PDF export, which can't host a
/// Flutter widget). [size] is the raster edge in pixels; render at 4–6× the
/// final display size for crisp output.
Future<Uint8List> renderBrandLogoPng({
  int size = 192,
  Color color = AppColors.gold,
  Color? background = kBrandNavy,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  BrandLogoPainter(color: color, background: background)
      .paint(canvas, Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('PNG encode returned null');
    }
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
