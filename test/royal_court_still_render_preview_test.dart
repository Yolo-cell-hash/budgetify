// Dev-only proof sheets for the court sheet's "ON YOUR SCREENS" still, in the
// same spirit as picker_render_preview_test.dart: royal_court_still_test.dart
// asserts the colours come from courtDressFor, and these say what that
// actually looks like. Run by hand when the still or a court changes.
//
//   flutter test test/royal_court_still_render_preview_test.dart \
//     --dart-define=COURT_STILL_OUT=<dir>
//
// Not an assertion suite — it only fails if something throws.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/providers/app_preferences.dart';
import 'package:budget_tracker/providers/locale_provider.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';
import 'package:budget_tracker/widgets/royal_court_still.dart';

const _outDirOverride = String.fromEnvironment('COURT_STILL_OUT');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render court-still proof sheets', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final dir = _outDirOverride.isNotEmpty
        ? _outDirOverride
        : Directory.systemTemp.createTempSync('court_stills').path;
    Directory(dir).createSync(recursive: true);

    // Real brand typography, so the proof reflects the shipped composition.
    await tester.runAsync(() async {
      final loader = FontLoader('Manrope');
      for (final weight in ['400', '500', '600', '700', '800']) {
        loader.addFont(rootBundle.load('assets/fonts/manrope-$weight.ttf'));
      }
      await loader.load();
    });

    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final variant in [AppThemeVariant.dark, AppThemeVariant.light]) {
      for (final royal in kRoyalAvatars) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<LocaleProvider>(
                    create: (_) => LocaleProvider()),
                ChangeNotifierProvider<AppPreferences>(
                    create: (_) => AppPreferences()),
                ChangeNotifierProvider<ThemeProvider>(
                  create: (_) => ThemeProvider()..setVariant(variant),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.of(variant),
                home: Builder(
                  builder: (ctx) => Scaffold(
                    backgroundColor: AppColors.of(ctx).surface,
                    body: Padding(
                      padding: const EdgeInsets.all(20),
                      child: RoyalCourtStill(royal: royal),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // Land mid-wave, where the character is facing the reader and standing
        // still — the frame a contact sheet is judged on.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 3300));
        expect(tester.takeException(), isNull,
            reason: '${royal.id}/${variant.name}');

        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File('$dir/court_${royal.id}_${variant.name}.png')
              .writeAsBytes(data!.buffer.asUint8List());
        });
      }
    }

    // Where to look, when run by hand.
    // ignore: avoid_print
    print('Court-still proof sheets → $dir');
  });
}
