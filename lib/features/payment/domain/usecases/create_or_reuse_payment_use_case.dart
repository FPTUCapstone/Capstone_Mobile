import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';
import 'package:trip_mate_mobile/features/payment/domain/repositories/payment_repository.dart';

final class CreateOrReusePaymentUseCase {
  const CreateOrReusePaymentUseCase(this._repository);
  final PaymentRepository _repository;

  Future<PaymentLink> call(String bookingId) =>
      _repository.createOrReusePayment(bookingId);
}
