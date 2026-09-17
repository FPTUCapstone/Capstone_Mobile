import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

abstract final class ErrorMapper {
  static Failure toFailure(Object error) {
    if (error is AuthenticationException) {
      return AuthenticationFailure(error.message);
    }
    if (error is NetworkException) {
      return NetworkFailure(error.message);
    }
    if (error is ServerException) {
      return ServerFailure(error.message);
    }
    if (error is DioException) {
      return _mapDioException(error);
    }
    return const UnknownFailure();
  }

  static Failure _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 400) {
      final message = _extractValidationMessage(error.response?.data);
      return message != null
          ? ValidationFailure(message)
          : const ValidationFailure();
    }
    if (statusCode == 401) return const AuthenticationFailure();
    if (statusCode == 403) return const PermissionFailure();
    if (statusCode == 409) {
      final (message, groupId) = _extractConflictDetails(error.response?.data);
      return ConflictFailure(
        message ?? 'Conflict occurred. Please try again.',
        groupId,
      );
    }
    if (statusCode != null && statusCode >= 500) return const ServerFailure();

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => const NetworkFailure(),
      _ => const UnknownFailure(),
    };
  }

  static String? _extractValidationMessage(dynamic data) {
    if (data is! Map) return null;

    final errorCode = _extractErrorCode(data);
    if (errorCode == 'travel_group.invitation_unavailable') {
      return 'This invitation is invalid, expired, or no longer available. Please check the invitation and try again.';
    }
    if (errorCode == 'travel_group.idempotency_key_payload_mismatch') {
      return 'A conflicting request with a different invitation code is already in progress. Please try again.';
    }

    final errors = data['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty && value.first is String) {
          final first = (value.first as String).trim();
          if (first.isNotEmpty) return first;
        }
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    return null;
  }

  static (String?, int?) _extractConflictDetails(dynamic data) {
    if (data is! Map) return (null, null);

    final errorCode = _extractErrorCode(data);
    final groupId = _extractGroupId(data);

    if (errorCode == 'travel_group.already_active_member') {
      return ('You are already a member of this travel group.', groupId);
    }
    if (errorCode == 'travel_group.idempotency_key_payload_mismatch') {
      return (
        'A conflicting request with a different invitation code is already in progress. Please try again.',
        groupId,
      );
    }

    return (null, groupId);
  }

  static String? _extractErrorCode(Map data) {
    final dynamic code =
        data['errorCode'] ??
        (data['extensions'] is Map ? data['extensions']['errorCode'] : null);
    return code is String ? code : null;
  }

  static int? _extractGroupId(Map data) {
    final extensions = data['extensions'];
    final dynamic rawGroupId =
        (extensions is Map ? extensions['groupId'] : null) ?? data['groupId'];
    if (rawGroupId is num) {
      return rawGroupId.toInt();
    }
    if (rawGroupId is String) {
      return int.tryParse(rawGroupId);
    }
    return null;
  }
}
