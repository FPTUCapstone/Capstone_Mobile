import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';

final class AuthInterceptor extends Interceptor {
  /// [refreshClient] and [retry] enable transparent renewal of the short-lived
  /// access token: [refreshClient] must carry no interceptors (so a failed
  /// refresh can never recurse) and [retry] replays a request on the main
  /// client. Without them a 401 invalidates the session straight away.
  AuthInterceptor(
    this._secureStorage, {
    SessionCoordinator? coordinator,
    Dio? refreshClient,
    Future<Response<dynamic>> Function(RequestOptions options)? retry,
  }) : _coordinator = coordinator,
       _refreshClient = refreshClient,
       _retry = retry;

  final SecureStorageService _secureStorage;
  final SessionCoordinator? _coordinator;
  final Dio? _refreshClient;
  final Future<Response<dynamic>> Function(RequestOptions options)? _retry;

  /// One refresh serves every request that failed with the same expired token.
  Future<String?>? _pendingRefresh;

  /// Most endpoints under this prefix (login, register, refresh, password
  /// reset, ...) run before a session exists; their 401 is a normal
  /// sign-in/recovery failure and must never trigger global invalidation.
  static const _authPathPrefix = '/api/v1/auth/';
  static const _refreshPath = '/api/v1/auth/refresh';
  static const _retriedKey = 'authRetriedAfterRefresh';

  /// UC-07: the one Bearer-carrying, already-authenticated exception to
  /// [_authPathPrefix] — its 401 means the session credential itself was
  /// rejected and must invalidate the session exactly like any other
  /// authenticated endpoint (spec §5/§6).
  static const _authenticatedAuthPaths = {
    '/api/v1/auth/change-password',
    '/api/v1/auth/web/change-password',
  };

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
    // A 401 on an authenticated (non-auth-endpoint) request means the access
    // token is no longer accepted. It is renewed once with the refresh token
    // and the request replayed; when that is impossible the whole local
    // session is invalidated. 403 and other statuses never clear it (403 is a
    // per-operation denial handled by the feature).
    final options = err.requestOptions;
    final status = err.response?.statusCode;
    final authorization = options.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => entry.value)
        .whereType<String>()
        .firstOrNull;
    final hasBearer =
        authorization != null &&
        authorization.startsWith('Bearer ') &&
        authorization.substring(7).trim().isNotEmpty;
    final path = options.path;
    final isExcludedAuthPath =
        path.startsWith(_authPathPrefix) &&
        !_authenticatedAuthPaths.contains(path);

    if (status != 401 || !hasBearer || isExcludedAuthPath) {
      handler.next(err);
      return;
    }

    final retry = _retry;
    if (retry != null && options.extra[_retriedKey] != true) {
      final accessToken = await _refreshAccessToken();
      if (accessToken != null) {
        final renewed = options.copyWith(
          headers: {...options.headers, 'Authorization': 'Bearer $accessToken'},
          extra: {...options.extra, _retriedKey: true},
        );
        try {
          handler.resolve(await retry(renewed));
        } on DioException catch (retryError) {
          // A second 401 already invalidated the session on its own pass.
          handler.next(retryError);
        }
        return;
      }
    }

    if (_coordinator != null) {
      try {
        await _coordinator.invalidate();
      } catch (_) {
        // Invalidation is best-effort; the original HTTP 401 must continue.
      }
    }
    handler.next(err);
  }

  Future<String?> _refreshAccessToken() => _pendingRefresh ??=
      _requestAccessToken().whenComplete(() => _pendingRefresh = null);

  Future<String?> _requestAccessToken() async {
    final client = _refreshClient;
    final refreshToken = await _secureStorage.read(
      AppConstants.refreshTokenKey,
    );
    if (client == null || refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    try {
      final response = await client.post<Map<String, dynamic>>(
        _refreshPath,
        data: {'refreshToken': refreshToken},
      );
      final data = response.data?['data'];
      final accessToken = data is Map<String, dynamic>
          ? data['accessToken']
          : null;
      if (accessToken is! String || accessToken.isEmpty) return null;
      await _secureStorage.write(AppConstants.accessTokenKey, accessToken);
      return accessToken;
    } catch (_) {
      // An expired, revoked or unreachable refresh ends the session normally.
      return null;
    }
  }
}
