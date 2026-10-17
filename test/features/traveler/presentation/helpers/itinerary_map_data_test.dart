import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_map_data.dart';

import '../pages/itinerary_detail_edit_test.dart';

void main() {
  DateTime vn(int hour, int minute) =>
      DateTime.utc(2026, 10, 18, hour - 7, minute);

  ItineraryDetail withEnds(
    ItineraryDetail plan, {
    ItineraryLocation? start,
    ItineraryLocation? end,
  }) => ItineraryDetail(
    itineraryId: plan.itineraryId,
    schedulingRequestId: plan.schedulingRequestId,
    title: plan.title,
    version: plan.version,
    status: plan.status,
    validFrom: plan.validFrom,
    validTo: plan.validTo,
    canManage: plan.canManage,
    totalEstimatedCost: plan.totalEstimatedCost,
    totalDurationMinutes: plan.totalDurationMinutes,
    items: plan.items,
    transportMode: plan.transportMode,
    startLocation: start,
    endLocation: end,
  );

  const hotel = ItineraryLocation(
    latitude: 16.0,
    longitude: 108.2,
    address: 'Hotel',
  );
  const station = ItineraryLocation(latitude: 16.1, longitude: 108.3);

  test('numbers visit stops and colours them by type', () {
    final data = ItineraryMapData.fromDetail(
      withEnds(editablePlan(), start: hotel, end: station),
    );

    expect(data.markers.map((marker) => marker.kind), [
      ItineraryMarkerKind.start,
      ItineraryMarkerKind.attraction,
      ItineraryMarkerKind.attraction,
      ItineraryMarkerKind.food,
      ItineraryMarkerKind.end,
    ]);
    expect(data.markers.map((marker) => marker.label), [
      'Xuất phát',
      '1',
      '2',
      '3',
      'Kết thúc',
    ]);
    // Visit markers carry their itinerary item ID for list sync.
    expect(data.markers[1].itemId, 10);
    expect(data.markers.first.itemId, isNull);
  });

  test('a trip that returns to its start shows one start/end marker', () {
    final data = ItineraryMapData.fromDetail(
      withEnds(editablePlan(), start: hotel, end: hotel),
    );

    expect(
      data.markers.where((marker) => marker.kind == ItineraryMarkerKind.end),
      isEmpty,
    );
    expect(data.markers.first.label, 'Xuất phát · Kết thúc');
    expect(
      data.legs.last.to,
      const NavigationCoordinate(latitude: 16.0, longitude: 108.2),
    );
  });

  test('legs use the transport of each leg, else the trip default', () {
    final plan = editablePlan(
      items: [
        planItem(1, 'Museum', vn(8, 0)),
        planItem(2, 'Beach', vn(9, 30), mode: TransportMode.walking),
        planItem(3, 'Noodles', vn(11, 0), costKind: CostKind.averageSpend),
      ],
    );
    final data = ItineraryMapData.fromDetail(withEnds(plan, start: hotel));

    expect(data.legs.map((leg) => leg.mode), [
      TransportMode.motorbike, // hotel -> museum: trip default
      TransportMode.walking,
      TransportMode.motorbike,
    ]);
    expect(
      data.legs.first.from,
      const NavigationCoordinate(latitude: 16.0, longitude: 108.2),
    );
  });

  test('stops without coordinates are left off the map', () {
    final plan = editablePlan();
    final noCoordinates = ItineraryDetail(
      itineraryId: plan.itineraryId,
      schedulingRequestId: plan.schedulingRequestId,
      title: plan.title,
      version: plan.version,
      status: plan.status,
      validFrom: plan.validFrom,
      validTo: plan.validTo,
      canManage: plan.canManage,
      totalEstimatedCost: plan.totalEstimatedCost,
      totalDurationMinutes: plan.totalDurationMinutes,
      items: [
        ItineraryDetailItem(
          itemId: 1,
          sequenceNo: 1,
          poiId: 1,
          poiName: 'Old stop',
          category: null,
          itemKind: ItineraryItemKind.visit,
          plannedArrival: vn(8, 0),
          plannedDeparture: vn(9, 0),
          travelDurationFromPreviousMinutes: null,
          stayDurationMinutes: 60,
          estimatedCost: null,
          isMandatory: false,
          recommendationReason: null,
          isUnavailable: false,
        ),
      ],
    );

    final data = ItineraryMapData.fromDetail(noCoordinates);
    expect(data.markers, isEmpty);
    expect(data.legs, isEmpty);
  });
}
