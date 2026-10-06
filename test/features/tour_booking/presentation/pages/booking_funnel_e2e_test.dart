import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/electronic_payment_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/qr_eticket_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/pages/electronic_payment_page.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/pages/qr_eticket_page.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/pages/tour_booking_page.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/pages/tour_detail_page.dart';

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this.values);

  final Map<String, String> values;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

Future<AuthSessionCubit> _createAuthenticatedTravelerSessionCubit() async {
  final storage = _MemoryStorage({
    AppConstants.keepSignedInKey: 'true',
    AppConstants.accessTokenKey: 'demo-access-token',
    AppConstants.refreshTokenKey: 'demo-refresh-token',
    AppConstants.sessionRoleKey: 'traveler',
  });
  final cubit = AuthSessionCubit(null, storage);
  await cubit.restoreSession();
  return cubit;
}

void main() {
  final store = DemoBookingFunnelStore.instance;

  setUp(store.reset);

  group('Booking Funnel End-to-End, Production Leak & Route Guards', () {
    testWidgets(
      'End-to-End Demo regression: UC-26 -> UC-27 -> UC-28 -> UC-29 and Back navigation preserve ?demo=true continuity',
      (tester) async {
        final sessionCubit = await _createAuthenticatedTravelerSessionCubit();
        addTearDown(sessionCubit.close);

        final router = GoRouter(
          initialLocation: AppRoutes.tourDetail('demo-tour-1', demo: true),
          redirect: (_, state) =>
              RouteGuards.redirect(sessionCubit.state, state),
          routes: [
            GoRoute(
              path: AppRoutes.tourDetailPattern,
              builder: (_, state) => TourDetailPage(
                tourId: state.pathParameters['tourId'] ?? '',
                isDemoMode: state.uri.queryParameters['demo'] == 'true',
              ),
            ),
            GoRoute(
              path: AppRoutes.bookTourPattern,
              builder: (_, state) => TourBookingPage(
                tourId: state.pathParameters['tourId'] ?? '',
                scheduleId: state.uri.queryParameters['scheduleId'],
                initialDetail: state.extra is TourDetail
                    ? state.extra as TourDetail
                    : null,
                isDemoMode: state.uri.queryParameters['demo'] == 'true',
              ),
            ),
            GoRoute(
              path: AppRoutes.bookingPaymentPattern,
              builder: (_, state) => ElectronicPaymentPage(
                bookingId: state.pathParameters['bookingId'] ?? '',
                initialBooking: state.extra is TourBookingRecord
                    ? state.extra as TourBookingRecord
                    : null,
                isDemoMode: state.uri.queryParameters['demo'] == 'true',
                enableTicker: false,
              ),
            ),
            GoRoute(
              path: AppRoutes.bookingEticketPattern,
              builder: (_, state) => QrEticketPage(
                bookingId: state.pathParameters['bookingId'] ?? '',
                initialBooking: state.extra is TourBookingRecord
                    ? state.extra as TourBookingRecord
                    : null,
                isDemoMode: state.uri.queryParameters['demo'] == 'true',
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          BlocProvider<AuthSessionCubit>.value(
            value: sessionCubit,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // 1. On UC-26 TourDetailPage (?demo=true)
        expect(find.text('Chi tiết Tour'), findsOneWidget);
        final bookNowBtn = find.byKey(const Key('tour-detail-book-now-button'));
        expect(bookNowBtn, findsOneWidget);

        await tester.tap(bookNowBtn);
        await tester.pumpAndSettle();

        // 2. Landed on UC-27 TourBookingPage (?demo=true)
        expect(find.text('Đặt Tour'), findsOneWidget);
        expect(
          router
              .routerDelegate
              .currentConfiguration
              .uri
              .queryParameters['demo'],
          'true',
        );

        // Apply SUMMER2026 voucher via quick demo chip
        final summerChip = find.byKey(
          const Key('demo-voucher-chip-SUMMER2026'),
        );
        await tester.ensureVisible(summerChip);
        await tester.tap(summerChip);
        await tester.pumpAndSettle();

        // Tap Confirm Booking and accept CR-05 confirmation dialog
        final confirmBtn = find.byKey(const Key('booking-confirm-button'));
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        final dialogSubmit = find.byKey(
          const Key('booking-confirm-dialog-submit'),
        );
        expect(dialogSubmit, findsOneWidget);
        await tester.tap(dialogSubmit);
        await tester.pumpAndSettle();

        // 3. Landed on UC-28 ElectronicPaymentPage (?demo=true)
        expect(find.text('Thanh toán điện tử'), findsOneWidget);
        expect(find.text('BK-DEMO-1001'), findsOneWidget);
        expect(
          router
              .routerDelegate
              .currentConfiguration
              .uri
              .queryParameters['demo'],
          'true',
        );

        // Proceed to Payment (BR-71)
        await tester.tap(find.byKey(const Key('payment-proceed-button')));
        await tester.pumpAndSettle();
        expect(find.text(ElectronicPaymentState.msg85), findsOneWidget);

        // Gateway Return (BR-73 / PC-06: non-authoritative -> MSG90, not yet confirmed)
        await tester.tap(find.byKey(const Key('demo-uc28-gateway-return')));
        await tester.pumpAndSettle();
        expect(find.text(ElectronicPaymentState.msg90), findsOneWidget);
        expect(
          find.byKey(const Key('payment-view-eticket-button')),
          findsNothing,
        );

        // Verified Server IPN (BR-73 / BR-80 -> MSG86, confirmed)
        await tester.tap(find.byKey(const Key('demo-uc28-verified-success')));
        await tester.pumpAndSettle();
        expect(find.text(ElectronicPaymentState.msg86), findsOneWidget);

        final viewEticketBtn = find.byKey(
          const Key('payment-view-eticket-button'),
        );
        expect(viewEticketBtn, findsOneWidget);
        await tester.tap(viewEticketBtn);
        await tester.pumpAndSettle();

        // 4. Landed on UC-29 QrEticketPage (?demo=true)
        expect(find.text('Vé điện tử QR (E-ticket)'), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text(QrEticketState.msg93), findsOneWidget);
        expect(
          router
              .routerDelegate
              .currentConfiguration
              .uri
              .queryParameters['demo'],
          'true',
        );

        // 5. Back navigation from UC-29 returns cleanly to UC-28 with ?demo=true preserved
        final backBtn = find.byKey(const Key('eticket-appbar-back-button'));
        await tester.tap(backBtn);
        await tester.pumpAndSettle();

        expect(find.text('Thanh toán điện tử'), findsOneWidget);
        expect(
          router
              .routerDelegate
              .currentConfiguration
              .uri
              .queryParameters['demo'],
          'true',
        );
      },
    );

    testWidgets(
      'Production leak test: navigating to UC-27, UC-28, and UC-29 without ?demo=true creates zero Demo bookings, transactions, or QR payloads',
      (tester) async {
        final sessionCubit = await _createAuthenticatedTravelerSessionCubit();
        addTearDown(sessionCubit.close);

        final router = GoRouter(
          initialLocation: AppRoutes.bookTour('tour-prod-1', demo: false),
          redirect: (_, state) =>
              RouteGuards.redirect(sessionCubit.state, state),
          routes: [
            GoRoute(
              path: AppRoutes.bookTourPattern,
              builder: (_, state) => TourBookingPage(
                tourId: state.pathParameters['tourId'] ?? '',
                isDemoMode: state.uri.queryParameters['demo'] == 'true',
              ),
            ),
            GoRoute(
              path: AppRoutes.bookingPaymentPattern,
              builder: (_, state) => ElectronicPaymentPage(
                bookingId: state.pathParameters['bookingId'] ?? '',
                isDemoMode: state.uri.queryParameters['demo'] == 'true',
                enableTicker: false,
              ),
            ),
            GoRoute(
              path: AppRoutes.bookingEticketPattern,
              builder: (_, state) => QrEticketPage(
                bookingId: state.pathParameters['bookingId'] ?? '',
                isDemoMode: state.uri.queryParameters['demo'] == 'true',
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          BlocProvider<AuthSessionCubit>.value(
            value: sessionCubit,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // UC-27 Production
        expect(
          find.byKey(const Key('booking-pending-integration-banner')),
          findsOneWidget,
        );
        expect(store.totalBookingsCount, 0);

        // UC-28 Production
        router.go(AppRoutes.bookingPayment('BK-PROD-1', demo: false));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('payment-pending-integration-banner')),
          findsOneWidget,
        );
        expect(store.totalBookingsCount, 0);

        // UC-29 Production
        router.go(AppRoutes.bookingEticket('BK-PROD-1', demo: false));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('eticket-pending-integration-banner')),
          findsOneWidget,
        );
        expect(find.byType(QrImageView), findsNothing);
        expect(store.totalBookingsCount, 0);
      },
    );

    testWidgets(
      'RouteGuards protect UC-27, UC-28, and UC-29 for Authenticated Traveler only (Guest redirected to login, TourOperator denied)',
      (tester) async {
        final protectedPaths = [
          AppRoutes.bookTour('tour-1'),
          AppRoutes.bookingPayment('BK-1'),
          AppRoutes.bookingEticket('BK-1'),
        ];

        for (final targetPath in protectedPaths) {
          // 1. Guest -> redirected to /auth/login
          const guestSession = AuthSessionState.unauthenticated();
          final guestRouter = GoRouter(
            initialLocation: targetPath,
            redirect: (_, state) => RouteGuards.redirect(guestSession, state),
            routes: [
              GoRoute(
                path: AppRoutes.login,
                builder: (_, _) => const Text('Sign In'),
              ),
              GoRoute(
                path: AppRoutes.bookTourPattern,
                builder: (_, _) => const Text('Book Tour'),
              ),
              GoRoute(
                path: AppRoutes.bookingPaymentPattern,
                builder: (_, _) => const Text('Payment'),
              ),
              GoRoute(
                path: AppRoutes.bookingEticketPattern,
                builder: (_, _) => const Text('E-ticket'),
              ),
            ],
          );
          await tester.pumpWidget(
            MaterialApp.router(routerConfig: guestRouter),
          );
          await tester.pumpAndSettle();
          expect(find.text('Sign In'), findsOneWidget);
          guestRouter.dispose();

          // 2. Approved TourOperator -> redirected to /operator
          const operatorSession = AuthSessionState.authenticated(
            UserRole.tourOperator,
            applicationStatus: TourOperatorApplicationStatus.approved,
          );
          final operatorRouter = GoRouter(
            initialLocation: targetPath,
            redirect: (_, state) =>
                RouteGuards.redirect(operatorSession, state),
            routes: [
              GoRoute(
                path: AppRoutes.operator,
                builder: (_, _) => const Text('Operator Workspace'),
              ),
              GoRoute(
                path: AppRoutes.bookTourPattern,
                builder: (_, _) => const Text('Book Tour'),
              ),
              GoRoute(
                path: AppRoutes.bookingPaymentPattern,
                builder: (_, _) => const Text('Payment'),
              ),
              GoRoute(
                path: AppRoutes.bookingEticketPattern,
                builder: (_, _) => const Text('E-ticket'),
              ),
            ],
          );
          await tester.pumpWidget(
            MaterialApp.router(routerConfig: operatorRouter),
          );
          await tester.pumpAndSettle();
          expect(find.text('Operator Workspace'), findsOneWidget);
          operatorRouter.dispose();
        }
      },
    );
  });
}
