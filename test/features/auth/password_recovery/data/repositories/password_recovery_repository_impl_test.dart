import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/datasources/password_recovery_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/confirm_password_reset_request.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/password_reset_message_dto.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/models/password_reset_request.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/data/repositories/password_recovery_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/domain/failures/password_recovery_failures.dart';

void main() {
  group('PasswordRecoveryRepositoryImpl', () {
    test('forwards request and confirm values exactly', () async {
      final remote = _FakeRemoteDataSource();
      final repository = PasswordRecoveryRepositoryImpl(remote);

      await repository.requestPasswordReset('user@example.com');
      await repository.confirmPasswordReset(
        email: 'user@example.com',
        code: '012345',
        newPassword: 'NewPassword123!',
      );

      expect(remote.request?.toJson(), {'email': 'user@example.com'});
      expect(remote.confirm?.toJson(), {
        'email': 'user@example.com',
        'code': '012345',
        'newPassword': 'NewPassword123!',
      });
    });

    test(
      'normalizes the Backend ValidationProblemDetails field errors',
      () async {
        final remote = _FakeRemoteDataSource(
          error: _dioError(400, const {
            'title': 'One or more validation errors occurred.',
            'status': 400,
            'errors': {
              'Email': ['Invalid email format.'],
              'NewPassword': ['Password must be at least 8 characters.'],
            },
          }),
        );
        final repository = PasswordRecoveryRepositoryImpl(remote);

        await expectLater(
          repository.requestPasswordReset('invalid'),
          throwsA(
            isA<ValidationFailure>()
                .having((failure) => failure.fieldErrors['email'], 'email', [
                  'Invalid email format.',
                ])
                .having(
                  (failure) => failure.fieldErrors['newPassword'],
                  'password',
                  ['Password must be at least 8 characters.'],
                ),
          ),
        );
      },
    );

    test(
      'keeps every supported MSG14 envelope generic and reset-specific',
      () async {
        final envelopes = <Map<String, Object>>[
          const {'errorCode': 'MSG14'},
          const {'code': 'MSG14'},
          const {
            'extensions': {'errorCode': 'MSG14'},
          },
        ];

        for (final envelope in envelopes) {
          final repository = PasswordRecoveryRepositoryImpl(
            _FakeRemoteDataSource(error: _dioError(400, envelope)),
          );

          await expectLater(
            repository.confirmPasswordReset(
              email: 'user@example.com',
              code: '000000',
              newPassword: 'NewPassword123!',
            ),
            throwsA(
              isA<InvalidResetCredentialFailure>().having(
                (failure) => failure.message,
                'message',
                'The reset code is invalid or no longer usable. Request a new code and try again.',
              ),
            ),
          );
        }
      },
    );

    test('maps rate limit, system, and network failures safely', () async {
      final cases = <(Object, Type, String)>[
        (
          _dioError(429, const {'title': 'raw limiter detail'}),
          RateLimitFailure,
          'Too many reset attempts. Please wait and try again.',
        ),
        (
          _dioError(400, const {
            'code': 'MSG127',
            'detail': 'raw stack detail',
          }),
          ServerFailure,
          'Something went wrong. Please try again later.',
        ),
        (
          DioException(
            requestOptions: RequestOptions(path: '/request'),
            type: DioExceptionType.connectionError,
          ),
          NetworkFailure,
          'Please check your connection and try again.',
        ),
      ];

      for (final testCase in cases) {
        final repository = PasswordRecoveryRepositoryImpl(
          _FakeRemoteDataSource(error: testCase.$1),
        );

        await expectLater(
          repository.requestPasswordReset('user@example.com'),
          throwsA(
            isA<Failure>()
                .having((failure) => failure.runtimeType, 'type', testCase.$2)
                .having((failure) => failure.message, 'message', testCase.$3),
          ),
        );
      }
    });
  });
}

final class _FakeRemoteDataSource implements PasswordRecoveryRemoteDataSource {
  _FakeRemoteDataSource({this.error});

  final Object? error;
  PasswordResetRequest? request;
  ConfirmPasswordResetRequest? confirm;

  @override
  Future<PasswordResetMessageDto> requestPasswordReset(
    PasswordResetRequest request,
  ) async {
    this.request = request;
    if (error != null) throw error!;
    return const PasswordResetMessageDto(message: 'Request accepted.');
  }

  @override
  Future<PasswordResetMessageDto> confirmPasswordReset(
    ConfirmPasswordResetRequest request,
  ) async {
    confirm = request;
    if (error != null) throw error!;
    return const PasswordResetMessageDto(message: 'Password reset.');
  }
}

DioException _dioError(int statusCode, Map<String, Object> data) {
  final request = RequestOptions(path: '/api/v1/auth/password-reset/request');
  return DioException.badResponse(
    statusCode: statusCode,
    requestOptions: request,
    response: Response<Object>(
      requestOptions: request,
      statusCode: statusCode,
      data: data,
    ),
  );
}
