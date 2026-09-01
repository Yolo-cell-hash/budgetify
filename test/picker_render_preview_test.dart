import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/l10n/app_strings.dart';
import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';

/// Proof sheets for the date and time pickers, in the same spirit as
/// wrapped_render_preview_test.dart: the assertions in picker_theme_test.dart
/// say the colours come from the palette, and these say what that actually
/// looks like. Run by hand when the picker theme changes.
///
///   flutter test test/picker_render_preview_test.dart \
///     --dart-define=PICKER_OUT=`<dir>`
const _outDirOverride = String.fromEnvironment('PICKER_OUT');

void main() {
  testWidgets('render picker proof sheets', (tester) async {
    final dir = _outDirOverride.isNotEmpty
        ? _outDirOverride
        : Directory.systemTemp.createTempSync('picker_previews').path;
    Directory(dir).createSync(recursive: true);

    // Real brand typography, so the proof reflects the shipped composition.
    await tester.runAsync(() async {
      final loader = FontLoader('Manrope');
      for (final weight in ['400', '500', '600', '700', '800']) {
        loader.addFont(rootBundle.load('assets/fonts/manrope-$weight.ttf'));
      }
      await loader.load();
    });

    tester.view.physicalSize = const Size(760, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The real button and help text of the two-step move, so the proofs show
    // what a person actually reads rather than Material's "OK"/"Cancel".
    final en = AppStrings(AppLanguage.english);
    final day = DateTime(2026, 9, 1);

    final darkPrince = kRoyalAvatars.firstWhere((r) => r.id == 'darkprince');
    final court = courtDressFor('pixel', '${darkPrince.spriteIndex}')!;

    // The two base themes, one reward palette, and the dark theme under a
    // royal court — the combination that produced the reported gold-beside-
    // rose dialog.
    final scenarios = <String, ThemeData>{
      'light': AppTheme.of(AppThemeVariant.light),
      'dark': AppTheme.of(AppThemeVariant.dark),
      'midnightIndigo': AppTheme.of(AppThemeVariant.midnightIndigo),
      'dark_court': court(
        AppThemeVariant.dark,
        AppTheme.of(AppThemeVariant.dark),
      ),
    };

    for (final entry in scenarios.entries) {
      for (final kind in const ['date', 'time']) {
        final key = GlobalKey();
        // The boundary wraps the whole app, not `home`: a dialog is pushed
        // into the Navigator's overlay, so a boundary inside `home` captures
        // the empty screen behind it.
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: entry.value,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => kind == 'date'
                          ? showDatePicker(
                              context: ctx,
                              initialDate: day,
                              firstDate: DateTime(2020),
                              lastDate: day,
                              helpText: en.moveTransactionTo,
                              confirmText: en.commonNext,
                              cancelText: en.commonCancel,
                            )
                          : showTimePicker(
                              context: ctx,
                              initialTime:
                                  const TimeOfDay(hour: 7, minute: 53),
                              helpText: en.timeOnDate(en.dayMonth(day)),
                              confirmText: en.commonSave,
                              cancelText: en.commonCancel,
                            ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'threw on ${entry.key}/$kind');

        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File('$dir/picker_${kind}_${entry.key}.png')
              .writeAsBytes(data!.buffer.asUint8List());
        });
      }
    }

    // Where to look, when run by hand.
    // ignore: avoid_print
    print('Picker proof sheets → $dir');
  });
}
