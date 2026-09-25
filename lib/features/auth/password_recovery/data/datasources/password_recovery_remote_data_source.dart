import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/confirm_password_reset_request.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/password_reset_message_dto.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/password_reset_request.dart';

abstract interface class PasswordRecoveryRemoteDataSource {
  Future<PasswordResetMessageDto> requestPasswordReset(
    PasswordResetRequest request,
  );

  Future<PasswordResetMessageDto> confirmPasswordReset(
    ConfirmPasswordResetRequest request,
  );
}

final class PasswordRecoveryRemoteDataSourceImpl
    implements PasswordRecoveryRemoteDataSource {
  const PasswordRecoveryRemoteDataSourceImpl(this._dioClient);

  static const _requestPath = '/api/v1/auth/password-reset/request';
  static const _confirmPath = '/api/v1/auth/password-reset/confirm';

  final DioClient _dioClient;

  @override
  Future<PasswordResetMessageDto> requestPasswordReset(
    PasswordResetRequest request,
  ) => _post(_requestPath, request.toJson());

  @override
  Future<PasswordResetMessageDto> confirmPasswordReset(
    ConfirmPasswordResetRequest request,
  ) => _post(_confirmPath, request.toJson());

  Future<PasswordResetMessageDto> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _dioClient.dio.post<Map<String, dynamic>>(
      path,
      data: body,
      options: Options(extra: const {'skipAuth': true}),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty password-reset response.');
    }
    return PasswordResetMessageDto.fromJson(data);
  }
}
