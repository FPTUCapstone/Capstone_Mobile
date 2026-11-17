import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/shared/widgets/tripmate_logo.dart';

void main() {
  group('TripMateLogo & TripMateBrand (PR 1 Logo Fix)', () {
    testWidgets(
      'TripMateBrand uses BricolageGrotesque instead of missing Geist font',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TripMateBrand(
                subtitle: 'Central Vietnam Travel',
                titleColor: Color(0xFF00152A),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final title = tester.widget<Text>(find.text('TripMate'));
        expect(title.style?.fontFamily, AppTypography.displayFont);
        expect(title.style?.fontFamily, isNot('Geist'));
      },
    );

    testWidgets(
      'TripMateLogo.wordmark renders valid PNG assets instead of broken SVG paths',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TripMateLogo.wordmark(),
                  TripMateLogo.wordmark(isWhite: true),
                  TripMateLogo.full(),
                  TripMateLogo.full(isWhite: true),
                  TripMateLogo.emblem(),
                  TripMateEmblem(isWhite: true),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(images, hasLength(6));
        for (final image in images) {
          expect(image.image, isA<AssetImage>());
          final assetName = (image.image as AssetImage).assetName;
          expect(assetName, endsWith('.png'));
          expect(assetName, isNot(endsWith('.svg')));
        }
      },
    );
  });
}
