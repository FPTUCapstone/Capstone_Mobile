import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_image.dart';

void main() {
  group('PoiImage (Decision A asset + network regression)', () {
    testWidgets('renders bundled local destination assets using Image.asset', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 120,
                  width: 200,
                  child: PoiImage(
                    url: 'assets/images/destinations/bana_golden_bridge.jpg',
                    semanticLabel: 'Golden Bridge',
                  ),
                ),
                SizedBox(
                  height: 120,
                  width: 200,
                  child: PoiImage(
                    url: 'assets/images/destinations/hoian_ancient_town.jpg',
                    semanticLabel: 'Hoi An',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      expect(images[0].image, isA<AssetImage>());
      expect(
        (images[0].image as AssetImage).assetName,
        'assets/images/destinations/bana_golden_bridge.jpg',
      );
      expect(images[1].image, isA<AssetImage>());
      expect(find.byIcon(Icons.landscape_outlined), findsNothing);
    });

    testWidgets(
      'preserves Image.network branch and placeholder fallback for invalid network images',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 120,
                width: 200,
                child: PoiImage(url: 'https://example.invalid/poi.jpg'),
              ),
            ),
          ),
        );
        await tester.pump();

        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, isA<NetworkImage>());
        expect(
          (image.image as NetworkImage).url,
          'https://example.invalid/poi.jpg',
        );
      },
    );

    testWidgets(
      'renders placeholder when url is null or empty or invalid asset',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(height: 80, width: 120, child: PoiImage(url: null)),
                  SizedBox(height: 80, width: 120, child: PoiImage(url: '   ')),
                  SizedBox(
                    height: 80,
                    width: 120,
                    child: PoiImage(
                      url: 'assets/images/destinations/missing.jpg',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.landscape_outlined), findsNWidgets(3));
      },
    );
  });
}
