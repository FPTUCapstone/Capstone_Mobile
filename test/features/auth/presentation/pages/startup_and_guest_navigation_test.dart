import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:trip_mate_mobile/features/guest/presentation/pages/guest_landing_page.dart';

void main() {
  testWidgets('SplashPage Get started button navigates to Guest Home', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.splash,
      routes: [
        GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
        GoRoute(
          path: AppRoutes.guestHome,
          builder: (_, _) =>
              const Scaffold(body: Text('Guest Home Destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    );
    await tester.pumpAndSettle();

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Guest Home Destination'), findsOneWidget);
  });

  testWidgets(
    'LoginPage "Duyệt khám phá không cần đăng nhập" navigates to Guest Home',
    (tester) async {
      final sessionCubit = AuthSessionCubit(
        _FakeAuthRepository(),
        _MemoryStorage(),
      );
      addTearDown(sessionCubit.close);

      final router = GoRouter(
        initialLocation: AppRoutes.login,
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => BlocProvider<AuthSessionCubit>.value(
              value: sessionCubit,
              child: const LoginPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.guestHome,
            builder: (_, _) =>
                const Scaffold(body: Text('Guest Home Destination')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      );
      await tester.pumpAndSettle();

      final exploreButton = find.text('Duyệt khám phá không cần đăng nhập');
      await tester.scrollUntilVisible(
        exploreButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(exploreButton, findsOneWidget);

      await tester.tap(exploreButton);
      await tester.pumpAndSettle();

      expect(find.text('Guest Home Destination'), findsOneWidget);
    },
  );

  testWidgets(
    'GuestLandingPage "Lên lịch trình cùng AI" navigates to Login with createItinerary return target',
    (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.guestHome,
        routes: [
          GoRoute(
            path: AppRoutes.guestHome,
            builder: (_, _) => const GuestLandingPage(),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (context, state) {
              final from = state.uri.queryParameters['from'];
              return Scaffold(body: Text('Login Screen: from=$from'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      );
      await tester.pumpAndSettle();

      final ctaButton = find.text('Lên lịch trình cùng AI');
      await tester.scrollUntilVisible(
        ctaButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(ctaButton, findsOneWidget);
      await tester.tap(ctaButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Login Screen: from=${AppRoutes.createItinerary}'),
        findsOneWidget,
      );
    },
  );
}

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage();

  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login(
    AuthCredentials credentials, [
    String? firebaseIdToken,
  ]) => throw UnimplementedError();

  @override
  Future<AuthSession> googleAuth(String firebaseIdToken) =>
      throw UnimplementedError();

  @override
  Future<TravelerRegistrationResult> registerTraveler(
    TravelerRegistration registration,
    String firebaseIdToken,
  ) => throw UnimplementedError();

  @override
  Future<AuthSession> verifyEmail(String firebaseIdToken) =>
      throw UnimplementedError();

  @override
  Future<void> logout(String? refreshToken) => throw UnimplementedError();
}
