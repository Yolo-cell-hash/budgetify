import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/royal_avatars.dart';

/// The date and time pickers were the last dialogs in the app dressed by
/// Material rather than by the palette, and it showed: a gold hour field
/// beside a rose dial on a canvas that was neither (device screenshot,
/// Sep '26).
///
/// Two causes, both guarded here. `ColorScheme.light/dark(...)` fills only the
/// roles it is handed, and the time picker reads *container* roles — never
/// touched — for its hour/minute field. And the royal dress re-colours eight
/// component themes so a court reaches the buttons and the nav bar, but could
/// not reach the pickers because they had no component theme to re-colour.
///
/// Unlike the screens in screen_palette_test.dart, these dialogs touch no
/// database, so they can be pumped for real rather than read as source.
void main() {
  AppColors paletteOf(AppThemeVariant v) =>
      AppTheme.of(v).extension<AppPalette>()!.colors;

  /// TimePickerThemeData types its state-dependent slots as plain `Color?`,
  /// because a WidgetStateColor *is* a Color. Resolving one means casting
  /// back to the property it also implements.
  Color? stateColor(Color? c, Set<WidgetState> states) =>
      c == null ? null : (c as WidgetStateProperty<Color>).resolve(states);

  group('every theme dresses its own pickers', () {
    for (final variant in AppThemeVariant.values) {
      test('${variant.name}: surfaces come from the palette', () {
        final theme = AppTheme.of(variant);
        final c = paletteOf(variant);

        final date = theme.datePickerTheme;
        final time = theme.timePickerTheme;

        // Populated at all — a variant added later without wiring these up
        // silently falls back to Material's baseline, which is exactly the
        // bug this file exists for.
        expect(date.backgroundColor, isNotNull, reason: variant.name);
        expect(time.backgroundColor, isNotNull, reason: variant.name);

        // And populated from THIS variant's palette, not a hand-written hex:
        // brightness alone cannot tell smokyIvory from light.
        expect(date.backgroundColor, c.card, reason: variant.name);
        expect(time.backgroundColor, c.card, reason: variant.name);
        expect(date.headerBackgroundColor, c.card, reason: variant.name);
        expect(date.dividerColor, c.border, reason: variant.name);
        expect(time.dialBackgroundColor, c.cardAlt, reason: variant.name);
      });

      test('${variant.name}: the accent, not Material, marks the selection',
          () {
        final theme = AppTheme.of(variant);
        final date = theme.datePickerTheme;
        final time = theme.timePickerTheme;

        final selectedDay =
            date.dayBackgroundColor?.resolve({WidgetState.selected});
        final unselectedDay = date.dayBackgroundColor?.resolve({});

        expect(selectedDay, isNotNull, reason: variant.name);
        expect(selectedDay, isNot(Colors.transparent), reason: variant.name);
        expect(unselectedDay, Colors.transparent, reason: variant.name);

        // The dial hand and the selected day agree on one accent — the whole
        // complaint was that the two halves of the dialog disagreed.
        expect(time.dialHandColor, selectedDay, reason: variant.name);
        expect(date.todayBorder?.color, selectedDay, reason: variant.name);

        // The hour field is a wash of that same accent, never an unrelated
        // container colour Material chose for us.
        final selectedField =
            stateColor(time.hourMinuteColor, {WidgetState.selected});
        final fieldText =
            stateColor(time.hourMinuteTextColor, {WidgetState.selected});
        expect(fieldText, selectedDay, reason: variant.name);
        expect(selectedField, isNotNull, reason: variant.name);
        expect(
          selectedField!.a,
          lessThan(1.0),
          reason: '${variant.name}: the selected hour should be a wash, not '
              'a solid block competing with the dial',
        );
      });
    }
  });

  group('the pickers actually build', () {
    // Cheap, but it is the check that catches a themed field the installed
    // Flutter does not have, or a resolver that throws on a state combination
    // the dialog really does ask for.
    for (final variant in [AppThemeVariant.light, AppThemeVariant.dark]) {
      testWidgets('${variant.name}: date picker opens and paints',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.of(variant),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDatePicker(
                  context: ctx,
                  initialDate: DateTime(2026, 9, 1),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2026, 9, 1),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsOneWidget);
        final dialogTheme = Theme.of(
          tester.element(find.byType(DatePickerDialog)),
        ).datePickerTheme;
        expect(dialogTheme.backgroundColor, paletteOf(variant).card);
      });

      testWidgets('${variant.name}: time picker opens and paints',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.of(variant),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showTimePicker(
                  context: ctx,
                  initialTime: const TimeOfDay(hour: 7, minute: 53),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);
        final dialogTheme = Theme.of(
          tester.element(find.byType(TimePickerDialog)),
        ).timePickerTheme;
        expect(dialogTheme.backgroundColor, paletteOf(variant).card);
        expect(dialogTheme.dialHandColor, isNotNull);
      });
    }
  });

  group('the court reaches the pickers', () {
    test('a dressed dark theme moves both pickers off gold', () {
      final darkPrince =
          kRoyalAvatars.firstWhere((r) => r.id == 'darkprince');
      final dress = courtDressFor('pixel', '${darkPrince.spriteIndex}')!;
      final base = AppTheme.of(AppThemeVariant.dark);
      final dressed = dress(AppThemeVariant.dark, base);

      final tint = darkPrince.theme.accent;

      expect(
        dressed.datePickerTheme.dayBackgroundColor
            ?.resolve({WidgetState.selected}),
        tint,
      );
      expect(dressed.timePickerTheme.dialHandColor, tint);
      expect(
        stateColor(
            dressed.timePickerTheme.hourMinuteTextColor,
            {WidgetState.selected}),
        tint,
      );

      // The gold-beside-rose bug, stated directly: nothing accent-bearing in
      // either picker may still be the base theme's gold once a court is on.
      expect(
        dressed.datePickerTheme.dayBackgroundColor
            ?.resolve({WidgetState.selected}),
        isNot(AppColors.gold),
      );
      expect(dressed.timePickerTheme.dialHandColor, isNot(AppColors.gold));

      // Canvas colours are the dress's business to leave alone.
      expect(dressed.datePickerTheme.backgroundColor,
          base.datePickerTheme.backgroundColor);
      expect(dressed.timePickerTheme.dialBackgroundColor,
          base.timePickerTheme.dialBackgroundColor);
    });

    test('the reward palettes are never dressed, pickers included', () {
      final darkPrince =
          kRoyalAvatars.firstWhere((r) => r.id == 'darkprince');
      final dress = courtDressFor('pixel', '${darkPrince.spriteIndex}')!;
      final base = AppTheme.of(AppThemeVariant.onyxAmber);

      expect(dress(AppThemeVariant.onyxAmber, base), same(base));
    });
  });
}
