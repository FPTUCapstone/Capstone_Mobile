import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/data/datasources/tour_recommendations_data_source.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/data/repositories/tour_recommendations_repository_impl.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_query.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

void main() {
  test(
    'filters eligibility and strict threshold, sorts, and paginates',
    () async {
      final repository = TourRecommendationsRepositoryImpl(
        _FakeDataSource([
          _candidate('threshold', 0.80),
          _candidate('private', 0.99, isPublic: false),
          _candidate('unapproved', 0.98, isApproved: false),
          _candidate('sold-out', 0.97, status: AvailabilityStatus.soldOut),
          _candidate('second', 0.82),
          _candidate('first', 0.95),
        ]),
      );

      final result = await repository.getRecommendations(
        const TourRecommendationsQuery(page: 1, pageSize: 1),
      );

      expect(result, isA<TourRecommendationsSuccess>());
      final success = result as TourRecommendationsSuccess;
      expect(success.recommendations.single.tour.tourId, 'first');
      expect(success.totalItems, 2);
      expect(success.totalPages, 2);
    },
  );

  test('returns no preferences before asking the data source', () async {
    final source = _FakeDataSource([_candidate('tour', 0.95)]);
    final repository = TourRecommendationsRepositoryImpl(source);

    final result = await repository.getRecommendations(
      const TourRecommendationsQuery(hasPreferences: false),
    );

    expect(result, isA<TourRecommendationsNoPreferences>());
    expect(source.calls, 0);
  });

  test('returns no matches when all candidates are ineligible', () async {
    final repository = TourRecommendationsRepositoryImpl(
      _FakeDataSource([_candidate('threshold', 0.80)]),
    );

    final result = await repository.getRecommendations(
      const TourRecommendationsQuery(),
    );

    expect(result, isA<TourRecommendationsNoMatches>());
  });
}

TourRecommendationCandidate _candidate(
  String id,
  double score, {
  bool isApproved = true,
  bool isPublic = true,
  AvailabilityStatus status = AvailabilityStatus.available,
}) => TourRecommendationCandidate(
  tour: TourSummary(
    tourId: id,
    title: id,
    destinations: const ['Da Nang'],
    operatorName: 'TripMate Tours',
    durationDays: 1,
    basePrice: 100,
    currency: 'VND',
    representativeScheduleId: 'schedule-$id',
    departureAtUtc: DateTime.utc(2026, 10, 1),
    availabilityStatus: status,
    remainingSlots: 1,
  ),
  matchingScore: score,
  isApproved: isApproved,
  isPublic: isPublic,
);

final class _FakeDataSource implements TourRecommendationsDataSource {
  _FakeDataSource(this.candidates);

  final List<TourRecommendationCandidate> candidates;
  int calls = 0;

  @override
  Future<TourRecommendationCandidates> fetchCandidates() async {
    calls++;
    return TourRecommendationCandidatesAvailable(candidates);
  }
}
