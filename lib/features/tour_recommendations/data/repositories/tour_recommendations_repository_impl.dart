import 'package:trip_mate_mobile/features/tour_recommendations/data/datasources/tour_recommendations_data_source.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendation.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_query.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_result.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/repositories/tour_recommendations_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

final class TourRecommendationsRepositoryImpl
    implements TourRecommendationsRepository {
  const TourRecommendationsRepositoryImpl(this._dataSource);

  final TourRecommendationsDataSource _dataSource;

  @override
  Future<TourRecommendationsResult> getRecommendations(
    TourRecommendationsQuery query,
  ) async {
    if (!query.hasPreferences) return const TourRecommendationsNoPreferences();

    final sourceResult = await _dataSource.fetchCandidates(query);
    if (sourceResult is TourRecommendationCandidatesPending) {
      return const TourRecommendationsPending();
    }
    if (sourceResult is TourRecommendationCandidatesNoPreferences) {
      return const TourRecommendationsNoPreferences();
    }

    final available = sourceResult as TourRecommendationCandidatesAvailable;
    final candidates =
        available.items
            .where(
              (item) =>
                  item.isApproved &&
                  item.isPublic &&
                  item.tour.availabilityStatus ==
                      AvailabilityStatus.available &&
                  item.matchingScore > 80.00,
            )
            .toList()
          ..sort(
            (left, right) => right.matchingScore.compareTo(left.matchingScore),
          );

    if (candidates.isEmpty &&
        (!available.serverPaged || available.totalItems == 0)) {
      return const TourRecommendationsNoMatches();
    }

    if (available.serverPaged) {
      return TourRecommendationsSuccess(
        recommendations: candidates.map(_toEntity).toList(growable: false),
        currentPage: available.page,
        totalPages: available.totalPages,
        totalItems: available.totalItems,
      );
    }

    final totalPages = (candidates.length / query.pageSize).ceil();
    final currentPage = query.page.clamp(1, totalPages);
    final start = (currentPage - 1) * query.pageSize;
    final end = (start + query.pageSize).clamp(0, candidates.length);

    return TourRecommendationsSuccess(
      recommendations: candidates
          .sublist(start, end)
          .map(_toEntity)
          .toList(growable: false),
      currentPage: currentPage,
      totalPages: totalPages,
      totalItems: candidates.length,
    );
  }

  static TourRecommendation _toEntity(TourRecommendationCandidate item) =>
      TourRecommendation(
        tour: item.tour,
        matchingScore: item.matchingScore,
        matchReasons: item.matchReasons,
      );
}
