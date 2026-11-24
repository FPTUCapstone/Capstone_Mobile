import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

void main() {
  Future<String> resolve(WidgetTester tester, String initial) async {
    const session = AuthSessionState.offlineReadOnly(7);
    final router = GoRouter(
      initialLocation: initial,
      redirect: (_, state) => RouteGuards.redirect(session, state),
      routes: [
        for (final path in [
          AppRoutes.splash,
          AppRoutes.login,
          '/traveler/offline-packages',
          '/traveler/trips/:itineraryId/offline',
          '/traveler/trips/:itineraryId/offline/view',
          '/traveler/trips/:itineraryId/offline/map',
          AppRoutes.traveler,
          '/operator',
          '/explore/tours/:id/book',
        ])
          GoRoute(path: path, builder: (_, _) => Text(path)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router.routeInformationProvider.value.uri.path;
  }

  testWidgets('offline identity opens only local package routes', (
    tester,
  ) async {
    for (final path in [
      '/traveler/offline-packages',
      '/traveler/trips/11/offline',
      '/traveler/trips/11/offline/view',
      '/traveler/trips/11/offline/map',
    ]) {
      expect(await resolve(tester, path), path);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets(
    'offline identity cannot enter online traveler/operator/booking routes',
    (tester) async {
      for (final path in [
        AppRoutes.traveler,
        '/operator',
        '/explore/tours/2/book',
        '/traveler/trips/0/offline',
      ]) {
        expect(await resolve(tester, path), AppRoutes.login);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'offline restart leads to retained list while sign-in stays reachable',
    (tester) async {
      expect(
        await resolve(tester, AppRoutes.splash),
        '/traveler/offline-packages',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(await resolve(tester, AppRoutes.login), AppRoutes.login);
    },
  );
}
