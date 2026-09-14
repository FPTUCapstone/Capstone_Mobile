import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

abstract final class ErrorMapper {
  static Failure toFailure(Object error) {
    if (error is Failure) {
      return error;
    }
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
    final responseData = error.response?.data;
    if (statusCode == 400) {
      return ValidationFailure(
        _safeTitle(responseData) ?? 'Dữ liệu gửi lên không hợp lệ.',
        fieldErrors: _fieldErrors(responseData),
      );
    }
    if (statusCode == 404 && _errorCode(responseData) == 'Poi.NotFound') {
      return const NotFoundFailure();
    }
    if (statusCode == 401 || statusCode == 403) {
      return const AuthenticationFailure();
    }
    if (statusCode != null && statusCode >= 500) {
      return const ServerFailure();
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => const NetworkFailure(),
      _ => const UnknownFailure(),
    };
  }

  static String? _errorCode(Object? data) {
    if (data case final Map<Object?, Object?> body) {
      final code = body['errorCode'];
      return code is String ? code : null;
    }
    return null;
  }

  static String? _safeTitle(Object? data) {
    if (data case final Map<Object?, Object?> body) {
      final title = body['title'];
      return title is String && title.trim().isNotEmpty ? title.trim() : null;
    }
    return null;
  }

  static Map<String, List<String>> _fieldErrors(Object? data) {
    if (data is! Map<Object?, Object?>) {
      return const {};
    }
    final errors = data['errors'];
    if (errors is! Map<Object?, Object?>) {
      return const {};
    }
    return {
      for (final entry in errors.entries)
        if (entry.key is String)
          entry.key as String: switch (entry.value) {
            final List<Object?> values => values.whereType<String>().toList(),
            final String value => [value],
            _ => const <String>[],
          },
    };
  }
}
