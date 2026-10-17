import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';
import 'package:trip_mate_mobile/features/payment/domain/repositories/payment_repository.dart';

final class CompleteMockPaymentUseCase {
  const CompleteMockPaymentUseCase(this._repository);
  final PaymentRepository _repository;

  Future<PaymentTransactionStatus> call({
    required int paymentId,
    required String outcome,
  }) => _repository.completeMockPayment(
        paymentId: paymentId,
        outcome: outcome,
      );
}
