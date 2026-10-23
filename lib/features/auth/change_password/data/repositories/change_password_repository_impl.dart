import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/datasources/change_password_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/models/change_password_request.dart';
import 'package:trip_mate_mobile/features/auth/change_password/domain/repositories/change_password_repository.dart';
import 'package:trip_mate_mobile/features/auth/data/mappers/auth_mapper.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';

/// UC-07 spec §5 error mapping, ahead of the shared [ErrorMapper]: MSG17 and
/// the local-password-unavailable 403 have dedicated Failure types so the
/// Cubit/UI can target the right field without parsing error codes itself.
/// Everything else (network, 401, MSG127/5xx) falls through to the generic
/// mapper, matching PasswordRecoveryRepositoryImpl's precedent.
final class ChangePasswordRepositoryImpl implements ChangePasswordRepository {
  const ChangePasswordRepositoryImpl(this._remoteDataSource);

  final ChangePasswordRemoteDataSource _remoteDataSource;

  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _remoteDataSource.changePassword(
        ChangePasswordRequest(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );
      return response.toDomain();
    } catch (error) {
      throw _toFailure(error);
    }
  }

  Failure _toFailure(Object error) {
    if (error is FormatException) {
      return const ServerFailure('Something went wrong. Please try again.');
    }
    if (error is DioException) {
      final data = error.response?.data;
      final errorCode = ErrorMapper.extractErrorCode(data);
      if (errorCode == 'MSG17') {
        return const IncorrectCurrentPasswordFailure();
      }
      if (errorCode == 'auth.local_password_unavailable') {
        return const LocalPasswordUnavailableFailure();
      }
      if (errorCode == 'MSG05') {
        final message =
            _safeTitle(data) ??
            'The new password is invalid or matches the current password.';
        return ValidationFailure(
          message,
          fieldErrors: {
            'newPassword': [message],
          },
        );
      }
    }

    final failure = ErrorMapper.toFailure(error);
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

  String? _safeTitle(Object? data) {
    if (data is! Map) return null;
    final title = data['title'];
    if (title is! String) return null;
    final normalized = title.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
