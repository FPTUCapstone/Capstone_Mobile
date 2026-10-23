import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/datasources/change_password_remote_data_source.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/models/change_password_request.dart';
import 'package:trip_mate_mobile/features/auth/change_password/data/repositories/change_password_repository_impl.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';

void main() {
  group('ChangePasswordRepositoryImpl', () {
    test('forwards the exact request and maps a successful session', () async {
      final remote = _FakeRemoteDataSource(
        response: const SessionResponseDto(
          userId: 1,
          status: 'Active',
          role: 'Traveler',
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
        ),
      );
      final repository = ChangePasswordRepositoryImpl(remote);

      final session = await repository.changePassword(
        currentPassword: 'CurrentPass1!',
        newPassword: 'NewPass2@aaaa',
      );

      expect(remote.request?.toJson(), {
        'currentPassword': 'CurrentPass1!',
        'newPassword': 'NewPass2@aaaa',
      });
      expect(session.accessToken, 'new-access');
      expect(session.refreshToken, 'new-refresh');
    });

    test('maps MSG17 to IncorrectCurrentPasswordFailure', () async {
      final remote = _FakeRemoteDataSource(
        error: _dioError(400, const {
          'title': 'Current password does not match our records.',
          'status': 400,
          'errorCode': 'MSG17',
        }),
      );
      final repository = ChangePasswordRepositoryImpl(remote);

      await expectLater(
        repository.changePassword(
          currentPassword: 'WrongPass1!',
          newPassword: 'NewPass2@aaaa',
        ),
        throwsA(isA<IncorrectCurrentPasswordFailure>()),
      );
    });

    test(
      'maps MSG05 to a newPassword-field ValidationFailure using the safe title',
      () async {
        final remote = _FakeRemoteDataSource(
          error: _dioError(400, const {
            'title':
                'New password must be different from the current password.',
            'status': 400,
            'errorCode': 'MSG05',
          }),
        );
        final repository = ChangePasswordRepositoryImpl(remote);

        await expectLater(
          repository.changePassword(
            currentPassword: 'CurrentPass1!',
            newPassword: 'CurrentPass1!',
          ),
          throwsA(
            isA<ValidationFailure>()
                .having(
                  (failure) => failure.message,
                  'message',
                  'New password must be different from the current password.',
                )
                .having(
                  (failure) => failure.fieldErrors['newPassword'],
                  'newPassword field',
                  ['New password must be different from the current password.'],
                ),
          ),
        );
      },
    );

    test(
      'maps the 403 local-password-unavailable code to a dedicated failure',
      () async {
        final remote = _FakeRemoteDataSource(
          error: _dioError(403, const {
            'title': 'A local password is not available for this account.',
            'status': 403,
            'errorCode': 'auth.local_password_unavailable',
          }),
        );
        final repository = ChangePasswordRepositoryImpl(remote);

        await expectLater(
          repository.changePassword(
            currentPassword: 'Anything1!',
            newPassword: 'NewPass2@aaaa',
          ),
          throwsA(isA<LocalPasswordUnavailableFailure>()),
        );
      },
    );

    test('maps a generic 401 to the shared AuthenticationFailure', () async {
      final remote = _FakeRemoteDataSource(error: _dioError(401, null));
      final repository = ChangePasswordRepositoryImpl(remote);

      await expectLater(
        repository.changePassword(
          currentPassword: 'CurrentPass1!',
          newPassword: 'NewPass2@aaaa',
        ),
        throwsA(isA<AuthenticationFailure>()),
      );
    });

    test('maps MSG127 to a safe generic ServerFailure', () async {
      final remote = _FakeRemoteDataSource(
        error: _dioError(503, const {'errorCode': 'MSG127'}),
      );
      final repository = ChangePasswordRepositoryImpl(remote);

      await expectLater(
        repository.changePassword(
          currentPassword: 'CurrentPass1!',
          newPassword: 'NewPass2@aaaa',
        ),
        throwsA(isA<ServerFailure>()),
      );
    });

    test('maps a transport failure to NetworkFailure', () async {
      final remote = _FakeRemoteDataSource(
        error: DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/change-password'),
          type: DioExceptionType.connectionError,
        ),
      );
      final repository = ChangePasswordRepositoryImpl(remote);

      await expectLater(
        repository.changePassword(
          currentPassword: 'CurrentPass1!',
          newPassword: 'NewPass2@aaaa',
        ),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}

DioException _dioError(int statusCode, Map<String, dynamic>? data) =>
    DioException(
      requestOptions: RequestOptions(path: '/api/v1/auth/change-password'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/v1/auth/change-password'),
        statusCode: statusCode,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );

final class _FakeRemoteDataSource implements ChangePasswordRemoteDataSource {
  _FakeRemoteDataSource({this.response, this.error});

  final SessionResponseDto? response;
  final Object? error;
  ChangePasswordRequest? request;

  @override
  Future<SessionResponseDto> changePassword(
    ChangePasswordRequest request,
  ) async {
    this.request = request;
    if (error != null) throw error!;
    return response!;
  }
}
