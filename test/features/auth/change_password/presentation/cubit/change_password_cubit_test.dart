import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/change_password/domain/repositories/change_password_repository.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_cubit.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_state.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';

void main() {
  group('ChangePasswordCubit', () {
    test(
      'success persists exactly the new access and refresh tokens once',
      () async {
        final storage = _MemoryStorage()
          ..values[AppConstants.accessTokenKey] = 'old-access'
          ..values[AppConstants.refreshTokenKey] = 'old-refresh'
          ..values[AppConstants.sessionRoleKey] = 'traveler';
        final repository = _FakeRepository(
          session: const AuthSession(
            userId: 1,
            status: 'Active',
            accessToken: 'new-access',
            refreshToken: 'new-refresh',
            role: 'Traveler',
          ),
        );
        final cubit = ChangePasswordCubit(repository, storage);
        addTearDown(cubit.close);

        final result = await cubit.submit(
          currentPassword: 'CurrentPass1!',
          newPassword: 'NewPass2@aaaa',
        );

        expect(result, isTrue);
        expect(cubit.state.status, ChangePasswordStatus.success);
        expect(storage.values[AppConstants.accessTokenKey], 'new-access');
        expect(storage.values[AppConstants.refreshTokenKey], 'new-refresh');
        // Role is untouched by this flow.
        expect(storage.values[AppConstants.sessionRoleKey], 'traveler');
        expect(storage.writeCount, 2);
      },
    );

    test(
      'a malformed/failed response leaves the previous session intact',
      () async {
        final storage = _MemoryStorage()
          ..values[AppConstants.accessTokenKey] = 'old-access'
          ..values[AppConstants.refreshTokenKey] = 'old-refresh';
        final repository = _FakeRepository(
          error: const IncorrectCurrentPasswordFailure(),
        );
        final cubit = ChangePasswordCubit(repository, storage);
        addTearDown(cubit.close);

        final result = await cubit.submit(
          currentPassword: 'WrongPass1!',
          newPassword: 'NewPass2@aaaa',
        );

        expect(result, isFalse);
        expect(storage.values[AppConstants.accessTokenKey], 'old-access');
        expect(storage.values[AppConstants.refreshTokenKey], 'old-refresh');
        expect(storage.writeCount, 0);
      },
    );

    test(
      'targets Current Password for IncorrectCurrentPasswordFailure',
      () async {
        final repository = _FakeRepository(
          error: const IncorrectCurrentPasswordFailure(),
        );
        final cubit = ChangePasswordCubit(repository, _MemoryStorage());
        addTearDown(cubit.close);

        await cubit.submit(
          currentPassword: 'WrongPass1!',
          newPassword: 'NewPass2@aaaa',
        );

        expect(cubit.state.status, ChangePasswordStatus.failure);
        expect(cubit.state.fieldErrors['currentPassword'], isNotEmpty);
      },
    );

    test('targets New Password for a ValidationFailure (MSG05)', () async {
      final repository = _FakeRepository(
        error: const ValidationFailure(
          'New password must be different from the current password.',
          fieldErrors: {
            'newPassword': [
              'New password must be different from the current password.',
            ],
          },
        ),
      );
      final cubit = ChangePasswordCubit(repository, _MemoryStorage());
      addTearDown(cubit.close);

      await cubit.submit(
        currentPassword: 'CurrentPass1!',
        newPassword: 'CurrentPass1!',
      );

      expect(cubit.state.status, ChangePasswordStatus.failure);
      expect(cubit.state.fieldErrors['newPassword'], isNotEmpty);
    });

    test(
      'a 403 local-password-unavailable failure is a generic message',
      () async {
        final repository = _FakeRepository(
          error: const LocalPasswordUnavailableFailure(),
        );
        final cubit = ChangePasswordCubit(repository, _MemoryStorage());
        addTearDown(cubit.close);

        await cubit.submit(
          currentPassword: 'Anything1!',
          newPassword: 'NewPass2@aaaa',
        );

        expect(cubit.state.status, ChangePasswordStatus.failure);
        expect(cubit.state.fieldErrors, isEmpty);
        expect(cubit.state.errorMessage, isNotNull);
      },
    );

    test('a duplicate submit while busy is ignored', () async {
      final repository = _SlowFakeRepository();
      final cubit = ChangePasswordCubit(repository, _MemoryStorage());
      addTearDown(cubit.close);

      final first = cubit.submit(
        currentPassword: 'CurrentPass1!',
        newPassword: 'NewPass2@aaaa',
      );
      final second = await cubit.submit(
        currentPassword: 'CurrentPass1!',
        newPassword: 'NewPass2@aaaa',
      );

      expect(second, isFalse);
      await first;
    });

    test('clearFieldError removes only the named field', () async {
      final repository = _FakeRepository(
        error: const IncorrectCurrentPasswordFailure(),
      );
      final cubit = ChangePasswordCubit(repository, _MemoryStorage());
      addTearDown(cubit.close);
      await cubit.submit(
        currentPassword: 'WrongPass1!',
        newPassword: 'NewPass2@aaaa',
      );
      expect(cubit.state.fieldErrors.containsKey('currentPassword'), isTrue);

      cubit.clearFieldError('currentPassword');

      expect(cubit.state.fieldErrors.containsKey('currentPassword'), isFalse);
    });
  });
}

final class _MemoryStorage implements SecureStorageService {
  final values = <String, String>{};
  var writeCount = 0;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    values[key] = value;
  }
}

final class _FakeRepository implements ChangePasswordRepository {
  _FakeRepository({this.session, this.error});

  final AuthSession? session;
  final Object? error;

  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (error != null) throw error!;
    return session!;
  }
}

final class _SlowFakeRepository implements ChangePasswordRepository {
  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return Future<AuthSession>.delayed(
      const Duration(milliseconds: 50),
      () => const AuthSession(
        userId: 1,
        status: 'Active',
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        role: 'Traveler',
      ),
    );
  }
}
