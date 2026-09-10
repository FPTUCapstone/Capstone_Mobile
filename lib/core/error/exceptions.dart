class AppException implements Exception {
  const AppException([this.message = 'An unexpected error occurred.']);

  final String message;

  @override
  String toString() => 'AppException: $message';
}

final class NetworkException extends AppException {
  const NetworkException([super.message = 'A network error occurred.']);
}

final class ServerException extends AppException {
  const ServerException([
    super.message = 'A server error occurred.',
    this.code,
    this.statusCode,
  ]);

  final String? code;
  final int? statusCode;
}

final class AuthenticationException extends AppException {
  const AuthenticationException([
    super.message = 'Authentication is required.',
  ]);
}

final class CacheException extends AppException {
  const CacheException([super.message = 'Local data could not be accessed.']);
}
