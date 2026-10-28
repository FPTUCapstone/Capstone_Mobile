import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/usecases/get_booking_refund_progress_use_case.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_state.dart';

final class BookingRefundProgressCubit
    extends Cubit<BookingRefundProgressState> {
  BookingRefundProgressCubit({
    required GetBookingRefundProgressUseCase getProgress,
  }) : _getProgress = getProgress,
       super(const BookingRefundProgressState());

  final GetBookingRefundProgressUseCase _getProgress;

  Future<void> load(String bookingId) async {
    if (bookingId.trim().isEmpty) return;
    emit(
      const BookingRefundProgressState(
        status: BookingRefundProgressStatus.loading,
      ),
    );
    try {
      final progress = await _getProgress(bookingId);
      if (!isClosed) {
        emit(
          BookingRefundProgressState(
            status: BookingRefundProgressStatus.success,
            progress: progress,
          ),
        );
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          BookingRefundProgressState(
            status: BookingRefundProgressStatus.failure,
            failure: failure,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          const BookingRefundProgressState(
            status: BookingRefundProgressStatus.failure,
            failure: ServerFailure('Could not load refund progress.'),
          ),
        );
      }
    }
  }
}
