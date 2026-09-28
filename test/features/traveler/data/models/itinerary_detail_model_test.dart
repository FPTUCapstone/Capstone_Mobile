import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_detail_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

void main() {
  test('parses rest item, unavailable POI, and nullable fields safely', () {
    final detail = ItineraryDetailModel.fromJson({
      'itineraryId': 10,
      'schedulingRequestId': 20,
      'title': 'Da Nang day',
      'version': 2,
      'status': 'Draft',
      'validFrom': '2026-09-20T01:00:00Z',
      'validTo': '2026-09-20T08:00:00Z',
      'canManage': true,
      'totalEstimatedCost': 150000,
      'totalDurationMinutes': 420,
      'items': [
        {
          'itemId': 1,
          'sequenceNo': 1,
          'poiId': null,
          'poiName': null,
          'category': null,
          'kind': 'Rest',
          'plannedArrival': '2026-09-20T04:00:00Z',
          'plannedDeparture': '2026-09-20T04:30:00Z',
          'travelDurationFromPreviousMinutes': 15,
          'stayDurationMinutes': 30,
          'estimatedCost': null,
          'isMandatory': false,
          'recommendationReason': 'Free/rest time',
          'isUnavailable': false,
        },
        {
          'itemId': 2,
          'sequenceNo': 2,
          'poiId': 99,
          'poiName': 'Closed museum',
          'category': 'Museum',
          'kind': 'Visit',
          'plannedArrival': '2026-09-20T05:00:00Z',
          'plannedDeparture': '2026-09-20T06:00:00Z',
          'travelDurationFromPreviousMinutes': 30,
          'stayDurationMinutes': 60,
          'estimatedCost': 150000,
          'isMandatory': true,
          'recommendationReason': 'Must-see',
          'isUnavailable': true,
        },
      ],
    }).toEntity();

    expect(detail.version, 2);
    expect(detail.items, hasLength(2));
    expect(detail.items.first.itemKind, ItineraryItemKind.rest);
    expect(detail.items.last.isUnavailable, isTrue);
    expect(detail.items.first.poiId, isNull);
  });

  test('rejects an unknown item kind', () {
    expect(
      () => ItineraryDetailModel.fromJson({
        'itineraryId': 1,
        'schedulingRequestId': 2,
        'version': 1,
        'status': 'Draft',
        'canManage': false,
        'totalDurationMinutes': 1,
        'items': [
          {
            'itemId': 1,
            'sequenceNo': 1,
            'kind': 'Unknown',
            'plannedArrival': '2026-09-20T05:00:00Z',
            'plannedDeparture': '2026-09-20T06:00:00Z',
            'stayDurationMinutes': 60,
            'isMandatory': false,
            'isUnavailable': false,
          },
        ],
      }).toEntity(),
      throwsFormatException,
    );
  });
}
