import 'package:trip_mate_mobile/features/tour_detail/data/datasources/tour_detail_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/repositories/tour_detail_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

/// Production boundary until the canonical UC-26 detail contract exists.
final class PendingTourDetailDataSource implements TourDetailDataSource {
  const PendingTourDetailDataSource();

  @override
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  }) async => throw const TourDetailIntegrationPendingException();
}
