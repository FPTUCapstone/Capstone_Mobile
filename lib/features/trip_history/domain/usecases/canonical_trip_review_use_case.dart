import 'package:trip_mate_mobile/features/trip_history/domain/entities/canonical_trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/canonical_trip_review_repository.dart';

final class CanonicalTripReviewUseCase {
  const CanonicalTripReviewUseCase(this._repository);
  final CanonicalTripReviewRepository _repository;

  Future<CanonicalReviewContext> load(ReviewableRecordRef reference) =>
      _repository.getContext(reference);

  Future<CanonicalTripReview> create(
    ReviewableRecordRef reference, {
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required List<ReviewPhotoUpload> photos,
  }) => _repository.create(
    reference,
    rating: rating,
    title: title,
    content: content,
    publishDisplayName: publishDisplayName,
    photos: photos,
  );

  Future<CanonicalTripReview> update(
    ReviewableRecordRef reference, {
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required String version,
  }) => _repository.update(
    reference,
    rating: rating,
    title: title,
    content: content,
    publishDisplayName: publishDisplayName,
    version: version,
  );
}
