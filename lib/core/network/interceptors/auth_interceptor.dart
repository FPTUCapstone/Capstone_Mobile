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
  final _pendingRefresh = <String, Future<String?>>{};

  /// Most endpoints under this prefix (login, register, refresh, password
  /// reset, ...) run before a session exists; their 401 is a normal
  /// sign-in/recovery failure and must never trigger global invalidation.
  static const _authPathPrefix = '/api/v1/auth/';
  static const _refreshPath = '/api/v1/auth/refresh';
  static const _retriedKey = 'authRetriedAfterRefresh';
  static const _sessionKey = 'authRequestSession';

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
    if (options.cancelToken?.isCancelled == true) {
      handler.reject(options.cancelToken!.cancelError!);
      return;
    }
    final explicitAuthorization = options.headers['Authorization'];
    final hasExplicit =
        explicitAuthorization is String &&
        explicitAuthorization.trim().isNotEmpty;
    if (hasExplicit &&
        (!explicitAuthorization.startsWith('Bearer ') ||
            (options.path.startsWith(_authPathPrefix) &&
                !_authenticatedAuthPaths.contains(options.path)))) {
      handler.next(options);
      return;
    }
    try {
      final current = await _secureStorage.withSessionLock(_readSession);
      final boundSession = options.extra[_sessionKey];
      if (boundSession is _RequestSession && !boundSession.matches(current)) {
        handler.reject(
          DioException.requestCancelled(
            requestOptions: options,
            reason: 'The request session has ended.',
          ),
        );
        return;
      }
      options.extra[_sessionKey] ??=
          hasExplicit &&
              explicitAuthorization != 'Bearer ${current.accessToken}'
          ? _RequestSession(explicitAuthorization.substring(7), null)
          : current;
      if (!hasExplicit &&
          current.accessToken != null &&
          current.accessToken!.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer ${current.accessToken}';
      }
      handler.next(options);
    } catch (error) {
      handler.reject(DioException(requestOptions: options, error: error));
    }
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

    final session = options.extra[_sessionKey] is _RequestSession
        ? options.extra[_sessionKey] as _RequestSession
        : _RequestSession(authorization.substring(7), null);
    if (!await _isCurrent(session) ||
        options.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }

    final retry = _retry;
    if (retry != null && options.extra[_retriedKey] != true) {
      final accessToken = await _refreshAccessToken(session);
      if (!await _isCurrent(session) ||
          options.cancelToken?.isCancelled == true) {
        handler.next(err);
        return;
      }
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
        await _coordinator.invalidate(
          isCurrent: () async =>
              session.matches(await _readSession()) &&
              options.cancelToken?.isCancelled != true,
        );
      } catch (_) {
        // Invalidation is best-effort; the original HTTP 401 must continue.
      }
    }
    handler.next(err);
  }

  Future<_RequestSession> _readSession() async => _RequestSession(
    await _secureStorage.read(AppConstants.accessTokenKey),
    await _secureStorage.read(AppConstants.refreshTokenKey),
  );

  Future<bool> _isCurrent(_RequestSession session) async {
    try {
      return await _secureStorage.withSessionLock(
        () async => session.matches(await _readSession()),
      );
    } catch (_) {
      return false;
    }
  }

  Future<String?> _refreshAccessToken(_RequestSession session) {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return Future.value(null);
    return _pendingRefresh.putIfAbsent(
      refreshToken,
      () => _requestAccessToken(session).whenComplete(() {
        _pendingRefresh.remove(refreshToken);
      }),
    );
  }

  Future<String?> _requestAccessToken(_RequestSession session) async {
    final client = _refreshClient;
    final refreshToken = session.refreshToken;
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
      return await _secureStorage.withSessionLock(() async {
        if (!session.matches(await _readSession())) return null;
        await _secureStorage.write(AppConstants.accessTokenKey, accessToken);
        return accessToken;
      });
    } catch (_) {
      // An expired, revoked or unreachable refresh ends the session normally.
      return null;
    }
  }
}

/// Kept as an opaque object so request logging cannot stringify credentials.
final class _RequestSession {
  const _RequestSession(this.accessToken, this.refreshToken);

  final String? accessToken;
  final String? refreshToken;

  bool matches(_RequestSession current) =>
      current.accessToken != null &&
      current.accessToken!.isNotEmpty &&
      (refreshToken == null
          ? current.accessToken == accessToken
          : current.refreshToken == refreshToken);
}
