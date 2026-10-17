import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/datasources/operator_tour_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';

final class OperatorTourRepositoryImpl implements OperatorTourRepository {
  const OperatorTourRepositoryImpl(this._remote);
  final OperatorTourRemoteDataSource _remote;

  /// Every remote failure is mapped to a user-safe [Failure]; raw backend text never reaches the UI.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey) =>
      _guard(() => _remote.createDraft(draft, idempotencyKey));

  @override
  Future<TourPackageOptions> loadOptions() => _guard(_remote.loadOptions);

  @override
  Future<TourPackagePage> listTours({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) => _guard(
    () => _remote.listTours(status: status, page: page, pageSize: pageSize),
  );

  @override
  Future<TourPackageDetail> getTour(int tourId) =>
      _guard(() => _remote.getTour(tourId));

  @override
  Future<void> updateDraft(int tourId, TourPackageDraft draft) =>
      _guard(() => _remote.updateDraft(tourId, draft));

  @override
  Future<void> submitForReview(int tourId) =>
      _guard(() => _remote.submitForReview(tourId));

  @override
  Future<List<TourMediaItem>> listMedia(int tourId) =>
      _guard(() => _remote.listMedia(tourId));

  @override
  Future<void> uploadMedia(
    int tourId,
    TourImageUpload image, {
    required String altText,
    required bool makePrimary,
    required String idempotencyKey,
  }) => _guard(
    () => _remote.uploadMedia(
      tourId,
      image,
      altText: altText,
      makePrimary: makePrimary,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<void> setPrimaryMedia(int tourId, int mediaId) =>
      _guard(() => _remote.setPrimaryMedia(tourId, mediaId));

  @override
  Future<void> deleteMedia(int tourId, int mediaId) =>
      _guard(() => _remote.deleteMedia(tourId, mediaId));
}
