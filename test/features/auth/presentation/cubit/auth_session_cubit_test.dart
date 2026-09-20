import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
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

    testWidgets('TC1 Traveler password success resolves to Traveler', (
      tester,
    ) async {
      repository = FakeAuthRepository(session: _session);
      storage = FakeSecureStorageService();
      firebase = FakeFirebaseAuthService(signInToken: 'firebase-id-token');
      final cubit = AuthSessionCubit(repository, storage, firebase);
      addTearDown(cubit.close);

      await cubit.signIn(
        email: ' Traveler@Example.com ',
        password: 'Password123!',
      );

      expect(
        cubit.state,
        const AuthSessionState.authenticated(UserRole.traveler),
      );
      expect(repository.lastLoginCredentials?.email, 'traveler@example.com');
      expect(repository.loginFirebaseIdToken, 'firebase-id-token');
      expect(storage.values[AppConstants.accessTokenKey], _session.accessToken);
      expect(
        await _resolveAuthenticatedRoute(tester, cubit.state),
        AppRoutes.traveler,
      );
    });

    testWidgets('TC8 existing Google Traveler resolves to Traveler', (
      tester,
    ) async {
      repository = FakeAuthRepository(session: _session);
      storage = FakeSecureStorageService();
      firebase = FakeFirebaseAuthService(googleToken: 'google-id-token');
      final cubit = AuthSessionCubit(repository, storage, firebase);
      addTearDown(cubit.close);

      await cubit.signInWithGoogle();

      expect(
        cubit.state,
        const AuthSessionState.authenticated(UserRole.traveler),
      );
      expect(repository.googleCalls, 1);
      expect(repository.googleFirebaseIdToken, 'google-id-token');
      expect(
        await _resolveAuthenticatedRoute(tester, cubit.state),
        AppRoutes.traveler,
      );
    });

    testWidgets(
      'TC9 existing Google approved TourOperator resolves to operator',
      (tester) async {
        repository = FakeAuthRepository(session: _approvedOperatorSession);
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(googleToken: 'google-id-token');
        final cubit = AuthSessionCubit(repository, storage, firebase);
        addTearDown(cubit.close);

        await cubit.signInWithGoogle();

        expect(
          cubit.state,
          const AuthSessionState.authenticated(
            UserRole.tourOperator,
            applicationStatus: TourOperatorApplicationStatus.approved,
          ),
        );
        expect(repository.googleCalls, 1);
        expect(
          storage.values[AppConstants.sessionApplicationStatusKey],
          TourOperatorApplicationStatus.approved.name,
        );
        expect(
          await _resolveAuthenticatedRoute(tester, cubit.state),
          AppRoutes.operator,
        );
      },
    );

    testWidgets(
      'TC10 backend-provisioned Google Traveler resolves to Traveler',
      (tester) async {
        repository = FakeAuthRepository(
          session: _firstTimeGoogleTravelerSession,
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(googleToken: 'new-google-id-token');
        final cubit = AuthSessionCubit(repository, storage, firebase);
        addTearDown(cubit.close);

        await cubit.signInWithGoogle();

        expect(repository.googleCalls, 1);
        expect(repository.googleFirebaseIdToken, 'new-google-id-token');
        expect(
          cubit.state,
          const AuthSessionState.authenticated(UserRole.traveler),
        );
        expect(
          storage.values[AppConstants.accessTokenKey],
          _firstTimeGoogleTravelerSession.accessToken,
        );
        expect(
          await _resolveAuthenticatedRoute(tester, cubit.state),
          AppRoutes.traveler,
        );
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'rejects an unverified Firebase user without calling backend login',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          signInError: const AuthIdentityException(
            AuthIdentityFailure.emailUnverified,
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
          signInError: const AuthIdentityException(
            AuthIdentityFailure.invalidCredentials,
          ),
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
          signInError: const AuthIdentityException(AuthIdentityFailure.network),
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
          sendEmailVerificationError: const AuthIdentityException(
            AuthIdentityFailure.tooManyRequests,
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
        failure: AuthIdentityFailure.noCurrentUser,
        message:
            'Your verification session has expired. Please sign in to request a new verification link.',
      ),
      (
        name: 'Firebase network failure',
        failure: AuthIdentityFailure.network,
        message:
            'TripMate is temporarily unable to process your request. Please check your connection and try again.',
      ),
      (
        name: 'unknown Firebase failure',
        failure: AuthIdentityFailure.unknown,
        message:
            'Unable to send verification email. Please try again later or sign in.',
      ),
    ]) {
      blocTest<AuthSessionCubit, AuthSessionState>(
        'maps ${scenario.name} safely while resending',
        build: () {
          firebase = FakeFirebaseAuthService(
            sendEmailVerificationError: AuthIdentityException(scenario.failure),
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
          refreshError: const AuthIdentityException(
            AuthIdentityFailure.noCurrentUser,
          ),
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
          refreshError: const AuthIdentityException(
            AuthIdentityFailure.network,
          ),
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

    // --- B2: Administrator is Web-only; unknown identity never fabricates Traveler.
    blocTest<AuthSessionCubit, AuthSessionState>(
      'rejects an Administrator password session before persisting any credential',
      build: () {
        repository = FakeAuthRepository(session: _administratorSession);
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(signInToken: 'fb-token');
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'admin@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'Administrator accounts are supported on Web only.',
        ),
      ],
      verify: (_) {
        expect(storage.values, isEmpty);
        expect(firebase.signOutCalls, 1);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'maps backend Administrator Mobile refusal and clears Firebase identity',
      build: () {
        repository = FakeAuthRepository(
          loginError: const ServerException(
            'Administrator accounts are supported on Web only.',
            'auth.admin_mobile_sign_in_disabled',
            403,
          ),
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(signInToken: 'fb-token');
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'admin@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'Administrator accounts are supported on Web only.',
        ),
      ],
      verify: (cubit) {
        expect(cubit.state.isAuthenticated, isFalse);
        expect(storage.values, isEmpty);
        expect(firebase.signOutCalls, 1);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'Firebase cleanup failure cannot mask backend Administrator Mobile refusal',
      build: () {
        repository = FakeAuthRepository(
          loginError: const ServerException(
            'internal server detail',
            'auth.admin_mobile_sign_in_disabled',
            403,
          ),
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          signInToken: 'fb-token',
          signOutError: StateError('Firebase configuration detail'),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'admin@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'Administrator accounts are supported on Web only.',
        ),
      ],
      verify: (cubit) {
        expect(cubit.state.isLoading, isFalse);
        expect(cubit.state.isAuthenticated, isFalse);
        expect(storage.values, isEmpty);
        expect(firebase.signOutCalls, 1);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'Firebase configuration detail is never displayed during sign in',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          signInError: const AuthIdentityException(
            AuthIdentityFailure.unavailable,
          ),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'traveler@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'Sign in is unavailable. Please try again later.',
        ),
      ],
      verify: (_) => expect(storage.values, isEmpty),
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'Administrator password refusal survives provider sign-out failure',
      build: () {
        repository = FakeAuthRepository(session: _administratorSession);
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          signInToken: 'fb-token',
          signOutError: StateError('Firebase configuration detail'),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'admin@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'Administrator accounts are supported on Web only.',
        ),
      ],
      verify: (_) {
        expect(storage.values, isEmpty);
        expect(firebase.signOutCalls, 1);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'rejects an Administrator verify-email recovery session before persisting',
      build: () {
        repository = FakeAuthRepository(
          verifyEmailSession: _administratorSession,
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(refreshToken: 'fb-token');
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.verifyEmail(),
      expect: () => const [
        AuthSessionState.loading(operation: AuthSessionOperation.verifyEmail),
        AuthSessionState.failure(
          'Administrator accounts are supported on Web only.',
        ),
      ],
      verify: (_) => expect(storage.values, isEmpty),
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'Administrator verify-email refusal survives provider sign-out failure',
      build: () {
        repository = FakeAuthRepository(
          verifyEmailSession: _administratorSession,
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          refreshToken: 'fb-token',
          signOutError: StateError('Firebase configuration detail'),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.verifyEmail(),
      expect: () => const [
        AuthSessionState.loading(operation: AuthSessionOperation.verifyEmail),
        AuthSessionState.failure(
          'Administrator accounts are supported on Web only.',
        ),
      ],
      verify: (_) {
        expect(storage.values, isEmpty);
        expect(firebase.signOutCalls, 1);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'maps the Google administrator-disabled 403 to the Web-only message',
      build: () {
        repository = FakeAuthRepository(
          googleError: const ServerException(
            'Administrator accounts must sign in with email and password.',
            'auth.admin_google_sign_in_disabled',
            403,
          ),
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(googleToken: 'fb-google-token');
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'Administrator accounts are supported on Web only.',
        ),
      ],
      verify: (_) {
        expect(storage.values, isEmpty);
        expect(firebase.signOutCalls, 1);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'Google administrator 403 refusal survives provider sign-out failure',
      build: () {
        repository = FakeAuthRepository(
          googleError: const ServerException(
            'internal rule detail',
            'auth.admin_google_sign_in_disabled',
            403,
          ),
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          googleToken: 'fb-google-token',
          signOutError: StateError('Firebase configuration detail'),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'Administrator accounts are supported on Web only.',
        ),
      ],
      verify: (cubit) {
        expect(
          cubit.state,
          const AuthSessionState.failure(
            'Administrator accounts are supported on Web only.',
          ),
        );
        expect(storage.values, isEmpty);
        expect(firebase.signOutCalls, 1);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'never fabricates Traveler from a missing or unknown role',
      build: () {
        repository = FakeAuthRepository(session: _noRoleSession);
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(signInToken: 'fb-token');
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'x@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure('Unable to sign in. Please try again later.'),
      ],
      verify: (_) => expect(storage.values, isEmpty),
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'persists the TourOperator application status for routing',
      build: () {
        repository = FakeAuthRepository(session: _pendingOperatorSession);
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(signInToken: 'fb-token');
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'op@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.authenticated(
          UserRole.tourOperator,
          applicationStatus: TourOperatorApplicationStatus.pendingApproval,
        ),
      ],
      verify: (_) {
        expect(storage.values[AppConstants.sessionRoleKey], 'tourOperator');
        expect(
          storage.values[AppConstants.sessionApplicationStatusKey],
          'pendingApproval',
        );
      },
    );

    for (final scenario
        in <({String? stored, TourOperatorApplicationStatus expected})>[
          (
            stored: 'Approved',
            expected: TourOperatorApplicationStatus.approved,
          ),
          (
            stored: 'approved',
            expected: TourOperatorApplicationStatus.approved,
          ),
          (
            stored: 'PendingApproval',
            expected: TourOperatorApplicationStatus.pendingApproval,
          ),
          (
            stored: 'pendingApproval',
            expected: TourOperatorApplicationStatus.pendingApproval,
          ),
          (
            stored: 'Rejected',
            expected: TourOperatorApplicationStatus.rejected,
          ),
          (
            stored: 'rejected',
            expected: TourOperatorApplicationStatus.rejected,
          ),
          (stored: null, expected: TourOperatorApplicationStatus.unresolved),
          (
            stored: 'unknown',
            expected: TourOperatorApplicationStatus.unresolved,
          ),
        ]) {
      blocTest<AuthSessionCubit, AuthSessionState>(
        'restores persisted application status ${scenario.stored}',
        build: () {
          storage = FakeSecureStorageService()
            ..values.addAll({
              AppConstants.accessTokenKey: 'stored-access-token',
              AppConstants.refreshTokenKey: 'stored-refresh-token',
              AppConstants.sessionRoleKey: 'tourOperator',
              AppConstants.keepSignedInKey: 'true',
            });
          final stored = scenario.stored;
          if (stored != null) {
            storage.values[AppConstants.sessionApplicationStatusKey] = stored;
          }
          return AuthSessionCubit(null, storage);
        },
        act: (cubit) => cubit.restoreSession(),
        expect: () => [
          AuthSessionState.authenticated(
            UserRole.tourOperator,
            applicationStatus: scenario.expected,
          ),
        ],
      );
    }

    test(
      'invalidates the active session through the session coordinator',
      () async {
        final storage = FakeSecureStorageService()
          ..values.addAll({
            AppConstants.accessTokenKey: 'access',
            AppConstants.refreshTokenKey: 'refresh',
            AppConstants.sessionRoleKey: 'traveler',
            AppConstants.keepSignedInKey: 'true',
          });
        final cubit = AuthSessionCubit(null, storage);
        addTearDown(cubit.close);
        await cubit.restoreSession();
        expect(cubit.state.isAuthenticated, isTrue);
        final coordinator = SessionCoordinator();
        coordinator.register(cubit.handleSessionExpired);
        await coordinator.invalidate();
        expect(cubit.state, const AuthSessionState.unauthenticated());
        coordinator.unregister(cubit.handleSessionExpired);
        await coordinator.invalidate(); // no listeners: no throw
      },
    );

    test(
      'session expiry clears every persisted routing and credential field',
      () async {
        final storage = FakeSecureStorageService()
          ..values.addAll({
            AppConstants.accessTokenKey: 'access',
            AppConstants.refreshTokenKey: 'refresh',
            AppConstants.sessionRoleKey: 'tourOperator',
            AppConstants.sessionApplicationStatusKey: 'approved',
            AppConstants.keepSignedInKey: 'true',
          });
        final cubit = AuthSessionCubit(null, storage);
        addTearDown(cubit.close);
        await cubit.restoreSession();
        expect(cubit.state.isAuthenticated, isTrue);

        await cubit.handleSessionExpired();

        expect(storage.values, isEmpty);
        expect(cubit.state, const AuthSessionState.unauthenticated());
      },
    );

    test(
      'provider sign-out failure cannot leave an expired session visible',
      () async {
        final storage = FakeSecureStorageService()
          ..values.addAll({
            AppConstants.accessTokenKey: 'access',
            AppConstants.refreshTokenKey: 'refresh',
            AppConstants.sessionRoleKey: 'traveler',
            AppConstants.keepSignedInKey: 'true',
          });
        final firebase = FakeFirebaseAuthService(
          signOutError: StateError('provider unavailable'),
        );
        final cubit = AuthSessionCubit(null, storage, firebase);
        addTearDown(cubit.close);
        await cubit.restoreSession();
        expect(cubit.state.isAuthenticated, isTrue);

        await cubit.handleSessionExpired();

        expect(storage.values, isEmpty);
        expect(cubit.state, const AuthSessionState.unauthenticated());
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'Google user cancellation returns quietly to sign-in',
      build: () {
        repository = FakeAuthRepository();
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService(
          googleError: const AuthIdentityException(
            AuthIdentityFailure.canceled,
          ),
        );
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.unauthenticated(),
      ],
      verify: (_) => expect(storage.values, isEmpty),
    );

    // --- UC-05 T02: backend-integrated sign-out foundation.

    const localCleanupFailureCopy =
        'We couldn\'t complete sign out on this device. Please try again.';

    Future<AuthSessionCubit> buildAuthenticatedCubit({
      Completer<void>? logoutCompleter,
      AppException? logoutError,
      FakeSecureStorageService? storageOverride,
    }) async {
      repository = FakeAuthRepository(
        logoutCompleter: logoutCompleter,
        logoutError: logoutError,
      );
      storage =
          storageOverride ??
          (FakeSecureStorageService()
            ..values.addAll({
              AppConstants.accessTokenKey: 'access',
              AppConstants.refreshTokenKey: 'refresh-123',
              AppConstants.sessionRoleKey: 'traveler',
              AppConstants.keepSignedInKey: 'true',
            }));
      firebase = FakeFirebaseAuthService();
      final cubit = AuthSessionCubit(repository, storage, firebase);
      addTearDown(cubit.close);
      await cubit.restoreSession();
      expect(cubit.state.isAuthenticated, isTrue);
      return cubit;
    }

    test(
      'UC-05 signOut forwards the stored refresh token and ends the session',
      () async {
        final cubit = await buildAuthenticatedCubit();

        await cubit.signOut();

        expect(repository.logoutCalls, 1);
        expect(repository.lastLogoutRefreshToken, 'refresh-123');
        expect(storage.values, isEmpty);
        expect(firebase.signOutCalls, 1);
        expect(cubit.state, const AuthSessionState.unauthenticated());
        expect(cubit.state.isAuthenticated, isFalse);
      },
    );

    test(
      'UC-05 signOut stays authenticated while pending and blocks duplicates',
      () async {
        final completer = Completer<void>();
        final cubit = await buildAuthenticatedCubit(logoutCompleter: completer);
        final statuses = <AuthSessionStatus>[];
        final subscription = cubit.stream.listen(
          (state) => statuses.add(state.status),
        );
        addTearDown(subscription.cancel);

        final pending = cubit.signOut();

        expect(cubit.state.status, AuthSessionStatus.authenticated);
        expect(cubit.state.operation, AuthSessionOperation.signOut);
        expect(cubit.state.isAuthenticated, isTrue);
        expect(cubit.state.isLoading, isFalse);

        // The repository call is issued once the storage read resolves and then
        // stays pending on the gated completer.
        await pumpEventQueue();
        expect(repository.logoutCalls, 1);

        // A second intent while the first request is in flight must not issue
        // another repository call.
        await cubit.signOut();
        expect(repository.logoutCalls, 1);

        completer.complete();
        await pending;
        await pumpEventQueue();

        expect(cubit.state, const AuthSessionState.unauthenticated());
        // Exactly two emissions: the in-flight authenticated marker and the
        // terminal state — never AuthSessionStatus.loading.
        expect(statuses, [
          AuthSessionStatus.authenticated,
          AuthSessionStatus.unauthenticated,
        ]);
      },
    );

    test('UC-05 signOut sends null for a missing stored token', () async {
      final cubit = await buildAuthenticatedCubit();
      storage.values.remove(AppConstants.refreshTokenKey);

      await cubit.signOut();

      expect(repository.logoutCalls, 1);
      expect(repository.lastLogoutRefreshToken, isNull);
      expect(cubit.state, const AuthSessionState.unauthenticated());
      expect(cubit.state.operation, AuthSessionOperation.none);
    });

    test('UC-05 signOut normalises an empty stored token to null', () async {
      final cubit = await buildAuthenticatedCubit();
      storage.values[AppConstants.refreshTokenKey] = '';

      await cubit.signOut();

      expect(repository.logoutCalls, 1);
      expect(repository.lastLogoutRefreshToken, isNull);
      expect(cubit.state, const AuthSessionState.unauthenticated());
    });

    test(
      'UC-05 signOut normalises a whitespace stored token to null',
      () async {
        final cubit = await buildAuthenticatedCubit();
        storage.values[AppConstants.refreshTokenKey] = '   ';

        await cubit.signOut();

        expect(repository.logoutCalls, 1);
        expect(repository.lastLogoutRefreshToken, isNull);
        expect(cubit.state, const AuthSessionState.unauthenticated());
      },
    );

    test(
      'UC-05 signOut sends null when the token read fails and fails closed when safety cannot be verified',
      () async {
        final cubit = await buildAuthenticatedCubit();
        storage.readError = StateError('keystore unavailable');

        // The storage failure must not escape, block logout or reach the UI.
        await expectLater(cubit.signOut(), completes);

        expect(repository.logoutCalls, 1);
        expect(repository.lastLogoutRefreshToken, isNull);

        // T05/M7 supersedes the earlier expectation for this case: when every
        // read fails, non-restorability cannot be proven, so no local sign-out
        // may be claimed. Only the approved local-cleanup copy is carried, and
        // no storage detail is exposed.
        expect(cubit.state.status, AuthSessionStatus.authenticated);
        expect(cubit.state.operation, AuthSessionOperation.none);
        expect(cubit.state.errorMessage, localCleanupFailureCopy);
        expect(cubit.state.errorMessage, isNot(contains('keystore')));
      },
    );

    test(
      'UC-05 signOut clears every session key and the provider identity',
      () async {
        final cubit = await buildAuthenticatedCubit();
        storage.values[AppConstants.sessionApplicationStatusKey] = 'approved';

        await cubit.signOut();

        expect(
          storage.values.containsKey(AppConstants.accessTokenKey),
          isFalse,
        );
        expect(
          storage.values.containsKey(AppConstants.refreshTokenKey),
          isFalse,
        );
        expect(
          storage.values.containsKey(AppConstants.sessionRoleKey),
          isFalse,
        );
        expect(
          storage.values.containsKey(AppConstants.sessionApplicationStatusKey),
          isFalse,
        );
        expect(
          storage.values.containsKey(AppConstants.keepSignedInKey),
          isFalse,
        );
        expect(firebase.signOutCalls, 1);
        expect(cubit.state, const AuthSessionState.unauthenticated());
        expect(cubit.state.isAuthenticated, isFalse);
      },
    );

    // --- UC-05: a remote failure preserves the local session for retry.

    const remoteFailureCopy = AuthSessionCubit.signOutFailureMessage;
    const rawTransportDetail =
        'SocketException: Connection refused (OS Error: errno = 10061) '
        'at localhost:5000';

    test(
      'UC-05 signOut preserves the local session on a network failure',
      () async {
        final cubit = await buildAuthenticatedCubit(
          logoutError: const NetworkException(rawTransportDetail),
        );

        await expectLater(cubit.signOut(), completes);

        expect(repository.logoutCalls, 1);
        expect(storage.values[AppConstants.refreshTokenKey], 'refresh-123');
        expect(firebase.signOutCalls, 0);
        expect(cubit.state.status, AuthSessionStatus.authenticated);
        expect(cubit.state.isAuthenticated, isTrue);
        expect(cubit.state.operation, AuthSessionOperation.none);
        expect(cubit.state.errorMessage, remoteFailureCopy);
      },
    );

    test('UC-05 signOut preserves the local session on a server 500', () async {
      final cubit = await buildAuthenticatedCubit(
        logoutError: const ServerException('raw 500 detail', 'MSG127', 500),
      );

      await expectLater(cubit.signOut(), completes);

      expect(repository.logoutCalls, 1);
      expect(storage.values[AppConstants.refreshTokenKey], 'refresh-123');
      expect(firebase.signOutCalls, 0);
      expect(cubit.state.status, AuthSessionStatus.authenticated);
      expect(cubit.state.errorMessage, remoteFailureCopy);
    });

    test('UC-05 signOut never surfaces raw remote detail', () async {
      final cubit = await buildAuthenticatedCubit(
        logoutError: const ServerException(
          'System.NullReferenceException at AuthController.Logout',
          'MSG127',
          500,
        ),
      );

      await cubit.signOut();

      final message = cubit.state.errorMessage;
      expect(message, remoteFailureCopy);
      expect(message, isNot(contains('NullReferenceException')));
      expect(message, isNot(contains('MSG127')));
      expect(message, isNot(contains('500')));
      expect(message, isNot(contains('refresh-123')));
    });

    test('UC-05 signOut emits exactly one authenticated retry state', () async {
      final cubit = await buildAuthenticatedCubit(
        logoutError: const NetworkException(rawTransportDetail),
      );
      final emissions = <AuthSessionState>[];
      final subscription = cubit.stream.listen(emissions.add);
      addTearDown(subscription.cancel);

      await cubit.signOut();
      await pumpEventQueue();

      final withNotice = emissions
          .where((state) => state.errorMessage != null)
          .toList();
      expect(withNotice, hasLength(1));
      expect(withNotice.single.status, AuthSessionStatus.authenticated);
      expect(emissions.last.errorMessage, remoteFailureCopy);
      expect(
        emissions.any((state) => state.status == AuthSessionStatus.failure),
        isFalse,
      );
    });

    test(
      'UC-05 signOut leaves no M3 notice on a clean remote success',
      () async {
        final cubit = await buildAuthenticatedCubit();

        await cubit.signOut();

        expect(cubit.state.status, AuthSessionStatus.unauthenticated);
        expect(cubit.state.errorMessage, isNull);
        expect(cubit.state.isAuthenticated, isFalse);
      },
    );

    // --- UC-05 T05: M7 restore-safety. Local logout may only be reported as
    // complete when the ACTUAL restoreSession() predicate is proven false; a
    // cleanup that cannot be proven safe keeps the session and asks to retry.

    FakeSecureStorageService restorableStorage() =>
        FakeSecureStorageService()
          ..values.addAll({
            AppConstants.accessTokenKey: 'access',
            AppConstants.refreshTokenKey: 'refresh-123',
            AppConstants.sessionRoleKey: 'traveler',
            AppConstants.sessionApplicationStatusKey: 'approved',
            AppConstants.keepSignedInKey: 'true',
          });

    /// A fresh Cubit over the same persisted storage: proves the session cannot
    /// be restored again. Never rely on the in-memory state alone.
    Future<void> expectNoRestore(FakeSecureStorageService sameStorage) async {
      final fresh = AuthSessionCubit(null, sameStorage);
      addTearDown(fresh.close);
      await fresh.restoreSession();
      expect(fresh.state.isAuthenticated, isFalse);
    }

    test('M7-A normal invalidation is proven non-restorable', () async {
      final cubit = await buildAuthenticatedCubit(
        storageOverride: restorableStorage(),
      );

      await cubit.signOut();

      expect(storage.values, isEmpty);
      expect(cubit.state, const AuthSessionState.unauthenticated());
      expect(firebase.signOutCalls, 1);
      // A single attempt suffices: five distinct keys, no retry, no gate
      // fallback write.
      expect(storage.deleteCalls.length, 5);
      expect(storage.writeCalls, isEmpty);
      await expectNoRestore(storage);
    });

    test('M7-B leftover token bytes are safe once the gate is gone', () async {
      final cubit = await buildAuthenticatedCubit(
        storageOverride: restorableStorage(),
      );
      storage.permanentMutationFailures.addAll({
        AppConstants.accessTokenKey,
        AppConstants.refreshTokenKey,
      });

      await cubit.signOut();

      // Physical leftovers remain, yet the persisted session is not restorable
      // because the keep-signed-in gate is gone.
      expect(storage.values.containsKey(AppConstants.accessTokenKey), isTrue);
      expect(storage.values.containsKey(AppConstants.refreshTokenKey), isTrue);
      expect(storage.values.containsKey(AppConstants.keepSignedInKey), isFalse);
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.errorMessage, isNull);
      await expectNoRestore(storage);
    });

    test('M7-C one bounded retry recovers a failing first attempt', () async {
      final cubit = await buildAuthenticatedCubit(
        storageOverride: restorableStorage(),
      );
      storage.blockMutationsUntilGateVerifyRead = true;
      final gateReadsBefore =
          storage.readCalls[AppConstants.keepSignedInKey] ?? 0;

      await expectLater(cubit.signOut(), completes);

      expect(storage.values, isEmpty);
      expect(cubit.state.status, AuthSessionStatus.unauthenticated);
      expect(cubit.state.errorMessage, isNull);
      // At most one verification read per attempt → at most two attempts.
      expect(
        (storage.readCalls[AppConstants.keepSignedInKey] ?? 0) -
            gateReadsBefore,
        lessThanOrEqualTo(2),
      );
      await expectNoRestore(storage);
    });

    test(
      'M7-D an unprovable cleanup keeps the session and asks to retry',
      () async {
        final cubit = await buildAuthenticatedCubit(
          storageOverride: restorableStorage(),
        );
        final statuses = <AuthSessionStatus>[];
        final subscription = cubit.stream.listen(
          (state) => statuses.add(state.status),
        );
        addTearDown(subscription.cancel);
        storage.permanentMutationFailures.addAll({
          AppConstants.accessTokenKey,
          AppConstants.refreshTokenKey,
          AppConstants.sessionRoleKey,
          AppConstants.sessionApplicationStatusKey,
          AppConstants.keepSignedInKey,
        });
        final gateReadsBefore =
            storage.readCalls[AppConstants.keepSignedInKey] ?? 0;

        await expectLater(cubit.signOut(), completes);
        await pumpEventQueue();

        expect(cubit.state.status, AuthSessionStatus.authenticated);
        expect(cubit.state.isAuthenticated, isTrue);
        expect(cubit.state.operation, AuthSessionOperation.none);
        expect(cubit.state.errorMessage, localCleanupFailureCopy);
        expect(cubit.state.errorMessage, isNot(remoteFailureCopy));
        // Provider sign-out must not run before local completion is proven, and
        // no false success claim may be emitted.
        expect(firebase.signOutCalls, 0);
        expect(statuses, isNot(contains(AuthSessionStatus.loading)));
        expect(statuses, isNot(contains(AuthSessionStatus.unauthenticated)));
        expect(storage.values[AppConstants.keepSignedInKey], 'true');
        // Bounded: one verification read per attempt, two attempts maximum.
        expect(
          (storage.readCalls[AppConstants.keepSignedInKey] ?? 0) -
              gateReadsBefore,
          lessThanOrEqualTo(2),
        );
      },
    );

    test('M7-E an unreadable verification fails closed', () async {
      final cubit = await buildAuthenticatedCubit(
        storageOverride: restorableStorage(),
      );
      storage.permanentReadFailures.add(AppConstants.accessTokenKey);

      await expectLater(cubit.signOut(), completes);

      expect(cubit.state.status, AuthSessionStatus.authenticated);
      expect(cubit.state.operation, AuthSessionOperation.none);
      expect(cubit.state.errorMessage, localCleanupFailureCopy);
      expect(firebase.signOutCalls, 0);
    });

    test('M7-G remote failure does not begin local cleanup', () async {
      final cubit = await buildAuthenticatedCubit(
        logoutError: const NetworkException(rawTransportDetail),
      );

      await cubit.signOut();

      expect(cubit.state.status, AuthSessionStatus.authenticated);
      expect(cubit.state.isAuthenticated, isTrue);
      expect(cubit.state.errorMessage, remoteFailureCopy);
      expect(cubit.state.errorMessage, isNot(localCleanupFailureCopy));
      expect(firebase.signOutCalls, 0);
      expect(storage.values[AppConstants.refreshTokenKey], 'refresh-123');
    });

    test(
      'M7-H remote failure returns before any unprovable local cleanup',
      () async {
        final cubit = await buildAuthenticatedCubit(
          logoutError: const ServerException('raw 500 detail', 'MSG127', 500),
        );
        storage.permanentMutationFailures.addAll({
          AppConstants.accessTokenKey,
          AppConstants.refreshTokenKey,
          AppConstants.sessionRoleKey,
          AppConstants.sessionApplicationStatusKey,
          AppConstants.keepSignedInKey,
        });

        await expectLater(cubit.signOut(), completes);

        expect(cubit.state.status, AuthSessionStatus.authenticated);
        expect(cubit.state.operation, AuthSessionOperation.none);
        expect(cubit.state.errorMessage, remoteFailureCopy);
        expect(cubit.state.errorMessage, isNot(localCleanupFailureCopy));
        expect(cubit.state.errorMessage, isNot(contains('500')));
        expect(cubit.state.errorMessage, isNot(contains('MSG127')));
        expect(firebase.signOutCalls, 0);
      },
    );
  });
}

Future<String> _resolveAuthenticatedRoute(
  WidgetTester tester,
  AuthSessionState session,
) async {
  final router = GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (_, state) => RouteGuards.redirect(session, state),
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const Text('Sign In')),
      GoRoute(
        path: AppRoutes.traveler,
        builder: (_, _) => const Text('Traveler area'),
      ),
      GoRoute(
        path: AppRoutes.operator,
        builder: (_, _) => const Text('Operator workspace'),
      ),
      GoRoute(
        path: AppRoutes.operatorApplication,
        builder: (_, _) => const Text('Operator application'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router.routerDelegate.currentConfiguration.last.matchedLocation;
}

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.loginError,
    this.verifyEmailError,
    this.googleError,
    this.logoutError,
    this.logoutCompleter,
    AuthSession? session,
    AuthSession? verifyEmailSession,
  }) : session = session ?? _session,
       verifyEmailSession = verifyEmailSession ?? _session;

  final ServerException? loginError;
  final AppException? verifyEmailError;
  final ServerException? googleError;
  final AppException? logoutError;
  final Completer<void>? logoutCompleter;
  final AuthSession session;
  final AuthSession verifyEmailSession;
  var loginCalls = 0;
  var verifyEmailCalls = 0;
  var googleCalls = 0;
  var logoutCalls = 0;
  AuthCredentials? lastLoginCredentials;
  String? loginFirebaseIdToken;
  String? verifyEmailFirebaseIdToken;
  String? googleFirebaseIdToken;
  String? lastLogoutRefreshToken;

  @override
  Future<AuthSession> login(
    AuthCredentials request, [
    String? firebaseIdToken,
  ]) async {
    loginCalls += 1;
    lastLoginCredentials = request;
    loginFirebaseIdToken = firebaseIdToken;
    if (loginError != null) throw loginError!;
    return session;
  }

  @override
  Future<AuthSession> verifyEmail(String firebaseIdToken) async {
    verifyEmailCalls += 1;
    verifyEmailFirebaseIdToken = firebaseIdToken;
    if (verifyEmailError != null) throw verifyEmailError!;
    return verifyEmailSession;
  }

  @override
  Future<AuthSession> googleAuth(String firebaseIdToken) async {
    googleCalls += 1;
    googleFirebaseIdToken = firebaseIdToken;
    if (googleError != null) throw googleError!;
    return session;
  }

  @override
  Future<void> logout(String? refreshToken) async {
    logoutCalls += 1;
    lastLogoutRefreshToken = refreshToken;
    if (logoutCompleter != null) {
      await logoutCompleter!.future;
    }
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<TravelerRegistrationResult> registerTraveler(
    TravelerRegistration request,
    String firebaseIdToken,
  ) => throw UnimplementedError();
}

final class FakeSecureStorageService implements SecureStorageService {
  final values = <String, String>{};

  /// When set, [read] throws instead of returning a value so the sign-out
  /// read-failure path can be exercised without a real keystore.
  Object? readError;

  /// Keys whose mutation (delete or write) always throws.
  final permanentMutationFailures = <String>{};

  /// Keys whose read always throws.
  final permanentReadFailures = <String>{};

  /// When true, every mutation throws until the next read of
  /// [AppConstants.keepSignedInKey]. Models "the first local invalidation
  /// attempt fails and the bounded retry succeeds" deterministically, without
  /// timing or internal-ordering assumptions.
  bool blockMutationsUntilGateVerifyRead = false;

  final deleteCalls = <String, int>{};
  final writeCalls = <String, int>{};
  final readCalls = <String, int>{};

  int get mutationCalls =>
      deleteCalls.values.fold(0, (sum, count) => sum + count) +
      writeCalls.values.fold(0, (sum, count) => sum + count);

  @override
  Future<void> delete(String key) async {
    deleteCalls[key] = (deleteCalls[key] ?? 0) + 1;
    if (blockMutationsUntilGateVerifyRead ||
        permanentMutationFailures.contains(key)) {
      throw StateError('delete failed');
    }
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async {
    readCalls[key] = (readCalls[key] ?? 0) + 1;
    if (readError != null) throw readError!;
    if (permanentReadFailures.contains(key)) throw StateError('read failed');
    if (blockMutationsUntilGateVerifyRead &&
        key == AppConstants.keepSignedInKey) {
      blockMutationsUntilGateVerifyRead = false;
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writeCalls[key] = (writeCalls[key] ?? 0) + 1;
    if (blockMutationsUntilGateVerifyRead ||
        permanentMutationFailures.contains(key)) {
      throw StateError('write failed');
    }
    values[key] = value;
  }
}

final class FakeFirebaseAuthService implements AuthIdentityService {
  FakeFirebaseAuthService({
    this.signInError,
    this.signInToken,
    this.refreshError,
    this.refreshToken,
    this.firebaseEmail,
    this.emailVerified = true,
    this.sendEmailVerificationError,
    this.sendEmailVerificationCompleter,
    this.googleToken,
    this.googleError,
    this.signOutError,
  });

  final Object? signInError;
  final String? signInToken;
  final Object? refreshError;
  final String? refreshToken;
  final String? firebaseEmail;
  final bool emailVerified;
  final Object? sendEmailVerificationError;
  final Completer<void>? sendEmailVerificationCompleter;
  final String? googleToken;
  final Object? googleError;
  final Object? signOutError;
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
    if (signOutError != null) throw signOutError!;
  }

  @override
  Future<String> signInWithGoogle() async {
    if (googleError != null) throw googleError!;
    if (googleToken == null) {
      throw const AuthIdentityException(AuthIdentityFailure.canceled);
    }
    return googleToken!;
  }
}

// Post-A1/A2 the backend always returns role on session-issuing responses, so
// the shared fixture carries it. Role-less responses are covered separately by
// _noRoleSession to prove the client never fabricates a Traveler.
const _session = AuthSession(
  userId: 1,
  status: 'Active',
  role: 'Traveler',
  accessToken: 'backend-access-token',
  refreshToken: 'backend-refresh-token',
);

const _administratorSession = AuthSession(
  userId: 2,
  status: 'Active',
  role: 'Administrator',
  accessToken: 'backend-access-token',
  refreshToken: 'backend-refresh-token',
);

const _approvedOperatorSession = AuthSession(
  userId: 5,
  status: 'Active',
  role: 'TourOperator',
  applicationStatus: TourOperatorApplicationStatus.approved,
  accessToken: 'operator-access-token',
  refreshToken: 'operator-refresh-token',
);

const _firstTimeGoogleTravelerSession = AuthSession(
  userId: 6,
  status: 'Active',
  role: 'Traveler',
  accessToken: 'provisioned-access-token',
  refreshToken: 'provisioned-refresh-token',
  email: 'new.traveler@example.com',
  fullName: 'New Traveler',
);

const _noRoleSession = AuthSession(
  userId: 3,
  status: 'Active',
  accessToken: 'backend-access-token',
  refreshToken: 'backend-refresh-token',
);

const _pendingOperatorSession = AuthSession(
  userId: 4,
  status: 'Active',
  role: 'TourOperator',
  applicationStatus: TourOperatorApplicationStatus.pendingApproval,
  accessToken: 'backend-access-token',
  refreshToken: 'backend-refresh-token',
);
