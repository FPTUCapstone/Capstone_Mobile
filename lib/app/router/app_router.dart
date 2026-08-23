import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/registration_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/pages/operator_shell_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_shell_page.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

GoRouter createAppRouter(AuthSessionCubit sessionCubit) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (_, state) => RouteGuards.redirect(sessionCubit.state, state),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRouteNames.splash,
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRouteNames.login,
        builder: (_, _) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.travelerRegistration,
        name: AppRouteNames.travelerRegistration,
        builder: (_, _) => const RegistrationPage(role: UserRole.traveler),
      ),
      GoRoute(
        path: AppRoutes.operatorRegistration,
        name: AppRouteNames.operatorRegistration,
        builder: (_, _) => const RegistrationPage(role: UserRole.tourOperator),
      ),
      GoRoute(
        path: AppRoutes.traveler,
        name: AppRouteNames.traveler,
        builder: (_, _) => const TravelerShellPage(),
      ),
      GoRoute(
        path: AppRoutes.operator,
        name: AppRouteNames.operator,
        builder: (_, _) => const OperatorShellPage(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: ErrorView(message: state.error?.toString() ?? 'Page not found.'),
    ),
  );
}
