import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/selectable_poi_model.dart';

void main() {
  test('parses only the traveler POI search contract', () {
    final poi = SelectablePoiModel.fromJson({
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
    }).toEntity();

    expect(poi.id, 12);
    expect(poi.openingHoursKnown, isTrue);
    expect(poi.name, 'Marble Mountains');
  });
}
