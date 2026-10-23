import 'package:trip_mate_mobile/features/tour_detail/data/datasources/tour_detail_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/repositories/tour_detail_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

final class TourDetailRepositoryImpl implements TourDetailRepository {
  const TourDetailRepositoryImpl(this._dataSource);

  final TourDetailDataSource _dataSource;

  @override
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  }) => _dataSource.getTourDetail(tourId, initialSummary: initialSummary);
}
