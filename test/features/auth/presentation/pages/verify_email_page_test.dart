import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_auth_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/verify_email_page.dart';

void main() {
  group('VerifyEmailPage', () {
    testWidgets('shows only a masked email supplied through route memory', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          cubit: AuthSessionCubit(
            FakeAuthRepository(),
            FakeSecureStorageService(),
            FakeFirebaseAuthService(),
          ),
          email: 'person@example.com',
        ),
      );

      expect(find.text('p***@example.com'), findsOneWidget);
      expect(find.text('person@example.com'), findsNothing);
    });

    testWidgets(
      'reads the email from GoRouter extra without putting it in URL',
      (tester) async {
        final cubit = AuthSessionCubit(
          FakeAuthRepository(),
          FakeSecureStorageService(),
          FakeFirebaseAuthService(),
        );
        final router = GoRouter(
          initialLocation: '/start',
          routes: [
            GoRoute(
              path: '/start',
              builder: (_, _) => const Scaffold(body: Text('Start')),
            ),
            GoRoute(
              path: '/verify',
              builder: (_, state) =>
                  VerifyEmailPage(email: state.extra as String?),
            ),
          ],
        );
        await tester.pumpWidget(
          BlocProvider<AuthSessionCubit>(
            create: (_) => cubit,
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        router.go('/verify', extra: 'route@example.com');
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.query, isEmpty);
        expect(find.text('r***@example.com'), findsOneWidget);
        expect(find.text('route@example.com'), findsNothing);
      },
    );

    testWidgets('falls back to the masked current Firebase user email', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          cubit: AuthSessionCubit(
            FakeAuthRepository(),
            FakeSecureStorageService(),
            FakeFirebaseAuthService(firebaseEmail: 'fallback@example.com'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('f***@example.com'), findsOneWidget);
      expect(find.text('fallback@example.com'), findsNothing);
    });

    testWidgets('keeps the verification actions available when email is absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          cubit: AuthSessionCubit(
            FakeAuthRepository(),
            FakeSecureStorageService(),
            FakeFirebaseAuthService(
              sendEmailVerificationError: FirebaseAuthException(
                code: 'no-current-user',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('I verified my email'), findsOneWidget);
      expect(find.text('Resend Verification Email'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);

      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();

      expect(
        find.text(
          'Your verification session has expired. Please sign in to request a new verification link.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('resend success starts and completes a 60-second cooldown', (
      tester,
    ) async {
      final firebase = FakeFirebaseAuthService();
      await tester.pumpWidget(
        _testApp(
          cubit: AuthSessionCubit(
            FakeAuthRepository(),
            FakeSecureStorageService(),
            firebase,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();

      expect(firebase.sendEmailVerificationCalls, 1);
      expect(
        find.text(
          'A fresh verification link has been sent to your email address.',
        ),
        findsOneWidget,
      );
      expect(find.text('Resend Email (60s)'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend Email (59s)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Resend Verification Email'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNotNull,
      );
    });

    testWidgets('resend loading prevents UI double-submit', (tester) async {
      final completer = Completer<void>();
      final firebase = FakeFirebaseAuthService(
        sendEmailVerificationCompleter: completer,
      );
      await tester.pumpWidget(
        _testApp(
          cubit: AuthSessionCubit(
            FakeAuthRepository(),
            FakeSecureStorageService(),
            firebase,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pump();

      expect(firebase.sendEmailVerificationCalls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );

      completer.complete();
      await tester.pump();
    });

    testWidgets('disposes the resend countdown when leaving the page', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          cubit: AuthSessionCubit(
            FakeAuthRepository(),
            FakeSecureStorageService(),
            FakeFirebaseAuthService(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 61));

      expect(tester.takeException(), isNull);
    });

    testWidgets('rate-limited resend shows a safe error and starts cooldown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          cubit: AuthSessionCubit(
            FakeAuthRepository(),
            FakeSecureStorageService(),
            FakeFirebaseAuthService(
              sendEmailVerificationError: FirebaseAuthException(
                code: 'too-many-requests',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();

      expect(
        find.text(
          'Too many resend attempts. Please wait a few minutes before trying again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Resend Email (60s)'), findsOneWidget);
    });

    testWidgets('network failure while resending shows a safe error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          cubit: AuthSessionCubit(
            FakeAuthRepository(),
            FakeSecureStorageService(),
            FakeFirebaseAuthService(
              sendEmailVerificationError: FirebaseAuthException(
                code: 'network-request-failed',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Resend Verification Email'));
      await tester.pump();

      expect(
        find.text(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Resend Verification Email'), findsOneWidget);
    });

    testWidgets('unverified email stays on the page with an actionable error', (
      tester,
    ) async {
      final cubit = AuthSessionCubit(
        FakeAuthRepository(),
        FakeSecureStorageService(),
        FakeFirebaseAuthService(emailVerified: false),
      );
      await tester.pumpWidget(_routerTestApp(cubit));

      await tester.tap(find.text('I verified my email'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(
        find.text('Please verify your email before continuing.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'unverified check exits loading and keeps an active resend countdown running',
      (tester) async {
        final repository = FakeAuthRepository();
        final cubit = AuthSessionCubit(
          repository,
          FakeSecureStorageService(),
          FakeFirebaseAuthService(emailVerified: false),
        );
        await tester.pumpWidget(_routerTestApp(cubit));

        await tester.tap(find.text('Resend Verification Email'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 7));
        expect(find.text('Resend Email (53s)'), findsOneWidget);

        await tester.tap(find.text('I verified my email'));
        await tester.pump();

        expect(cubit.state.isLoading, isFalse);
        expect(
          find.text('Please verify your email before continuing.'),
          findsOneWidget,
        );
        expect(find.text('I verified my email'), findsOneWidget);
        expect(repository.verifyEmailCalls, 0);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Resend Email (52s)'), findsOneWidget);
      },
    );

    testWidgets('backend verification failure stays on page without a session', (
      tester,
    ) async {
      final storage = FakeSecureStorageService();
      final cubit = AuthSessionCubit(
        FakeAuthRepository(
          verifyEmailError: const ServerException(
            'TripMate is temporarily unable to process your request. Please check your connection and try again.',
            'MSG127',
            500,
          ),
        ),
        storage,
        FakeFirebaseAuthService(refreshToken: 'refreshed-token'),
      );
      await tester.pumpWidget(_routerTestApp(cubit));

      await tester.tap(find.text('I verified my email'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(
        find.text(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(storage.values, isEmpty);
    });

    testWidgets('successful verification navigates to the Traveler area', (
      tester,
    ) async {
      final cubit = AuthSessionCubit(
        FakeAuthRepository(),
        FakeSecureStorageService(),
        FakeFirebaseAuthService(refreshToken: 'refreshed-token'),
      );
      await tester.pumpWidget(_routerTestApp(cubit));

      await tester.tap(find.text('I verified my email'));
      await tester.pumpAndSettle();

      expect(find.text('Traveler destination'), findsOneWidget);
    });

    testWidgets('Back to sign in navigates to the sign-in route', (
      tester,
    ) async {
      final cubit = AuthSessionCubit(
        FakeAuthRepository(),
        FakeSecureStorageService(),
        FakeFirebaseAuthService(),
      );
      await tester.pumpWidget(_routerTestApp(cubit));

      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in destination'), findsOneWidget);
    });
  });
}

Widget _testApp({required AuthSessionCubit cubit, String? email}) {
  return MaterialApp(
    home: BlocProvider<AuthSessionCubit>(
      create: (_) => cubit,
      child: VerifyEmailPage(email: email),
    ),
  );
}

Widget _routerTestApp(AuthSessionCubit cubit) {
  final router = GoRouter(
    initialLocation: '/verify',
    routes: [
      GoRoute(path: '/verify', builder: (_, _) => const VerifyEmailPage()),
      GoRoute(
        path: '/auth/login',
        builder: (_, _) => const Scaffold(body: Text('Sign in destination')),
      ),
      GoRoute(
        path: '/traveler',
        builder: (_, _) => const Scaffold(body: Text('Traveler destination')),
      ),
    ],
  );
  return BlocProvider<AuthSessionCubit>(
    create: (_) => cubit,
    child: MaterialApp.router(routerConfig: router),
  );
}

final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.verifyEmailError});

  final AppException? verifyEmailError;
  var verifyEmailCalls = 0;

  @override
  Future<SessionResponseDto> verifyEmail(String firebaseIdToken) async {
    verifyEmailCalls += 1;
    if (verifyEmailError != null) throw verifyEmailError!;
    return _session;
  }

  @override
  Future<SessionResponseDto> googleAuth(String firebaseIdToken) =>
      throw UnimplementedError();

  @override
  Future<SessionResponseDto> login(
    LoginRequest request, [
    String? firebaseIdToken,
  ]) => throw UnimplementedError();

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
    this.firebaseEmail,
    this.emailVerified = true,
    this.refreshError,
    this.refreshToken,
    this.sendEmailVerificationCompleter,
    this.sendEmailVerificationError,
  });

  final String? firebaseEmail;
  final bool emailVerified;
  final Object? refreshError;
  final String? refreshToken;
  final Completer<void>? sendEmailVerificationCompleter;
  final Object? sendEmailVerificationError;
  var sendEmailVerificationCalls = 0;

  @override
  Future<String?> get currentUserEmail async => firebaseEmail;

  @override
  Future<String?> refreshIdToken() async {
    if (refreshError != null) throw refreshError!;
    if (!emailVerified) return null;
    return refreshToken ?? 'refreshed-token';
  }

  @override
  Future<void> sendEmailVerification() async {
    sendEmailVerificationCalls += 1;
    if (sendEmailVerificationError != null) {
      throw sendEmailVerificationError!;
    }
    await sendEmailVerificationCompleter?.future;
  }

  @override
  Future<bool> get isEmailVerified async => emailVerified;

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<String> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

const _session = SessionResponseDto(
  userId: 1,
  status: 'Active',
  accessToken: 'backend-access-token',
  refreshToken: 'backend-refresh-token',
);
