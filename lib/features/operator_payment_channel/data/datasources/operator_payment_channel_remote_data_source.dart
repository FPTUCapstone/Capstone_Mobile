import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/operator_payment_channel/domain/entities/payment_channel_status.dart';

abstract interface class OperatorPaymentChannelRemoteDataSource {
  Future<PaymentChannelStatus> getChannel();
  Future<PaymentChannelStatus> submitCredentials(
    SubmitCredentialsRequest request,
  );
  Future<PaymentChannelStatus> verify();
}

final class DioOperatorPaymentChannelRemoteDataSource
    implements OperatorPaymentChannelRemoteDataSource {
  DioOperatorPaymentChannelRemoteDataSource(DioClient client)
    : _dio = client.dio;
  final Dio _dio;

  static const _path = '/api/v1/operator/payment-channel';

  @override
  Future<PaymentChannelStatus> getChannel() async {
    final response = await _dio.get<Object?>(_path);
    return _parse(response.data);
  }

  @override
  Future<PaymentChannelStatus> submitCredentials(
    SubmitCredentialsRequest request,
  ) async {
    final response = await _dio.put<Object?>(
      _path,
      data: {
        'clientId': request.clientId,
        'apiKey': request.apiKey,
        'checksumKey': request.checksumKey,
        'beneficiaryAccountNumber': request.beneficiaryAccountNumber,
        'beneficiaryAccountName': request.beneficiaryAccountName,
        'beneficiaryBankCode': request.beneficiaryBankCode,
      },
    );
    return _parse(response.data);
  }

  @override
  Future<PaymentChannelStatus> verify() async {
    final response = await _dio.post<Object?>('$_path/verify');
    return _parse(response.data);
  }

  static PaymentChannelStatus _parse(Object? data) {
    if (data is! Map) {
      throw const FormatException('Invalid payment channel response.');
    }
    final actions = data['allowedActions'];
    return PaymentChannelStatus(
      channelId: (data['channelId'] as num?)?.toInt(),
      status: PaymentChannelState.fromString(
        (data['status'] as String?) ?? 'NoChannel',
      ),
      channelVersion: (data['channelVersion'] as num?)?.toInt(),
      beneficiaryAccountNumberMasked:
          data['beneficiaryAccountNumberMasked'] as String?,
      beneficiaryAccountName: data['beneficiaryAccountName'] as String?,
      beneficiaryBankCode: data['beneficiaryBankCode'] as String?,
      webhookRegisteredAt: data['webhookRegisteredAt'] == null
          ? null
          : DateTime.tryParse(data['webhookRegisteredAt'] as String),
      connectedAt: data['connectedAt'] == null
          ? null
          : DateTime.tryParse(data['connectedAt'] as String),
      lastVerifiedAt: data['lastVerifiedAt'] == null
          ? null
          : DateTime.tryParse(data['lastVerifiedAt'] as String),
      allowedActions: actions is List
          ? actions.whereType<String>().toList()
          : const [],
    );
  }
}
