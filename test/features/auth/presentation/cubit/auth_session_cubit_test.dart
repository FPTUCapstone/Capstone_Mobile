import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_auth_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

void main() {
  group('AuthSessionCubit', () {
    late FakeAuthRepository repository;
    late FakeSecureStorageService storage;
    late FakeFirebaseAuthService firebase;

    test('starts unauthenticated', () {
      final cubit = AuthSessionCubit();
      addTearDown(cubit.close);

      expect(cubit.state, const AuthSessionState.unauthenticated());
    });

    blocTest<AuthSessionCubit, AuthSessionState>(
      'rejects an unverified Firebase user without calling backend login',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          signInError: const AuthenticationException(
            'Please verify your email before continuing.',
          ),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'traveler@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure('Please verify your email before continuing.'),
      ],
      verify: (_) {
        expect(repository.loginCalls, 0);
        expect(storage.values, isEmpty);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'maps invalid Firebase credentials to a safe actionable error',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          signInError: FirebaseAuthException(code: 'invalid-credential'),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'traveler@example.com', password: 'wrong'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'Invalid email or password. Please try again.',
        ),
      ],
      verify: (_) {
        expect(repository.loginCalls, 0);
        expect(storage.values, isEmpty);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'maps a Firebase network failure to the existing connection error',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          signInError: FirebaseAuthException(code: 'network-request-failed'),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'traveler@example.com', password: 'not-logged'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
      ],
      verify: (_) {
        expect(repository.loginCalls, 0);
        expect(storage.values, isEmpty);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'verified Firebase user synchronizes an unverified backend account and signs in',
      build: () {
        repository = FakeAuthRepository(
          loginError: const ServerException(
            'Please verify your email before signing in.',
            'MSG_UNVERIFIED',
            403,
          ),
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          signInToken: 'refreshed-firebase-token',
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'traveler@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.authenticated(UserRole.traveler),
      ],
      verify: (_) {
        expect(repository.loginFirebaseIdToken, 'refreshed-firebase-token');
        expect(repository.loginCalls, 1);
        expect(
          repository.verifyEmailFirebaseIdToken,
          'refreshed-firebase-token',
        );
        expect(repository.verifyEmailCalls, 1);
        expect(firebase.signOutCalls, 0);
        expect(storage.values, {
          AppConstants.accessTokenKey: 'backend-access-token',
          AppConstants.refreshTokenKey: 'backend-refresh-token',
          AppConstants.sessionRoleKey: 'traveler',
          AppConstants.keepSignedInKey: 'true',
        });
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'resends the verification email and emits safe success feedback',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService();
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.resendVerificationEmail(),
      expect: () => const [
        AuthSessionState.loading(
          operation: AuthSessionOperation.resendVerificationEmail,
        ),
        AuthSessionState.verificationEmailSent(
          'A fresh verification link has been sent to your email address.',
        ),
      ],
      verify: (_) => expect(firebase.sendEmailVerificationCalls, 1),
    );

    test(
      'blocks a second verification action while resend is in progress',
      () async {
        final resendCompleter = Completer<void>();
        firebase = FakeFirebaseAuthService(
          sendEmailVerificationCompleter: resendCompleter,
        );
        final cubit = AuthSessionCubit(
          FakeAuthRepository(),
          FakeSecureStorageService(),
          firebase,
        );
        addTearDown(cubit.close);

        final firstRequest = cubit.resendVerificationEmail();
        final secondRequest = cubit.resendVerificationEmail();

        expect(firebase.sendEmailVerificationCalls, 1);
        resendCompleter.complete();
        await Future.wait([firstRequest, secondRequest]);
      },
    );

    test(
      'returns the current Firebase email for in-memory route fallback',
      () async {
        firebase = FakeFirebaseAuthService(
          firebaseEmail: 'traveler@example.com',
        );
        final cubit = AuthSessionCubit(
          FakeAuthRepository(),
          FakeSecureStorageService(),
          firebase,
        );
        addTearDown(cubit.close);

        expect(await cubit.currentFirebaseUserEmail, 'traveler@example.com');
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'maps Firebase resend rate limiting safely and requests cooldown',
      build: () {
        firebase = FakeFirebaseAuthService(
          sendEmailVerificationError: FirebaseAuthException(
            code: 'too-many-requests',
          ),
        );
        return AuthSessionCubit(
          FakeAuthRepository(),
          FakeSecureStorageService(),
          firebase,
        );
      },
      act: (cubit) => cubit.resendVerificationEmail(),
      expect: () => const [
        AuthSessionState.loading(
          operation: AuthSessionOperation.resendVerificationEmail,
        ),
        AuthSessionState.failure(
          'Too many resend attempts. Please wait a few minutes before trying again.',
          startResendCooldown: true,
        ),
      ],
    );

    for (final scenario in [
      (
        name: 'missing Firebase session',
        code: 'no-current-user',
        message:
            'Your verification session has expired. Please sign in to request a new verification link.',
      ),
      (
        name: 'Firebase network failure',
        code: 'network-request-failed',
        message:
            'TripMate is temporarily unable to process your request. Please check your connection and try again.',
      ),
      (
        name: 'unknown Firebase failure',
        code: 'unexpected',
        message:
            'Unable to send verification email. Please try again later or sign in.',
      ),
    ]) {
      blocTest<AuthSessionCubit, AuthSessionState>(
        'maps ${scenario.name} safely while resending',
        build: () {
          firebase = FakeFirebaseAuthService(
            sendEmailVerificationError: FirebaseAuthException(
              code: scenario.code,
            ),
          );
          return AuthSessionCubit(
            FakeAuthRepository(),
            FakeSecureStorageService(),
            firebase,
          );
        },
        act: (cubit) => cubit.resendVerificationEmail(),
        expect: () => [
          const AuthSessionState.loading(
            operation: AuthSessionOperation.resendVerificationEmail,
          ),
          AuthSessionState.failure(scenario.message),
        ],
      );
    }

    blocTest<AuthSessionCubit, AuthSessionState>(
      'keeps an unverified Firebase user on the verification flow',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(emailVerified: false);
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.verifyEmail(),
      expect: () => const [
        AuthSessionState.loading(operation: AuthSessionOperation.verifyEmail),
        AuthSessionState.failure('Please verify your email before continuing.'),
      ],
      verify: (_) {
        expect(repository.verifyEmailCalls, 0);
        expect(storage.values, isEmpty);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'maps a missing Firebase session safely while verifying',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          refreshError: FirebaseAuthException(code: 'no-current-user'),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.verifyEmail(),
      expect: () => const [
        AuthSessionState.loading(operation: AuthSessionOperation.verifyEmail),
        AuthSessionState.failure(
          'Your verification session has expired. Please sign in and request a new verification link.',
        ),
      ],
      verify: (_) {
        expect(repository.verifyEmailCalls, 0);
        expect(storage.values, isEmpty);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'maps a Firebase network failure safely while verifying',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          refreshError: FirebaseAuthException(code: 'network-request-failed'),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.verifyEmail(),
      expect: () => const [
        AuthSessionState.loading(operation: AuthSessionOperation.verifyEmail),
        AuthSessionState.failure(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
      ],
      verify: (_) {
        expect(repository.verifyEmailCalls, 0);
        expect(storage.values, isEmpty);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'verifies with the refreshed Firebase token then persists the Traveler session',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          refreshToken: 'refreshed-firebase-token',
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.verifyEmail(),
      expect: () => const [
        AuthSessionState.loading(operation: AuthSessionOperation.verifyEmail),
        AuthSessionState.authenticated(UserRole.traveler),
      ],
      verify: (_) {
        expect(firebase.refreshIdTokenCalls, 1);
        expect(
          repository.verifyEmailFirebaseIdToken,
          'refreshed-firebase-token',
        );
        expect(storage.values, {
          AppConstants.accessTokenKey: 'backend-access-token',
          AppConstants.refreshTokenKey: 'backend-refresh-token',
          AppConstants.sessionRoleKey: 'traveler',
          AppConstants.keepSignedInKey: 'true',
        });
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'restores a persisted Traveler session',
      build: () {
        storage = FakeSecureStorageService()
          ..values.addAll({
            AppConstants.accessTokenKey: 'stored-access-token',
            AppConstants.refreshTokenKey: 'stored-refresh-token',
            AppConstants.sessionRoleKey: 'traveler',
            AppConstants.keepSignedInKey: 'true',
          });
        return AuthSessionCubit(null, storage);
      },
      act: (cubit) => cubit.restoreSession(),
      expect: () => const [AuthSessionState.authenticated(UserRole.traveler)],
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'does not restore and clears a session when keep signed in is false',
      build: () {
        storage = FakeSecureStorageService()
          ..values.addAll({
            AppConstants.accessTokenKey: 'stored-access-token',
            AppConstants.refreshTokenKey: 'stored-refresh-token',
            AppConstants.sessionRoleKey: 'traveler',
            AppConstants.keepSignedInKey: 'false',
          });
        return AuthSessionCubit(null, storage);
      },
      act: (cubit) => cubit.restoreSession(),
      expect: () => const <AuthSessionState>[],
      verify: (_) => expect(storage.values, isEmpty),
    );
  });
}

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.loginError, this.verifyEmailError});

  final ServerException? loginError;
  final AppException? verifyEmailError;
  var loginCalls = 0;
  var verifyEmailCalls = 0;
  String? loginFirebaseIdToken;
  String? verifyEmailFirebaseIdToken;

  @override
  Future<SessionResponseDto> login(
    LoginRequest request, [
    String? firebaseIdToken,
  ]) async {
    loginCalls += 1;
    loginFirebaseIdToken = firebaseIdToken;
    if (loginError != null) throw loginError!;
    return _session;
  }

  @override
  Future<SessionResponseDto> verifyEmail(String firebaseIdToken) async {
    verifyEmailCalls += 1;
    verifyEmailFirebaseIdToken = firebaseIdToken;
    if (verifyEmailError != null) throw verifyEmailError!;
    return _session;
  }

  @override
  Future<SessionResponseDto> googleAuth(String firebaseIdToken) async =>
      _session;

  @override
  Future<RegisterTravelerResponse> registerTraveler(
    RegisterTravelerRequest request,
    String firebaseIdToken,
  ) => throw UnimplementedError();
}

final class FakeSecureStorageService implements SecureStorageService {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final class FakeFirebaseAuthService implements FirebaseAuthService {
  FakeFirebaseAuthService({
    this.signInError,
    this.signInToken,
    this.refreshError,
    this.refreshToken,
    this.firebaseEmail,
    this.emailVerified = true,
    this.sendEmailVerificationError,
    this.sendEmailVerificationCompleter,
  });

  final Object? signInError;
  final String? signInToken;
  final Object? refreshError;
  final String? refreshToken;
  final String? firebaseEmail;
  final bool emailVerified;
  final Object? sendEmailVerificationError;
  final Completer<void>? sendEmailVerificationCompleter;
  var sendEmailVerificationCalls = 0;
  var refreshIdTokenCalls = 0;
  var signOutCalls = 0;

  @override
  Future<String?> get currentUserEmail async => firebaseEmail;

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    return signInToken!;
  }

  @override
  Future<bool> get isEmailVerified async => emailVerified;

  @override
  Future<String?> refreshIdToken() async {
    refreshIdTokenCalls += 1;
    if (refreshError != null) throw refreshError!;
    if (!emailVerified) return null;
    return refreshToken ?? signInToken!;
  }

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() async {
    sendEmailVerificationCalls += 1;
    if (sendEmailVerificationError != null) {
      throw sendEmailVerificationError!;
    }
    await sendEmailVerificationCompleter?.future;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  Future<String> signInWithGoogle() => throw UnimplementedError();
}

const _session = SessionResponseDto(
  userId: 1,
  status: 'Active',
  accessToken: 'backend-access-token',
  refreshToken: 'backend-refresh-token',
);
