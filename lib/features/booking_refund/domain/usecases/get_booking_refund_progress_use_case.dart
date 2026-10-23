import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/repositories/booking_refund_repository.dart';

final class GetBookingRefundProgressUseCase {
  const GetBookingRefundProgressUseCase(this._repository);
  final BookingRefundRepository _repository;

  Future<BookingRefundProgress> call(String bookingId) =>
      _repository.getProgress(bookingId);
}
