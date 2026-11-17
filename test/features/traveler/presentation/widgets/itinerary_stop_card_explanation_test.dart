import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_stop_card.dart';

ItineraryDetailItem _item({
  ItineraryItemKind kind = ItineraryItemKind.visit,
  String? reason = 'Template reason',
  String? friendly,
  String? poiName = 'Cham Museum',
}) => ItineraryDetailItem(
  itemId: 1,
  sequenceNo: 1,
  poiId: kind == ItineraryItemKind.visit ? 10 : null,
  poiName: poiName,
  category: null,
  itemKind: kind,
  plannedArrival: DateTime.utc(2026, 9, 20, 1),
  plannedDeparture: DateTime.utc(2026, 9, 20, 2),
  travelDurationFromPreviousMinutes: null,
  stayDurationMinutes: 60,
  estimatedCost: null,
  isMandatory: false,
  recommendationReason: reason,
  friendlyExplanation: friendly,
  isUnavailable: false,
);

Future<void> _pump(WidgetTester tester, ItineraryDetailItem item) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ItineraryStopCard(item: item)),
    ),
  );
}

void main() {
  testWidgets('shows the AI sentence and not the recommendation reason', (
    tester,
  ) async {
    await _pump(tester, _item(friendly: 'AI sentence for this stop'));

    expect(find.text('AI sentence for this stop'), findsOneWidget);
    expect(find.text('Template reason'), findsNothing);
  });

  testWidgets('falls back to the reason when the AI sentence is whitespace', (
    tester,
  ) async {
    await _pump(tester, _item(friendly: '   '));

    expect(find.text('Template reason'), findsOneWidget);
  });

  testWidgets('shows the reason when there is no AI sentence', (tester) async {
    await _pump(tester, _item());

    expect(find.text('Template reason'), findsOneWidget);
  });

  testWidgets('shows the placeholder when neither sentence has text', (
    tester,
  ) async {
    await _pump(tester, _item(reason: null, friendly: ' '));

    expect(find.text('Địa điểm gợi ý'), findsOneWidget);
  });

  testWidgets('leaves the wording of a rest stop unchanged', (tester) async {
    await _pump(
      tester,
      _item(
        kind: ItineraryItemKind.rest,
        poiName: null,
        reason: 'Free rest time',
        friendly: 'AI sentence',
      ),
    );

    expect(find.text('Free rest time'), findsOneWidget);
    expect(find.text('AI sentence'), findsNothing);
  });
}
