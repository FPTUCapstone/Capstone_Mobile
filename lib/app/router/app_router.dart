import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/password_demo_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/change_password_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/demo_screen_index_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_application_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_registration_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/reset_password_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/traveler_registration_page.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/pages/operator_shell_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/create_travel_group_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/invite_group_members_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_preferences_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_profile_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_settings_page.dart';
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
        builder: (_, _) => const TravelerRegistrationPage(),
      ),
      GoRoute(
        path: AppRoutes.operatorRegistration,
        name: AppRouteNames.operatorRegistration,
        builder: (_, _) => BlocProvider(
          create: (_) => OperatorApplicationCubit(
            initialStatus: OperatorApplicationStatus.draft,
          ),
          child: const OperatorRegistrationPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        name: AppRouteNames.resetPassword,
        builder: (_, _) => BlocProvider(
          create: (_) => PasswordDemoCubit(),
          child: const ResetPasswordPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.traveler,
        name: AppRouteNames.traveler,
        builder: (_, _) => const TravelerShellPage(),
      ),
      GoRoute(
        path: AppRoutes.travelerSettings,
        name: AppRouteNames.travelerSettings,
        builder: (_, _) => const TravelerSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.travelerProfile,
        name: AppRouteNames.travelerProfile,
        builder: (_, _) => const TravelerProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.travelerPreferences,
        name: AppRouteNames.travelerPreferences,
        builder: (_, _) => BlocProvider(
          create: (_) => TravelPreferencesCubit(),
          child: const TravelPreferencesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.travelerChangePassword,
        name: AppRouteNames.travelerChangePassword,
        builder: (_, _) => BlocProvider(
          create: (_) => PasswordDemoCubit(),
          child: const ChangePasswordPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.createTravelGroup,
        name: AppRouteNames.createTravelGroup,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final itineraryId = extra?['itineraryId'] as int?;
          final itineraryTitle = extra?['itineraryTitle'] as String?;
          return BlocProvider(
            create: (_) => CreateTravelGroupCubit(repository: serviceLocator()),
            child: CreateTravelGroupPage(
              itineraryId: itineraryId,
              itineraryTitle: itineraryTitle,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.inviteGroupMembers,
        name: AppRouteNames.inviteGroupMembers,
        builder: (_, state) {
          final groupId = int.tryParse(state.pathParameters['groupId'] ?? '');
          if (groupId == null || groupId <= 0) {
            return const Scaffold(body: ErrorView(message: 'Page not found.'));
          }
          return BlocProvider(
            create: (_) =>
                InviteGroupMembersCubit(repository: serviceLocator()),
            child: InviteGroupMembersPage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.operator,
        name: AppRouteNames.operator,
        builder: (_, _) => const OperatorShellPage(),
      ),
      GoRoute(
        path: AppRoutes.operatorApplication,
        name: AppRouteNames.operatorApplication,
        builder: (_, state) => BlocProvider(
          create: (_) => OperatorApplicationCubit(
            initialStatus:
                state.extra as OperatorApplicationStatus? ??
                OperatorApplicationStatus.rejected,
          ),
          child: const OperatorApplicationPage(),
        ),
      ),
      if (kDebugMode) ..._demoRoutes,
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: ErrorView(message: state.error?.toString() ?? 'Page not found.'),
    ),
  );
}

final _demoRoutes = <RouteBase>[
  GoRoute(
    path: AppRoutes.demoIndex,
    name: AppRouteNames.demoIndex,
    builder: (_, _) => const DemoScreenIndexPage(),
  ),
  GoRoute(
    path: AppRoutes.demoUc01,
    builder: (_, _) => const TravelerRegistrationPage(),
  ),
  GoRoute(
    path: AppRoutes.demoUc02,
    builder: (_, _) => BlocProvider(
      create: (_) => OperatorApplicationCubit(
        initialStatus: OperatorApplicationStatus.draft,
      ),
      child: const OperatorRegistrationPage(),
    ),
  ),
  GoRoute(
    path: AppRoutes.demoUc03,
    builder: (_, _) => BlocProvider(
      create: (_) => OperatorApplicationCubit(),
      child: const OperatorApplicationPage(),
    ),
  ),
  GoRoute(path: AppRoutes.demoUc04, builder: (_, _) => const LoginPage()),
  GoRoute(
    path: AppRoutes.demoUc05,
    builder: (_, _) => const TravelerSettingsPage(),
  ),
  GoRoute(
    path: AppRoutes.demoUc06,
    builder: (_, _) => BlocProvider(
      create: (_) => PasswordDemoCubit(),
      child: const ResetPasswordPage(),
    ),
  ),
  GoRoute(
    path: AppRoutes.demoUc07,
    builder: (_, _) => BlocProvider(
      create: (_) => PasswordDemoCubit(),
      child: const ChangePasswordPage(),
    ),
  ),
  GoRoute(
    path: AppRoutes.demoUc08,
    builder: (_, _) => const TravelerProfilePage(),
  ),
  GoRoute(
    path: AppRoutes.demoUc09,
    builder: (_, _) => BlocProvider(
      create: (_) => TravelPreferencesCubit(),
      child: const TravelPreferencesPage(),
    ),
  ),
  GoRoute(
    path: AppRoutes.demoUc17,
    builder: (_, state) {
      final extra = state.extra as Map<String, dynamic>?;
      final itineraryId = extra?['itineraryId'] as int?;
      final itineraryTitle = extra?['itineraryTitle'] as String?;
      return BlocProvider(
        create: (_) => CreateTravelGroupCubit(repository: serviceLocator()),
        child: CreateTravelGroupPage(
          itineraryId: itineraryId,
          itineraryTitle: itineraryTitle,
        ),
      );
    },
  ),
];
