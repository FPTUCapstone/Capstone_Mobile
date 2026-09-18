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
      firebase = FakeFirebaseAuthService();
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
      // Backend is the sole password authority: the password is forwarded to
      // POST /api/v1/auth/login without any Firebase intermediary.
      expect(repository.loginFirebaseIdToken, isNull);
      expect(firebase.signInWithEmailCalls, 0);
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
      'maps invalid Backend credentials to a safe actionable error',
      build: () {
        repository = FakeAuthRepository(
          loginError: const ServerException(
            'Invalid email or password. Please try again.',
            'auth.invalid_credentials',
            401,
          ),
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService();
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
        expect(repository.loginCalls, 1);
        expect(firebase.signInWithEmailCalls, 0);
        expect(repository.loginFirebaseIdToken, isNull);
        expect(storage.values, isEmpty);
      },
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'maps a Backend network failure to the existing connection error',
      build: () {
        repository = FakeAuthRepository(
          loginError: const NetworkException(
            'TripMate is temporarily unable to process your request. '
            'Please check your connection and try again.',
          ),
        );
        storage = FakeSecureStorageService();
        firebase = FakeFirebaseAuthService();
        return AuthSessionCubit(repository, storage, firebase);
      },
      act: (cubit) =>
          cubit.signIn(email: 'traveler@example.com', password: 'Password123!'),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.failure(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
      ],
      verify: (_) {
        expect(repository.loginCalls, 1);
        expect(firebase.signInWithEmailCalls, 0);
        expect(repository.loginFirebaseIdToken, isNull);
        expect(storage.values, isEmpty);
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
        firebase = FakeFirebaseAuthService();
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
        // The password is verified by the Backend directly; no Firebase
        // authentication step is required or used.
        expect(firebase.signInWithEmailCalls, 0);
        expect(repository.loginFirebaseIdToken, isNull);
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
        expect(repository.loginFirebaseIdToken, isNull);
        expect(firebase.signInWithEmailCalls, 0);
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
    AuthSession? session,
    AuthSession? verifyEmailSession,
  }) : session = session ?? _session,
       verifyEmailSession = verifyEmailSession ?? _session;

  final AppException? loginError;
  final AppException? verifyEmailError;
  final ServerException? googleError;
  final AuthSession session;
  final AuthSession verifyEmailSession;
  var loginCalls = 0;
  var verifyEmailCalls = 0;
  var googleCalls = 0;
  AuthCredentials? lastLoginCredentials;
  String? loginFirebaseIdToken;
  String? verifyEmailFirebaseIdToken;
  String? googleFirebaseIdToken;

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
  Future<TravelerRegistrationResult> registerTraveler(
    TravelerRegistration request,
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

final class FakeFirebaseAuthService implements AuthIdentityService {
  FakeFirebaseAuthService({
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
  var signInWithEmailCalls = 0;

  @override
  Future<String?> get currentUserEmail async => firebaseEmail;

  /// Canary: [AuthIdentityService] no longer declares this method, so a
  /// non-zero [signInWithEmailCalls] count means a Firebase password sign-in
  /// path was reintroduced into production code.
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInWithEmailCalls += 1;
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
