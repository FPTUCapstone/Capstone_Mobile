import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/tour_search/data/datasources/tour_search_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/paged_tour_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_search_repository.dart';

final class TourSearchRepositoryImpl implements TourSearchRepository {
  const TourSearchRepositoryImpl(this._remoteDataSource);
  final TourSearchRemoteDataSource _remoteDataSource;

  @override
  Future<PagedTourResult> searchTours(TourSearchQuery query) async {
    try {
      return (await _remoteDataSource.searchTours(query)).toEntity();
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
