import 'package:trip_mate_mobile/features/operator_payment_channel/domain/entities/payment_channel_status.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/domain/repositories/operator_payment_channel_repository.dart';

final class GetPaymentChannelUseCase {
  const GetPaymentChannelUseCase(this._repository);
  final OperatorPaymentChannelRepository _repository;

  Future<PaymentChannelStatus> call() => _repository.getChannel();
}

final class SubmitPaymentChannelCredentialsUseCase {
  const SubmitPaymentChannelCredentialsUseCase(this._repository);
  final OperatorPaymentChannelRepository _repository;

  Future<PaymentChannelStatus> call(SubmitCredentialsRequest request) =>
      _repository.submitCredentials(request);
}

final class VerifyPaymentChannelUseCase {
  const VerifyPaymentChannelUseCase(this._repository);
  final OperatorPaymentChannelRepository _repository;

  Future<PaymentChannelStatus> call() => _repository.verify();
}
