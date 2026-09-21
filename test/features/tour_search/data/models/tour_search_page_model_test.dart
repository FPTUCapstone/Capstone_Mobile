import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_search/data/models/tour_search_page_model.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

void main() {
  final sampleJson = <String, Object?>{
    'page': 1,
    'pageSize': 20,
    'totalCount': 1,
    'totalPages': 1,
    'asOfUtc': '2026-09-20T01:00:00Z',
    'items': [
      {
        'tourId': '9007199254740995',
        'title': 'Tour Đà Nẵng – Hội An',
        'destinations': ['Đà Nẵng', 'Hội An'],
        'operatorName': 'Endpoint Travel',
        'durationDays': 2,
        'basePrice': 800000,
        'currency': 'VND',
        'representativeScheduleId': '9007199254740997',
        'departureAtUtc': '2026-10-01T01:00:00Z',
        'availabilityStatus': 'available',
        'remainingSlots': 11,
      },
    ],
  };

  test('Full valid JSON parses correctly and maps to domain entities', () {
    final model = TourSearchPageModel.fromJson(sampleJson);
    expect(model.page, 1);
    expect(model.pageSize, 20);
    expect(model.totalCount, 1);
    expect(model.totalPages, 1);
    expect(model.items.length, 1);

    final item = model.items.first;
    expect(item.tourId, '9007199254740995');
    expect(item.title, 'Tour Đà Nẵng – Hội An');
    expect(item.destinations, ['Đà Nẵng', 'Hội An']);
    expect(item.operatorName, 'Endpoint Travel');
    expect(item.durationDays, 2);
    expect(item.basePrice, 800000);
    expect(item.currency, 'VND');
    expect(item.representativeScheduleId, '9007199254740997');
    expect(item.departureAtUtc, DateTime.parse('2026-10-01T01:00:00Z'));
    expect(item.availabilityStatus, 'available');
    expect(item.remainingSlots, 11);

    final entity = model.toEntity();
    expect(entity.page, 1);
    expect(entity.pageSize, 20);
    expect(entity.totalCount, 1);
    expect(entity.totalPages, 1);
    expect(entity.items.length, 1);

    final entityItem = entity.items.first;
    expect(entityItem.tourId, '9007199254740995');
    expect(entityItem.title, 'Tour Đà Nẵng – Hội An');
    expect(entityItem.destinations, ['Đà Nẵng', 'Hội An']);
    expect(entityItem.operatorName, 'Endpoint Travel');
    expect(entityItem.durationDays, 2);
    expect(entityItem.basePrice, 800000);
    expect(entityItem.currency, 'VND');
    expect(entityItem.representativeScheduleId, '9007199254740997');
    expect(entityItem.departureAtUtc, DateTime.parse('2026-10-01T01:00:00Z'));
    expect(entityItem.availabilityStatus, AvailabilityStatus.available);
    expect(entityItem.remainingSlots, 11);
  });

  test('Nullable fields null parses without error', () {
    final json = <String, Object?>{
      'page': 1,
      'pageSize': 20,
      'totalCount': 0,
      'totalPages': 0,
      'items': [
        {
          'tourId': '123',
          'title': 'Test Tour',
          'destinations': ['Test'],
          'operatorName': 'Test Op',
          'durationDays': 1,
          'basePrice': 100,
          'currency': 'USD',
          'representativeScheduleId': null,
          'departureAtUtc': null,
          'availabilityStatus': 'available',
          'remainingSlots': null,
        },
      ],
    };

    final model = TourSearchPageModel.fromJson(json);
    expect(model.items.first.representativeScheduleId, isNull);
    expect(model.items.first.departureAtUtc, isNull);
    expect(model.items.first.remainingSlots, isNull);
  });

  test('Empty items list parses with empty list', () {
    final json = <String, Object?>{
      'page': 1,
      'pageSize': 20,
      'totalCount': 0,
      'totalPages': 0,
      'items': <Object?>[],
    };

    final model = TourSearchPageModel.fromJson(json);
    expect(model.items, isEmpty);
  });

  test(
    'availabilityStatus unknown string maps to AvailabilityStatus.unknown',
    () {
      final json = <String, Object?>{
        'page': 1,
        'pageSize': 20,
        'totalCount': 0,
        'totalPages': 0,
        'items': [
          {
            'tourId': '123',
            'title': 'Test Tour',
            'destinations': ['Test'],
            'operatorName': 'Test Op',
            'durationDays': 1,
            'basePrice': 100,
            'currency': 'USD',
            'representativeScheduleId': null,
            'departureAtUtc': null,
            'availabilityStatus': 'some_weird_status',
            'remainingSlots': null,
          },
        ],
      };

      final model = TourSearchPageModel.fromJson(json);
      final entity = model.toEntity();
      expect(entity.items.first.availabilityStatus, AvailabilityStatus.unknown);
    },
  );

  test('Missing required field throws FormatException', () {
    final json = <String, Object?>{
      'page': 1,
      'pageSize': 20,
      'totalCount': 0,
      'totalPages': 0,
      'items': [
        {
          // Missing tourId
          'title': 'Test Tour',
          'destinations': ['Test'],
          'operatorName': 'Test Op',
          'durationDays': 1,
          'basePrice': 100,
          'currency': 'USD',
          'availabilityStatus': 'available',
        },
      ],
    };

    expect(() => TourSearchPageModel.fromJson(json), throwsFormatException);
  });

  test('destinations as empty array parses as empty list', () {
    final json = <String, Object?>{
      'page': 1,
      'pageSize': 20,
      'totalCount': 0,
      'totalPages': 0,
      'items': [
        {
          'tourId': '123',
          'title': 'Test Tour',
          'destinations': <Object?>[],
          'operatorName': 'Test Op',
          'durationDays': 1,
          'basePrice': 100,
          'currency': 'USD',
          'representativeScheduleId': null,
          'departureAtUtc': null,
          'availabilityStatus': 'available',
          'remainingSlots': null,
        },
      ],
    };

    final model = TourSearchPageModel.fromJson(json);
    expect(model.items.first.destinations, isEmpty);
  });
}
