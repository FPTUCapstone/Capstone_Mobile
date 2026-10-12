import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class TripReviewRepositoryImpl implements TripReviewRepository {
  TripReviewRepositoryImpl({
    this.dioClient,
    required DemoTripHistoryStore demoStore,
    this.isDemoMode = false,
  }) : _demoStore = demoStore;

  final DioClient? dioClient;
  final DemoTripHistoryStore _demoStore;
  final bool isDemoMode;

  @override
  Future<TripReview> submitReview(TripReviewSubmission submission) async {
    if (isDemoMode) {
      return _demoStore.submitReview(submission);
    }

    // Production review endpoints are merged for authoritative commerce-booking
    // and service-booking identifiers. UC-32 does not yet supply that typed,
    // server-owned booking reference, so this screen must not infer one from a
    // trip ID or booking code and must keep mutations disabled.
    throw const ServerFailure(
      TripHistoryStringsEn.productionReviewMutationDisabled,
    );
  }

  @override
  Future<TripReview> updateReview(TripReviewSubmission submission) async {
    if (isDemoMode) {
      return _demoStore.updateReview(submission);
    }

    // The merged edit endpoint likewise requires an authoritative typed booking
    // reference that the unavailable UC-32 aggregate contract cannot provide.
    throw const ServerFailure(
      TripHistoryStringsEn.productionReviewMutationDisabled,
    );
  }

  @override
  Future<TripReview?> getReviewForTrip({
    int? travelerId,
    required String tripId,
  }) async {
    if (isDemoMode) {
      final trip = _demoStore.getTripById(
        travelerId: travelerId,
        tripId: tripId,
      );
      return trip?.review;
    }

    // Review reads exist per booking kind, but UC-32 cannot yet identify the
    // correct booking namespace and numeric ID. Do not guess and do not fail
    // open to null (which would incorrectly mean "unreviewed").
    throw const ServerFailure(
      TripHistoryStringsEn.productionReviewMutationDisabled,
    );
  }
}
