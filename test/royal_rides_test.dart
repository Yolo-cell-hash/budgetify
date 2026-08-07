import 'dart:ui' as ui;

import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _cell = Size(190, 126);

/// Renders one royal's ride at [t] and returns the raw pixels.
///
/// Pixels rather than a golden file on purpose: the point of these tests is
/// that two rides are not the SAME, which is a comparison between two renders,
/// not a comparison against a checked-in image nobody would re-approve
/// carefully.
Future<List<int>> _ridePixels(
  WidgetTester tester,
  RoyalAvatar royal,
  double t,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: CustomPaint(
              size: _cell,
              painter: RoyalCharacterPainter(
                royal: royal,
                action: RoyalAction.ride,
                t: t,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull, reason: '${royal.id} threw at t=$t');

  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  List<int>? out;
  await tester.runAsync(() async {
    final img = await boundary.toImage();
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    out = data!.buffer.asUint8List().toList(growable: false);
  });
  return out!;
}

/// Reduces a render to "is there anything drawn here", so two rides can be
/// compared by shape alone.
///
/// Uses ALPHA, not colour. A RepaintBoundary captures on a transparent
/// background, so every untouched pixel is rgba(0,0,0,0) — judged by colour
/// the empty background reads as solid black and the entire image counts as
/// drawn, which makes any two royals look 99% identical.
List<bool> _silhouette(List<int> rgba) {
  final out = <bool>[];
  for (var k = 0; k < rgba.length; k += 4) {
    out.add(rgba[k + 3] > 24);
  }
  return out;
}

void main() {
  group('royal rides', () {
    testWidgets('every royal renders a ride at every phase of its cycle',
        (tester) async {
      for (final r in kRoyalAvatars) {
        for (final t in [0.0, 0.25, 0.5, 0.75, 0.99]) {
          await _ridePixels(tester, r, t);
        }
      }
    });

    testWidgets('no two royals ride the same', (tester) async {
      // The complaint this feature answers: four of the six shared one gallop
      // and differed only by coat colour, a horn and a mane. Comparing renders
      // pairwise is the direct check that they are now actually distinct — and
      // it fails loudly if a future royal is added as a recolour of another.
      final shots = <String, List<int>>{};
      for (final r in kRoyalAvatars) {
        shots[r.id] = await _ridePixels(tester, r, 0.30);
      }

      // Compared as SILHOUETTES, not colours. Comparing colours would have
      // passed before this change too — the old unicorn was a near-white horse
      // with a horn glued on, so a colour diff scored "different" for what was
      // plainly the same animal. A silhouette diff only moves when the shape
      // moves, which is the thing that was actually wrong.
      final masks = {
        for (final e in shots.entries) e.key: _silhouette(e.value),
      };

      final ids = masks.keys.toList();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final a = masks[ids[i]]!, b = masks[ids[j]]!;
          var differing = 0;
          for (var k = 0; k < a.length; k++) {
            if (a[k] != b[k]) differing++;
          }
          final pct = differing / a.length * 100;
          expect(pct, greaterThan(6.0),
              reason: '${ids[i]} and ${ids[j]} have near-identical silhouettes '
                  '(${pct.toStringAsFixed(2)}% differ) — one is a recolour of '
                  'the other, not a different ride');
        }
      }
    });

    testWidgets('each ride actually moves through its cycle', (tester) async {
      // Guards the gait maths: a royal whose bob/legs/wings resolved to a
      // constant would render one still frame forever and nobody would notice
      // from a static screenshot.
      for (final r in kRoyalAvatars) {
        final a = await _ridePixels(tester, r, 0.0);
        final b = await _ridePixels(tester, r, 0.5);
        var differing = 0;
        for (var k = 0; k < a.length; k += 4) {
          if (a[k] != b[k] || a[k + 1] != b[k + 1] || a[k + 2] != b[k + 2]) {
            differing++;
          }
        }
        expect(differing, greaterThan(0),
            reason: '${r.id} renders identically at t=0 and t=0.5 — its ride '
                'is not animating');
      }
    });
  });
}
