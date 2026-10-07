import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class TripReviewCubit extends Cubit<TripReviewState> {
  TripReviewCubit({required TripReviewRepository repository})
    : _repository = repository,
      super(const TripReviewState());

  final TripReviewRepository _repository;

  void initialize({
    required TripHistoryItem trip,
    required int travelerId,
    TripReview? existingReview,
    DateTime? referenceTime,
  }) {
    // 5.a2. The Traveler is not the owner of the booking -> MSG126
    if (trip.travelerId != travelerId) {
      emit(
        state.copyWith(
          trip: () => trip,
          travelerId: travelerId,
          generalError: () => TripHistoryStringsEn.permissionDenied,
          status: TripReviewStatus.failure,
        ),
      );
      return;
    }

    // 5.a1. The trip is not completed -> MSG52
    if (trip.status != TripStatus.completed) {
      emit(
        state.copyWith(
          trip: () => trip,
          travelerId: travelerId,
          generalError: () => TripHistoryStringsEn.noticeReviewNotCompleted,
          status: TripReviewStatus.failure,
        ),
      );
      return;
    }

    final review = existingReview ?? trip.review;

    if (review != null) {
      final isEditable = review.isEditable(referenceTime);
      final isReadOnly = !isEditable;

      emit(
        state.copyWith(
          trip: () => trip,
          existingReview: () => review,
          travelerId: travelerId,
          rating: () => review.rating,
          title: review.title,
          content: review.content,
          photos: review.photoUrls
              .map(
                (url) => TripReviewPhotoAttachment(
                  name: url,
                  sizeBytes: 1024 * 1024,
                ),
              )
              .toList(),
          isEdit: isEditable,
          isReadOnly: isReadOnly,
          readOnlyNotice: () =>
              isReadOnly ? TripHistoryStringsEn.reviewReadOnlyNotice : null,
          generalError: () => isEditable
              ? TripHistoryStringsEn.noticeReviewAlreadyExists
              : null,
          status: TripReviewStatus.initial,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        trip: () => trip,
        existingReview: () => null,
        travelerId: travelerId,
        rating: () => null,
        title: '',
        content: '',
        photos: const [],
        isEdit: false,
        isReadOnly: false,
        readOnlyNotice: () => null,
        generalError: () => null,
        ratingError: () => null,
        titleError: () => null,
        contentError: () => null,
        photoError: () => null,
        status: TripReviewStatus.initial,
      ),
    );
  }

  void setRating(int rating) {
    if (state.isReadOnly) return;
    emit(state.copyWith(rating: () => rating, ratingError: () => null));
  }

  void setTitle(String title) {
    if (state.isReadOnly) return;
    emit(state.copyWith(title: title, titleError: () => null));
  }

  void setContent(String content) {
    if (state.isReadOnly) return;
    emit(state.copyWith(content: content, contentError: () => null));
  }

  void addPhoto(TripReviewPhotoAttachment photo) {
    if (state.isReadOnly) return;

    if (state.photos.length >= 5) {
      emit(
        state.copyWith(
          photoError: () => TripHistoryStringsEn.validationPhotoMaxCount,
        ),
      );
      return;
    }

    // BR-16: An attached photo must not exceed 5 MB
    if (!photo.isValidSize) {
      emit(
        state.copyWith(
          photoError: () => TripHistoryStringsEn.validationPhotoExceedsLimit,
        ),
      );
      return;
    }

    emit(
      state.copyWith(photos: [...state.photos, photo], photoError: () => null),
    );
  }

  void removePhoto(int index) {
    if (state.isReadOnly) return;
    if (index < 0 || index >= state.photos.length) return;

    final updated = [...state.photos]..removeAt(index);
    emit(state.copyWith(photos: updated, photoError: () => null));
  }

  Future<void> submit() async {
    if (state.isReadOnly || state.isSubmitting) return;

    final trip = state.trip;
    if (trip == null) return;

    var hasError = false;
    String? ratingError;
    String? titleError;
    String? contentError;

    // 2.a1. The rating has not been selected -> MSG66
    if (state.rating == null || state.rating! < 1 || state.rating! > 5) {
      ratingError = TripHistoryStringsEn.validationRatingRequired;
      hasError = true;
    }

    // 3.a1. A required field is empty -> MSG01
    if (state.title.trim().isEmpty) {
      titleError = TripHistoryStringsEn.validationFieldRequired;
      hasError = true;
    }

    if (state.content.trim().isEmpty) {
      contentError = TripHistoryStringsEn.validationFieldRequired;
      hasError = true;
    }

    if (hasError) {
      emit(
        state.copyWith(
          ratingError: () => ratingError,
          titleError: () => titleError,
          contentError: () => contentError,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TripReviewStatus.submitting,
        generalError: () => null,
        ratingError: () => null,
        titleError: () => null,
        contentError: () => null,
        photoError: () => null,
      ),
    );

    final submission = TripReviewSubmission(
      tripId: trip.id,
      bookingCode: trip.bookingCode,
      travelerId: state.travelerId,
      rating: state.rating!,
      title: state.title.trim(),
      content: state.content.trim(),
      photos: state.photos,
      existingReviewId: state.isEdit ? state.existingReview?.id : null,
    );

    try {
      final result = state.isEdit
          ? await _repository.updateReview(submission)
          : await _repository.submitReview(submission);

      emit(
        state.copyWith(
          status: TripReviewStatus.success,
          existingReview: () => result,
          successMessage: () => state.isEdit
              ? TripHistoryStringsEn.reviewUpdateSuccess
              : TripHistoryStringsEn.reviewSubmitSuccess,
        ),
      );
    } on ValidationFailure catch (e) {
      emit(
        state.copyWith(
          status: TripReviewStatus.failure,
          generalError: () => e.message,
        ),
      );
    } on ConflictFailure catch (e) {
      emit(
        state.copyWith(
          status: TripReviewStatus.failure,
          generalError: () => e.message,
        ),
      );
    } on PermissionFailure catch (e) {
      emit(
        state.copyWith(
          status: TripReviewStatus.failure,
          generalError: () => e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: TripReviewStatus.failure,
          generalError: () => TripHistoryStringsEn.errorMessageGeneric,
        ),
      );
    }
  }
}
