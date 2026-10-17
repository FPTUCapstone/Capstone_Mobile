import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';

final class ListTourPackagesUseCase {
  const ListTourPackagesUseCase(this._repository);
  final OperatorTourRepository _repository;
  Future<TourPackagePage> call({String? status, int page = 1}) =>
      _repository.listTours(status: status, page: page);
}

final class GetTourPackageUseCase {
  const GetTourPackageUseCase(this._repository);
  final OperatorTourRepository _repository;
  Future<TourPackageDetail> call(int tourId) => _repository.getTour(tourId);
}

final class UpdateTourPackageUseCase {
  const UpdateTourPackageUseCase(this._repository);
  final OperatorTourRepository _repository;
  Future<void> call(int tourId, TourPackageDraft draft) =>
      _repository.updateDraft(tourId, draft);
}

final class SubmitTourForReviewUseCase {
  const SubmitTourForReviewUseCase(this._repository);
  final OperatorTourRepository _repository;
  Future<void> call(int tourId) => _repository.submitForReview(tourId);
}

/// Cover-photo operations share one use case: they are thin and always travel together.
final class ManageTourMediaUseCase {
  const ManageTourMediaUseCase(this._repository);
  final OperatorTourRepository _repository;

  Future<List<TourMediaItem>> list(int tourId) => _repository.listMedia(tourId);

  Future<void> upload(
    int tourId,
    TourImageUpload image, {
    required String altText,
    required bool makePrimary,
    required String idempotencyKey,
  }) => _repository.uploadMedia(
    tourId,
    image,
    altText: altText,
    makePrimary: makePrimary,
    idempotencyKey: idempotencyKey,
  );

  Future<void> setPrimary(int tourId, int mediaId) =>
      _repository.setPrimaryMedia(tourId, mediaId);

  Future<void> delete(int tourId, int mediaId) =>
      _repository.deleteMedia(tourId, mediaId);
}
