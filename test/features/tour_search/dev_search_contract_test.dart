import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';

void main() {
  test('V2 uses canonical filters and keeps legacy query unchanged', () {
    final query = TourSearchQuery(
      keyword: ' biển yên tĩnh ',
      departureDate: DateTime(2027, 1, 1),
      endDate: DateTime(2027, 1, 5),
      durationDays: 3,
      category: 'active-server-code',
      minimumRating: 4.5,
      mode: 'hybrid',
      sort: 'priceAsc',
    );
    expect(query.toV2QueryParameters(), {
      'keyword': 'biển yên tĩnh',
      'startDate': '2027-01-01',
      'endDate': '2027-01-05',
      'durationDays': 3,
      'category': 'active-server-code',
      'minimumRating': 4.5,
      'mode': 'hybrid',
      'sort': 'priceAsc',
      'page': 1,
      'pageSize': 20,
    });
    expect(query.toQueryParameters(), {
      'departureDate': '2027-01-01',
      'page': 1,
      'pageSize': 20,
    });
    expect(query.copyWith(page: 2).keyword, query.keyword);
    expect(query.copyWith(category: null).category, isNull);
  });
  test('V2 validation rejects inverted dates and invalid mode/rating', () {
    for (final query in [
      TourSearchQuery(departureDate: DateTime(2027), endDate: DateTime(2026)),
      const TourSearchQuery(mode: 'unknown'),
      const TourSearchQuery(minimumRating: 5.1),
      const TourSearchQuery(minimumRating: 0),
      const TourSearchQuery(page: 0),
    ]) {
      expect(query.toV2QueryParameters, throwsA(isA<ValidationFailure>()));
    }
  });
  test('dev gate fails closed in production or without key', () {
    AppConfig config(Environment env, String? key) => AppConfig(
      environment: env,
      apiBaseUrl: Uri.parse('http://127.0.0.1:5077'),
      devSearchV2: true,
      devSearchKey: key,
    );
    expect(
      config(Environment.production, 'test-only-key').devSearchEnabled,
      isFalse,
    );
    expect(config(Environment.development, null).devSearchEnabled, isFalse);
    expect(
      config(Environment.development, 'test-only-key').devSearchEnabled,
      isTrue,
    );
  });
}
