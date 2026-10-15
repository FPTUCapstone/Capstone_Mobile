import 'dart:typed_data';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/canonical_trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';

final class ReviewPhotoUpload {
  const ReviewPhotoUpload({
    required this.name,
    required this.contentType,
    required this.bytes,
  });
  final String name;
  final String contentType;
  final Uint8List bytes;
}

abstract interface class CanonicalTripReviewRepository {
  Future<CanonicalReviewContext> getContext(ReviewableRecordRef reference);
  Future<CanonicalTripReview> create(
    ReviewableRecordRef reference, {
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required List<ReviewPhotoUpload> photos,
  });
  Future<CanonicalTripReview> update(
    ReviewableRecordRef reference, {
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required String version,
  });
}
