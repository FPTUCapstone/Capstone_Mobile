import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/selectable_poi_search_result_model.dart';

void main() {
  test('parses only the POIs supplied by the search response', () {
    final result = SelectablePoiSearchResultModel.fromJson({
      'items': [
        {
          'id': 12,
          'name': 'Marble Mountains',
          'address': 'Ngu Hanh Son, Da Nang',
          'latitude': 16.0038,
          'longitude': 108.2631,
          'averageVisitDurationMinutes': 90,
          'estimatedVisitCost': 40000,
          'openingHoursKnown': true,
          'hasShelter': false,
          'categoryName': 'Attraction',
        },
      ],
      'page': 1,
      'pageSize': 50,
      'totalCount': 1,
    });

    expect(result.items, hasLength(1));
    expect(result.items.single.id, 12);
    expect(result.totalCount, 1);
  });
}
