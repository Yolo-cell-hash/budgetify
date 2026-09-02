import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/models/plus_products.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';

/// Play Console product icons for the eight royal avatars, one PNG per
/// `royal_*` one-time product.
///
///   flutter test test/royal_product_icon_test.dart \
///     --dart-define=ROYAL_ICON_OUT=marketing/subscriptions/royals
///
/// Written in Dart rather than alongside `marketing/subscriptions/
/// build-icons.mjs` for one reason: a royal is 16x16 rows of glyphs living in
/// `royal_avatars.dart`, so the only way for the icon to show the thing the
/// buyer actually receives is to paint it with the app's own painter. Redrawn
/// in SVG it would be a lookalike, free to drift from the art on the next
/// tweak. Here [RoyalAvatarPainter] does the character and the ground is the
/// same ink the Plus icons stand on, so the catalogue reads as one family.
///
/// Play's constraints on a product icon (from the Console form):
///   * 32-bit PNG, 1:1, each side 512-1080px, under 8MB
///   * "Use a unique and accurate image for each product."
///   * "Don't include text, promotions or branding."
///
/// So there is no wordmark, no price and no crown-of-Budgetify here — the
/// royal IS the product, and each one differs in the only thing the buyer is
/// choosing between: which of the court they are taking home.
const _outDirOverride = String.fromEnvironment('ROYAL_ICON_OUT');

/// Play accepts 512-1080; 1024 matches the Plus icons already in the folder.
const double _size = 1024;

/// How much of the canvas the royal's own disc takes. Deliberately short of
/// the edge: Play rounds and crops product icons in some surfaces, and a
/// character cropped at the shoulder reads as a mistake.
const double _discFraction = 0.645;

void main() {
  testWidgets('render the royal product icons', (tester) async {
    final dir = _outDirOverride.isNotEmpty
        ? _outDirOverride
        : Directory.systemTemp.createTempSync('royal_icons').path;
    Directory(dir).createSync(recursive: true);

    tester.view.physicalSize = const Size(_size, _size);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final royal in kRoyalAvatars) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CustomPaint(
            size: const Size.square(_size),
            painter: _RoyalProductIcon(royal),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: royal.id);

      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File('$dir/${royalProductId(royal.id)}.png');
        await file.writeAsBytes(data!.buffer.asUint8List());
        // Play rejects anything over 8MB; these land around 300KB, so this is
        // a tripwire rather than a real risk.
        expect(await file.length(), lessThan(8 * 1024 * 1024),
            reason: royal.id);
      });
    }

    // Where to look, when run by hand.
    // ignore: avoid_print
    print('Royal product icons → $dir');
  });
}

/// One product icon: the app's ink ground, a bloom in the royal's own court
/// colour, and the royal's living avatar frozen at its resting pose.
class _RoyalProductIcon extends CustomPainter {
  final RoyalAvatar royal;
  const _RoyalProductIcon(this.royal);

  /// The pose [AnimatedRoyalAvatar] itself falls back to when it isn't
  /// animating: eyes open, no wave. Using the same number means the icon can
  /// never show a face the picker doesn't.
  static const double _restingPose = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final accent = royal.theme.accent;

    // 1. The ink ground the Plus icons already stand on.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    // 2. A bloom in the court's colour — the one thing separating a Sovereign
    //    icon from an Empress icon at thumbnail size, before either face is
    //    legible.
    final bloomRadius = size.width * 0.46;
    canvas.drawCircle(
      centre,
      bloomRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: bloomRadius)),
    );

    // 3. The royal, on their own velvet disc.
    final disc = size.width * _discFraction;
    final discRect = Rect.fromCenter(center: centre, width: disc, height: disc);

    // A soft outer glow, so the disc sits ON the ground rather than being
    // pasted over it.
    canvas.drawCircle(
      centre,
      disc / 2,
      Paint()
        ..color = accent.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 34),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(discRect));
    canvas.translate(discRect.left, discRect.top);
    RoyalAvatarPainter(royal: royal, t: _restingPose)
        .paint(canvas, Size.square(disc));
    canvas.restore();

    // 4. The court's own hairline, the way the picker frames a royal tile.
    canvas.drawCircle(
      centre,
      disc / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.009
        ..color = accent.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(_RoyalProductIcon old) => old.royal.id != royal.id;
}
