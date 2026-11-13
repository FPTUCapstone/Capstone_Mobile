import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';

void main() {
  late _MemoryStorage storage;
  late _Server api;
  late _Server auth;
  late Dio dio;
  late int invalidated;
  late SessionCoordinator coordinator;

  setUp(() {
    storage = _MemoryStorage({
      AppConstants.accessTokenKey: 'expired-access',
      AppConstants.refreshTokenKey: 'refresh-1',
    });
    invalidated = 0;
    coordinator = SessionCoordinator()..register(() async => invalidated++);
    api = _Server((options) {
      // Only the renewed token is accepted by business endpoints.
      return options.headers['Authorization'] == 'Bearer fresh-access'
          ? (200, {'ok': true})
          : (401, {'errorCode': 'Unauthorized'});
    });
    auth = _Server((options) {
      final body = options.data as Map<String, dynamic>;
      return body['refreshToken'] == 'refresh-1'
          ? (
              200,
              {
                'data': {'accessToken': 'fresh-access'},
              },
            )
          : (401, {'errorCode': 'AUTH_TOKEN_INVALID'});
    });
    final refreshClient = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = auth;
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = api;
    dio.interceptors.add(
      AuthInterceptor(
        storage,
        coordinator: coordinator,
        refreshClient: refreshClient,
        retry: (options) => dio.fetch<dynamic>(options),
      ),
    );
  });

  test('an expired access token is renewed and the request replayed', () async {
    final response = await dio.get<dynamic>('/api/v1/itineraries');

    expect(response.statusCode, 200);
    expect(storage.values[AppConstants.accessTokenKey], 'fresh-access');
    expect(auth.requests.single.path, '/api/v1/auth/refresh');
    expect(auth.requests.single.data, {'refreshToken': 'refresh-1'});
    expect(api.requests.map((request) => request.headers['Authorization']), [
      'Bearer expired-access',
      'Bearer fresh-access',
    ]);
    expect(invalidated, 0);
  });

  test('concurrent expired requests share one refresh', () async {
    final responses = await Future.wait([
      dio.get<dynamic>('/api/v1/itineraries'),
      dio.get<dynamic>('/api/v1/navigation-sessions?state=Open'),
    ]);

    expect(responses.map((response) => response.statusCode), [200, 200]);
    expect(auth.requests, hasLength(1));
    expect(invalidated, 0);
  });

  test(
    'late chat 401 cannot replay private history in a new session',
    () async {
      final arrived = Completer<void>();
      final respond = Completer<void>();
      api.handler = (options) async {
        arrived.complete();
        await respond.future;
        return (401, {'errorCode': 'Unauthorized'});
      };
      final request = dio.post<dynamic>(
        '/api/v1/support-chat/messages',
        data: {
          'message': 'Follow-up',
          'history': [
            {'role': 'assistant', 'content': 'Private account A reply'},
          ],
        },
      );
      final assertion = expectLater(request, throwsA(isA<DioException>()));
      await arrived.future;
      storage.values[AppConstants.accessTokenKey] = 'account-B';
      storage.values[AppConstants.refreshTokenKey] = 'refresh-B';
      respond.complete();
      await assertion;
      expect(api.requests, hasLength(1));
      expect(auth.requests, isEmpty);
      expect(invalidated, 0);
      expect(storage.values[AppConstants.accessTokenKey], 'account-B');
    },
  );

  test(
    'session change during refresh cannot overwrite or invalidate new login',
    () async {
      final arrived = Completer<void>();
      final respond = Completer<void>();
      auth.handler = (_) async {
        arrived.complete();
        await respond.future;
        return (
          200,
          {
            'data': {'accessToken': 'fresh-access'},
          },
        );
      };
      final request = dio.get<dynamic>('/api/v1/itineraries');
      final assertion = expectLater(request, throwsA(isA<DioException>()));
      await arrived.future;
      storage.values[AppConstants.accessTokenKey] = 'account-B';
      storage.values[AppConstants.refreshTokenKey] = 'refresh-B';
      respond.complete();
      await assertion;
      expect(api.requests, hasLength(1));
      expect(invalidated, 0);
      expect(storage.values[AppConstants.accessTokenKey], 'account-B');
    },
  );

  test(
    'a rejected refresh invalidates the session and keeps the 401',
    () async {
      storage.values[AppConstants.refreshTokenKey] = 'revoked';

      await expectLater(
        dio.get<dynamic>('/api/v1/itineraries'),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            401,
          ),
        ),
      );

      expect(invalidated, 1);
      expect(storage.values[AppConstants.accessTokenKey], 'expired-access');
      expect(api.requests, hasLength(1));
    },
  );

  test(
    'without a refresh token the session ends without a refresh call',
    () async {
      storage.values.remove(AppConstants.refreshTokenKey);

      await expectLater(
        dio.get<dynamic>('/api/v1/itineraries'),
        throwsA(isA<DioException>()),
      );

      expect(auth.requests, isEmpty);
      expect(invalidated, 1);
    },
  );

  test('a request still rejected after renewal is not retried again', () async {
    api.handler = (_) => (401, {'errorCode': 'Unauthorized'});

    await expectLater(
      dio.get<dynamic>('/api/v1/itineraries'),
      throwsA(isA<DioException>()),
    );

    expect(auth.requests, hasLength(1));
    expect(api.requests, hasLength(2));
    expect(invalidated, 1);
  });

  test('auth endpoint failures are never refreshed', () async {
    api.handler = (_) => (401, {'errorCode': 'auth.invalid_credentials'});

    await expectLater(
      dio.post<dynamic>(
        '/api/v1/auth/login',
        options: Options(headers: {'Authorization': 'Bearer expired-access'}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(auth.requests, isEmpty);
    expect(invalidated, 0);
  });

  test(
    'expired session cleanup cannot clear a login completed during push cleanup',
    () async {
      final push = _PausedPushCleanup();
      final cubit = AuthSessionCubit(null, storage, null, push);
      addTearDown(cubit.close);
      storage.values[AppConstants.sessionRoleKey] = 'traveler';
      storage.values[AppConstants.keepSignedInKey] = 'true';
      await cubit.restoreSession();
      coordinator.register(
        cubit.handleSessionExpired,
        guarded: (isCurrent) =>
            cubit.handleSessionExpired(isCurrent: isCurrent),
      );
      auth.handler = (_) => (401, {'errorCode': 'Revoked'});
      final request = dio.get<dynamic>('/api/v1/itineraries');
      final assertion = expectLater(request, throwsA(isA<DioException>()));
      await push.started.future;
      await storage.withSessionLock(() async {
        await storage.write(AppConstants.accessTokenKey, 'account-B');
        await storage.write(AppConstants.refreshTokenKey, 'refresh-B');
      });
      push.resume.complete();
      await assertion;
      expect(cubit.state.isAuthenticated, isTrue);
      expect(storage.values[AppConstants.accessTokenKey], 'account-B');
      expect(storage.values[AppConstants.refreshTokenKey], 'refresh-B');
    },
  );

  test(
    'explicit Firebase auth still dispatches when secure storage fails',
    () async {
      storage.failReads = true;
      api.handler = (_) => (200, {'ok': true});
      final response = await dio.post<dynamic>(
        '/api/v1/auth/register',
        options: Options(headers: {'Authorization': 'Bearer firebase-token'}),
      );
      expect(response.statusCode, 200);
      expect(
        api.requests.single.headers['Authorization'],
        'Bearer firebase-token',
      );
      expect(auth.requests, isEmpty);
    },
  );

  test('storage read failure settles the request with an error', () async {
    storage.failReads = true;
    await expectLater(
      dio.get<dynamic>('/api/v1/itineraries'),
      throwsA(isA<DioException>()),
    );
    expect(api.requests, isEmpty);
  });

  test('login waits for an in-flight refresh credential write', () async {
    final writing = Completer<void>();
    final finishWrite = Completer<void>();
    storage.beforeWrite = (key, value) async {
      if (value == 'fresh-access') {
        writing.complete();
        await finishWrite.future;
      }
    };
    final request = dio.get<dynamic>('/api/v1/itineraries');
    final assertion = expectLater(request, throwsA(isA<DioException>()));
    await writing.future;
    var savedB = false;
    final loginB = storage.withSessionLock(() async {
      await storage.write(AppConstants.accessTokenKey, 'account-B');
      await storage.write(AppConstants.refreshTokenKey, 'refresh-B');
      savedB = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(savedB, isFalse);
    finishWrite.complete();
    await loginB;
    await assertion;
    expect(storage.values[AppConstants.accessTokenKey], 'account-B');
    expect(storage.values[AppConstants.refreshTokenKey], 'refresh-B');
    expect(api.requests, hasLength(1));
    expect(invalidated, 0);
  });

  test(
    'an explicit old credential cannot refresh using the current account',
    () async {
      storage.values[AppConstants.accessTokenKey] = 'account-B';
      storage.values[AppConstants.refreshTokenKey] = 'refresh-B';
      await expectLater(
        dio.post<dynamic>(
          '/api/v1/support-chat/messages',
          options: Options(headers: {'Authorization': 'Bearer account-A'}),
          data: {'message': 'Private account A question'},
        ),
        throwsA(isA<DioException>()),
      );
      expect(api.requests, hasLength(1));
      expect(auth.requests, isEmpty);
      expect(invalidated, 0);
    },
  );

  test(
    'cancelling during refresh prevents replay and session invalidation',
    () async {
      final arrived = Completer<void>();
      final respond = Completer<void>();
      auth.handler = (_) async {
        arrived.complete();
        await respond.future;
        return (
          200,
          {
            'data': {'accessToken': 'fresh-access'},
          },
        );
      };
      final cancellation = CancelToken();
      final request = dio.post<dynamic>(
        '/api/v1/support-chat/messages',
        cancelToken: cancellation,
        data: {'message': 'Private question'},
      );
      final assertion = expectLater(request, throwsA(isA<DioException>()));
      await arrived.future;
      cancellation.cancel();
      respond.complete();
      await assertion;
      await Future<void>.delayed(Duration.zero);
      expect(api.requests, hasLength(1));
      expect(invalidated, 0);
    },
  );
}

final class _PausedPushCleanup implements PushDeviceLifecycle {
  final started = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<void> onAuthenticated() async {}
  @override
  Future<void> onBeforeLogout() async {
    started.complete();
    await resume.future;
  }
}

final class _Server implements HttpClientAdapter {
  _Server(this.handler);

  FutureOr<(int, Object)> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this.values);

  final Map<String, String> values;
  bool failReads = false;
  Future<void> Function(String key, String value)? beforeWrite;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('Storage unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    await beforeWrite?.call(key, value);
    values[key] = value;
  }
}
