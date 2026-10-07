import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';

enum TripReviewStatus { initial, loading, submitting, success, failure }

final class TripReviewState extends Equatable {
  const TripReviewState({
    this.status = TripReviewStatus.initial,
    this.trip,
    this.existingReview,
    this.rating,
    this.title = '',
    this.content = '',
    this.photos = const <TripReviewPhotoAttachment>[],
    this.isEdit = false,
    this.isReadOnly = false,
    this.readOnlyNotice,
    this.ratingError,
    this.titleError,
    this.contentError,
    this.photoError,
    this.generalError,
    this.successMessage,
    this.travelerId = 1,
  });

  final TripReviewStatus status;
  final TripHistoryItem? trip;
  final TripReview? existingReview;
  final int? rating;
  final String title;
  final String content;
  final List<TripReviewPhotoAttachment> photos;
  final bool isEdit;
  final bool isReadOnly;
  final String? readOnlyNotice;
  final String? ratingError;
  final String? titleError;
  final String? contentError;
  final String? photoError;
  final String? generalError;
  final String? successMessage;
  final int travelerId;

  bool get isSubmitting => status == TripReviewStatus.submitting;
  bool get isSuccess => status == TripReviewStatus.success;

  TripReviewState copyWith({
    TripReviewStatus? status,
    TripHistoryItem? Function()? trip,
    TripReview? Function()? existingReview,
    int? Function()? rating,
    String? title,
    String? content,
    List<TripReviewPhotoAttachment>? photos,
    bool? isEdit,
    bool? isReadOnly,
    String? Function()? readOnlyNotice,
    String? Function()? ratingError,
    String? Function()? titleError,
    String? Function()? contentError,
    String? Function()? photoError,
    String? Function()? generalError,
    String? Function()? successMessage,
    int? travelerId,
  }) {
    return TripReviewState(
      status: status ?? this.status,
      trip: trip != null ? trip() : this.trip,
      existingReview: existingReview != null
          ? existingReview()
          : this.existingReview,
      rating: rating != null ? rating() : this.rating,
      title: title ?? this.title,
      content: content ?? this.content,
      photos: photos ?? this.photos,
      isEdit: isEdit ?? this.isEdit,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      readOnlyNotice: readOnlyNotice != null
          ? readOnlyNotice()
          : this.readOnlyNotice,
      ratingError: ratingError != null ? ratingError() : this.ratingError,
      titleError: titleError != null ? titleError() : this.titleError,
      contentError: contentError != null ? contentError() : this.contentError,
      photoError: photoError != null ? photoError() : this.photoError,
      generalError: generalError != null ? generalError() : this.generalError,
      successMessage: successMessage != null
          ? successMessage()
          : this.successMessage,
      travelerId: travelerId ?? this.travelerId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    trip,
    existingReview,
    rating,
    title,
    content,
    photos,
    isEdit,
    isReadOnly,
    readOnlyNotice,
    ratingError,
    titleError,
    contentError,
    photoError,
    generalError,
    successMessage,
    travelerId,
  ];
}
