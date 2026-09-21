import 'package:trip_mate_mobile/features/tour_search/domain/entities/paged_tour_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_search_repository.dart';

final class SearchToursUseCase {
  const SearchToursUseCase(this._repository);

  final TourSearchRepository _repository;

  Future<PagedTourResult> call(TourSearchQuery query) =>
      _repository.searchTours(query);
}
