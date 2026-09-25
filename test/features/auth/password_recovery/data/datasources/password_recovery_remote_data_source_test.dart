import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/datasources/password_recovery_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/confirm_password_reset_request.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/password_reset_request.dart';

void main() {
  group('PasswordRecoveryRemoteDataSource', () {
    late DioClient client;
    late PasswordRecoveryRemoteDataSource dataSource;

    setUp(() {
      client = DioClient(
        config: AppConfig(
          environment: Environment.development,
          apiBaseUrl: Uri.parse('https://api.test.invalid'),
        ),
        secureStorage: _EmptySecureStorage(),
      );
      dataSource = PasswordRecoveryRemoteDataSourceImpl(client);
    });

    test(
      'request posts anonymous email-only body and parses direct DTO',
      () async {
        final adapter = _RecordingAdapter(
          body: '{"message":"Request accepted."}',
        );
        client.dio.httpClientAdapter = adapter;

        final response = await dataSource.requestPasswordReset(
          const PasswordResetRequest(email: 'user@example.com'),
        );

        expect(adapter.request?.path, '/api/v1/auth/password-reset/request');
        expect(adapter.request?.method, 'POST');
        expect(adapter.request?.data, {'email': 'user@example.com'});
        expect(adapter.request?.extra['skipAuth'], isTrue);
        expect(response.message, 'Request accepted.');
      },
    );

    test(
      'confirm posts exact body and preserves a leading-zero code',
      () async {
        final adapter = _RecordingAdapter(
          body: '{"message":"Password reset."}',
        );
        client.dio.httpClientAdapter = adapter;

        await dataSource.confirmPasswordReset(
          const ConfirmPasswordResetRequest(
            email: 'user@example.com',
            code: '012345',
            newPassword: 'NewPassword123!',
          ),
        );

        expect(adapter.request?.path, '/api/v1/auth/password-reset/confirm');
        expect(adapter.request?.method, 'POST');
        expect(adapter.request?.data, {
          'email': 'user@example.com',
          'code': '012345',
          'newPassword': 'NewPassword123!',
        });
        expect(adapter.request?.extra['skipAuth'], isTrue);
      },
    );

    test('rejects a legacy success envelope', () async {
      client.dio.httpClientAdapter = _RecordingAdapter(
        body: '{"success":true,"data":{"message":"Request accepted."}}',
      );

      await expectLater(
        dataSource.requestPasswordReset(
          const PasswordResetRequest(email: 'user@example.com'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('leaves Backend validation responses for the Repository', () async {
      client.dio.httpClientAdapter = _RecordingAdapter(
        statusCode: 400,
        body:
            '{"title":"One or more validation errors occurred.","status":400,"errors":{"Email":["Invalid email format."]}}',
      );

      await expectLater(
        dataSource.requestPasswordReset(
          const PasswordResetRequest(email: 'invalid'),
        ),
        throwsA(
          isA<DioException>()
              .having((error) => error.response?.statusCode, 'status', 400)
              .having(
                (error) => error.response?.data,
                'ProblemDetails body',
                containsPair('errors', {
                  'Email': ['Invalid email format.'],
                }),
              ),
        ),
      );
    });

    test('leaves transport failures for the Repository', () async {
      client.dio.httpClientAdapter = _FailingAdapter();

      await expectLater(
        dataSource.requestPasswordReset(
          const PasswordResetRequest(email: 'user@example.com'),
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

final class _EmptySecureStorage implements SecureStorageService {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
