import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_detail_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
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

  test('reads whether the trip is being navigated, defaulting to false', () {
    Map<String, dynamic> json([Object? flag]) => {
      'itineraryId': 10,
      'schedulingRequestId': 20,
      'title': null,
      'version': 1,
      'status': 'Active',
      'validFrom': null,
      'validTo': null,
      'canManage': true,
      'totalEstimatedCost': 0,
      'totalDurationMinutes': 60,
      'items': <Object>[],
      'isNavigationInProgress': ?flag,
    };

    expect(
      ItineraryDetailModel.fromJson(json(true)).toEntity().canEdit,
      isFalse,
    );
    expect(
      ItineraryDetailModel.fromJson(json()).toEntity().isNavigationInProgress,
      isFalse,
    );
  });

  test('reads the Review 2 trip and leg fields', () {
    final detail = ItineraryDetailModel.fromJson({
      'itineraryId': 10,
      'schedulingRequestId': 20,
      'title': 'Da Nang day',
      'version': 3,
      'status': 'Draft',
      'validFrom': '2026-09-20T01:00:00Z',
      'validTo': '2026-09-20T08:00:00Z',
      'canManage': true,
      'totalEstimatedCost': 235000,
      'totalDurationMinutes': 420,
      'transportMode': 'Motorbike',
      'budgetVnd': 800000,
      'startLocation': {
        'latitude': 16.06,
        'longitude': 108.22,
        'address': 'Hotel',
      },
      'endLocation': {'latitude': 16.07, 'longitude': 108.23, 'address': null},
      'items': [
        {
          'itemId': 1,
          'sequenceNo': 1,
          'poiId': 7,
          'poiName': 'Cham Museum',
          'category': 'Museum',
          'kind': 'Visit',
          'plannedArrival': '2026-09-20T01:10:00Z',
          'plannedDeparture': '2026-09-20T02:10:00Z',
          'travelDurationFromPreviousMinutes': 10,
          'stayDurationMinutes': 60,
          'estimatedCost': 60000,
          'isMandatory': true,
          'recommendationReason': null,
          'isUnavailable': false,
          'latitude': 16.0603,
          'longitude': 108.2234,
          'costKind': 'AdmissionTicket',
          'travelDistanceFromPreviousMeters': 9400,
          'transportModeFromPrevious': 'Walking',
          'address': '2 2 Thang 9',
        },
        {
          'itemId': 2,
          'sequenceNo': 2,
          'poiId': 8,
          'poiName': 'Noodle house',
          'category': 'Food & Drink',
          'kind': 'Visit',
          'plannedArrival': '2026-09-20T02:30:00Z',
          'plannedDeparture': '2026-09-20T03:30:00Z',
          'travelDurationFromPreviousMinutes': 20,
          'stayDurationMinutes': 60,
          'estimatedCost': 85000,
          'isMandatory': false,
          'recommendationReason': null,
          'isUnavailable': false,
          'costKind': 'AverageSpend',
        },
      ],
    }).toEntity();

    expect(detail.transportMode, TransportMode.motorbike);
    expect(detail.budgetVnd, 800000);
    expect(
      detail.startLocation,
      const ItineraryLocation(
        latitude: 16.06,
        longitude: 108.22,
        address: 'Hotel',
      ),
    );
    expect(detail.endLocation?.address, isNull);
    final museum = detail.items.first;
    expect(museum.travelDistanceFromPreviousMeters, 9400);
    expect(museum.transportModeFromPrevious, TransportMode.walking);
    expect(museum.costKind, CostKind.admissionTicket);
    expect(museum.address, '2 2 Thang 9');
    expect(museum.latitude, 16.0603);
    expect(museum.longitude, 108.2234);
    final food = detail.items.last;
    expect(food.costKind, CostKind.averageSpend);
    expect(food.travelDistanceFromPreviousMeters, isNull);
    expect(food.transportModeFromPrevious, isNull);
    expect(food.latitude, isNull);
  });

  test('older responses leave the Review 2 fields empty', () {
    final detail = ItineraryDetailModel.fromJson({
      'itineraryId': 10,
      'schedulingRequestId': 20,
      'version': 1,
      'status': 'Draft',
      'canManage': true,
      'totalDurationMinutes': 60,
      'items': <Object>[],
    }).toEntity();

    expect(detail.transportMode, isNull);
    expect(detail.budgetVnd, isNull);
    expect(detail.startLocation, isNull);
    expect(detail.endLocation, isNull);
  });
}
