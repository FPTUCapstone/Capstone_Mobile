import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/create_travel_group_route_args.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_application_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_registration_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/traveler_registration_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/verify_email_page.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/pages/operator_shell_page.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/create_travel_group_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_details_page.dart';
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
        path: AppRoutes.verifyEmail,
        name: AppRouteNames.verifyEmail,
        builder: (_, state) => VerifyEmailPage(
          email: state.extra is String ? state.extra as String : null,
        ),
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
        path: AppRoutes.createTravelGroup,
        name: AppRouteNames.createTravelGroup,
        builder: (_, state) {
          final args = state.extra;
          if (args is! CreateTravelGroupRouteArgs || args.itineraryId <= 0) {
            return const ErrorView(message: 'A valid itinerary is required.');
          }
          return BlocProvider(
            create: (_) => CreateTravelGroupCubit(repository: serviceLocator()),
            child: CreateTravelGroupPage(
              itineraryId: args.itineraryId,
              itineraryTitle: args.itineraryTitle,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.travelGroupDetails,
        name: AppRouteNames.travelGroupDetails,
        builder: (_, state) {
          final groupId = int.tryParse(state.pathParameters['groupId'] ?? '');
          if (groupId == null || groupId <= 0) {
            return const ErrorView(message: 'Page not found.');
          }
          return TravelGroupDetailsPage(
            groupId: groupId,
            group: state.extra is TravelGroup
                ? state.extra as TravelGroup
                : null,
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
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: ErrorView(message: state.error?.toString() ?? 'Page not found.'),
    ),
  );
}
