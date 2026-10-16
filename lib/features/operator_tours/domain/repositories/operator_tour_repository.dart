import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';

abstract interface class OperatorTourRepository {
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey);
  Future<TourPackageOptions> loadOptions();

  /// [status] is a [TourPackageStatus.apiName] filter; null lists every status.
  Future<TourPackagePage> listTours({
    String? status,
    int page = 1,
    int pageSize = 20,
  });
  Future<TourPackageDetail> getTour(int tourId);
  Future<void> updateDraft(int tourId, TourPackageDraft draft);
  Future<void> submitForReview(int tourId);

  Future<List<TourMediaItem>> listMedia(int tourId);
  Future<void> uploadMedia(
    int tourId,
    TourImageUpload image, {
    required String altText,
    required bool makePrimary,
    required String idempotencyKey,
  });
  Future<void> setPrimaryMedia(int tourId, int mediaId);
  Future<void> deleteMedia(int tourId, int mediaId);
}
