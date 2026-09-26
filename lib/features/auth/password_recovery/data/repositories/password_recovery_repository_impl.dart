import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/datasources/password_recovery_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/confirm_password_reset_request.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/password_reset_request.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/domain/repositories/password_recovery_repository.dart';

final class PasswordRecoveryRepositoryImpl
    implements PasswordRecoveryRepository {
  const PasswordRecoveryRepositoryImpl(this._remoteDataSource);

  final PasswordRecoveryRemoteDataSource _remoteDataSource;

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _remoteDataSource.requestPasswordReset(
        PasswordResetRequest(email: email),
      );
    } catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _remoteDataSource.confirmPasswordReset(
        ConfirmPasswordResetRequest(
          email: email,
          code: code,
          newPassword: newPassword,
        ),
      );
    } catch (error) {
      throw _toFailure(error);
    }
  }

  Failure _toFailure(Object error) {
    if (error is FormatException) {
      return const ServerFailure(
        'Something went wrong. Please try again later.',
      );
    }
    if (error is DioException &&
        ErrorMapper.extractErrorCode(error.response?.data) == 'MSG14') {
      return const InvalidResetCredentialFailure();
    }

    final failure = ErrorMapper.toFailure(error);
    if (failure is ValidationFailure) {
      return ValidationFailure(
        'Unable to complete this request. Please check the highlighted fields.',
        fieldErrors: _normalizeValidationErrors(failure.fieldErrors),
      );
    }
    if (failure is RateLimitFailure) {
      return const RateLimitFailure(
        'Too many reset attempts. Please wait and try again.',
      );
    }
    if (failure is NetworkFailure) {
      return const NetworkFailure(
        'Please check your connection and try again.',
      );
    }
    if (failure is ServerFailure || failure is UnknownFailure) {
      return const ServerFailure(
        'Something went wrong. Please try again later.',
      );
    }
    return failure;
  }

  Map<String, List<String>> _normalizeValidationErrors(
    Map<String, List<String>> errors,
  ) {
    final result = <String, List<String>>{};

    for (final entry in errors.entries) {
      final field = switch (entry.key.toLowerCase()) {
        'email' => 'email',
        'newpassword' => 'newPassword',
        'code' => 'code',
        _ => entry.key,
      };
      if (entry.value.isNotEmpty) result[field] = entry.value;
    }

    return result;
  }
}
