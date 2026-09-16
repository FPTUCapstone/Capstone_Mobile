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
      final message = _extractMessage(error.response?.data);
      return message != null
          ? ValidationFailure(message)
          : const ValidationFailure();
    }
    if (statusCode == 401) return const AuthenticationFailure();
    if (statusCode == 403) return const PermissionFailure();
    if (statusCode == 409) {
      final message = _extractMessage(error.response?.data);
      return message != null
          ? ConflictFailure(message)
          : const ConflictFailure();
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

  static String? _extractMessage(dynamic data) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      final title = data['title'];
      if (title is String && title.trim().isNotEmpty) {
        return title.trim();
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
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
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return null;
  }
}
