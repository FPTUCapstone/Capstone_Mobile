import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/features/tour_discovery/domain/entities/tour_discovery_item.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/compact_horizontal_tour_card.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/featured_tour_editorial_card.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/search_continuation_strip.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/traveler_tour_discovery_section.dart';

Widget _buildHarness(
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('Variant A Editorial Tour Cards (Commit 02)', () {
    testWidgets(
      'FeaturedTourEditorialCard renders complete layout and fires onTap',
      (tester) async {
        var tapped = false;
        final tour = TourDiscoveryItem.curatedDefault[0];

        await tester.pumpWidget(
          _buildHarness(
            FeaturedTourEditorialCard(tour: tour, onTap: () => tapped = true),
          ),
        );

        expect(find.text(tour.title), findsOneWidget);
        expect(find.textContaining('Huế'), findsWidgets);
        expect(find.text(tour.operatorName), findsOneWidget);
        expect(find.text('850,000 VND'), findsOneWidget);
        expect(find.text('4.9'), findsOneWidget);

        await tester.tap(find.byType(FeaturedTourEditorialCard));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'CompactHorizontalTourCard renders horizontal layout and fires onTap',
      (tester) async {
        var tapped = false;
        final tour = TourDiscoveryItem.curatedDefault[1];

        await tester.pumpWidget(
          _buildHarness(
            CompactHorizontalTourCard(tour: tour, onTap: () => tapped = true),
          ),
        );

        expect(find.text(tour.title), findsOneWidget);
        expect(find.text(tour.operatorName), findsOneWidget);
        expect(find.text('1,250,000 VND'), findsOneWidget);
        expect(find.text('4.8'), findsOneWidget);

        await tester.tap(find.byType(CompactHorizontalTourCard));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'SearchContinuationStrip renders search entry and fires onTap',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          _buildHarness(SearchContinuationStrip(onTap: () => tapped = true)),
        );

        expect(find.text('Tìm kiếm & lọc thêm tour'), findsOneWidget);
        expect(find.text('Lọc điểm đến, ngày đi & mức giá'), findsOneWidget);
        expect(find.byIcon(Icons.manage_search_rounded), findsOneWidget);

        await tester.tap(find.byType(SearchContinuationStrip));
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'TravelerTourDiscoverySection composes 1 featured, 2 compact rows, and continuation',
      (tester) async {
        TourDiscoveryItem? selectedTour;

        await tester.pumpWidget(
          _buildHarness(
            TravelerTourDiscoverySection(onTapTour: (t) => selectedTour = t),
          ),
        );

        expect(find.text('Tour nổi bật miền Trung'), findsOneWidget);
        expect(find.text('Xem tất cả'), findsOneWidget);
        expect(find.byType(FeaturedTourEditorialCard), findsOneWidget);
        expect(find.byType(CompactHorizontalTourCard), findsNWidgets(2));
        expect(find.byType(SearchContinuationStrip), findsOneWidget);

        // Tap featured
        await tester.tap(find.byType(FeaturedTourEditorialCard));
        expect(selectedTour?.id, 'hue');
      },
    );

    for (final (width, name, scale) in [
      (360.0, '360dp standard', 1.0),
      (390.0, '390dp standard', 1.0),
      (412.0, '412dp standard', 1.0),
      (360.0, '360dp large text (1.3x)', 1.3),
    ]) {
      testWidgets(
        'TravelerTourDiscoverySection renders without overflow at $name',
        (tester) async {
          await tester.pumpWidget(
            _buildHarness(
              const TravelerTourDiscoverySection(),
              size: Size(width, 800),
              textScale: scale,
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
  });
}
