import 'package:trip_mate_mobile/features/operator_payment_channel/domain/entities/payment_channel_status.dart';

abstract interface class OperatorPaymentChannelRepository {
  Future<PaymentChannelStatus> getChannel();
  Future<PaymentChannelStatus> submitCredentials(SubmitCredentialsRequest request);
  Future<PaymentChannelStatus> verify();
}
