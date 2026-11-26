import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/create_travel_group_route_args.dart';
import 'package:trip_mate_mobile/app/router/notification_destinations.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/app/router/travel_group_details_route_args.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/platform/device_window.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_cubit.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/pages/change_password_page.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_cubit.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/pages/password_recovery_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_application_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/operator_email_recovery_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/register_operator_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_application_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_email_recovery_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/operator_registration_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/resubmit_operator_application_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/traveler_registration_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/verify_email_page.dart';
import 'package:trip_mate_mobile/features/auth/presentation/services/operator_document_picker.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/presentation/cubit/book_tour_cubit.dart';
import 'package:trip_mate_mobile/features/booking/presentation/pages/book_tour_page.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/cubit/booking_refund_progress_cubit.dart';
import 'package:trip_mate_mobile/features/booking_refund/presentation/pages/booking_refund_progress_page.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/commercial_booking_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/commercial_booking_page.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/commercial_booking_requests_page.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/cubit/create_coupon_cubit.dart';
import 'package:trip_mate_mobile/features/coupon/presentation/pages/create_coupon_page.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/usecases/get_e_ticket_use_case.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/cubit/e_ticket_cubit.dart';
import 'package:trip_mate_mobile/features/e_ticket/presentation/pages/e_ticket_page.dart';
import 'package:trip_mate_mobile/features/e_ticket/resources/e_ticket_en.dart';
import 'package:trip_mate_mobile/features/guest/presentation/pages/guest_landing_page.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/pages/messenger_page.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/cubit/in_app_inbox_cubit.dart';
import 'package:trip_mate_mobile/features/notifications/presentation/pages/in_app_inbox_page.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_booking_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/pages/operator_booking_detail_page.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/pages/operator_check_in_page.dart';
import 'package:trip_mate_mobile/features/operator_contracts/domain/repositories/operator_contract_repository.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/cubit/operator_contract_cubit.dart';
import 'package:trip_mate_mobile/features/operator_contracts/presentation/pages/operator_contract_page.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/pages/operator_settlement_history_page.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/operator_tours_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/create_tour_package_page.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/edit_tour_package_page.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/operator_tours_page.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_evidence_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_review_detail_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/pages/emergency_decision_page.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/pages/operator_safety_review_detail_page.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/pages/operator_safety_reviews_page.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/cubit/partial_refund_proposal_cubit.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/pages/partial_refund_proposal_page.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/resources/partial_refund_proposal_en.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_cubit.dart';
import 'package:trip_mate_mobile/features/payment/presentation/pages/payment_page.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/explore_poi_page.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/poi_detail_page.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/my_post_trip_complaints_cubit.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/cubit/post_trip_complaint_cubit.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/pages/my_post_trip_complaints_page.dart';
import 'package:trip_mate_mobile/features/post_trip_complaints/presentation/pages/post_trip_complaint_page.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/support_chat/presentation/cubit/support_chat_cubit.dart';
import 'package:trip_mate_mobile/features/support_chat/presentation/pages/support_chat_page.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/pages/tour_detail_page.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_profile.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/cubit/operator_profile_cubit.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/pages/operator_profile_edit_page.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/pages/operator_shell_page.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/pages/tour_recommendations_page.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/pages/tour_search_page.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/pending_explanation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/address_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/join_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_preferences_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/active_trip_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/create_itinerary_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/create_travel_group_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/group_location_sharing_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/invite_group_members_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_detail_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_result_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/join_travel_group_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_itinerary_map_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_itinerary_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_packages_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_trip_package_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_details_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_members_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_preferences_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_profile_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_settings_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_shell_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/trip_alerts_page.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_cubit.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_notices_cubit.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/pages/traveler_emergency_page.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/canonical_trip_review_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/pages/canonical_trip_review_page.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/pages/trip_history_page.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/pages/trip_review_page.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

/// Demo mode for operator check-in is strictly debug-only per the project routing convention.
/// Release builds ignore any `demo=true` query parameter and strictly route to the live Backend.
@visibleForTesting
bool resolveOperatorCheckInDemo(Uri uri, {bool isDebug = kDebugMode}) =>
    isDebug && uri.queryParameters['demo'] == 'true';

GoRouter createAppRouter(
  AuthSessionCubit sessionCubit, {
  bool isDebug = kDebugMode,
}) {
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
        builder: (_, state) => LoginPage(
          notice: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: AppRouteNames.forgotPassword,
        builder: (_, _) => BlocProvider(
          create: (_) => serviceLocator<PasswordRecoveryCubit>(),
          child: const PasswordRecoveryPage(),
        ),
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
          create: (_) => serviceLocator<RegisterOperatorCubit>(),
          child: OperatorRegistrationPage(
            documentPicker: serviceLocator<OperatorDocumentPicker>(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.operatorEmailRecovery,
        name: AppRouteNames.operatorEmailRecovery,
        builder: (_, state) => BlocProvider(
          create: (_) => serviceLocator<OperatorEmailRecoveryCubit>(),
          child: OperatorEmailRecoveryPage(
            email: state.extra is String ? state.extra as String : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.explore,
        name: AppRouteNames.explore,
        builder: (_, _) =>
            sessionCubit.state.isAuthenticated &&
                sessionCubit.state.role == UserRole.traveler
            ? const TravelerShellPage(initialSection: TravelerSectionId.explore)
            : BlocProvider(
                create: (_) => serviceLocator<PoiListCubit>()..loadInitial(),
                child: ExplorePoiPage(
                  isTraveler: sessionCubit.state.role == UserRole.traveler,
                ),
              ),
      ),
      GoRoute(
        path: AppRoutes.guestHome,
        name: AppRouteNames.guestHome,
        builder: (_, _) => const GuestLandingPage(),
      ),
      GoRoute(
        path: AppRoutes.poiDetailPattern,
        name: AppRouteNames.poiDetail,
        builder: (_, state) => BlocProvider(
          create: (_) =>
              serviceLocator<PoiDetailCubit>()
                ..load(state.pathParameters['id'] ?? ''),
          child: PoiDetailPage(
            isTraveler: sessionCubit.state.role == UserRole.traveler,
            itineraryId: _positiveId(state.uri.queryParameters['itineraryId']),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.commercialBookingRequests,
        builder: (_, _) => BlocProvider(
          create: (_) => serviceLocator<CommercialBookingCubit>(),
          child: const CommercialBookingRequestsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.commercialBookingPattern,
        builder: (_, state) {
          final poiId = _positiveId(state.pathParameters['poiId']);
          if (poiId == null) return const _RouteNotFound();
          return BlocProvider(
            key: ValueKey(state.uri),
            create: (_) => serviceLocator<CommercialBookingCubit>(),
            child: CommercialBookingPage(
              poiId: poiId,
              itineraryId: _positiveId(
                state.uri.queryParameters['itineraryId'],
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.tourSearch,
        name: AppRouteNames.tourSearch,
        builder: (_, _) =>
            sessionCubit.state.isAuthenticated &&
                sessionCubit.state.role == UserRole.traveler
            ? const TravelerShellPage(
                initialSection: TravelerSectionId.bookings,
              )
            : BlocProvider(
                create: (_) => serviceLocator<TourSearchCubit>()..loadInitial(),
                child: TourSearchPage(
                  isTraveler: sessionCubit.state.role == UserRole.traveler,
                ),
              ),
      ),
      GoRoute(
        path: AppRoutes.tourDetailPattern,
        name: AppRouteNames.tourDetail,
        builder: (_, state) {
          final tourId = state.pathParameters['tourId'] ?? '';
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          final summary = state.extra is TourSummary
              ? state.extra as TourSummary
              : null;
          final heroTag = state.uri.queryParameters['heroTag'];
          return TourDetailPage(
            tourId: tourId,
            initialSummary: summary,
            heroTag: heroTag,
            isDemoMode: isDemo,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.bookTourPattern,
        name: AppRouteNames.bookTour,
        redirect: (_, state) {
          final scheduleId = state.uri.queryParameters['scheduleId'];
          if (scheduleId != null && scheduleId.isNotEmpty) return null;
          return AppRoutes.tourDetail(state.pathParameters['tourId'] ?? '');
        },
        builder: (_, state) {
          final scheduleId = state.uri.queryParameters['scheduleId']!;
          final adults = int.tryParse(
            state.uri.queryParameters['adults'] ?? '',
          );
          return BlocProvider(
            create: (_) => serviceLocator<BookTourCubit>(
              param1: scheduleId,
              param2: adults == null
                  ? null
                  : ParticipantCounts(
                      adult: adults,
                      child:
                          int.tryParse(
                            state.uri.queryParameters['children'] ?? '0',
                          ) ??
                          -1,
                      infant:
                          int.tryParse(
                            state.uri.queryParameters['infants'] ?? '0',
                          ) ??
                          -1,
                    ),
            ),
            child: const BookTourPage(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.paymentPattern,
        name: AppRouteNames.payment,
        builder: (_, state) {
          final bookingId = state.pathParameters['bookingId']!;
          final bookingCode = state.uri.queryParameters['code'];
          final amountStr = state.uri.queryParameters['amount'];
          final currency = state.uri.queryParameters['currency'];
          final amount = amountStr != null ? int.tryParse(amountStr) : null;

          return BlocProvider(
            create: (_) => serviceLocator<PaymentCubit>(),
            child: PaymentPage(
              bookingId: bookingId,
              initialBookingCode: bookingCode,
              initialAmount: amount,
              initialCurrency: currency,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.bookingRefundPattern,
        name: AppRouteNames.bookingRefund,
        builder: (_, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          if (int.tryParse(bookingId) == null || int.parse(bookingId) <= 0) {
            return const Scaffold(
              body: ErrorView(message: 'Refund information is unavailable.'),
            );
          }
          return BlocProvider(
            create: (_) => serviceLocator<BookingRefundProgressCubit>(),
            child: BookingRefundProgressPage(bookingId: bookingId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.partialRefundProposalPattern,
        name: AppRouteNames.partialRefundProposal,
        builder: (_, state) {
          final complaintId = int.tryParse(
            state.pathParameters['complaintId'] ?? '',
          );
          if (complaintId == null || complaintId <= 0) {
            return const Scaffold(
              body: ErrorView(message: PartialRefundProposalStrings.notFound),
            );
          }
          return BlocProvider(
            // A new complaint id must get a new cubit, e.g. when a notification
            // for another complaint is opened while this screen is showing.
            key: ValueKey('partial-refund-proposal-$complaintId'),
            create: (_) =>
                serviceLocator<PartialRefundProposalCubit>(param1: complaintId),
            child: const PartialRefundProposalPage(),
          );
        },
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
      for (final path in [AppRoutes.supportChat, AppRoutes.operatorSupportChat])
        GoRoute(
          path: path,
          builder: (_, state) => BlocProvider(
            create: (_) {
              final cubit = SupportChatCubit(
                serviceLocator(),
                sessionChanges: sessionCubit.stream,
              );
              if (state.extra case final SupportChatContext initialContext) {
                cubit.selectContext(initialContext);
              }
              return cubit;
            },
            child: BlocListener<SupportChatCubit, SupportChatState>(
              listenWhen: (_, state) => state.failure is AuthenticationFailure,
              listener: (_, _) => sessionCubit.handleSessionExpired(),
              child: const SupportChatPage(),
            ),
          ),
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
          create: (_) => serviceLocator<TravelPreferencesCubit>()..load(),
          child: const TravelPreferencesPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.travelerChangePassword,
        name: AppRouteNames.travelerChangePassword,
        builder: (_, _) => BlocProvider(
          create: (_) => serviceLocator<ChangePasswordCubit>(),
          child: const ChangePasswordPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.tourRecommendations,
        name: AppRouteNames.tourRecommendations,
        builder: (_, state) {
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          return TourRecommendationsPage(isDemoMode: isDemo);
        },
      ),
      GoRoute(
        path: AppRoutes.createItinerary,
        name: AppRouteNames.createItinerary,
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => CreateItineraryCubit(repository: serviceLocator()),
            ),
            BlocProvider(
              create: (_) => PoiSearchCubit(
                locationService: serviceLocator(),
                repository: serviceLocator(),
              ),
            ),
            BlocProvider(create: (_) => serviceLocator<AddressSearchCubit>()),
          ],
          child: const CreateItineraryPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.itineraryDetail,
        name: AppRouteNames.itineraryDetail,
        builder: (_, state) {
          final itineraryId = int.tryParse(
            state.pathParameters['itineraryId'] ?? '',
          );
          if (itineraryId == null || itineraryId <= 0) {
            return const ErrorView(message: 'Your itinerary is unavailable.');
          }
          return BlocProvider(
            create: (_) => ItineraryDetailCubit(repository: serviceLocator()),
            child: ItineraryDetailPage(
              itineraryId: itineraryId,
              pendingExplanation: PendingExplanation.forRoute(
                state.extra,
                itineraryId,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.itineraryResult,
        name: AppRouteNames.itineraryResult,
        builder: (_, state) {
          final itinerary = state.extra;
          if (itinerary is! GeneratedItinerary) {
            return const ErrorView(message: 'Your itinerary is unavailable.');
          }
          return ItineraryResultPage(itinerary: itinerary);
        },
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
              destination: args.destination,
              dateRange: args.dateRange,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.joinTravelGroup,
        name: AppRouteNames.joinTravelGroup,
        builder: (_, state) {
          final isDemoMode =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          return BlocProvider(
            create: (_) => JoinTravelGroupCubit(
              repository: serviceLocator(),
              isDemoMode: isDemoMode,
            ),
            child: JoinTravelGroupPage(isDemoMode: isDemoMode),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.inAppInbox,
        name: AppRouteNames.inAppInbox,
        builder: (_, _) => BlocProvider(
          create: (_) => serviceLocator<InAppInboxCubit>()..load(),
          child: const InAppInboxPage(
            destinationFor: travelerNotificationDestination,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.travelGroupDetails,
        name: AppRouteNames.travelGroupDetails,
        builder: (_, state) {
          final groupId = int.tryParse(state.pathParameters['groupId'] ?? '');
          if (groupId == null || groupId <= 0) {
            return const ErrorView(message: 'Page not found.');
          }
          final args = state.extra;
          return TravelGroupDetailsPage(
            groupId: groupId,
            repository: serviceLocator<TravelGroupRepository>(),
            group: switch (args) {
              TravelGroupDetailsRouteArgs(:final group) => group,
              TravelGroup group => group,
              _ => null,
            },
            isHost: args is TravelGroupDetailsRouteArgs && args.isHost,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.inviteGroupMembers,
        name: AppRouteNames.inviteGroupMembers,
        builder: (_, state) {
          final groupId = int.tryParse(state.pathParameters['groupId'] ?? '');
          if (groupId == null || groupId <= 0) {
            return const ErrorView(message: 'Page not found.');
          }
          return BlocProvider(
            create: (_) =>
                InviteGroupMembersCubit(repository: serviceLocator()),
            child: InviteGroupMembersPage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.travelGroupMembers,
        name: AppRouteNames.travelGroupMembers,
        builder: (_, state) {
          final groupId = int.tryParse(state.pathParameters['groupId'] ?? '');
          if (groupId == null || groupId <= 0) {
            return const ErrorView(message: 'Page not found.');
          }
          return BlocProvider(
            create: (_) =>
                serviceLocator<TravelGroupMembersCubit>()
                  ..load(groupId: groupId),
            child: TravelGroupMembersPage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.travelGroupChat,
        name: AppRouteNames.travelGroupChat,
        builder: (_, state) {
          final groupId = int.tryParse(state.pathParameters['groupId'] ?? '');
          if (groupId == null || groupId <= 0) {
            return const ErrorView(message: 'Page not found.');
          }
          return MessengerRoutePage(initialGroupId: groupId);
        },
      ),
      GoRoute(
        path: AppRoutes.travelerMessages,
        name: AppRouteNames.travelerMessages,
        builder: (_, _) => const MessengerRoutePage(),
      ),
      GoRoute(
        path: AppRoutes.operatorMessages,
        name: AppRouteNames.operatorMessages,
        builder: (_, _) => const MessengerRoutePage(),
      ),
      GoRoute(
        path: AppRoutes.groupLocationSharing,
        name: AppRouteNames.groupLocationSharing,
        builder: (_, state) {
          final groupId = int.tryParse(state.pathParameters['groupId'] ?? '');
          if (groupId == null || groupId <= 0) {
            return const ErrorView(message: 'Page not found.');
          }
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          final groupName = switch (state.extra) {
            String name when name.trim().isNotEmpty => name.trim(),
            TravelGroup group when group.name.trim().isNotEmpty =>
              group.name.trim(),
            _ => null,
          };
          return GroupLocationSharingPage(
            groupId: groupId,
            groupName: groupName,
            isDemoMode: isDemo,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.activeTripLivePattern,
        name: AppRouteNames.activeTripLive,
        builder: (_, state) {
          final itineraryId = int.tryParse(
            state.pathParameters['itineraryId'] ?? '',
          );
          if (itineraryId == null || itineraryId <= 0) {
            return const ErrorView(message: 'Page not found.');
          }
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          final extraTitle = switch (state.extra) {
            String title when title.trim().isNotEmpty => title.trim(),
            GeneratedItinerary it when it.title.trim().isNotEmpty =>
              it.title.trim(),
            ItineraryDetail d when (d.title?.trim().isNotEmpty ?? false) =>
              d.title!.trim(),
            _ => null,
          };
          final title = isDemo
              ? (extraTitle ?? 'Đà Nẵng Day Trip')
              : extraTitle;
          return ActiveTripPage(
            itineraryId: itineraryId,
            title: title,
            isDemoMode: isDemo,
            initialIncidentId: int.tryParse(
              state.uri.queryParameters['incidentId'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.tripAlertsPattern,
        name: AppRouteNames.tripAlerts,
        builder: (_, state) {
          final itineraryId = int.tryParse(
            state.pathParameters['itineraryId'] ?? '',
          );
          if (itineraryId == null || itineraryId <= 0) {
            return const ErrorView(message: 'Page not found.');
          }
          return TripAlertsPage(itineraryId: itineraryId);
        },
      ),
      GoRoute(
        path: AppRoutes.offlinePackagePattern,
        name: AppRouteNames.offlinePackage,
        builder: (_, state) {
          final itineraryId = int.tryParse(
            state.pathParameters['itineraryId'] ?? '',
          );
          if (itineraryId == null || itineraryId <= 0) {
            return const ErrorView(message: 'Page not found.');
          }
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          final extraTitle = switch (state.extra) {
            String title when title.trim().isNotEmpty => title.trim(),
            GeneratedItinerary it when it.title.trim().isNotEmpty =>
              it.title.trim(),
            ItineraryDetail d when (d.title?.trim().isNotEmpty ?? false) =>
              d.title!.trim(),
            _ => null,
          };
          final title = isDemo
              ? (extraTitle ?? 'Đà Nẵng City Explorer')
              : extraTitle;
          return OfflineTripPackagePage(
            itineraryId: itineraryId,
            title: title,
            isDemoMode: isDemo,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.offlinePackages,
        name: AppRouteNames.offlinePackages,
        builder: (_, _) => const OfflinePackagesPage(),
      ),
      GoRoute(
        path: AppRoutes.offlineItineraryPattern,
        name: AppRouteNames.offlineItinerary,
        builder: (_, state) {
          final id = _positiveId(state.pathParameters['itineraryId']);
          return id == null
              ? const ErrorView(message: 'Page not found.')
              : OfflineItineraryPage(itineraryId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.offlineMapPattern,
        name: AppRouteNames.offlineMap,
        builder: (_, state) {
          final id = _positiveId(state.pathParameters['itineraryId']);
          return id == null
              ? const ErrorView(message: 'Page not found.')
              : OfflineItineraryMapPage(itineraryId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.eTicketPattern,
        name: AppRouteNames.eTicket,
        builder: (_, state) =>
            _eTicketRoute(state.pathParameters['ticketId'], ETicketKey.ticket),
      ),
      GoRoute(
        path: AppRoutes.bookingETicketPattern,
        name: AppRouteNames.bookingETicket,
        builder: (_, state) => _eTicketRoute(
          state.pathParameters['bookingId'],
          ETicketKey.booking,
        ),
      ),
      GoRoute(
        path: AppRoutes.travelerEmergencyPattern,
        name: AppRouteNames.travelerEmergency,
        builder: (_, state) {
          final bookingId = _positiveId(state.pathParameters['bookingId']);
          if (bookingId == null) return const _RouteNotFound();
          return BlocProvider<TravelerEmergencyCubit>(
            create: (_) =>
                serviceLocator<TravelerEmergencyCubit>(param1: bookingId)
                  ..load(),
            child: TravelerEmergencyPage(
              onAcknowledged:
                  serviceLocator<TravelerEmergencyNoticesCubit>().refresh,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.postTripComplaintPattern,
        name: AppRouteNames.postTripComplaint,
        builder: (_, state) {
          final bookingId = _positiveId(state.pathParameters['bookingId']);
          if (bookingId == null) return const _RouteNotFound();
          return BlocProvider<PostTripComplaintCubit>(
            create: (_) =>
                serviceLocator<PostTripComplaintCubit>(param1: bookingId)
                  ..load(),
            child: const PostTripComplaintPage(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.myPostTripComplaints,
        name: AppRouteNames.myPostTripComplaints,
        builder: (_, _) => BlocProvider<MyPostTripComplaintsCubit>(
          create: (_) => serviceLocator<MyPostTripComplaintsCubit>()..load(),
          child: const MyPostTripComplaintsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.tripHistory,
        name: AppRouteNames.tripHistory,
        builder: (_, state) {
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          return BlocProvider(
            create: (_) =>
                serviceLocator<TripRecordsCubit>(param1: isDemo)..loadInitial(),
            child: TripHistoryPage(isDemoMode: isDemo),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.tripReviewPattern,
        name: AppRouteNames.tripReview,
        builder: (_, state) {
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          final routeTripId = state.pathParameters['tripId'] ?? '';
          if (routeTripId.trim().isEmpty) {
            return const Scaffold(
              body: ErrorView(
                message: TripHistoryStringsEn.tripInformationUnavailable,
              ),
            );
          }
          final cachedTrip =
              state.extra is TripHistoryItem &&
                  (state.extra as TripHistoryItem).id == routeTripId
              ? state.extra as TripHistoryItem
              : null;
          return BlocProvider(
            create: (_) => serviceLocator<TripReviewCubit>(param1: isDemo)
              ..loadTripAndReview(
                tripId: routeTripId,
                cachedTrip: cachedTrip,
                travelerId: isDemo ? DemoTripHistoryStore.demoTravelerId : null,
              ),
            child: TripReviewPage(
              tripId: routeTripId,
              initialTrip: cachedTrip,
              isDemoMode: isDemo,
              demoTravelerId: isDemo
                  ? DemoTripHistoryStore.demoTravelerId
                  : null,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.canonicalTripReviewPattern,
        builder: (_, state) {
          final kind = switch (state.pathParameters['kind']) {
            'commerceBooking' => ReviewableRecordKind.commerceBooking,
            'serviceBooking' => ReviewableRecordKind.serviceBooking,
            _ => null,
          };
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (kind == null || id == null || id <= 0) {
            return const Scaffold(
              body: ErrorView(message: 'Review information is unavailable.'),
            );
          }
          final reference = ReviewableRecordRef(kind: kind, id: id);
          return CanonicalTripReviewPage(
            cubit: serviceLocator<CanonicalTripReviewCubit>(param1: reference),
          );
        },
      ),
      GoRoute(
        path: '/traveler/trips/:tripId',
        redirect: (_, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          final demo = state.uri.queryParameters['demo'] == 'true'
              ? '?demo=true'
              : '';
          return '/traveler/trips/$tripId/review$demo';
        },
      ),
      GoRoute(
        path: AppRoutes.operator,
        name: AppRouteNames.operator,
        builder: (_, state) {
          // Demo fixtures are debug-only, like every other demo route: a release build ignores the flag.
          final isDemo =
              kDebugMode && state.uri.queryParameters['demo'] == 'true';
          return OperatorShellPage(isDemoMode: isDemo);
        },
      ),
      GoRoute(
        path: AppRoutes.operatorInbox,
        name: AppRouteNames.operatorInbox,
        builder: (_, _) => BlocProvider(
          create: (_) => serviceLocator<InAppInboxCubit>()..load(),
          child: const InAppInboxPage(
            destinationFor: operatorNotificationDestination,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.operatorSettlementHistory,
        builder: (_, state) {
          final demo = isDebug && state.uri.queryParameters['demo'] == 'true';
          return BlocProvider<OperatorSettlementHistoryCubit>(
            create: (_) =>
                serviceLocator<OperatorSettlementHistoryCubit>(param1: demo)
                  ..ensureLoaded(),
            child: OperatorSettlementHistoryPage(isDemoMode: demo),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.operatorTours,
        name: AppRouteNames.operatorTours,
        builder: (_, _) => BlocProvider(
          create: (_) => serviceLocator<OperatorToursCubit>()..load(),
          child: const OperatorToursPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.operatorSafetyReviews,
        name: AppRouteNames.operatorSafetyReviews,
        builder: (_, _) => BlocProvider<OperatorSafetyReviewsCubit>.value(
          value: serviceLocator<OperatorSafetyReviewsCubit>(),
          child: const OperatorSafetyReviewsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.operatorSafetyReview,
        name: AppRouteNames.operatorSafetyReview,
        builder: (_, state) {
          final reviewId = _positiveId(state.pathParameters['reviewId']);
          if (reviewId == null) return const _RouteNotFound();
          return BlocProvider<OperatorSafetyReviewDetailCubit>(
            create: (_) => serviceLocator<OperatorSafetyReviewDetailCubit>(
              param1: reviewId,
            )..load(),
            child: OperatorSafetyReviewDetailPage(
              onChanged: serviceLocator<OperatorSafetyReviewsCubit>().refresh,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.operatorEmergencyDecision,
        name: AppRouteNames.operatorEmergencyDecision,
        builder: (_, state) {
          final tourId = _positiveId(state.pathParameters['tourId']);
          final scheduleId = _positiveId(state.pathParameters['scheduleId']);
          if (tourId == null || scheduleId == null) {
            return const _RouteNotFound();
          }
          final departure = (tourId: tourId, scheduleId: scheduleId);
          return MultiBlocProvider(
            providers: [
              BlocProvider<EmergencyDecisionCubit>(
                create: (_) =>
                    serviceLocator<EmergencyDecisionCubit>(param1: departure)
                      ..load(),
              ),
              BlocProvider<EmergencyEvidenceCubit>(
                create: (_) =>
                    serviceLocator<EmergencyEvidenceCubit>(param1: departure),
              ),
            ],
            child: EmergencyDecisionPage(
              tourId: tourId,
              scheduleId: scheduleId,
              window: serviceLocator<DeviceWindow>(),
              onDecided: serviceLocator<OperatorSafetyReviewsCubit>().refresh,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.operatorBooking,
        name: AppRouteNames.operatorBooking,
        builder: (_, state) => _operatorBookingRoute(
          state.pathParameters['bookingId'],
          isDemo: kDebugMode && state.uri.queryParameters['demo'] == 'true',
          initialBooking: state.extra is OperatorBookingListItem
              ? state.extra as OperatorBookingListItem
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.operatorCheckIn,
        name: AppRouteNames.operatorCheckIn,
        builder: (_, state) {
          final isDemo = resolveOperatorCheckInDemo(
            state.uri,
            isDebug: isDebug,
          );
          final scheduleIdStr = state.uri.queryParameters['scheduleId'];
          final scheduleId = scheduleIdStr != null
              ? int.tryParse(scheduleIdStr)
              : null;
          return BlocProvider<OperatorCheckInCubit>(
            create: (_) => serviceLocator<OperatorCheckInCubit>(param1: isDemo),
            child: OperatorCheckInPage(initialScheduleId: scheduleId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.editTourPackage,
        name: AppRouteNames.editTourPackage,
        builder: (_, state) => BlocProvider(
          create: (_) => serviceLocator<CreateTourPackageCubit>(),
          child: EditTourPackagePage(
            tourId: int.tryParse(state.pathParameters['tourId'] ?? ''),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.createTourPackage,
        name: AppRouteNames.createTourPackage,
        builder: (_, _) => BlocProvider(
          create: (_) =>
              serviceLocator<CreateTourPackageCubit>()..loadOptions(),
          child: const CreateTourPackagePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.createCoupon,
        name: AppRouteNames.createCoupon,
        builder: (_, _) => BlocProvider(
          create: (_) => serviceLocator<CreateCouponCubit>(),
          child: const CreateCouponPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.operatorChangePassword,
        name: AppRouteNames.operatorChangePassword,
        builder: (_, _) => BlocProvider(
          create: (_) => serviceLocator<ChangePasswordCubit>(),
          child: const ChangePasswordPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.operatorContract,
        name: AppRouteNames.operatorContract,
        builder: (_, _) => BlocProvider(
          create: (_) => serviceLocator<OperatorContractCubit>(),
          child: const OperatorContractPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.operatorProfileEdit,
        name: AppRouteNames.operatorProfileEdit,
        builder: (_, state) {
          final isDemo = state.uri.queryParameters['demo'] == 'true';
          final initialProfile = state.extra is OperatorProfile
              ? state.extra as OperatorProfile
              : null;
          return BlocProvider(
            create: (_) => serviceLocator<OperatorProfileCubit>(param1: isDemo),
            child: OperatorProfileEditPage(
              initialProfile: initialProfile,
              isDemoMode: isDemo,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.operatorApplication,
        name: AppRouteNames.operatorApplication,
        builder: (_, state) => BlocProvider(
          create: (_) => serviceLocator<OperatorApplicationCubit>(),
          child: OperatorApplicationPage(
            renewSession: () =>
                serviceLocator<OperatorContractRepository>().renewSession(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.operatorApplicationResubmit,
        name: AppRouteNames.operatorApplicationResubmit,
        builder: (_, state) => BlocProvider(
          create: (_) => serviceLocator<OperatorApplicationCubit>(),
          child: ResubmitOperatorApplicationPage(
            picker: serviceLocator<OperatorDocumentPicker>(),
          ),
        ),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: const ErrorView(message: 'Page not found.'),
    ),
  );
}

int? _positiveId(String? raw) {
  final id = int.tryParse(raw ?? '');
  return id != null && id > 0 ? id : null;
}

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: const ErrorView(message: 'Page not found.'),
  );
}

/// UC-40: a digit-only id opens the booking; anything else is answered as not
/// found without calling the Backend. [initialBooking] is the list card the page
/// was opened from, so its basics show before the detail arrives.
Widget _operatorBookingRoute(
  String? rawId, {
  required bool isDemo,
  OperatorBookingListItem? initialBooking,
}) {
  if (rawId == null || !RegExp(r'^\d+$').hasMatch(rawId)) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: const ErrorView(message: 'Page not found.'),
    );
  }
  return BlocProvider(
    create: (_) => serviceLocator<OperatorBookingDetailCubit>(
      param1: rawId,
      param2: isDemo,
    )..load(),
    child: OperatorBookingDetailPage(initialBooking: initialBooking),
  );
}

/// UC-29: a positive id opens the ticket; anything else is answered as not
/// found without calling the Backend.
Widget _eTicketRoute(String? rawId, ETicketKey Function(int id) toKey) {
  final id = int.tryParse(rawId ?? '');
  if (id == null || id <= 0) {
    return Scaffold(
      appBar: AppBar(title: const Text(ETicketStrings.title)),
      body: const Center(child: Text(ETicketStrings.notFound)),
    );
  }
  return BlocProvider(
    create: (_) => serviceLocator<ETicketCubit>(param1: toKey(id))..start(),
    child: const ETicketPage(),
  );
}
