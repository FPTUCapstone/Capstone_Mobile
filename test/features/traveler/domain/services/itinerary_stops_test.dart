import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/itinerary_stops.dart';

void main() {
  // 08:00 Vietnam time = 01:00 UTC.
  DateTime vn(int hour, [int minute = 0]) =>
      DateTime.utc(2026, 10, 18, hour - 7, minute);

  ItineraryDetailItem visit(
    int id,
    int poiId, {
    required DateTime arrival,
    int stay = 60,
    TransportMode? modeFromPrevious,
    CostKind costKind = CostKind.admissionTicket,
  }) => ItineraryDetailItem(
    itemId: id,
    sequenceNo: id,
    poiId: poiId,
    poiName: 'POI $poiId',
    category: null,
    itemKind: ItineraryItemKind.visit,
    plannedArrival: arrival,
    plannedDeparture: arrival.add(Duration(minutes: stay)),
    travelDurationFromPreviousMinutes: 10,
    stayDurationMinutes: stay,
    estimatedCost: null,
    isMandatory: false,
    recommendationReason: null,
    isUnavailable: false,
    transportModeFromPrevious: modeFromPrevious,
    costKind: costKind,
  );

  ItineraryDetailItem rest(
    int id,
    DateTime arrival, {
    TransportMode? modeFromPrevious,
  }) => ItineraryDetailItem(
    itemId: id,
    sequenceNo: id,
    poiId: null,
    poiName: null,
    category: null,
    itemKind: ItineraryItemKind.rest,
    plannedArrival: arrival,
    plannedDeparture: arrival.add(const Duration(minutes: 30)),
    travelDurationFromPreviousMinutes: 0,
    stayDurationMinutes: 30,
    estimatedCost: null,
    isMandatory: false,
    recommendationReason: null,
    isUnavailable: false,
    transportModeFromPrevious: modeFromPrevious,
  );

  ItineraryDetail detail(List<ItineraryDetailItem> items, {DateTime? to}) =>
      ItineraryDetail(
        itineraryId: 1,
        schedulingRequestId: 2,
        title: null,
        version: 1,
        status: 'Draft',
        validFrom: vn(8),
        validTo: to ?? vn(17),
        canManage: true,
        totalEstimatedCost: 0,
        totalDurationMinutes: 540,
        items: items,
      );

  final plan = detail([
    visit(1, 11, arrival: vn(8)),
    visit(2, 22, arrival: vn(9, 30), modeFromPrevious: TransportMode.walking),
    // Leaving the beach by motorbike for a break; the break -> next leg is
    // by car and belongs to the break, not to the beach.
    rest(3, vn(10, 30), modeFromPrevious: TransportMode.motorbike),
    visit(4, 33, arrival: vn(11, 30), modeFromPrevious: TransportMode.car),
  ]);

  group('current stops', () {
    test('each visit keeps its own outgoing leg, even before a break', () {
      expect(ItineraryStops.current(plan), const [
        ItineraryStop(poiId: 11, transportModeToNext: TransportMode.walking),
        ItineraryStop(poiId: 22, transportModeToNext: TransportMode.motorbike),
        ItineraryStop(poiId: 33),
      ]);
    });
  });

  group('edits', () {
    final stops = ItineraryStops.current(plan);

    test('changing a leg sets the mode on the stop before it', () {
      expect(
        ItineraryStops.withLegMode(
          stops,
          toPoiId: 33,
          mode: TransportMode.motorbike,
        ),
        const [
          ItineraryStop(poiId: 11, transportModeToNext: TransportMode.walking),
          ItineraryStop(
            poiId: 22,
            transportModeToNext: TransportMode.motorbike,
          ),
          ItineraryStop(poiId: 33),
        ],
      );
    });

    test('inserting after a stop keeps the other legs', () {
      expect(ItineraryStops.insertAfter(stops, afterPoiId: 22, poiId: 99), [
        stops[0],
        stops[1],
        const ItineraryStop(poiId: 99),
        stops[2],
      ]);
    });

    test('replacing keeps the position and the outgoing mode', () {
      expect(ItineraryStops.replace(stops, oldPoiId: 11, newPoiId: 77), [
        const ItineraryStop(
          poiId: 77,
          transportModeToNext: TransportMode.walking,
        ),
        stops[1],
        stops[2],
      ]);
    });

    test('removing drops only that stop', () {
      expect(ItineraryStops.remove(stops, 22), [stops[0], stops[2]]);
    });

    test('reordering keeps a mode only where the next stop is unchanged', () {
      expect(ItineraryStops.reorder(stops, [22, 33, 11]), const [
        ItineraryStop(poiId: 22, transportModeToNext: TransportMode.motorbike),
        ItineraryStop(poiId: 33),
        ItineraryStop(poiId: 11),
      ]);
    });
  });

  test('arrival shifts list stops whose time moved, in minutes', () {
    final after = detail([
      visit(5, 11, arrival: vn(8)),
      visit(6, 22, arrival: vn(9, 55)),
      visit(7, 33, arrival: vn(11, 20)),
      visit(8, 44, arrival: vn(13)),
    ]);

    expect(ItineraryStops.arrivalShifts(plan, after), {22: 25, 33: -10});
  });

  group('lunch slot', () {
    test('suggests the stop whose departure is closest to noon', () {
      final day = detail([
        visit(1, 11, arrival: vn(8), stay: 120),
        visit(2, 22, arrival: vn(10, 30), stay: 75),
        visit(3, 33, arrival: vn(14)),
      ]);
      expect(ItineraryStops.lunchSlotAfterItemId(day), 2);
    });

    test('no card when a restaurant is already planned', () {
      final day = detail([
        visit(1, 11, arrival: vn(8), stay: 120),
        visit(2, 22, arrival: vn(11, 30), costKind: CostKind.averageSpend),
        visit(3, 33, arrival: vn(14)),
      ]);
      expect(ItineraryStops.lunchSlotAfterItemId(day), isNull);
    });

    test('no card when the trip does not cover 11:00-13:30', () {
      final morning = detail([
        visit(1, 11, arrival: vn(8)),
        visit(2, 22, arrival: vn(10), stay: 90),
      ], to: vn(11, 30));
      expect(ItineraryStops.lunchSlotAfterItemId(morning), isNull);
    });
  });
}
