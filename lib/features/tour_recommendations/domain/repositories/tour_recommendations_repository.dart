import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_query.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendations_result.dart';

abstract interface class TourRecommendationsRepository {
  Future<TourRecommendationsResult> getRecommendations(
    TourRecommendationsQuery query,
  );
}
