import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

void main() {
  const approved = AuthSessionState.authenticated(
    UserRole.tourOperator,
    applicationStatus: TourOperatorApplicationStatus.approved,
  );
  const pending = AuthSessionState.authenticated(
    UserRole.tourOperator,
    applicationStatus: TourOperatorApplicationStatus.pendingApproval,
  );
  const rejected = AuthSessionState.authenticated(
    UserRole.tourOperator,
    applicationStatus: TourOperatorApplicationStatus.rejected,
  );
  const traveler = AuthSessionState.authenticated(UserRole.traveler);
  const signedOut = AuthSessionState.unauthenticated();

  final inbox = AppRoutes.operatorSafetyReviews;
  final detail = AppRoutes.operatorSafetyReviewPath(7);
  final decision = AppRoutes.operatorEmergencyDecisionPath(
    tourId: 12,
    scheduleId: 31,
  );
  final notice = AppRoutes.travelerEmergency(42);

  Future<String> resolve(
    WidgetTester tester,
    AuthSessionState session,
    String location,
  ) async {
    Widget here(BuildContext _, GoRouterState state) =>
        Text(state.uri.toString());
    final router = GoRouter(
      initialLocation: location,
      redirect: (_, state) => RouteGuards.redirect(session, state),
      routes: [
        for (final path in [
          AppRoutes.login,
          AppRoutes.traveler,
          AppRoutes.operator,
          AppRoutes.operatorApplication,
          AppRoutes.operatorSafetyReviews,
          AppRoutes.operatorSafetyReview,
          AppRoutes.operatorEmergencyDecision,
          AppRoutes.travelerEmergencyPattern,
        ])
          GoRoute(path: path, builder: here),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router.routeInformationProvider.value.uri.toString();
  }

  test('routes stay in the role scopes and name no Administrator', () {
    for (final path in [inbox, detail, decision]) {
      expect(path, startsWith('/operator/'));
    }
    expect(notice, startsWith('/traveler/'));
  });

  testWidgets('an approved Operator reaches every Operator route', (
    tester,
  ) async {
    for (final path in [inbox, detail, decision]) {
      expect(await resolve(tester, approved, path), path);
    }
  });

  testWidgets(
    'pending and rejected Operators are confined to the application',
    (tester) async {
      for (final session in [pending, rejected]) {
        for (final path in [inbox, detail, decision]) {
          expect(
            await resolve(tester, session, path),
            AppRoutes.operatorApplication,
          );
        }
      }
    },
  );

  testWidgets('a Traveler cannot reach Operator routes', (tester) async {
    for (final path in [inbox, detail, decision]) {
      expect(await resolve(tester, traveler, path), AppRoutes.traveler);
    }
  });

  testWidgets('a Traveler reaches the notice and an Operator does not', (
    tester,
  ) async {
    expect(await resolve(tester, traveler, notice), notice);
    expect(await resolve(tester, approved, notice), AppRoutes.operator);
  });

  testWidgets('signed out goes to Sign In remembering only the route', (
    tester,
  ) async {
    for (final path in [detail, notice]) {
      final uri = Uri.parse(await resolve(tester, signedOut, path));
      expect(uri.path, AppRoutes.login);
      expect(uri.queryParameters['from'], path);
    }
  });
}
