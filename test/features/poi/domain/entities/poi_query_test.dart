import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';

void main() {
  group('PoiQuery', () {
    test('omits distance parameters when origin is incomplete', () {
      const query = PoiQuery(
        originLatitude: 16.061,
        maxDistanceKm: 5,
        sort: PoiSort.distance,
      );

      final parameters = query.toQueryParameters();

      expect(parameters, isNot(contains('originLatitude')));
      expect(parameters, isNot(contains('originLongitude')));
      expect(parameters, isNot(contains('maxDistanceKm')));
      expect(parameters['sort'], 'name');
    });

    test('trims search without silently truncating it', () {
      const query = PoiQuery(search: '  biển Mỹ Khê  ', openNow: true);

      expect(query.toQueryParameters(), containsPair('search', 'biển Mỹ Khê'));
      expect(query.toQueryParameters(), containsPair('openNow', true));
    });

    test('rejects search longer than the API contract', () {
      final query = PoiQuery(search: List.filled(201, 'a').join());

      expect(
        query.toQueryParameters,
        throwsA(
          isA<ValidationFailure>().having(
            (failure) => failure.fieldErrors,
            'fieldErrors',
            contains('search'),
          ),
        ),
      );
    });
  });
}
