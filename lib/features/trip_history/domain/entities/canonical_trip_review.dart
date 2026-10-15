import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';

final class CanonicalTripReview extends Equatable {
  const CanonicalTripReview({
    required this.id,
    required this.rating,
    required this.title,
    required this.content,
    required this.publishDisplayName,
    required this.createdAtUtc,
    required this.editDeadlineUtc,
    required this.version,
    this.mediaUrls = const [],
  });
  final int id;
  final int rating;
  final String title;
  final String content;
  final bool publishDisplayName;
  final DateTime createdAtUtc;
  final DateTime editDeadlineUtc;
  final String version;
  final List<String> mediaUrls;
  @override
  List<Object?> get props => [
    id,
    rating,
    title,
    content,
    publishDisplayName,
    createdAtUtc,
    editDeadlineUtc,
    version,
    mediaUrls,
  ];
}

final class CanonicalReviewContext extends Equatable {
  const CanonicalReviewContext({
    required this.reference,
    required this.bookingStatus,
    required this.name,
    required this.departureAtUtc,
    required this.bookingReference,
    required this.canSubmit,
    this.submitUnavailableReason,
    required this.existingReviewKind,
    this.review,
    this.editableFields = const [],
  });
  final ReviewableRecordRef reference;
  final String bookingStatus;
  final String name;
  final DateTime departureAtUtc;
  final String bookingReference;
  final bool canSubmit;
  final String? submitUnavailableReason;
  final String existingReviewKind;
  final CanonicalTripReview? review;
  final List<String> editableFields;
  bool get isEditable => review != null && editableFields.isNotEmpty;
  @override
  List<Object?> get props => [
    reference,
    bookingStatus,
    name,
    departureAtUtc,
    bookingReference,
    canSubmit,
    submitUnavailableReason,
    existingReviewKind,
    review,
    editableFields,
  ];
}
