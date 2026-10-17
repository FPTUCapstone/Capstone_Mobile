import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

abstract interface class TourDetailRepository {
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  });
}

final class TourDetailIntegrationPendingException implements Exception {
  const TourDetailIntegrationPendingException();
}
