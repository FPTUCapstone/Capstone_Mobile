import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_detail_model.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_page_model.dart';

void main() {
  test('maps paged POIs and nullable list fields', () {
    final model = PoiPageModel.fromJson({
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
      'totalPages': 1,
      'items': [
        {
          'id': 42,
          'name': 'My Khe Beach',
          'categoryId': 3,
          'categoryName': 'Beach',
          'latitude': 16.061,
          'longitude': 108.246,
          'address': null,
          'indoorOutdoor': 'Outdoor',
          'averageVisitDurationMinutes': 90,
          'hasShelter': false,
          'averageRating': null,
          'reviewCount': 0,
          'thumbnailUrl': null,
          'distanceKm': null,
          'isOpenNow': true,
        },
      ],
    });

    final page = model.toEntity();
    expect(page.items.single.name, 'My Khe Beach');
    expect(page.items.single.averageRating, isNull);
    expect(page.items.single.distanceKm, isNull);
  });

  test('maps detail collections in API order', () {
    final detail = PoiDetailModel.fromJson({
      'id': 42,
      'name': 'My Khe Beach',
      'description': 'A public beach.',
      'status': 'Active',
      'categoryId': 3,
      'categoryName': 'Beach',
      'latitude': 16.061,
      'longitude': 108.246,
      'address': null,
      'indoorOutdoor': 'Outdoor',
      'averageVisitDurationMinutes': 90,
      'hasShelter': false,
      'scenicScore': null,
      'photoRating': null,
      'averageRating': 4.6,
      'reviewCount': 1284,
      'isOpenNow': true,
      'openingHours': [
        {'dayOfWeek': 0, 'openTime': null, 'closeTime': null, 'isClosed': true},
        {
          'dayOfWeek': 1,
          'openTime': '05:00:00',
          'closeTime': '21:00:00',
          'isClosed': false,
        },
      ],
      'photos': [
        {
          'id': 8,
          'url': 'https://example.test/photo.jpg',
          'caption': null,
          'sortOrder': 0,
        },
      ],
      'tags': [
        {'id': 2, 'name': 'Sunrise'},
      ],
      'createdAtUtc': '2026-09-09T11:20:00Z',
      'updatedAtUtc': '2026-09-09T11:20:00Z',
    }).toEntity();

    expect(detail.openingHours.first.dayOfWeek, 0);
    expect(detail.openingHours.first.openTime, isNull);
    expect(detail.openingHours.first.closeTime, isNull);
    expect(detail.photos.single.id, 8);
    expect(detail.tags.single.name, 'Sunrise');
  });

  test('accepts a null detail description', () {
    final detail = PoiDetailModel.fromJson({
      'id': 1,
      'name': 'POI',
      'description': null,
      'status': 'Active',
      'categoryId': 1,
      'categoryName': 'Attraction',
      'latitude': 1,
      'longitude': 1,
      'indoorOutdoor': 'Outdoor',
      'averageVisitDurationMinutes': 60,
      'hasShelter': false,
      'reviewCount': 0,
      'isOpenNow': true,
      'openingHours': [],
      'photos': [],
      'tags': [],
      'createdAtUtc': '2026-01-01T00:00:00Z',
      'updatedAtUtc': '2026-01-01T00:00:00Z',
    }).toEntity();
    expect(detail.description, isNull);
  });
}
