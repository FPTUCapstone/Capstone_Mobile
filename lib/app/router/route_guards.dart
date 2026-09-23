import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

abstract final class RouteGuards {
  static String? redirect(AuthSessionState session, GoRouterState routerState) {
    final location = routerState.matchedLocation;
    final isAuthRoute = location.startsWith(AppRoutes.authPrefix);
    final isTravelerRoute = _isInScope(location, AppRoutes.travelerPrefix);
    final isOperatorRoute = _isInScope(location, AppRoutes.operatorPrefix);
    final isProtectedRoute = isTravelerRoute || isOperatorRoute;

    if (!session.isAuthenticated) {
      if (isProtectedRoute) {
        return Uri(
          path: AppRoutes.login,
          queryParameters: {'from': routerState.uri.toString()},
        ).toString();
      }
      if (location == AppRoutes.splash) {
        return AppRoutes.login;
      }
      return null;
    }

    // Operator destinations are decided by the backend-issued application
    // status only: approved reaches the workspace; every other value is
    // confined to the application view. Nothing is
    // inferred locally, so unresolved fails closed and never exposes approved
    // Operator content.
    final operatorHome =
        session.applicationStatus == TourOperatorApplicationStatus.approved
        ? AppRoutes.operator
        : AppRoutes.operatorApplication;
    final home = session.role == UserRole.traveler
        ? AppRoutes.traveler
        : operatorHome;

    if (location == AppRoutes.login) {
      return _safeReturnLocation(session, routerState.uri) ?? home;
    }
    if (location == AppRoutes.splash || isAuthRoute) {
      return home;
    }
    if (session.role == UserRole.traveler && isOperatorRoute) {
      return AppRoutes.traveler;
    }
    if (session.role == UserRole.tourOperator) {
      if (isTravelerRoute) {
        return operatorHome;
      }
      // A non-approved operator may never remain on the approved workspace.
      if (location == AppRoutes.operator &&
          session.applicationStatus != TourOperatorApplicationStatus.approved) {
        return AppRoutes.operatorApplication;
      }
    }
    return null;
  }

  static bool _isInScope(String path, String prefix) =>
      path == prefix || path.startsWith('$prefix/');

  static String? _safeReturnLocation(AuthSessionState session, Uri loginUri) {
    final rawTarget = loginUri.queryParameters['from'];
    if (rawTarget == null) return null;
    final target = Uri.tryParse(rawTarget);
    if (target == null ||
        target.hasScheme ||
        target.hasAuthority ||
        !target.path.startsWith('/')) {
      return null;
    }

    if (session.role == UserRole.traveler &&
        _isInScope(target.path, AppRoutes.travelerPrefix)) {
      return target.toString();
    }
    if (session.role == UserRole.tourOperator &&
        _isInScope(target.path, AppRoutes.operatorPrefix) &&
        (session.applicationStatus == TourOperatorApplicationStatus.approved ||
            target.path == AppRoutes.operatorApplication)) {
      return target.toString();
    }
    return null;
  }
}
