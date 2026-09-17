import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';

final class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._secureStorage, {SessionCoordinator? coordinator})
    : _coordinator = coordinator;

  final SecureStorageService _secureStorage;
  final SessionCoordinator? _coordinator;

  /// Auth endpoints run before a session exists; their 401 is a normal
  /// sign-in/recovery failure and must never trigger global invalidation.
  static const _authPathPrefix = '/api/v1/auth/';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }
    final explicitAuthorization = options.headers['Authorization'];
    if (explicitAuthorization is String &&
        explicitAuthorization.trim().isNotEmpty) {
      handler.next(options);
      return;
    }

    final accessToken = await _secureStorage.read(AppConstants.accessTokenKey);
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // A 401 on an authenticated (non-auth-endpoint) request means the session
    // credential is no longer accepted: invalidate the whole local session.
    // 403 and other statuses never clear it (the user may still be authorized
    // to the app; 403 is a per-operation denial handled by the feature).
    final path = err.requestOptions.path;
    final status = err.response?.statusCode;
    final authorization = err.requestOptions.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => entry.value)
        .whereType<String>()
        .firstOrNull;
    final hasBearer =
        authorization != null &&
        authorization.startsWith('Bearer ') &&
        authorization.substring(7).trim().isNotEmpty;
    if (status == 401 &&
        hasBearer &&
        !path.startsWith(_authPathPrefix) &&
        _coordinator != null) {
      try {
        await _coordinator.invalidate();
      } catch (_) {
        // Invalidation is best-effort; the original HTTP 401 must continue.
      }
    }
    handler.next(err);
  }
}
