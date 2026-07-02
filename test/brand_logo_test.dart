import 'package:budget_tracker/widgets/brand_logo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrandLogo', () {
    testWidgets('renders the bundled logo artwork at typical sizes',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogo(size: 13),
                BrandLogo(size: 54),
                BrandLogo(size: 128, circular: true),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(BrandLogo), findsNWidgets(3));
      // Every mark is the real bundled artwork, not a redrawn approximation.
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images, hasLength(3));
      for (final img in images) {
        expect((img.image as AssetImage).assetName, kBrandLogoAsset);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('loadBrandLogoBytes returns the bundled PNG', (tester) async {
      // rootBundle I/O completes on the real event loop, so it must run
      // outside the fake-async test zone.
      final bytes = await tester.runAsync(loadBrandLogoBytes);
      // PNG magic number: 89 50 4E 47.
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(100));
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}
