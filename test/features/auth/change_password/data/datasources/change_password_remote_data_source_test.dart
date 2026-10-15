import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/datasources/change_password_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/models/change_password_request.dart';

void main() {
  group('ChangePasswordRemoteDataSource', () {
    late DioClient client;
    late ChangePasswordRemoteDataSource dataSource;

    setUp(() {
      client = DioClient(
        config: AppConfig(
          environment: Environment.development,
          apiBaseUrl: Uri.parse('https://api.test.invalid'),
        ),
        secureStorage: _SeededSecureStorage(),
      );
      dataSource = ChangePasswordRemoteDataSourceImpl(client);
    });

    test(
      'posts exactly currentPassword/newPassword with the stored bearer token attached',
      () async {
        final adapter = _RecordingAdapter(
          body:
              '{"success":true,"data":{"userId":1,"status":"Active","role":"Traveler","accessToken":"new-access","refreshToken":"new-refresh"}}',
        );
        client.dio.httpClientAdapter = adapter;

        final response = await dataSource.changePassword(
          const ChangePasswordRequest(
            currentPassword: 'CurrentPass1!',
            newPassword: 'NewPass2@aaaa',
          ),
        );

        expect(adapter.request?.path, '/api/v1/auth/change-password');
        expect(adapter.request?.method, 'POST');
        expect(adapter.request?.data, {
          'currentPassword': 'CurrentPass1!',
          'newPassword': 'NewPass2@aaaa',
        });
        // No skipAuth extra: the centralized interceptor attaches the token.
        expect(adapter.request?.extra['skipAuth'], isNot(true));
        expect(
          adapter.request?.headers['Authorization'],
          'Bearer seeded-token',
        );
        expect(response.accessToken, 'new-access');
        expect(response.refreshToken, 'new-refresh');
      },
    );

    test('rejects a malformed success envelope', () async {
      client.dio.httpClientAdapter = _RecordingAdapter(
        body: '{"success":true,"data":{"accessToken":""}}',
      );

      await expectLater(
        dataSource.changePassword(
          const ChangePasswordRequest(
            currentPassword: 'CurrentPass1!',
            newPassword: 'NewPass2@aaaa',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('leaves Backend business failures for the Repository', () async {
      client.dio.httpClientAdapter = _RecordingAdapter(
        statusCode: 400,
        body:
            '{"title":"Current password does not match our records.","status":400,"errorCode":"MSG17"}',
      );

      await expectLater(
        dataSource.changePassword(
          const ChangePasswordRequest(
            currentPassword: 'WrongPass1!',
            newPassword: 'NewPass2@aaaa',
          ),
        ),
        throwsA(
          isA<DioException>()
              .having((error) => error.response?.statusCode, 'status', 400)
              .having(
                (error) => error.response?.data,
                'ProblemDetails body',
                containsPair('errorCode', 'MSG17'),
              ),
        ),
      );
    });

    test('leaves transport failures for the Repository', () async {
      client.dio.httpClientAdapter = _FailingAdapter();

      await expectLater(
        dataSource.changePassword(
          const ChangePasswordRequest(
            currentPassword: 'CurrentPass1!',
            newPassword: 'NewPass2@aaaa',
          ),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );
    });
  });
}

final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.body, this.statusCode = 200});

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

final class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _SeededSecureStorage implements SecureStorageService {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async =>
      key == AppConstants.accessTokenKey ? 'seeded-token' : null;

  @override
  Future<void> write(String key, String value) async {}
}
