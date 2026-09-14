import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';

class MockSecureStorageService implements SecureStorageService {
  MockSecureStorageService([this.value]);

  final String? value;

  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write(String key, String value) async {}
}

final class RecordingHttpClientAdapter implements HttpClientAdapter {
  RecordingHttpClientAdapter({
    this.statusCode = 200,
    this.body =
        '{"success":true,"data":{"userId":1,"status":"Active","accessToken":"app-access-token","refreshToken":"app-refresh-token"}}',
  });

  final String body;
  final int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('AuthRemoteDataSourceImpl', () {
    late DioClient dioClient;
    late AuthRemoteDataSourceImpl dataSource;

    setUp(() {
      dioClient = DioClient(
        config: AppConfig(
          environment: Environment.development,
          apiBaseUrl: Uri.parse('http://localhost:5000'),
        ),
        secureStorage: MockSecureStorageService(),
      );
      dataSource = AuthRemoteDataSourceImpl(dioClient);
    });

    final testRequest = const RegisterTravelerRequest(
      fullName: 'Nguyen Van A',
      email: 'traveler@example.com',
      password: 'Password123!',
      acceptedTerms: true,
      phoneNumber: '0912345678',
    );

    test('throws AppException when register endpoint network fails', () {
      expect(
        () => dataSource.registerTraveler(testRequest, 'firebase-token'),
        throwsA(isA<AppException>()),
      );
    });

    test(
      'verify-email preserves the refreshed Firebase bearer token when an app token is stored',
      () async {
        final client = DioClient(
          config: AppConfig(
            environment: Environment.production,
            apiBaseUrl: Uri.parse('https://api.test.invalid'),
          ),
          secureStorage: MockSecureStorageService('stale-app-token'),
        );
        final adapter = RecordingHttpClientAdapter();
        client.dio.httpClientAdapter = adapter;

        final response = await AuthRemoteDataSourceImpl(
          client,
        ).verifyEmail('refreshed-firebase-token');

        expect(response.status, 'Active');
        expect(response.accessToken, 'app-access-token');
        expect(response.refreshToken, 'app-refresh-token');
        expect(
          adapter.request?.headers['Authorization'],
          'Bearer refreshed-firebase-token',
        );
      },
    );

    test(
      'login sends the refreshed Firebase bearer instead of the stored app token',
      () async {
        final client = DioClient(
          config: AppConfig(
            environment: Environment.production,
            apiBaseUrl: Uri.parse('https://api.test.invalid'),
          ),
          secureStorage: MockSecureStorageService('stale-app-token'),
        );
        final adapter = RecordingHttpClientAdapter(
          body:
              '{"success":true,"data":{"userId":7,"email":"traveler@example.com","fullName":"Traveler","role":1,"status":2,"accessToken":"app-access-token","refreshToken":"app-refresh-token","accessTokenExpiresAtUtc":"2026-09-10T01:00:00Z"}}',
        );
        client.dio.httpClientAdapter = adapter;

        final response = await AuthRemoteDataSourceImpl(client).login(
          const LoginRequest(
            email: 'traveler@example.com',
            password: 'Password123!',
          ),
          'refreshed-firebase-token',
        );

        expect(adapter.request?.path, '/api/v1/auth/login');
        expect(response.userId, 7);
        expect(response.role, 'Traveler');
        expect(response.status, 'Active');
        expect(response.accessToken, 'app-access-token');
        expect(response.refreshToken, 'app-refresh-token');
        expect(
          adapter.request?.headers['Authorization'],
          'Bearer refreshed-firebase-token',
        );
      },
    );

    test('login preserves the backend MSG_UNVERIFIED 403 contract', () async {
      final client = DioClient(
        config: AppConfig(
          environment: Environment.production,
          apiBaseUrl: Uri.parse('https://api.test.invalid'),
        ),
        secureStorage: MockSecureStorageService(),
      );
      final adapter = RecordingHttpClientAdapter(
        statusCode: 403,
        body:
            '{"success":false,"statusCode":403,"message":"Email has not been verified or account is not active.","errors":{"code":"MSG_UNVERIFIED"}}',
      );
      client.dio.httpClientAdapter = adapter;

      expect(
        () => AuthRemoteDataSourceImpl(client).login(
          const LoginRequest(
            email: 'traveler@example.com',
            password: 'Password123!',
          ),
          'refreshed-firebase-token',
        ),
        throwsA(
          isA<ServerException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having((error) => error.code, 'code', 'MSG_UNVERIFIED'),
        ),
      );
    });

    test('login rejects a malformed successful response', () async {
      final client = DioClient(
        config: AppConfig(
          environment: Environment.production,
          apiBaseUrl: Uri.parse('https://api.test.invalid'),
        ),
        secureStorage: MockSecureStorageService(),
      );
      final adapter = RecordingHttpClientAdapter(
        body:
            '{"success":true,"data":{"userId":7,"role":1,"status":2,"accessToken":"","refreshToken":"app-refresh-token"}}',
      );
      client.dio.httpClientAdapter = adapter;

      expect(
        () => AuthRemoteDataSourceImpl(client).login(
          const LoginRequest(
            email: 'traveler@example.com',
            password: 'Password123!',
          ),
          'refreshed-firebase-token',
        ),
        throwsA(
          isA<ServerException>().having(
            (error) => error.message,
            'message',
            'Invalid authenticated response.',
          ),
        ),
      );
    });
  });
}
