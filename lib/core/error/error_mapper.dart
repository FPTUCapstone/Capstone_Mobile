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
}
