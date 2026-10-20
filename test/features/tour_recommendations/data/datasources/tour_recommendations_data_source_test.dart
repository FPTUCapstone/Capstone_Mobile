import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/data/datasources/tour_recommendations_data_source.dart';

void main() {
  test(
    'production source reports pending integration without demo data',
    () async {
      const source = PendingTourRecommendationsDataSource();

      final result = await source.fetchCandidates();

      expect(result, isA<TourRecommendationCandidatesPending>());
    },
  );

  test('demo source contains only English fixture copy', () async {
    const source = DemoTourRecommendationsDataSource();

    final result = await source.fetchCandidates();
    final candidates = (result as TourRecommendationCandidatesAvailable).items;

    expect(candidates, isNotEmpty);
    expect(
      candidates.map((item) => item.tour.title).join(),
      isNot(contains('Đ')),
    );
    expect(
      candidates.expand((item) => item.matchReasons).join(),
      isNot(contains('Phù hợp')),
    );
  });
}
