import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

abstract final class RouteGuards {
  static String? redirect(AuthSessionState session, GoRouterState routerState) {
    final location = routerState.matchedLocation;
    final isAuthRoute = location.startsWith(AppRoutes.authPrefix);
    final isTravelerRoute = location.startsWith(AppRoutes.travelerPrefix);
    final isOperatorRoute = location.startsWith(AppRoutes.operatorPrefix);
    final isProtectedRoute = isTravelerRoute || isOperatorRoute;

    if (!session.isAuthenticated) {
      if (location == AppRoutes.splash || isProtectedRoute) {
        return AppRoutes.login;
      }
      return null;
    }

    final home = switch (session.role) {
      UserRole.traveler => AppRoutes.traveler,
      UserRole.tourOperator when session.isRejectedOperator =>
        AppRoutes.operatorApplication,
      _ => AppRoutes.operator,
    };

    if (location == AppRoutes.splash || isAuthRoute) {
      return home;
    }
    if (session.role == UserRole.traveler && isOperatorRoute) {
      return AppRoutes.traveler;
    }
    if (session.role == UserRole.tourOperator && isTravelerRoute) {
      return AppRoutes.operator;
    }
    return null;
  }
}
