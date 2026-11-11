import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_failure.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_preview.dart';

enum BookingCancellationPhase { loading, ready, submitting, success, failure }

const _confirmationRequiredCode = 'booking.cancellation.confirmation_required';

final class BookingCancellationState extends Equatable {
  const BookingCancellationState({
    this.phase = BookingCancellationPhase.loading,
    this.preview,
    this.confirmed = false,
    this.failure,
  });

  final BookingCancellationPhase phase;
  final BookingCancellationPreview? preview;

  /// Ticked by the Traveler when [needsConfirmation] is true.
  final bool confirmed;
  final BookingCancellationFailureKind? failure;

  bool get needsConfirmation =>
      preview?.blockingReasonCode == _confirmationRequiredCode;

  bool get canSubmit =>
      phase != BookingCancellationPhase.submitting &&
      (preview?.canCancel ?? false) &&
      (!needsConfirmation || confirmed);

  BookingCancellationState copyWith({
    BookingCancellationPhase? phase,
    BookingCancellationPreview? preview,
    bool? confirmed,
    BookingCancellationFailureKind? failure,
    bool clearFailure = false,
  }) => BookingCancellationState(
    phase: phase ?? this.phase,
    preview: preview ?? this.preview,
    confirmed: confirmed ?? this.confirmed,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [phase, preview, confirmed, failure];
}
