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
import 'package:trip_mate_mobile/features/auth/data/models/sign_out_request.dart';

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
        '{"success":true,"data":{"userId":1,"role":"Traveler","status":"Active","applicationStatus":null,"accessToken":"app-access-token","refreshToken":"app-refresh-token"}}',
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

/// Simulates transport failures (no response at all) so the friendly-copy
/// mapping for network/timeout can be exercised without a real socket.
final class FailingHttpClientAdapter implements HttpClientAdapter {
  FailingHttpClientAdapter(this.type);

  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: type,
      error: const SocketExceptionStub(),
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Stand-in for a transport-level error object; its [toString] mimics raw
/// platform internals so the assertions can prove nothing leaks to the user.
final class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() =>
      'SocketException: Connection refused (OS Error: errno = 10061), address = localhost, port = 5000';
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

    test('unknown registration response maps to safe generic copy', () async {
      dioClient.dio.httpClientAdapter = RecordingHttpClientAdapter(
        body:
            '{"success":true,"data":{"userId":"internal-type-error","email":42}}',
      );

      await expectLater(
        () => dataSource.registerTraveler(testRequest, 'firebase-token'),
        throwsA(
          isA<ServerException>().having(
            (error) => error.message,
            'message',
            'Something went wrong. Please try again.',
          ),
        ),
      );
    });

    test(
      'structured duplicate registration error keeps its safe mapping',
      () async {
        dioClient.dio.httpClientAdapter = RecordingHttpClientAdapter(
          statusCode: 400,
          body: '{"errors":{"code":"MSG03"}}',
        );

        await expectLater(
          () => dataSource.registerTraveler(testRequest, 'firebase-token'),
          throwsA(
            isA<ServerException>()
                .having((error) => error.code, 'code', 'MSG03')
                .having(
                  (error) => error.message,
                  'message',
                  'An account with this email already exists. Please sign in or use another email.',
                ),
          ),
        );
      },
    );

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

    test('unresolved account state is mapped to support-oriented copy', () async {
      final adapter = RecordingHttpClientAdapter(
        statusCode: 403,
        body:
            '{"errorCode":"auth.account_state_unresolved","detail":"internal eligibility detail"}',
      );
      dioClient.dio.httpClientAdapter = adapter;

      expect(
        () => dataSource.login(
          const LoginRequest(
            email: 'operator@example.com',
            password: 'password',
          ),
        ),
        throwsA(
          isA<ServerException>()
              .having(
                (error) => error.code,
                'code',
                'auth.account_state_unresolved',
              )
              .having(
                (error) => error.message,
                'message',
                'We could not confirm your account status. Please contact TripMate support.',
              ),
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
            'Unable to complete sign in. Please try again.',
          ),
        ),
      );
    });

    // --- B5: every sign-in failure the backend can produce must surface friendly
    // copy and never raw tokens, stack traces or server internals.

    const signInRequest = LoginRequest(
      email: 'traveler@example.com',
      password: 'Password123!',
    );
    const unavailableCopy =
        'TripMate is temporarily unable to process your request. '
        'Please check your connection and try again.';

    Future<void> expectSignInFailure(
      RecordingHttpClientAdapter adapter,
      int statusCode,
      String expectedMessage,
    ) async {
      dioClient.dio.httpClientAdapter = adapter;
      await expectLater(
        () => dataSource.login(signInRequest),
        throwsA(
          isA<AppException>()
              .having((error) => error.message, 'message', expectedMessage)
              .having(
                (error) => error is ServerException ? error.statusCode : null,
                'statusCode',
                statusCode,
              ),
        ),
      );
    }

    test('invalid credentials map to a generic non-disclosing message', () async {
      await expectSignInFailure(
        RecordingHttpClientAdapter(
          statusCode: 401,
          body:
              '{"errorCode":"auth.invalid_credentials","detail":"password mismatch for user 42"}',
        ),
        401,
        'Invalid email or password. Please try again.',
      );
    });

    test('unknown backend 400 validation detail is never displayed', () async {
      await expectSignInFailure(
        RecordingHttpClientAdapter(
          statusCode: 400,
          body:
              '{"errors":{"code":"internal.validation","email":["System.NullReferenceException at AuthController.Login"]}}',
        ),
        400,
        'Unable to complete this request. Please try again.',
      );
    });

    test(
      'account without a password maps to the same generic message',
      () async {
        await expectSignInFailure(
          RecordingHttpClientAdapter(
            statusCode: 401,
            body: '{"errorCode":"auth.invalid_credentials"}',
          ),
          401,
          'Invalid email or password. Please try again.',
        );
      },
    );

    test('locked account maps to the support-oriented message', () async {
      await expectSignInFailure(
        RecordingHttpClientAdapter(
          statusCode: 403,
          body:
              '{"errorCode":"auth.account_locked","detail":"LockReason=abuse"}',
        ),
        403,
        'Your account is locked. Please contact support.',
      );
    });

    test('inactive account maps to the support-oriented message', () async {
      await expectSignInFailure(
        RecordingHttpClientAdapter(
          statusCode: 403,
          body: '{"errorCode":"auth.account_inactive"}',
        ),
        403,
        'Your account is inactive. Please contact support.',
      );
    });

    test('unverified email maps to the verification prompt', () async {
      await expectSignInFailure(
        RecordingHttpClientAdapter(
          statusCode: 403,
          body:
              '{"errorCode":"MSG_EMAIL_NOT_VERIFIED","detail":"Firebase claim"}',
        ),
        403,
        'Please verify your email before continuing.',
      );
    });

    test('administrator Google sign-in maps to the Web-only message', () async {
      await expectSignInFailure(
        RecordingHttpClientAdapter(
          statusCode: 403,
          body:
              '{"errorCode":"auth.admin_google_sign_in_disabled","detail":"BR-18 internal rule"}',
        ),
        403,
        'Administrator accounts are supported on Web only.',
      );
    });

    test(
      'administrator Mobile password refusal maps to the Web-only message',
      () async {
        await expectSignInFailure(
          RecordingHttpClientAdapter(
            statusCode: 403,
            body:
                '{"errorCode":"auth.admin_mobile_sign_in_disabled","detail":"internal mobile gate"}',
          ),
          403,
          'Administrator accounts are supported on Web only.',
        );
      },
    );

    test('server 5xx maps to friendly copy without leaking internals', () async {
      await expectSignInFailure(
        RecordingHttpClientAdapter(
          statusCode: 500,
          body:
              '{"detail":"System.NullReferenceException: Object reference not set at TripMate.Api.Controllers.V1.AuthController.Login"}',
        ),
        500,
        unavailableCopy,
      );
    });

    for (final type in <DioExceptionType>[
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test(
        'transport failure $type maps to a recoverable network message',
        () async {
          dioClient.dio.httpClientAdapter = FailingHttpClientAdapter(type);
          await expectLater(
            () => dataSource.login(signInRequest),
            throwsA(
              isA<NetworkException>().having(
                (error) => error.message,
                'message',
                unavailableCopy,
              ),
            ),
          );
        },
      );
    }

    // --- UC-05: sign-out request model + remote data-source contract.

    group('logout', () {
      RecordingHttpClientAdapter logoutAdapter({
        int statusCode = 200,
        String body =
            '{"success":true,"statusCode":200,"message":"Signed out successfully.","data":true,"errors":null}',
      }) {
        final adapter = RecordingHttpClientAdapter(
          statusCode: statusCode,
          body: body,
        );
        dioClient.dio.httpClientAdapter = adapter;
        return adapter;
      }

      test('serialises a refresh token value', () {
        expect(const SignOutRequest(refreshToken: 'refresh-value').toJson(), {
          'refreshToken': 'refresh-value',
        });
      });

      test('serialises an explicit null refresh token', () {
        expect(const SignOutRequest(refreshToken: null).toJson(), {
          'refreshToken': null,
        });
      });

      test(
        'posts the raw refresh token to the approved logout route',
        () async {
          final adapter = logoutAdapter();
          const rawToken = 'raw%2F+token/with=padding';

          await dataSource.logout(rawToken);

          expect(adapter.request?.path, '/api/v1/auth/logout');
          expect(adapter.request?.method, 'POST');
          expect(adapter.request?.data, {'refreshToken': rawToken});
        },
      );

      test('a missing token still sends an explicit JSON body', () async {
        final adapter = logoutAdapter();

        await dataSource.logout(null);

        expect(adapter.request?.data, isNotNull);
        expect(adapter.request?.data, {'refreshToken': null});
      });

      test('accepts a valid success envelope', () async {
        logoutAdapter();

        await expectLater(dataSource.logout('refresh-value'), completes);
      });

      test(
        'rejects a malformed 200 response as a safe server failure',
        () async {
          logoutAdapter(body: '{"message":"Signed out successfully."}');

          await expectLater(
            () => dataSource.logout('refresh-value'),
            throwsA(
              isA<ServerException>().having(
                (error) => error.message,
                'message',
                'Something went wrong. Please try again.',
              ),
            ),
          );
        },
      );

      test('a 500 maps through the existing server error mapping', () async {
        final adapter = RecordingHttpClientAdapter(
          statusCode: 500,
          body: '{"title":"A system error occurred.","status":500}',
        );
        dioClient.dio.httpClientAdapter = adapter;

        await expectLater(
          () => dataSource.logout('refresh-value'),
          throwsA(
            isA<ServerException>()
                .having((error) => error.statusCode, 'statusCode', 500)
                .having((error) => error.message, 'message', unavailableCopy),
          ),
        );
      });

      test(
        'a transport failure maps to the recoverable network copy',
        () async {
          dioClient.dio.httpClientAdapter = FailingHttpClientAdapter(
            DioExceptionType.connectionError,
          );

          await expectLater(
            () => dataSource.logout('refresh-value'),
            throwsA(
              isA<NetworkException>().having(
                (error) => error.message,
                'message',
                unavailableCopy,
              ),
            ),
          );
        },
      );

      test('adds no logout-specific Authorization requirement', () async {
        final adapter = logoutAdapter();

        await dataSource.logout('refresh-value');

        // Any Bearer would come only from the shared interceptor when secure
        // storage holds an access token; logout must not attach or require one.
        expect(adapter.request?.headers.containsKey('Authorization'), isFalse);
      });
    });

    group('logoutAll', () {
      RecordingHttpClientAdapter logoutAllAdapter({
        int statusCode = 200,
        String body =
            '{"success":true,"statusCode":200,"message":"Signed out from all devices.","data":true,"errors":null}',
      }) {
        final adapter = RecordingHttpClientAdapter(
          statusCode: statusCode,
          body: body,
        );
        dioClient.dio.httpClientAdapter = adapter;
        return adapter;
      }

      test('posts the unmodified raw refresh token to logout-all', () async {
        final adapter = logoutAllAdapter();
        const rawToken = 'raw%2F+token/with=padding';

        await dataSource.logoutAll(rawToken);

        expect(adapter.request?.path, '/api/v1/auth/logout-all');
        expect(adapter.request?.method, 'POST');
        expect(adapter.request?.data, {'refreshToken': rawToken});
      });

      test('accepts only a valid success envelope', () async {
        logoutAllAdapter();

        await expectLater(dataSource.logoutAll('refresh-value'), completes);
      });

      test('maps a 500 to safe copy without leaking internal detail', () async {
        logoutAllAdapter(
          statusCode: 500,
          body:
              '{"title":"SqlException: database tripmate_prod failed","status":500}',
        );

        await expectLater(
          () => dataSource.logoutAll('refresh-value'),
          throwsA(
            isA<ServerException>()
                .having((error) => error.statusCode, 'statusCode', 500)
                .having((error) => error.message, 'message', unavailableCopy)
                .having(
                  (error) => error.message,
                  'does not leak internal detail',
                  isNot(contains('SqlException')),
                ),
          ),
        );
      });
    });
  });
}
