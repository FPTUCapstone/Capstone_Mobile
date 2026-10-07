import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/route_guards.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_detail_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_detail_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/pages/poi_detail_page.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/itinerary_detail_page.dart';

class _StubPoiRepository implements PoiRepository {
  _StubPoiRepository(this.detail);

  final PoiDetail detail;

  @override
  Future<PoiDetail> getPoiDetail(int id) async => detail;

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) => throw UnimplementedError();
}

class _StubItineraryRepository implements ItineraryRepository {
  _StubItineraryRepository(this.detail);

  final ItineraryDetail detail;

  @override
  Future<ItineraryDetail> getById(int itineraryId) async => detail;

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> adjustItems({
    required int itineraryId,
    required List<int> orderedVisitPoiIds,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

PoiDetail _makePoi({required int id, required String categoryName}) {
  return PoiDetail(
    id: id,
    name: 'Test POI $categoryName',
    description: 'Description',
    status: 'Active',
    categoryId: 1,
    categoryName: categoryName,
    latitude: 16.0678,
    longitude: 108.2208,
    address: 'Da Nang',
    indoorOutdoor: 'Indoor',
    averageVisitDurationMinutes: 60,
    hasShelter: true,
    scenicScore: 4.5,
    photoRating: 4.5,
    averageRating: 4.6,
    reviewCount: 12,
    isOpenNow: true,
    openingHours: const [],
    photos: const [],
    tags: const [],
    createdAtUtc: DateTime.utc(2026, 1, 1),
    updatedAtUtc: DateTime.utc(2026, 1, 2),
  );
}

void main() {
  Future<String> resolveRoute(
    WidgetTester tester,
    AuthSessionState session,
    String location,
  ) async {
    final router = GoRouter(
      initialLocation: location,
      redirect: (_, state) => RouteGuards.redirect(session, state),
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Text('Sign In'),
        ),
        GoRoute(
          path: AppRoutes.traveler,
          builder: (_, _) => const Text('Traveler Home'),
        ),
        GoRoute(
          path: AppRoutes.operator,
          builder: (_, _) => const Text('Operator Home'),
        ),
        GoRoute(
          path: AppRoutes.operatorApplication,
          builder: (_, _) => const Text('Operator Application'),
        ),
        GoRoute(
          path: AppRoutes.commercialServiceDetailPattern,
          builder: (_, _) => const Text('Commercial Service Detail'),
        ),
        GoRoute(
          path: AppRoutes.commercialServiceBookingPattern,
          builder: (_, _) => const Text('Commercial Service Booking'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router.routerDelegate.currentConfiguration.last.matchedLocation;
  }

  group('UC-30/31 Route Guards', () {
    testWidgets(
      'Guest is redirected to Sign In and demo=true never bypasses auth or role guards',
      (tester) async {
        const guest = AuthSessionState.unauthenticated();
        expect(
          await resolveRoute(
            tester,
            guest,
            AppRoutes.commercialServiceDetail(901, demo: true),
          ),
          AppRoutes.login,
        );
        expect(
          await resolveRoute(
            tester,
            guest,
            AppRoutes.commercialServiceBooking(901, demo: true),
          ),
          AppRoutes.login,
        );

        const traveler = AuthSessionState.authenticated(UserRole.traveler);
        expect(
          await resolveRoute(
            tester,
            traveler,
            AppRoutes.commercialServiceDetail(901, demo: true),
          ),
          '/traveler/services/901',
        );
        expect(
          await resolveRoute(
            tester,
            traveler,
            AppRoutes.commercialServiceBooking(901, demo: true),
          ),
          '/traveler/services/901/book',
        );

        const approvedOperator = AuthSessionState.authenticated(
          UserRole.tourOperator,
          applicationStatus: TourOperatorApplicationStatus.approved,
        );
        expect(
          await resolveRoute(
            tester,
            approvedOperator,
            AppRoutes.commercialServiceDetail(901, demo: true),
          ),
          AppRoutes.operator,
        );
        expect(
          await resolveRoute(
            tester,
            approvedOperator,
            AppRoutes.commercialServiceBooking(901, demo: true),
          ),
          AppRoutes.operator,
        );
      },
    );
  });

  group('UC-30 Entry Points (BR-87)', () {
    testWidgets(
      'PoiDetailPage shows View Commercial Service button only for Hotel, Vehicle Rental, or Restaurant POIs',
      (tester) async {
        final hotelCubit = PoiDetailCubit(
          GetPoiDetailUseCase(
            _StubPoiRepository(_makePoi(id: 10, categoryName: 'Hotel')),
          ),
        );
        addTearDown(hotelCubit.close);
        await hotelCubit.load('10');

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: hotelCubit,
              child: const PoiDetailPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('poi_detail_view_commercial_service_button')),
          findsOneWidget,
        );

        final museumCubit = PoiDetailCubit(
          GetPoiDetailUseCase(
            _StubPoiRepository(_makePoi(id: 11, categoryName: 'Museum')),
          ),
        );
        addTearDown(museumCubit.close);
        await museumCubit.load('11');

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: museumCubit,
              child: const PoiDetailPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('poi_detail_view_commercial_service_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'ItineraryDetailPage shows View Commercial Service button only on commercial POI stops (BR-87)',
      (tester) async {
        final detail = ItineraryDetail(
          itineraryId: 50,
          schedulingRequestId: 60,
          title: 'Da Nang Culinary & Culture',
          version: 1,
          status: 'Active',
          validFrom: DateTime.utc(2026, 10, 15, 1),
          validTo: DateTime.utc(2026, 10, 15, 6),
          canManage: true,
          totalEstimatedCost: 500000,
          totalDurationMinutes: 240,
          items: [
            ItineraryDetailItem(
              itemId: 1,
              sequenceNo: 1,
              poiId: 903,
              poiName: 'Madame Lan Restaurant',
              category: 'Restaurant',
              itemKind: ItineraryItemKind.visit,
              plannedArrival: DateTime.utc(2026, 10, 15, 4),
              plannedDeparture: DateTime.utc(2026, 10, 15, 5),
              travelDurationFromPreviousMinutes: null,
              stayDurationMinutes: 60,
              estimatedCost: 350000,
              isMandatory: false,
              recommendationReason: 'Lunch stop',
              isUnavailable: false,
            ),
            ItineraryDetailItem(
              itemId: 2,
              sequenceNo: 2,
              poiId: 905,
              poiName: 'Cham Museum',
              category: 'Museum',
              itemKind: ItineraryItemKind.visit,
              plannedArrival: DateTime.utc(2026, 10, 15, 5, 15),
              plannedDeparture: DateTime.utc(2026, 10, 15, 6, 15),
              travelDurationFromPreviousMinutes: 15,
              stayDurationMinutes: 60,
              estimatedCost: 60000,
              isMandatory: false,
              recommendationReason: 'Culture stop',
              isUnavailable: false,
            ),
          ],
        );

        final cubit = ItineraryDetailCubit(
          repository: _StubItineraryRepository(detail),
        );
        addTearDown(cubit.close);

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: cubit,
              child: const ItineraryDetailPage(itineraryId: 50),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('itinerary_item_commercial_service_1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('itinerary_item_commercial_service_2')),
          findsNothing,
        );
      },
    );
  });
}
