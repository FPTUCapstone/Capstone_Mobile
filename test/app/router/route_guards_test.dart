import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

void main() {
  testWidgets('authenticated Traveler leaves Sign In for the Traveler area', (
    tester,
  ) async {
    const session = AuthSessionState.authenticated(UserRole.traveler);
    final router = GoRouter(
      initialLocation: AppRoutes.login,
      redirect: (_, state) => RouteGuards.redirect(session, state),
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Text('Sign In'),
        ),
        GoRoute(
          path: AppRoutes.traveler,
          builder: (_, _) => const Text('Traveler area'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Traveler area'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
  });

  Future<String> resolve(
    WidgetTester tester,
    AuthSessionState session,
    String location,
  ) async {
    final router = GoRouter(
      initialLocation: location,
      redirect: (_, state) => RouteGuards.redirect(session, state),
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Text('Sign In'),
        ),
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

  testWidgets('TourOperator Approved lands on the operator workspace', (
    tester,
  ) async {
    const session = AuthSessionState.authenticated(
      UserRole.tourOperator,
      applicationStatus: TourOperatorApplicationStatus.approved,
    );
    expect(await resolve(tester, session, AppRoutes.login), AppRoutes.operator);
  });

  testWidgets('TourOperator PendingApproval lands on the application view', (
    tester,
  ) async {
    const session = AuthSessionState.authenticated(
      UserRole.tourOperator,
      applicationStatus: TourOperatorApplicationStatus.pendingApproval,
    );
    expect(
      await resolve(tester, session, AppRoutes.operator),
      AppRoutes.operatorApplication,
    );
  });

  testWidgets('TourOperator Rejected lands on the application view', (
    tester,
  ) async {
    const session = AuthSessionState.authenticated(
      UserRole.tourOperator,
      applicationStatus: TourOperatorApplicationStatus.rejected,
    );
    expect(
      await resolve(tester, session, AppRoutes.operator),
      AppRoutes.operatorApplication,
    );
  });

  testWidgets('TourOperator unresolved fails closed to the application view', (
    tester,
  ) async {
    const session = AuthSessionState.authenticated(UserRole.tourOperator);
    expect(
      await resolve(tester, session, AppRoutes.operator),
      AppRoutes.operatorApplication,
    );
  });

  testWidgets('Traveler stays on the traveler area', (tester) async {
    const session = AuthSessionState.authenticated(UserRole.traveler);
    expect(
      await resolve(tester, session, AppRoutes.operator),
      AppRoutes.traveler,
    );
  });

  // UC-05 T09: the post-sign-out direction — an unauthenticated session on a
  // protected route must be sent to the sign-in screen by the guard alone.
  testWidgets(
    'an unauthenticated session is sent from protected routes to Sign In',
    (tester) async {
      const session = AuthSessionState.unauthenticated();
      expect(
        await resolve(tester, session, AppRoutes.traveler),
        AppRoutes.login,
      );
      expect(
        await resolve(tester, session, AppRoutes.operator),
        AppRoutes.login,
      );
    },
  );

  testWidgets(
    'a local cleanup failure stays on the protected route for retry',
    (tester) async {
      const session = AuthSessionState.authenticated(
        UserRole.traveler,
        errorMessage: AuthSessionCubit.signOutLocalCleanupFailureMessage,
      );

      expect(
        await resolve(tester, session, AppRoutes.traveler),
        AppRoutes.traveler,
      );
      expect(find.text('Traveler area'), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
    },
  );

  testWidgets(
    'real router does not redirect until pending sign-out completes locally',
    (tester) async {
      final logoutCompleter = Completer<void>();
      final storage = _MemoryStorage({
        AppConstants.accessTokenKey: 'access',
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'traveler',
        AppConstants.keepSignedInKey: 'true',
      });
      final session = AuthSessionCubit(
        _PendingLogoutRepository(logoutCompleter),
        storage,
      );
      addTearDown(session.close);
      await session.restoreSession();

      final router = createAppRouter(session);
      addTearDown(router.dispose);
      router.go(AppRoutes.travelerSettings);
      await tester.pumpWidget(
        BlocProvider<AuthSessionCubit>.value(
          value: session,
          child: BlocListener<AuthSessionCubit, Object?>(
            listener: (_, _) => router.refresh(),
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.travelerSettings,
      );

      final pending = session.signOut();
      await tester.pump();

      expect(session.state.operation, AuthSessionOperation.signOut);
      expect(session.state.isAuthenticated, isTrue);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.travelerSettings,
      );

      logoutCompleter.complete();
      await pending;
      await tester.pumpAndSettle();

      expect(session.state.isAuthenticated, isFalse);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.login,
      );
    },
  );

  testWidgets(
    'expired session restores the invitation after Traveler sign in',
    (tester) async {
      const invitation = '/traveler/groups/42/invitation?source=notification';
      var session = const AuthSessionState.authenticated(UserRole.traveler);
      final router = GoRouter(
        initialLocation: invitation,
        redirect: (_, state) => RouteGuards.redirect(session, state),
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const Text('Sign In'),
          ),
          GoRoute(
            path: AppRoutes.traveler,
            builder: (_, _) => const Text('Traveler area'),
          ),
          GoRoute(
            path: AppRoutes.inviteGroupMembers,
            builder: (_, _) => const Text('Invitation'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Invitation'), findsOneWidget);

      session = const AuthSessionState.unauthenticated();
      router.refresh();
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['from'],
        invitation,
      );

      session = const AuthSessionState.authenticated(UserRole.traveler);
      router.refresh();
      await tester.pumpAndSettle();

      expect(find.text('Invitation'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.toString(), invitation);
    },
  );

  testWidgets('operator cannot restore a Traveler invitation after sign in', (
    tester,
  ) async {
    const session = AuthSessionState.authenticated(
      UserRole.tourOperator,
      applicationStatus: TourOperatorApplicationStatus.approved,
    );
    final login = Uri(
      path: AppRoutes.login,
      queryParameters: {'from': '/traveler/groups/42/invitation'},
    ).toString();

    expect(await resolve(tester, session, login), AppRoutes.operator);
  });

  testWidgets('external return targets fall back to the Traveler home', (
    tester,
  ) async {
    const session = AuthSessionState.authenticated(UserRole.traveler);
    for (final target in ['https://example.com', '//example.com/traveler']) {
      final login = Uri(
        path: AppRoutes.login,
        queryParameters: {'from': target},
      ).toString();
      expect(await resolve(tester, session, login), AppRoutes.traveler);
    }
  });
}

final class _PendingLogoutRepository implements AuthRepository {
  const _PendingLogoutRepository(this.logoutCompleter);

  final Completer<void> logoutCompleter;

  @override
  Future<void> logout(String? refreshToken) => logoutCompleter.future;

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
