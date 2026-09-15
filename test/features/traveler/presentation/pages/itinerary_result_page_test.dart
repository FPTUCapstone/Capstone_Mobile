import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_result_page.dart';

GeneratedItinerary _makeItinerary({
  List<GeneratedItineraryItem> items = const [],
  double totalEstimatedCost = 0,
  int totalDurationMinutes = 240,
}) => GeneratedItinerary(
  schedulingRequestId: 1,
  itineraryId: 2,
  title: 'Generated itinerary - 20 Oct 2026',
  status: 'Draft',
  totalEstimatedCost: totalEstimatedCost,
  totalDurationMinutes: totalDurationMinutes,
  items: items,
);

void main() {
  testWidgets(
    'labels a rest stop as a suggested break and shows food-not-included note',
    (tester) async {
      final itinerary = _makeItinerary(
        items: [
          GeneratedItineraryItem(
            sequenceNo: 1,
            itemKind: ItineraryItemKind.rest,
            plannedArrival: DateTime.utc(2026, 10, 20, 5),
            plannedDeparture: DateTime.utc(2026, 10, 20, 5, 30),
            stayDurationMinutes: 30,
            isMandatory: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
      );

      expect(find.text('Suggested break'), findsOneWidget);
      expect(find.text('Food and drinks are not included.'), findsOneWidget);
    },
  );

  testWidgets('shows Must-see badge for mandatory visit items', (tester) async {
    final itinerary = _makeItinerary(
      items: [
        GeneratedItineraryItem(
          sequenceNo: 1,
          itemKind: ItineraryItemKind.visit,
          plannedArrival: DateTime.utc(2026, 10, 20, 3),
          plannedDeparture: DateTime.utc(2026, 10, 20, 4),
          stayDurationMinutes: 60,
          isMandatory: true,
          poiId: 10,
          poiName: 'My Son Sanctuary',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
    );

    expect(find.text('My Son Sanctuary'), findsOneWidget);
    expect(find.text('Must-see'), findsOneWidget);
    // Non-mandatory visit items do not show the badge
    expect(find.text('Food and drinks are not included.'), findsNothing);
  });

  testWidgets('does not show Must-see badge for optional visit items', (
    tester,
  ) async {
    final itinerary = _makeItinerary(
      items: [
        GeneratedItineraryItem(
          sequenceNo: 1,
          itemKind: ItineraryItemKind.visit,
          plannedArrival: DateTime.utc(2026, 10, 20, 3),
          plannedDeparture: DateTime.utc(2026, 10, 20, 4),
          stayDurationMinutes: 60,
          isMandatory: false,
          poiId: 11,
          poiName: 'Marble Mountains',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
    );

    expect(find.text('Marble Mountains'), findsOneWidget);
    expect(find.text('Must-see'), findsNothing);
  });

  testWidgets('shows total duration in summary', (tester) async {
    final itinerary = _makeItinerary(totalDurationMinutes: 455);

    await tester.pumpWidget(
      MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
    );

    // 455 minutes = 7 h 35 min
    expect(find.textContaining('7 h 35 min'), findsOneWidget);
  });

  testWidgets('shows estimated cost disclaimer', (tester) async {
    final itinerary = _makeItinerary();

    await tester.pumpWidget(
      MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
    );

    expect(
      find.text('All costs are estimates for POI entry fees only.'),
      findsOneWidget,
    );
  });
}
