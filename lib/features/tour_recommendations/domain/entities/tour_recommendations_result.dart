import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendation.dart';

sealed class TourRecommendationsResult extends Equatable {
  const TourRecommendationsResult();
}

final class TourRecommendationsSuccess extends TourRecommendationsResult {
  const TourRecommendationsSuccess({
    required this.recommendations,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
  });

  final List<TourRecommendation> recommendations;
  final int currentPage;
  final int totalPages;
  final int totalItems;

  @override
  List<Object?> get props => [
    recommendations,
    currentPage,
    totalPages,
    totalItems,
  ];
}

final class TourRecommendationsPending extends TourRecommendationsResult {
  const TourRecommendationsPending();
  @override
  List<Object?> get props => const [];
}

final class TourRecommendationsNoPreferences extends TourRecommendationsResult {
  const TourRecommendationsNoPreferences();
  @override
  List<Object?> get props => const [];
}

final class TourRecommendationsNoMatches extends TourRecommendationsResult {
  const TourRecommendationsNoMatches();
  @override
  List<Object?> get props => const [];
}
