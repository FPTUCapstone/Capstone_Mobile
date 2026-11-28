import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_result_page.dart';

GeneratedItinerary _makeItinerary({
  String status = 'Draft',
  List<GeneratedItineraryItem> items = const [],
  double totalEstimatedCost = 0,
  int totalDurationMinutes = 240,
}) => GeneratedItinerary(
  schedulingRequestId: 1,
  itineraryId: 2,
  title: 'Generated itinerary - 20 Oct 2026',
  status: status,
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

      expect(find.text('Nghỉ ngơi gợi ý'), findsOneWidget);
      expect(find.text('Chưa bao gồm chi phí ăn uống.'), findsOneWidget);
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
    expect(find.text('Điểm nổi bật'), findsOneWidget);
    // Non-mandatory visit items do not show the badge
    expect(find.text('Chưa bao gồm chi phí ăn uống.'), findsNothing);
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
    expect(find.text('Điểm nổi bật'), findsNothing);
  });

  testWidgets('shows total duration in summary', (tester) async {
    final itinerary = _makeItinerary(totalDurationMinutes: 455);

    await tester.pumpWidget(
      MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
    );

    // 455 minutes = 7 giờ 35 phút
    expect(find.textContaining('7 giờ 35 phút'), findsOneWidget);
  });

  testWidgets('shows estimated cost disclaimer', (tester) async {
    final itinerary = _makeItinerary();

    await tester.pumpWidget(
      MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
    );

    expect(
      find.text('Chi phí chỉ là ước tính vé tham quan các điểm đến.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a zero estimated cost and travel time between stops', (
    tester,
  ) async {
    final itinerary = _makeItinerary(
      totalEstimatedCost: 0,
      items: [
        GeneratedItineraryItem(
          sequenceNo: 1,
          itemKind: ItineraryItemKind.visit,
          plannedArrival: DateTime.utc(2026, 10, 20, 5),
          plannedDeparture: DateTime.utc(2026, 10, 20, 6),
          stayDurationMinutes: 60,
          travelDurationToNextMinutes: 15,
          isMandatory: false,
          poiName: 'First stop',
        ),
        GeneratedItineraryItem(
          sequenceNo: 2,
          itemKind: ItineraryItemKind.visit,
          plannedArrival: DateTime.utc(2026, 10, 20, 6, 15),
          plannedDeparture: DateTime.utc(2026, 10, 20, 7),
          stayDurationMinutes: 45,
          isMandatory: false,
          poiName: 'Second stop',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
    );

    expect(find.textContaining('Dự kiến'), findsOneWidget);
    // Same money format as the itinerary detail page.
    expect(find.textContaining('0 VNĐ'), findsOneWidget);
    expect(find.textContaining('Di chuyển: 15 phút'), findsOneWidget);
    expect(find.text('Tạo lịch trình khác'), findsOneWidget);
  });

  testWidgets('renders itinerary times in Vietnam planning time', (
    tester,
  ) async {
    final itinerary = _makeItinerary(
      items: [
        GeneratedItineraryItem(
          sequenceNo: 1,
          itemKind: ItineraryItemKind.visit,
          plannedArrival: DateTime.utc(2026, 10, 20, 5),
          plannedDeparture: DateTime.utc(2026, 10, 20, 6),
          stayDurationMinutes: 60,
          isMandatory: false,
          poiName: 'Da Nang Museum',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
    );

    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('13:00'), findsOneWidget);
  });

  testWidgets(
    'UC-11: Start Navigation is disabled for non-Active (Draft) itinerary with guidance',
    (tester) async {
      final itinerary = _makeItinerary(
        status: 'Draft',
        items: [
          GeneratedItineraryItem(
            sequenceNo: 1,
            itemKind: ItineraryItemKind.visit,
            plannedArrival: DateTime.utc(2026, 10, 20, 5),
            plannedDeparture: DateTime.utc(2026, 10, 20, 6),
            stayDurationMinutes: 60,
            isMandatory: false,
            poiName: 'Da Nang Museum',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
      );

      final startNavButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Bắt đầu dẫn đường'),
      );
      expect(startNavButton.onPressed, isNull);
      expect(
        find.textContaining(
          'Cần lịch trình đang hoạt động để dẫn đường (hiện tại: Bản nháp)',
        ),
        findsOneWidget,
      );
      expect(find.text('Tải về xem ngoại tuyến'), findsOneWidget);
      expect(find.text('Xem thử dẫn đường (Demo)'), findsOneWidget);
    },
  );

  testWidgets(
    'UC-11: Start Navigation is enabled for Active itinerary without guidance text',
    (tester) async {
      final itinerary = _makeItinerary(
        status: 'Active',
        items: [
          GeneratedItineraryItem(
            sequenceNo: 1,
            itemKind: ItineraryItemKind.visit,
            plannedArrival: DateTime.utc(2026, 10, 20, 5),
            plannedDeparture: DateTime.utc(2026, 10, 20, 6),
            stayDurationMinutes: 60,
            isMandatory: false,
            poiName: 'Da Nang Museum',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: ItineraryResultPage(itinerary: itinerary)),
      );

      final startNavButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Bắt đầu dẫn đường'),
      );
      expect(startNavButton.onPressed, isNotNull);
      expect(
        find.textContaining('Cần lịch trình đang hoạt động để dẫn đường'),
        findsNothing,
      );
      expect(find.text('Tải về xem ngoại tuyến'), findsOneWidget);
    },
  );
}
