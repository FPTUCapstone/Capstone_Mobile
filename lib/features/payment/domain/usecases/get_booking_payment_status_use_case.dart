import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';
import 'package:trip_mate_mobile/features/payment/domain/repositories/payment_repository.dart';

final class GetBookingPaymentStatusUseCase {
  const GetBookingPaymentStatusUseCase(this._repository);
  final PaymentRepository _repository;

  Future<BookingPaymentStatus> call(String bookingId) =>
      _repository.getBookingPaymentStatus(bookingId);
}
