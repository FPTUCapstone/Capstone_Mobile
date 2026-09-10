import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
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
}
