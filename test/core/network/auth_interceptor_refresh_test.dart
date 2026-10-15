import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';

void main() {
  late _MemoryStorage storage;
  late _Server api;
  late _Server auth;
  late Dio dio;
  late int invalidated;

  setUp(() {
    storage = _MemoryStorage({
      AppConstants.accessTokenKey: 'expired-access',
      AppConstants.refreshTokenKey: 'refresh-1',
    });
    invalidated = 0;
    final coordinator = SessionCoordinator()
      ..register(() async => invalidated++);
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
}

final class _Server implements HttpClientAdapter {
  _Server(this.handler);

  (int, Object) Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = handler(options);
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

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
