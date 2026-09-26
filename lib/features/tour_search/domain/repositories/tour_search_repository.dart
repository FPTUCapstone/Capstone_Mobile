import 'package:trip_mate_mobile/features/tour_search/domain/entities/paged_tour_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';

abstract interface class TourSearchRepository {
  Future<PagedTourResult> searchTours(TourSearchQuery query);
}
