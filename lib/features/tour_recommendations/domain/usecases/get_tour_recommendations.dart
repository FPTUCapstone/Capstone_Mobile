import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_query.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_result.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/repositories/tour_recommendations_repository.dart';

final class GetTourRecommendations {
  const GetTourRecommendations(this._repository);

  final TourRecommendationsRepository _repository;

  Future<TourRecommendationsResult> call(TourRecommendationsQuery query) =>
      _repository.getRecommendations(query);
}
