import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/usecases/operator_bookings_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_detail_state.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_failure_copy.dart';

/// UC-40 detail and passenger manifest of one booking (screen #85). The detail is fetched when the screen
/// opens; nothing is derived on the device.
final class OperatorBookingDetailCubit
    extends Cubit<OperatorBookingDetailState> {
  OperatorBookingDetailCubit({
    required GetOperatorBookingUseCase getBooking,
    required this.bookingId,
  }) : _getBooking = getBooking,
       super(const OperatorBookingDetailState());

  final GetOperatorBookingUseCase _getBooking;
  final String bookingId;

  /// Identifies the latest request; an answer for an older one is dropped.
  int _requestId = 0;

  Future<void> load() async {
    final request = ++_requestId;
    emit(const OperatorBookingDetailState());
    try {
      final detail = await _getBooking(bookingId);
      if (isClosed || request != _requestId) return;
      emit(
        OperatorBookingDetailState(
          status: OperatorBookingDetailStatus.success,
          detail: detail,
        ),
      );
    } on Object catch (error) {
      if (isClosed || request != _requestId) return;
      final copy = OperatorBookingFailureCopy.of(error);
      emit(
        OperatorBookingDetailState(
          status: OperatorBookingDetailStatus.failure,
          errorMessage: copy.message,
          canRetry: copy.canRetry,
        ),
      );
    }
  }

  Future<void> retry() => load();
}
