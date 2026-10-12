import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/repositories/tour_detail_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

final class GetTourDetail {
  const GetTourDetail(this._repository);

  final TourDetailRepository _repository;

  Future<TourDetail?> call(String tourId, {TourSummary? initialSummary}) =>
      _repository.getTourDetail(tourId, initialSummary: initialSummary);
}
