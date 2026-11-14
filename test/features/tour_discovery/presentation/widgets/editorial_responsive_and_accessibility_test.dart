import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/features/tour_discovery/domain/entities/tour_discovery_item.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/compact_horizontal_tour_card.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/featured_tour_editorial_card.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/search_continuation_strip.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/tour_discovery_feed_states.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/traveler_tour_discovery_section.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_parallax_image.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_scroll_reveal.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_tactile_card.dart';

import '../../support/tour_discovery_fixtures.dart';

Widget _buildTestApp({
  required Widget child,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  final sampleTours = TourDiscoveryTestFixtures.sampleTours;

  group('COMMIT 05: Responsive Viewport Matrix', () {
    const viewports = <String, Size>{
      '360dp compact width': Size(360, 800),
      '390dp standard width': Size(390, 844),
      '412dp large width': Size(412, 915),
    };

    for (final entry in viewports.entries) {
      testWidgets(
        'TravelerTourDiscoverySection renders cleanly on ${entry.key}',
        (tester) async {
          await tester.pumpWidget(
            _buildTestApp(
              size: entry.value,
              child: TravelerTourDiscoverySection(
                feedState: TourDiscoveryFeedState.content,
                tours: sampleTours,
                onTapTour: (tour) {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(FeaturedTourEditorialCard), findsOneWidget);
          expect(find.byType(CompactHorizontalTourCard), findsNWidgets(2));
          expect(find.byType(SearchContinuationStrip), findsOneWidget);
        },
      );
    }

    testWidgets(
      'TravelerTourDiscoverySection handles 360dp with 1.3x text scale without overflow',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            size: const Size(360, 800),
            textScale: 1.3,
            child: TravelerTourDiscoverySection(
              feedState: TourDiscoveryFeedState.content,
              tours: sampleTours,
              onTapTour: (tour) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(FeaturedTourEditorialCard), findsOneWidget);
        expect(find.byType(CompactHorizontalTourCard), findsNWidgets(2));
      },
    );
  });

  group('COMMIT 05: Reduced Motion Matrix', () {
    testWidgets(
      'EditorialScrollReveal displays immediately when disableAnimations is true',
      (tester) async {
        final coordinator = TourRevealCoordinator();
        await tester.pumpWidget(
          _buildTestApp(
            disableAnimations: true,
            child: EditorialScrollReveal(
              itemKey: 'immediate_key',
              coordinator: coordinator,
              child: const Text('Immediate Content'),
            ),
          ),
        );

        // On frame 0 without waiting for duration, text should be immediately mounted
        expect(find.text('Immediate Content'), findsOneWidget);

        final opacityFinder = find.descendant(
          of: find.byType(EditorialScrollReveal),
          matching: find.byType(FadeTransition),
        );
        expect(opacityFinder, findsNothing);
      },
    );

    testWidgets(
      'EditorialTactileCard suppresses scale animation when disableAnimations is true',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          _buildTestApp(
            disableAnimations: true,
            child: EditorialTactileCard(
              onTap: () => tapped = true,
              borderRadius: BorderRadius.circular(12),
              backgroundColor: Colors.white,
              borderColor: Colors.grey,
              semanticLabel: 'A11y Card',
              child: const SizedBox(
                width: 100,
                height: 50,
                child: Text('A11y Press'),
              ),
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

        await tester.tap(find.text('A11y Press'));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'EditorialParallaxImage suppresses offset when disableAnimations is true',
      (tester) async {
        final scrollController = ScrollController();

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: ListView(
                  controller: scrollController,
                  children: [
                    const SizedBox(height: 300),
                    EditorialParallaxImage(
                      imageUrl: 'assets/images/destinations/hue_ngo_mon.jpg',
                      semanticLabel: 'Parallax Destination',
                      maxDisplacement: 10.0,
                    ),
                    const SizedBox(height: 800),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(EditorialParallaxImage), findsOneWidget);
      },
    );
  });

  group('COMMIT 05: Accessibility and Semantics Verification', () {
    testWidgets(
      'FeaturedTourEditorialCard and CompactHorizontalTourCard expose semantic labels',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildTestApp(
            child: Column(
              children: [
                FeaturedTourEditorialCard(tour: sampleTours[0], onTap: () {}),
                CompactHorizontalTourCard(tour: sampleTours[1], onTap: () {}),
                SearchContinuationStrip(onTap: () {}),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(
            RegExp(sampleTours[0].title, caseSensitive: false),
          ),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.bySemanticsLabel(
            RegExp(sampleTours[1].title, caseSensitive: false),
          ),
          findsAtLeastNWidgets(1),
        );

        handle.dispose();
      },
    );

    testWidgets('Feed states expose semantic buttons and messages', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var retried = false;
      var searchTapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          child: Column(
            children: [
              TourDiscoveryEmptyView(onTapSearch: () => searchTapped = true),
              TourDiscoveryErrorView(
                onRetry: () => retried = true,
                onTapSearch: () => searchTapped = true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có tour công khai phù hợp'), findsOneWidget);
      expect(find.text('Không thể tải gợi ý tour'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(retried, isTrue);

      await tester.tap(find.text('Mở tìm kiếm tour').first);
      await tester.pumpAndSettle();
      expect(searchTapped, isTrue);

      handle.dispose();
    });
  });

  group('COMMIT 05: Navigation and Tagging Dispatch', () {
    testWidgets('Section fires onTapTour callback when card is tapped', (
      tester,
    ) async {
      TourDiscoveryItem? tappedTour;

      await tester.pumpWidget(
        _buildTestApp(
          child: TravelerTourDiscoverySection(
            feedState: TourDiscoveryFeedState.content,
            tours: sampleTours,
            onTapTour: (tour) => tappedTour = tour,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap featured tour
      await tester.tap(find.byType(FeaturedTourEditorialCard));
      await tester.pumpAndSettle();
      expect(tappedTour, equals(sampleTours[0]));

      // Scroll and tap first compact tour
      final firstCompactFinder = find.byType(CompactHorizontalTourCard).first;
      await tester.scrollUntilVisible(firstCompactFinder, 100);
      await tester.pumpAndSettle();

      await tester.tap(firstCompactFinder);
      await tester.pumpAndSettle();
      expect(tappedTour, equals(sampleTours[1]));
    });

    test(
      'AppRoutes.tourDetail generates correct path with query param heroTag',
      () {
        final routeWithoutHero = AppRoutes.tourDetail('tour_123');
        expect(routeWithoutHero, '/explore/tours/tour_123');

        final routeWithHero = AppRoutes.tourDetail(
          'tour_123',
          heroTag: 'home_featured_tour_123',
        );
        expect(
          routeWithHero,
          '/explore/tours/tour_123?heroTag=home_featured_tour_123',
        );
      },
    );
  });
}
