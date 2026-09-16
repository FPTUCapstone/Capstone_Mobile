import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

final class _MemoryStorage implements SecureStorageService {
  final values = <String, String>{'access_token': 'token'};
  String? failingDeleteKey;

  @override
  Future<void> delete(String key) async {
    if (key == failingDeleteKey) throw StateError('storage unavailable');
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  late _MemoryStorage storage;
  late SessionCoordinator coordinator;
  late AuthInterceptor interceptor;
  late int invalidated;

  setUp(() {
    storage = _MemoryStorage();
    coordinator = SessionCoordinator();
    interceptor = AuthInterceptor(storage, coordinator: coordinator);
    invalidated = 0;
    coordinator.register(() async => invalidated++);
  });

  DioException errorFor(String path, int status, {bool bearer = false}) =>
      DioException(
        requestOptions: RequestOptions(
          path: path,
          headers: bearer ? {'Authorization': 'Bearer token'} : {},
        ),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: status,
        ),
        type: DioExceptionType.badResponse,
      );

  Future<_RecordingHandler> driveError(
    String path,
    int status, {
    bool bearer = false,
  }) async {
    final handler = _RecordingHandler();
    await interceptor.onError(errorFor(path, status, bearer: bearer), handler);
    await Future<void>.delayed(Duration.zero);
    return handler;
  }

  test(
    '401 on an authenticated business request invalidates the session',
    () async {
      await driveError('/api/v1/travel-groups', 401, bearer: true);
      expect(invalidated, 1);
    },
  );

  test(
    '401 without a Bearer credential does not invalidate a session',
    () async {
      await driveError('/api/v1/travel-groups', 401);
      expect(invalidated, 0);
    },
  );

  test(
    '401 on auth endpoints does not invalidate (pre-session failure)',
    () async {
      await driveError('/api/v1/auth/login', 401, bearer: true);
      await driveError('/api/v1/auth/google', 401, bearer: true);
      await driveError('/api/v1/auth/verify-email', 401, bearer: true);
      expect(invalidated, 0);
    },
  );

  test('403 never invalidates the session', () async {
    await driveError('/api/v1/travel-groups', 403);
    expect(invalidated, 0);
  });

  test('500 does not invalidate the session', () async {
    await driveError('/api/v1/travel-groups', 500);
    expect(invalidated, 0);
  });

  test('the error is always forwarded to the handler', () async {
    final handler = await driveError(
      '/api/v1/travel-groups',
      401,
      bearer: true,
    );
    expect(handler.forwarded, isTrue);
  });

  test(
    'storage failure on authenticated 401 still signs out and forwards original 401',
    () async {
      storage.values.addAll({
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'traveler',
        AppConstants.keepSignedInKey: 'true',
      });
      storage.failingDeleteKey = AppConstants.accessTokenKey;
      final cubit = AuthSessionCubit(null, storage);
      addTearDown(cubit.close);
      await cubit.restoreSession();
      expect(cubit.state.isAuthenticated, isTrue);
      coordinator.register(cubit.handleSessionExpired);
      final original = errorFor('/api/v1/travel-groups', 401, bearer: true);
      final handler = _RecordingHandler();

      await interceptor.onError(original, handler);

      expect(cubit.state, const AuthSessionState.unauthenticated());
      expect(handler.forwardedError, same(original));
      expect(storage.values[AppConstants.refreshTokenKey], isNull);
      expect(storage.values[AppConstants.sessionRoleKey], isNull);
      expect(storage.values[AppConstants.keepSignedInKey], isNull);
    },
  );

  test('incomplete 401 cleanup cannot restore authenticated state', () async {
    storage.values.addAll({
      AppConstants.refreshTokenKey: 'refresh',
      AppConstants.sessionRoleKey: 'traveler',
      AppConstants.keepSignedInKey: 'true',
    });
    storage.failingDeleteKey = AppConstants.accessTokenKey;
    final active = AuthSessionCubit(null, storage);
    addTearDown(active.close);
    await active.restoreSession();
    expect(active.state.isAuthenticated, isTrue);
    coordinator.register(active.handleSessionExpired);
    await interceptor.onError(
      errorFor('/api/v1/travel-groups', 401, bearer: true),
      _RecordingHandler(),
    );

    final restarted = AuthSessionCubit(null, storage);
    addTearDown(restarted.close);
    await restarted.restoreSession();

    expect(restarted.state, const AuthSessionState.unauthenticated());
  });
}

final class _RecordingHandler extends ErrorInterceptorHandler {
  bool forwarded = false;
  DioException? forwardedError;

  @override
  void next(DioException err) {
    forwarded = true;
    forwardedError = err;
  }
}
