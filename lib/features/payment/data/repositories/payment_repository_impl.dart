import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';
import 'package:trip_mate_mobile/features/payment/domain/repositories/payment_repository.dart';

final class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl(this._remote);
  final PaymentRemoteDataSource _remote;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<PaymentLink> createOrReusePayment(String bookingId) =>
      _guard(() => _remote.createOrReusePayment(bookingId));

  @override
  Future<BookingPaymentStatus> getBookingPaymentStatus(String bookingId) =>
      _guard(() => _remote.getBookingPaymentStatus(bookingId));

  @override
  Future<void> cancelPayment(String bookingId) =>
      _guard(() => _remote.cancelPayment(bookingId));

  @override
  Future<PaymentTransactionStatus> completeMockPayment({
    required int paymentId,
    required String outcome,
  }) => _guard(
    () => _remote.completeMockPayment(paymentId: paymentId, outcome: outcome),
  );
}
