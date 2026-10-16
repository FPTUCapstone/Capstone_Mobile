import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/canonical_trip_review.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/canonical_trip_review_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/canonical_trip_review_use_case.dart';

enum CanonicalReviewOutcome { none, created, updated }

final class CanonicalTripReviewState extends Equatable {
  const CanonicalTripReviewState({
    this.context,
    this.busy = false,
    this.message,
    this.outcome = CanonicalReviewOutcome.none,
  });
  final CanonicalReviewContext? context;
  final bool busy;
  final String? message;
  final CanonicalReviewOutcome outcome;

  @override
  List<Object?> get props => [context, busy, message, outcome];
}

final class CanonicalTripReviewCubit extends Cubit<CanonicalTripReviewState> {
  CanonicalTripReviewCubit({required this.reference, required this.useCase})
    : super(const CanonicalTripReviewState());
  final ReviewableRecordRef reference;
  final CanonicalTripReviewUseCase useCase;

  Future<void> load({String? message}) async {
    emit(CanonicalTripReviewState(context: state.context, busy: true));
    try {
      emit(
        CanonicalTripReviewState(
          context: await useCase.load(reference),
          message: message,
        ),
      );
    } on Failure catch (failure) {
      emit(
        CanonicalTripReviewState(
          context: state.context,
          message: _message(failure),
        ),
      );
    } catch (_) {
      emit(
        CanonicalTripReviewState(
          context: state.context,
          message: _message(const ServerFailure()),
        ),
      );
    }
  }

  Future<void> submit({
    required int rating,
    required String title,
    required String content,
    required bool publishDisplayName,
    required List<ReviewPhotoUpload> photos,
  }) async {
    final existing = state.context?.review;
    emit(CanonicalTripReviewState(context: state.context, busy: true));
    try {
      if (existing == null) {
        await useCase.create(
          reference,
          rating: rating,
          title: title,
          content: content,
          publishDisplayName: publishDisplayName,
          photos: photos,
        );
        emit(
          CanonicalTripReviewState(
            context: state.context,
            message: 'Review published.',
            outcome: CanonicalReviewOutcome.created,
          ),
        );
      } else {
        await useCase.update(
          reference,
          rating: rating,
          title: title,
          content: content,
          publishDisplayName: publishDisplayName,
          version: existing.version,
        );
        await load(message: 'Review updated.');
        emit(
          CanonicalTripReviewState(
            context: state.context,
            message: state.message,
            outcome: CanonicalReviewOutcome.updated,
          ),
        );
      }
    } on ConflictFailure catch (failure) {
      if (failure.message == 'trip_review.duplicate') {
        await load(message: _message(failure));
      } else {
        emit(
          CanonicalTripReviewState(
            context: state.context,
            message: _message(failure),
          ),
        );
      }
    } on Failure catch (failure) {
      emit(
        CanonicalTripReviewState(
          context: state.context,
          message: _message(failure),
        ),
      );
    } catch (_) {
      emit(
        CanonicalTripReviewState(
          context: state.context,
          message: _message(const ServerFailure()),
        ),
      );
    }
  }

  static String _message(Failure failure) => switch (failure.message) {
    'trip_review.invalid_input' => 'Check the review details and try again.',
    'trip_review.not_found' => 'This booking could not be found.',
    'trip_review.forbidden' => 'You can only review your own booking.',
    'trip_review.booking_not_completed' =>
      'A review can only be submitted after the trip is completed.',
    'trip_review.duplicate' =>
      'A review already exists. The existing review is shown below.',
    'trip_review.edit_expired' =>
      'The seven-day edit window has expired. This review is read-only.',
    'trip_review.stale_version' =>
      'This review changed elsewhere. Reload it before saving again.',
    'trip_review.policy_rejected' =>
      'The review was rejected by the content policy.',
    'trip_review.policy_unavailable' =>
      'Content screening is temporarily unavailable. Please try again.',
    'trip_review.unsupported_subject' =>
      'This booking does not have a supported review subject.',
    'trip_review.unsupported_media_type' =>
      'Use JPEG, PNG, or WebP photos only.',
    'trip_review.body_too_large' => 'The selected photos are too large.',
    'trip_review.invalid_response' =>
      'The review service returned an invalid response.',
    _ when failure is NetworkFailure => 'Please check your connection.',
    _ when failure is AuthenticationFailure => 'Please sign in to continue.',
    _ when failure is PermissionFailure =>
      'You can only review your own booking.',
    _ when failure is NotFoundFailure => 'This booking could not be found.',
    _ => 'The review service is currently unavailable. Please try again.',
  };
}
