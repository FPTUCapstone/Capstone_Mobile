import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/datasources/operator_tour_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';

final class OperatorTourRepositoryImpl implements OperatorTourRepository {
  const OperatorTourRepositoryImpl(this._remote);
  final OperatorTourRemoteDataSource _remote;

  String? _extractErrorCode(DioException error) {
    final data = error.response?.data;
    if (data is! Map) return null;
    final extensions = data['extensions'];
    if (data['errorCode'] is String) return data['errorCode'] as String;
    if (data['code'] is String) return data['code'] as String;
    if (extensions is Map && extensions['errorCode'] is String) {
      return extensions['errorCode'] as String;
    }
    return null;
  }

  /// Every remote failure is mapped to a user-safe [Failure]; raw backend text never reaches the UI.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      final errorCode = _extractErrorCode(error);
      // Do not display arbitrary backend validation strings or internal field names.
      if (error.response?.statusCode == 400) {
        throw const ValidationFailure(
          'Check the tour information and submission note, then try again.',
        );
      }
      if (error.response?.statusCode == 409 &&
          errorCode == 'operator_tour.duplicate_departure') {
        throw const ConflictFailure(
          'A departure schedule with that start date and time already exists for this tour.',
        );
      }
      if (error.response?.statusCode == 422 &&
          errorCode == 'operator_tour.departure_itinerary_mismatch') {
        throw const ConstraintFailure(
          'The itinerary is missing planned visit times for one or more stops. Create a new draft version, add planned times, and submit it for review before reopening departures.',
        );
      }
      if (error.response?.statusCode == 422) {
        throw const ConstraintFailure(
          'Complete the required tour information, an itinerary for every day, a destination, a cover photo, a cancellation policy and a valid priced future departure before submitting.',
        );
      }
      throw ErrorMapper.toFailure(error);
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
  Future<void> deleteTour(int tourId) =>
      _guard(() => _remote.deleteTour(tourId));

  @override
  Future<TourDepartureDetail> addDeparture(
    int tourId,
    TourScheduleDraft departure,
    String idempotencyKey,
  ) => _guard(() => _remote.addDeparture(tourId, departure, idempotencyKey));

  @override
  Future<TourReviewSubmission> submitForReview(
    int tourId, {
    String? submissionNote,
  }) => _guard(
    () => _remote.submitForReview(tourId, submissionNote: submissionNote),
  );

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
