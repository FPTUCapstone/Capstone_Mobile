import 'package:trip_mate_mobile/features/operator_payment_channel/data/datasources/operator_payment_channel_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/domain/entities/payment_channel_status.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/domain/repositories/operator_payment_channel_repository.dart';

final class OperatorPaymentChannelRepositoryImpl
    implements OperatorPaymentChannelRepository {
  const OperatorPaymentChannelRepositoryImpl(this._dataSource);
  final OperatorPaymentChannelRemoteDataSource _dataSource;

  @override
  Future<PaymentChannelStatus> getChannel() => _dataSource.getChannel();

  @override
  Future<PaymentChannelStatus> submitCredentials(
    SubmitCredentialsRequest request,
  ) => _dataSource.submitCredentials(request);

  @override
  Future<PaymentChannelStatus> verify() => _dataSource.verify();
}
