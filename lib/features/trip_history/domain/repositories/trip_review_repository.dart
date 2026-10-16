import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';

abstract interface class TripReviewRepository {
  /// Submits a new review for a completed booking.
  ///
  /// BR-91: Trip must be completed.
  /// BR-92: At most one review per booking.
  /// BR-93: Rating mandatory (1-5).
  /// BR-94: Content screened against content policy.
  Future<TripReview> submitReview(TripReviewSubmission submission);

  /// Edits an existing review within 7 days.
  ///
  /// BR-95: Editable within 7 days, read-only afterwards.
  Future<TripReview> updateReview(TripReviewSubmission submission);

  /// Retrieves an existing review for a trip/booking.
  Future<TripReview?> getReviewForTrip({
    int? travelerId,
    required String tripId,
  });
}
