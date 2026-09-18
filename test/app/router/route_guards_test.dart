import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
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
}
