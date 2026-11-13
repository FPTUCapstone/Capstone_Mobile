import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/pages/tour_detail_page.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_tactile_card.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_tour_hero.dart';

import '../../support/tour_discovery_fixtures.dart';

Widget _buildHarness(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  group('MOTION-03: EditorialTactileCard', () {
    testWidgets(
      'press down triggers scale down, pointer release triggers onTap',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          _buildHarness(
            Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: EditorialTactileCard(
                  onTap: () => tapped = true,
                  borderRadius: BorderRadius.circular(16),
                  backgroundColor: Colors.white,
                  borderColor: Colors.grey,
                  semanticLabel: 'Test Card',
                  child: const Text('Card Content'),
                ),
              ),
            ),
          ),
        );

        final cardFinder = find.text('Card Content');
        final gesture = await tester.startGesture(tester.getCenter(cardFinder));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));

        final scaleFinder = find.descendant(
          of: find.byType(EditorialTactileCard),
          matching: find.byType(ScaleTransition),
        );
        expect(scaleFinder, findsOneWidget);
        final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
        expect(scaleWidget.scale.value, lessThan(1.0));

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'drag beyond 8dp cancels press animation without triggering onTap',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          _buildHarness(
            Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: EditorialTactileCard(
                  onTap: () => tapped = true,
                  borderRadius: BorderRadius.circular(16),
                  backgroundColor: Colors.white,
                  borderColor: Colors.grey,
                  semanticLabel: 'Test Card',
                  child: const Text('Draggable Card'),
                ),
              ),
            ),
          ),
        );

        final cardFinder = find.text('Draggable Card');
        final gesture = await tester.startGesture(tester.getCenter(cardFinder));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        // Drag 15px downwards (exceeding 8px threshold)
        await gesture.moveBy(const Offset(0, 15));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));

        await gesture.up();
        await tester.pumpAndSettle();
        expect(tapped, isFalse);
      },
    );

    testWidgets('reduceMotion bypasses scale animation', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          EditorialTactileCard(
            onTap: () {},
            borderRadius: BorderRadius.circular(16),
            backgroundColor: Colors.white,
            borderColor: Colors.grey,
            semanticLabel: 'Reduced Motion Card',
            reduceMotion: true,
            child: const Text('Static Card'),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(EditorialTactileCard),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(find.text('Static Card'), findsOneWidget);
    });
  });

  group('MOTION-04 & Screen #65: Hero Navigation and Frame-0 Thumbnail Mount', () {
    testWidgets(
      'TourDetailPage mounts frame-0 image header and EditorialTourHero when initialSummary is provided',
      (tester) async {
        final summary = TourDiscoveryTestFixtures.sampleTours[0].toSummary();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: TourDetailPage(
              tourId: summary.tourId,
              initialSummary: summary,
              heroTag: 'home_featured_${summary.tourId}',
              // Omit getTourDetail so it remains in loading status
            ),
          ),
        );

        // Frame 0 expectation: image header must exist inside EditorialTourHero before network completion
        expect(find.byType(EditorialTourHero), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final heroWidget = tester.widget<Hero>(find.byType(Hero));
        expect(heroWidget.tag, 'home_featured_${summary.tourId}');
      },
    );

    testWidgets(
      'TourDetailPage mounts plain CircularProgressIndicator when initialSummary is null',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: TourDetailPage(tourId: 'direct_entry_tour')),
        );

        expect(find.byType(EditorialTourHero), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );
  });
}
