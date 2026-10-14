import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review_submission.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_state.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class TripReviewCubit extends Cubit<TripReviewState> {
  TripReviewCubit({
    required TripReviewRepository repository,
    required TripHistoryRepository historyRepository,
    this.isDemoMode = false,
  }) : _repository = repository,
       _historyRepository = historyRepository,
       super(TripReviewState(isDemoMode: isDemoMode));

  final TripReviewRepository _repository;
  final TripHistoryRepository _historyRepository;
  final bool isDemoMode;

  Future<void> loadTripAndReview({
    required String tripId,
    TripHistoryItem? cachedTrip,
    int? travelerId,
    DateTime? referenceTime,
  }) async {
    final cleanTripId = tripId.trim();
    if (cleanTripId.isEmpty) {
      emit(
        state.copyWith(
          trip: () => null,
          status: TripReviewStatus.failure,
          generalError: () => TripHistoryStringsEn.tripInformationUnavailable,
        ),
      );
      return;
    }

    // 1. If valid matching cached trip was provided, use it directly (optimization/cache)
    if (cachedTrip != null && cachedTrip.id == cleanTripId) {
      _applyLoadedTrip(
        trip: cachedTrip,
        travelerId: travelerId,
        referenceTime: referenceTime,
      );
      return;
    }

    // 2. Otherwise load the trip by ID from the repository (deep link / app restore)
    emit(
      state.copyWith(
        status: TripReviewStatus.loading,
        generalError: () => null,
      ),
    );

    try {
      final trip = await _historyRepository.getTripById(
        travelerId: travelerId,
        tripId: cleanTripId,
      );

      if (trip == null) {
        emit(
          state.copyWith(
            trip: () => null,
            status: TripReviewStatus.failure,
            generalError: () => TripHistoryStringsEn.tripInformationUnavailable,
          ),
        );
        return;
      }

      _applyLoadedTrip(
        trip: trip,
        travelerId: travelerId,
        referenceTime: referenceTime,
      );
    } on PermissionFailure catch (e) {
      emit(
        state.copyWith(
          trip: () => null,
          demoTravelerId: () => travelerId,
          generalError: () => e.message,
          status: TripReviewStatus.failure,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          trip: () => null,
          demoTravelerId: () => travelerId,
          generalError: () => e.message,
          status: TripReviewStatus.failure,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          trip: () => null,
          demoTravelerId: () => travelerId,
          generalError: () => TripHistoryStringsEn.tripInformationUnavailable,
          status: TripReviewStatus.failure,
        ),
      );
    }
  }

  void initialize({
    required TripHistoryItem trip,
    int? travelerId,
    TripReview? existingReview,
    DateTime? referenceTime,
  }) {
    _applyLoadedTrip(
      trip: trip,
      travelerId: travelerId,
      existingReview: existingReview,
      referenceTime: referenceTime,
    );
  }

  void _applyLoadedTrip({
    required TripHistoryItem trip,
    int? travelerId,
    TripReview? existingReview,
    DateTime? referenceTime,
  }) {
    // In Demo mode, verify traveler ownership against demo tenant (BR-90)
    if (isDemoMode && travelerId != null && trip.travelerId != travelerId) {
      emit(
        state.copyWith(
          trip: () => null,
          demoTravelerId: () => travelerId,
          generalError: () => TripHistoryStringsEn.permissionDenied,
          status: TripReviewStatus.failure,
        ),
      );
      return;
    }

    // P1 / UC-33: Self-planned itineraries cannot be reviewed
    if (trip.type == TripType.itinerary) {
      emit(
        state.copyWith(
          trip: () => null,
          demoTravelerId: () => travelerId,
          generalError: () => TripHistoryStringsEn.noticeSelfPlannedNoReview,
          status: TripReviewStatus.failure,
        ),
      );
      return;
    }

    // BR-91: The trip is not completed
    if (trip.status != TripStatus.completed) {
      emit(
        state.copyWith(
          trip: () => null,
          demoTravelerId: () => travelerId,
          generalError: () => TripHistoryStringsEn.noticeReviewNotCompleted,
          status: TripReviewStatus.failure,
          title: '',
          content: '',
          rating: () => 0,
          photos: const [],
          isEdit: false,
          isReadOnly: false,
          existingReview: () => null,
          readOnlyNotice: () => null,
          editNotice: () => null,
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
          demoTravelerId: () => travelerId,
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
          editNotice: () =>
              isEditable ? TripHistoryStringsEn.reviewEditWindowActive : null,
          generalError: () => null,
          status: TripReviewStatus.initial,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        trip: () => trip,
        existingReview: () => null,
        demoTravelerId: () => travelerId,
        rating: () => null,
        title: '',
        content: '',
        photos: const [],
        isEdit: false,
        isReadOnly: false,
        readOnlyNotice: () => null,
        editNotice: () => null,
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

    // PROVISIONAL_BACKEND_CONTRACT_MAX_5_PHOTOS
    if (state.photos.length >= 5) {
      emit(
        state.copyWith(
          photoError: () => TripHistoryStringsEn.validationPhotoMaxCount,
        ),
      );
      return;
    }

    // Supported Demo image types: JPEG, PNG, WebP
    if (!photo.isValidType) {
      emit(
        state.copyWith(
          photoError: () => TripHistoryStringsEn.validationPhotoInvalidType,
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

    // In Production mode, mutations are truthfully disabled pending backend integration
    if (!isDemoMode) {
      emit(
        state.copyWith(
          status: TripReviewStatus.failure,
          generalError: () =>
              TripHistoryStringsEn.productionReviewMutationDisabled,
        ),
      );
      return;
    }

    final trip = state.trip;
    if (trip == null) {
      emit(
        state.copyWith(
          status: TripReviewStatus.failure,
          generalError: () => TripHistoryStringsEn.tripInformationUnavailable,
        ),
      );
      return;
    }

    if (trip.type == TripType.itinerary) {
      emit(
        state.copyWith(
          status: TripReviewStatus.failure,
          generalError: () => TripHistoryStringsEn.noticeSelfPlannedNoReview,
        ),
      );
      return;
    }

    if (trip.status != TripStatus.completed) {
      emit(
        state.copyWith(
          status: TripReviewStatus.failure,
          generalError: () => TripHistoryStringsEn.noticeReviewNotCompleted,
        ),
      );
      return;
    }

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
      travelerId: state.demoTravelerId,
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
    } on ServerFailure catch (e) {
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
