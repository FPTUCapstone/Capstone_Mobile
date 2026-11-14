import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/featured_tour_editorial_card.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/tour_discovery_feed_states.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/traveler_tour_discovery_section.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_parallax_image.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_scroll_reveal.dart';

import '../../support/tour_discovery_fixtures.dart';

Widget _buildHarness(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('MOTION-01: EditorialScrollReveal and TourRevealCoordinator', () {
    testWidgets('Coordinator marks items revealed and does not repeat', (
      tester,
    ) async {
      final coordinator = TourRevealCoordinator();
      expect(coordinator.hasRevealed('test_1'), isFalse);

      coordinator.markRevealed('test_1');
      expect(coordinator.hasRevealed('test_1'), isTrue);

      coordinator.resetAll();
      expect(coordinator.hasRevealed('test_1'), isFalse);
    });

    testWidgets(
      'EditorialScrollReveal animates opacity and translation on viewport entry',
      (tester) async {
        final coordinator = TourRevealCoordinator();

        await tester.pumpWidget(
          _buildHarness(
            EditorialScrollReveal(
              itemKey: 'card_reveal_1',
              coordinator: coordinator,
              enabled: true,
              child: const Text('Reveal Card Content'),
            ),
          ),
        );

        // Trigger post frame callback
        await tester.pump();

        // Check coordinator has been marked
        expect(coordinator.hasRevealed('card_reveal_1'), isTrue);

        // Advance through animation curve
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Reveal Card Content'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.text('Reveal Card Content'), findsOneWidget);
      },
    );

    testWidgets(
      'EditorialScrollReveal snaps instantly when disableAnimations is true',
      (tester) async {
        final coordinator = TourRevealCoordinator();

        await tester.pumpWidget(
          _buildHarness(
            EditorialScrollReveal(
              itemKey: 'card_reveal_reduced',
              coordinator: coordinator,
              enabled: true,
              reduceMotion: true,
              child: const Text('Reduced Motion Child'),
            ),
            disableAnimations: true,
          ),
        );

        await tester.pump();
        expect(coordinator.hasRevealed('card_reveal_reduced'), isTrue);
        expect(find.text('Reduced Motion Child'), findsOneWidget);
      },
    );
  });

  group('MOTION-02: EditorialParallaxImage', () {
    testWidgets('EditorialParallaxImage mounts with Flow and RepaintBoundary', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          SizedBox(
            height: 200,
            child: EditorialParallaxImage(
              imageUrl: 'assets/images/destinations/hue_ngo_mon.jpg',
              semanticLabel: 'Ảnh tour Huế',
              maxDisplacement: 10,
            ),
          ),
        ),
      );

      expect(find.byType(Flow), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets(
      'EditorialParallaxImage falls back to static image when animations disabled',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            SizedBox(
              height: 200,
              child: EditorialParallaxImage(
                imageUrl: 'assets/images/destinations/hue_ngo_mon.jpg',
                semanticLabel: 'Ảnh tour Huế',
                reduceMotion: true,
              ),
            ),
            disableAnimations: true,
          ),
        );

        expect(find.byType(Flow), findsNothing);
        expect(find.byType(Image), findsOneWidget);
      },
    );
  });

  group('MOTION-05: Feed State Transitions and Skeleton', () {
    testWidgets('Renders TourDiscoveryMotionSkeleton during loading state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          const TravelerTourDiscoverySection(
            feedState: TourDiscoveryFeedState.loading,
          ),
        ),
      );

      expect(find.byType(TourDiscoveryMotionSkeleton), findsOneWidget);
    });

    testWidgets('Renders TourDiscoveryEmptyView during empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          const TravelerTourDiscoverySection(
            feedState: TourDiscoveryFeedState.empty,
          ),
        ),
      );

      expect(find.byType(TourDiscoveryEmptyView), findsOneWidget);
      expect(find.text('Chưa có tour công khai phù hợp'), findsOneWidget);
    });

    testWidgets('Renders TourDiscoveryErrorView and fires onRetryFeed', (
      tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        _buildHarness(
          TravelerTourDiscoverySection(
            feedState: TourDiscoveryFeedState.error,
            onRetryFeed: () => retried = true,
          ),
        ),
      );

      expect(find.byType(TourDiscoveryErrorView), findsOneWidget);
      expect(find.text('Không thể tải gợi ý tour'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      expect(retried, isTrue);
    });

    testWidgets(
      'Transitions smoothly from loading to content with AnimatedSwitcher',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            const TravelerTourDiscoverySection(
              feedState: TourDiscoveryFeedState.loading,
            ),
          ),
        );

        expect(find.byType(TourDiscoveryMotionSkeleton), findsOneWidget);

        // Transition to content
        await tester.pumpWidget(
          _buildHarness(
            TravelerTourDiscoverySection(
              feedState: TourDiscoveryFeedState.content,
              tours: TourDiscoveryTestFixtures.sampleTours,
            ),
          ),
        );

        // Halfway through transition
        await tester.pump(const Duration(milliseconds: 160));
        expect(find.byType(AnimatedSwitcher), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(FeaturedTourEditorialCard), findsOneWidget);
      },
    );
  });
}
