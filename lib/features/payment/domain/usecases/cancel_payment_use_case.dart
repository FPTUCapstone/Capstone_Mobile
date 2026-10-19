import 'package:trip_mate_mobile/features/payment/domain/repositories/payment_repository.dart';

final class CancelPaymentUseCase {
  const CancelPaymentUseCase(this._repository);
  final PaymentRepository _repository;

  Future<void> call(String bookingId) => _repository.cancelPayment(bookingId);
}
