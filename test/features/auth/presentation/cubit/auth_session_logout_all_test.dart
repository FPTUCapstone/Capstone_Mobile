import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

const _rawRefreshToken = 'raw%2F+token/with=padding';

void main() {
  group('AuthSessionCubit logout-all', () {
    test(
      'keeps the authenticated session while logout-all is pending',
      () async {
        final completer = Completer<void>();
        final repository = _FakeAuthRepository(logoutAllCompleter: completer);
        final storage = _authenticatedStorage();
        final cubit = await _authenticatedCubit(repository, storage);
        addTearDown(cubit.close);

        final pending = cubit.signOutAllDevices();
        await pumpEventQueue();

        expect(repository.logoutAllTokens, [_rawRefreshToken]);
        expect(cubit.state.isAuthenticated, isTrue);
        expect(cubit.state.operation, AuthSessionOperation.signOut);
        expect(storage.values[AppConstants.refreshTokenKey], _rawRefreshToken);

        completer.complete();
        expect(await pending, isTrue);
        expect(storage.values, isEmpty);
        expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      },
    );

    test(
      'returns false without calling backend when the token is missing or blank',
      () async {
        for (final token in <String?>[null, '', '   ']) {
          final repository = _FakeAuthRepository();
          final storage = _authenticatedStorage();
          final cubit = await _authenticatedCubit(repository, storage);
          if (token == null) {
            storage.values.remove(AppConstants.refreshTokenKey);
          } else {
            storage.values[AppConstants.refreshTokenKey] = token;
          }
          addTearDown(cubit.close);

          expect(await cubit.signOutAllDevices(), isFalse);
          expect(repository.logoutAllTokens, isEmpty);
          expect(cubit.state.isAuthenticated, isTrue);
        }
      },
    );

    test(
      'backend failure preserves credentials and authenticated state',
      () async {
        final repository = _FakeAuthRepository(
          logoutAllError: const ServerException(
            'SqlException: tripmate_prod connection failed',
            'MSG127',
            500,
          ),
        );
        final storage = _authenticatedStorage();
        final cubit = await _authenticatedCubit(repository, storage);
        addTearDown(cubit.close);

        expect(await cubit.signOutAllDevices(), isFalse);

        expect(repository.logoutAllTokens, [_rawRefreshToken]);
        expect(storage.values[AppConstants.refreshTokenKey], _rawRefreshToken);
        expect(storage.values[AppConstants.accessTokenKey], 'access-token');
        expect(cubit.state.isAuthenticated, isTrue);
        expect(cubit.state.operation, AuthSessionOperation.none);
        expect(
          cubit.state.errorMessage,
          AuthSessionCubit.signOutFailureMessage,
        );
        expect(cubit.state.errorMessage, isNot(contains('SqlException')));
        expect(cubit.state.errorMessage, isNot(contains('MSG127')));
      },
    );

    test(
      'provider failure after backend success remains a successful logout-all',
      () async {
        final repository = _FakeAuthRepository();
        final storage = _authenticatedStorage();
        final provider = _FakeIdentityService(
          signOutError: StateError('provider failed'),
        );
        final cubit = await _authenticatedCubit(
          repository,
          storage,
          provider: provider,
        );
        addTearDown(cubit.close);

        expect(await cubit.signOutAllDevices(), isTrue);

        expect(provider.signOutCalls, 1);
        expect(storage.values, isEmpty);
        expect(cubit.state.status, AuthSessionStatus.unauthenticated);
        expect(cubit.state.errorMessage, isNull);
      },
    );

    test(
      'current logout backend failure no longer clears local session',
      () async {
        final repository = _FakeAuthRepository(
          logoutError: const ServerException(
            'raw database detail',
            'MSG127',
            500,
          ),
        );
        final storage = _authenticatedStorage();
        final cubit = await _authenticatedCubit(repository, storage);
        addTearDown(cubit.close);

        await cubit.signOut();

        expect(storage.values[AppConstants.refreshTokenKey], _rawRefreshToken);
        expect(cubit.state.isAuthenticated, isTrue);
        expect(
          cubit.state.errorMessage,
          AuthSessionCubit.signOutFailureMessage,
        );
      },
    );
  });
}

Future<AuthSessionCubit> _authenticatedCubit(
  _FakeAuthRepository repository,
  _MemoryStorage storage, {
  _FakeIdentityService? provider,
}) async {
  final cubit = AuthSessionCubit(repository, storage, provider);
  await cubit.restoreSession();
  expect(cubit.state.isAuthenticated, isTrue);
  return cubit;
}

_MemoryStorage _authenticatedStorage() => _MemoryStorage({
  AppConstants.accessTokenKey: 'access-token',
  AppConstants.refreshTokenKey: _rawRefreshToken,
  AppConstants.sessionRoleKey: 'traveler',
  AppConstants.keepSignedInKey: 'true',
});

final class _FakeAuthRepository implements AuthRepository, LogoutAllRepository {
  _FakeAuthRepository({
    this.logoutError,
    this.logoutAllError,
    this.logoutAllCompleter,
  });

  final Object? logoutError;
  final Object? logoutAllError;
  final Completer<void>? logoutAllCompleter;
  final logoutAllTokens = <String>[];

  @override
  Future<void> logout(String? refreshToken) async {
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<void> logoutAll(String refreshToken) async {
    logoutAllTokens.add(refreshToken);
    if (logoutAllCompleter != null) await logoutAllCompleter!.future;
    if (logoutAllError != null) throw logoutAllError!;
  }

  @override
  Future<AuthSession> googleAuth(String firebaseIdToken) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> login(
    AuthCredentials credentials, [
    String? firebaseIdToken,
  ]) => throw UnimplementedError();

  @override
  Future<TravelerRegistrationResult> registerTraveler(
    TravelerRegistration registration,
    String firebaseIdToken,
  ) => throw UnimplementedError();

  @override
  Future<AuthSession> verifyEmail(String firebaseIdToken) =>
      throw UnimplementedError();
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

final class _FakeIdentityService implements AuthIdentityService {
  _FakeIdentityService({this.signOutError});

  final Object? signOutError;
  var signOutCalls = 0;

  @override
  Future<String?> get currentUserEmail async => null;

  @override
  Future<bool> get isEmailVerified async => true;

  @override
  Future<String?> refreshIdToken() async => null;

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<String> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    if (signOutError != null) throw signOutError!;
  }
}
