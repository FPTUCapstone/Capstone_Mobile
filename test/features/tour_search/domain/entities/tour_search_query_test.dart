import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';

void main() {
  group('TourSearchQuery', () {
    test(
      'toQueryParameters() with no filters returns only default pagination',
      () {
        const query = TourSearchQuery();
        expect(query.toQueryParameters(), {'page': 1, 'pageSize': 20});
      },
    );

    test('with destination returns correct params', () {
      const query = TourSearchQuery(destination: 'Đà Nẵng');
      expect(query.toQueryParameters(), {
        'destination': 'Đà Nẵng',
        'page': 1,
        'pageSize': 20,
      });
    });

    test('empty/whitespace destination is omitted', () {
      const query = TourSearchQuery(destination: '   ');
      expect(query.toQueryParameters(), {'page': 1, 'pageSize': 20});
    });

    test(
      'with departureDate returns correct params formatted as yyyy-MM-dd',
      () {
        final query = TourSearchQuery(departureDate: DateTime(2026, 10, 1));
        expect(query.toQueryParameters(), {
          'departureDate': '2026-10-01',
          'page': 1,
          'pageSize': 20,
        });
      },
    );

    test('with minPrice and maxPrice returns both', () {
      const query = TourSearchQuery(minPrice: 500000, maxPrice: 2000000);
      expect(query.toQueryParameters(), {
        'minPrice': 500000,
        'maxPrice': 2000000,
        'page': 1,
        'pageSize': 20,
      });
    });

    test('only minPrice set', () {
      const query = TourSearchQuery(minPrice: 500000);
      expect(query.toQueryParameters(), {
        'minPrice': 500000,
        'page': 1,
        'pageSize': 20,
      });
    });

    test('only maxPrice set', () {
      const query = TourSearchQuery(maxPrice: 2000000);
      expect(query.toQueryParameters(), {
        'maxPrice': 2000000,
        'page': 1,
        'pageSize': 20,
      });
    });

    test('destination > 300 chars throws ValidationFailure', () {
      final query = TourSearchQuery(destination: 'a' * 301);
      expect(
        () => query.toQueryParameters(),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('minPrice > maxPrice throws ValidationFailure', () {
      const query = TourSearchQuery(minPrice: 1000, maxPrice: 500);
      expect(
        () => query.toQueryParameters(),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('destination exactly 300 chars is valid', () {
      final query = TourSearchQuery(destination: 'a' * 300);
      expect(query.toQueryParameters()['destination'], 'a' * 300);
    });

    test('negative minPrice throws ValidationFailure', () {
      const query = TourSearchQuery(minPrice: -1);
      expect(
        () => query.toQueryParameters(),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('negative maxPrice throws ValidationFailure', () {
      const query = TourSearchQuery(maxPrice: -100);
      expect(
        () => query.toQueryParameters(),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('minPrice exceeding 9_999_999_999 throws ValidationFailure', () {
      const query = TourSearchQuery(minPrice: 10000000000);
      expect(
        () => query.toQueryParameters(),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('maxPrice exceeding 9_999_999_999 throws ValidationFailure', () {
      const query = TourSearchQuery(maxPrice: 10000000000);
      expect(
        () => query.toQueryParameters(),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('valid boundary prices (0 and 9_999_999_999)', () {
      const query = TourSearchQuery(minPrice: 0, maxPrice: 9999999999);
      final params = query.toQueryParameters();
      expect(params['minPrice'], 0);
      expect(params['maxPrice'], 9999999999);
    });

    test(
      'copyWith preserves unset fields and allows nulling with sentinel',
      () {
        final query1 = TourSearchQuery(
          destination: 'Hanoi',
          departureDate: DateTime(2026, 10, 1),
          minPrice: 1000,
        );

        final query2 = query1.copyWith(destination: 'Hue');

        expect(query2.destination, 'Hue');
        expect(query2.departureDate, DateTime(2026, 10, 1));
        expect(query2.minPrice, 1000);

        final query3 = query1.copyWith(destination: null, departureDate: null);

        expect(query3.destination, isNull);
        expect(query3.departureDate, isNull);
        expect(query3.minPrice, 1000);
      },
    );
  });
}
