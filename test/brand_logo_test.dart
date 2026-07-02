import 'package:budget_tracker/providers/theme_provider.dart';
import 'package:budget_tracker/widgets/brand_logo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrandLogo', () {
    testWidgets('paints without errors at typical sizes', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogo(size: 13),
                BrandLogo(size: 54),
                BrandLogo(size: 128, background: kBrandNavy),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(BrandLogo), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renderBrandLogoPng produces real PNG bytes', (tester) async {
      // toImage/toByteData complete on the real event loop, so they must run
      // outside the fake-async test zone.
      final bytes = await tester.runAsync(
        () => renderBrandLogoPng(
          size: 96,
          color: AppColors.gold,
          background: kBrandNavy,
        ),
      );
      // PNG magic number: 89 50 4E 47.
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(100));
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}
