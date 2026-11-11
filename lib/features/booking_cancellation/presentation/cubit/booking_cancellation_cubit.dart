import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_failure.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/usecases/cancel_booking_use_case.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/usecases/get_booking_cancellation_preview_use_case.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/presentation/cubit/booking_cancellation_state.dart';
import 'package:uuid/uuid.dart';

/// UC-41 cancellation sheet state. One Idempotency-Key is generated for the lifetime of the
/// cubit (i.e. one open sheet): a retried submit after a transient failure replays the same
/// cancellation intent, never a new one.
final class BookingCancellationCubit extends Cubit<BookingCancellationState> {
  BookingCancellationCubit({
    required int bookingId,
    required GetBookingCancellationPreviewUseCase getPreview,
    required CancelBookingUseCase cancel,
  }) : _bookingId = bookingId,
       _getPreview = getPreview,
       _cancel = cancel,
       _idempotencyKey = const Uuid().v4(),
       super(const BookingCancellationState());

  final int _bookingId;
  final GetBookingCancellationPreviewUseCase _getPreview;
  final CancelBookingUseCase _cancel;
  final String _idempotencyKey;

  Future<void> load() async {
    emit(
      state.copyWith(
        phase: BookingCancellationPhase.loading,
        clearFailure: true,
      ),
    );
    try {
      final preview = await _getPreview(_bookingId);
      if (!isClosed) {
        emit(
          state.copyWith(
            phase: BookingCancellationPhase.ready,
            preview: preview,
          ),
        );
      }
    } on BookingCancellationFailure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(
            phase: BookingCancellationPhase.failure,
            failure: failure.kind,
          ),
        );
      }
    }
  }

  void toggleConfirmed(bool value) => emit(state.copyWith(confirmed: value));

  Future<void> submit({String? reasonCategory, String? reasonDetail}) async {
    if (!state.canSubmit) return;
    emit(
      state.copyWith(
        phase: BookingCancellationPhase.submitting,
        clearFailure: true,
      ),
    );
    try {
      await _cancel(
        _bookingId,
        reasonCategory: reasonCategory,
        reasonDetail: reasonDetail,
        confirmed: state.confirmed,
        idempotencyKey: _idempotencyKey,
      );
      if (!isClosed) {
        emit(state.copyWith(phase: BookingCancellationPhase.success));
      }
    } on BookingCancellationFailure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(
            phase: BookingCancellationPhase.failure,
            failure: failure.kind,
          ),
        );
      }
    }
  }
}
