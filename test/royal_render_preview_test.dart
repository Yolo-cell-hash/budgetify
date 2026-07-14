// Dev-only art proofing harness: renders every royal × action × phase to PNG
// contact sheets so body-rig art can be verified by eye (glyph/vector art
// authored blind WILL have readability issues). Not an assertion suite — it
// only fails if a painter throws. Sheets land in ROYAL_PREVIEW_DIR (or the
// system temp dir) as royal_<id>.png.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _outDirOverride = String.fromEnvironment('ROYAL_PREVIEW_DIR');

Future<void> _savePng(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render royal contact sheets', () async {
    final dir = _outDirOverride.isNotEmpty
        ? _outDirOverride
        : Directory.systemTemp.createTempSync('royal_previews').path;
    Directory(dir).createSync(recursive: true);

    const cellW = 92.0, cellH = 118.0; // standing box (host size)
    const rideW = 160.0, rideH = 104.0; // wide box for the mounted strip
    const pad = 8.0;
    final phases = [0.0, 0.12, 0.25, 0.38, 0.5, 0.62, 0.75, 0.88];
    final actions =
        RoyalAction.values.where((a) => a != RoyalAction.ride).toList();

    for (final royal in kRoyalAvatars) {
      final w = math.max((cellW + pad) * phases.length,
              (rideW + pad) * (phases.length / 2).ceil()) +
          pad;
      final h = (cellH + pad) * actions.length + rideH + 2 * pad;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      // Split background: left half warm ivory, right half midnight — art must
      // read on both primary themes.
      canvas.drawRect(Rect.fromLTWH(0, 0, w / 2, h),
          Paint()..color = const Color(0xFFF4EDE1));
      canvas.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h),
          Paint()..color = const Color(0xFF14161D));
      void cell(Offset origin, Size box, RoyalAction action, double t,
          double facing) {
        canvas.save();
        canvas.translate(origin.dx, origin.dy);
        canvas.drawRect(
            Offset.zero & box,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = const Color(0x33888888));
        RoyalCharacterPainter(royal: royal, action: action, t: t, facing: facing)
            .paint(canvas, box);
        canvas.restore();
      }

      for (var a = 0; a < actions.length; a++) {
        for (var p = 0; p < phases.length; p++) {
          cell(Offset(pad + p * (cellW + pad), pad + a * (cellH + pad)),
              const Size(cellW, cellH), actions[a], phases[p],
              p.isEven ? 1 : -1);
        }
      }
      // Mounted strip along the bottom, wide cells, half facing left.
      final rideY = pad + actions.length * (cellH + pad);
      for (var p = 0; p < phases.length ~/ 2; p++) {
        cell(Offset(pad + p * (rideW + pad), rideY), const Size(rideW, rideH),
            RoyalAction.ride, phases[p * 2], p.isEven ? 1 : -1);
      }
      final img = await rec.endRecording().toImage(w.ceil(), h.ceil());
      await _savePng(img, '$dir/royal_${royal.id}.png');
    }
    // ignore: avoid_print
    print('Royal preview sheets written to $dir');
  });
}
