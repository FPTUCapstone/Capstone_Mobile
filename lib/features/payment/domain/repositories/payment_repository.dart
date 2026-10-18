import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';

abstract interface class PaymentRepository {
  Future<PaymentLink> createOrReusePayment(String bookingId);

  Future<BookingPaymentStatus> getBookingPaymentStatus(String bookingId);

  Future<void> cancelPayment(String bookingId);

  Future<PaymentTransactionStatus> completeMockPayment({
    required int paymentId,
    required String outcome,
  });
}
