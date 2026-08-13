// Dev-only art proofing harness for the SIGNATURE moves and the royal rides —
// the two things that are hardest to get right authoring blind, and the two
// the plain contact sheet renders too small to judge. Renders each royal's
// signature across a full action cycle plus a wide ride strip.
//
// Not an assertion suite; it only fails if a painter throws. Sheets land in
// ROYAL_PREVIEW_DIR (or the system temp dir) as signature_<id>.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _outDirOverride = String.fromEnvironment('ROYAL_PREVIEW_DIR');

RoyalAction _signatureOf(String id) => switch (id) {
      'empress' => RoyalAction.spell,
      'princess' => RoyalAction.kiss,
      'darkprince' => RoyalAction.menace,
      'sovereign' => RoyalAction.roar,
      'royalmedic' => RoyalAction.mend,
      'prince' => RoyalAction.salute,
      'sentinel' => RoyalAction.brace,
      'huntress' => RoyalAction.daggerToss,
      _ => RoyalAction.wave,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render royal signature + ride sheets', () async {
    final dir = _outDirOverride.isNotEmpty
        ? _outDirOverride
        : Directory.systemTemp.createTempSync('royal_signature').path;
    Directory(dir).createSync(recursive: true);

    // Generous boxes: the host uses 78x100 standing and 150x96 riding, drawn
    // at 2x here so detail work (helm slit, chanfron, feather tips) is legible.
    const stand = Size(156, 200);
    const ride = Size(300, 192);
    const pad = 10.0;
    final phases = [0.0, 0.14, 0.28, 0.42, 0.56, 0.70, 0.84, 0.96];

    for (final royal in kRoyalAvatars) {
      final sig = _signatureOf(royal.id);
      final mounted = sig == RoyalAction.roar;
      final sigBox = mounted ? ride : stand;
      final w = (sigBox.width + pad) * phases.length + pad;
      final h = (sigBox.height + pad) + (ride.height + pad) + pad;

      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
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

      // Row 1: the signature, left to right through one full pass.
      for (var p = 0; p < phases.length; p++) {
        cell(Offset(pad + p * (sigBox.width + pad), pad), sigBox, sig,
            phases[p], 1);
      }
      // Row 2: the ride, half of them facing left to catch mirroring bugs.
      final rideY = pad + sigBox.height + pad;
      final perRow = ((w - pad) / (ride.width + pad)).floor();
      for (var p = 0; p < perRow; p++) {
        cell(Offset(pad + p * (ride.width + pad), rideY), ride,
            RoyalAction.ride, phases[p % phases.length], p.isEven ? 1 : -1);
      }

      final img = await rec.endRecording().toImage(w.ceil(), h.ceil());
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/signature_${royal.id}.png')
          .writeAsBytes(data!.buffer.asUint8List());
    }
    // ignore: avoid_print
    print('Signature sheets written to $dir');
  });
}
