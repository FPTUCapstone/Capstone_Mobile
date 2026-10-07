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
    DemoTripHistoryStore? demoStore,
    this.isDemoMode = false,
  }) : _demoStore = demoStore ?? DemoTripHistoryStore();

  final DioClient? dioClient;
  final DemoTripHistoryStore _demoStore;
  final bool isDemoMode;

  @override
  Future<TripReview> submitReview(TripReviewSubmission submission) async {
    if (isDemoMode) {
      return _demoStore.submitReview(submission);
    }

    // Production: Backend PR #30 is OPEN and unmerged.
    // Truthfully disable review submission without executing invented HTTP endpoints
    // or passing unauthenticated travelerId bodies.
    throw const ServerFailure(
      TripHistoryStringsEn.productionReviewMutationDisabled,
    );
  }

  @override
  Future<TripReview> updateReview(TripReviewSubmission submission) async {
    if (isDemoMode) {
      return _demoStore.updateReview(submission);
    }

    // Production: Backend PR #30 is OPEN and unmerged.
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

    // Production: Backend develop has no review endpoint.
    // Do NOT call an invented endpoint and do NOT fail open to null (unreviewed).
    throw const ServerFailure(
      TripHistoryStringsEn.productionReviewMutationDisabled,
    );
  }
}
