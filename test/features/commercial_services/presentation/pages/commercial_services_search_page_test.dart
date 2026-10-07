import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/pages/commercial_services_search_page.dart';
import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';

class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository({this.onGetPois});

  Future<PagedPoiResult> Function(PoiQuery query)? onGetPois;

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) async {
    if (onGetPois != null) {
      return onGetPois!(query);
    }
    return const PagedPoiResult(
      page: 1,
      pageSize: 20,
      totalCount: 0,
      totalPages: 0,
      items: [],
    );
  }

  @override
  Future<PoiDetail> getPoiDetail(int id) {
    throw UnimplementedError();
  }
}

PoiSummary _makePoiSummary({
  required int id,
  required String name,
  required String categoryName,
  int categoryId = 1,
  String? address = '123 Bach Dang, Da Nang',
  double? averageRating = 4.5,
  int reviewCount = 20,
}) {
  return PoiSummary(
    id: id,
    name: name,
    categoryId: categoryId,
    categoryName: categoryName,
    latitude: 16.0544,
    longitude: 108.2022,
    indoorOutdoor: 'Indoor',
    averageVisitDurationMinutes: 60,
    hasShelter: true,
    reviewCount: reviewCount,
    isOpenNow: true,
    address: address,
    averageRating: averageRating,
  );
}

Widget _wrapWithCubit(CommercialServicesSearchCubit cubit) {
  return MaterialApp(
    home: BlocProvider.value(
      value: cubit,
      child: const CommercialServicesSearchPage(),
    ),
  );
}

void main() {
  setUp(() {
    DemoCommercialServiceStore.instance.reset();
  });

  group('CommercialServicesSearchPage - Screen #71 Production Truthfulness', () {
    testWidgets(
      'renders search input, category chips, production truthfulness banner, and truthful PENDING_BE_INTEGRATION empty state without exposing ordinary POIs',
      (tester) async {
        final repo = _FakePoiRepository(
          onGetPois: (query) async => PagedPoiResult(
            page: 1,
            pageSize: 20,
            totalCount: 2,
            totalPages: 1,
            items: [
              _makePoiSummary(
                id: 10,
                name: 'Han River Hotel',
                categoryName: 'Hotel',
              ),
              _makePoiSummary(
                id: 20,
                name: 'Banh Mi Ba Lan',
                categoryName: 'Restaurant',
              ),
            ],
          ),
        );

        final cubit = CommercialServicesSearchCubit(
          getPois: GetPoisUseCase(repo),
          isDemoMode: false,
        );
        addTearDown(cubit.close);
        await cubit.loadInitial();

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_search_input')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_search_production_banner')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('commercial_search_production_banner')),
            matching: find.textContaining('PENDING_BE_INTEGRATION'),
          ),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('commercial_category_chip_all')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_category_chip_hotel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_category_chip_vehicle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_category_chip_restaurant')),
          findsOneWidget,
        );

        // Screen #71 Production Truthfulness:
        // Must NEVER render ordinary POIs or unverified catalog items.
        // Standalone commercial catalog capability is truthfully PENDING_BE_INTEGRATION.
        expect(
          find.byKey(const Key('commercial_search_pending_view')),
          findsOneWidget,
        );
        expect(
          find.text(CommercialServiceEn.search.catalogPendingNotice),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_service_card_10')),
          findsNothing,
        );
        expect(find.text('Han River Hotel'), findsNothing);
        expect(
          find.byKey(const Key('commercial_service_card_20')),
          findsNothing,
        );
        expect(find.text('Banh Mi Ba Lan'), findsNothing);
      },
    );

    testWidgets(
      'renders failure state with retry button on error, and recovers upon retry',
      (tester) async {
        var failure = true;
        final repo = _FakePoiRepository(
          onGetPois: (query) async {
            if (failure) {
              throw const ServerFailure('Backend error');
            }
            return PagedPoiResult(
              page: 1,
              pageSize: 20,
              totalCount: 1,
              totalPages: 1,
              items: [
                _makePoiSummary(
                  id: 10,
                  name: 'Han River Hotel',
                  categoryName: 'Hotel',
                ),
              ],
            );
          },
        );

        final cubit = CommercialServicesSearchCubit(
          getPois: GetPoisUseCase(repo),
          isDemoMode: false,
        );
        addTearDown(cubit.close);
        await cubit.loadInitial();

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_search_retry_button')),
          findsOneWidget,
        );
        expect(find.text(CommercialServiceMessages.msg127), findsOneWidget);

        failure = false;
        await tester.tap(
          find.byKey(const Key('commercial_search_retry_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_search_pending_view')),
          findsOneWidget,
        );
        expect(
          find.text(CommercialServiceEn.search.catalogPendingNotice),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders empty state when no demo items match and reset button clears filters',
      (tester) async {
        final repo = _FakePoiRepository();
        final cubit = CommercialServicesSearchCubit(
          getPois: GetPoisUseCase(repo),
          isDemoMode: true,
        );
        addTearDown(cubit.close);
        await cubit.loadInitial();
        await cubit.submitSearch('NonExistentHotelXYZ999');

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_search_empty_view')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_search_reset_button')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('commercial_search_reset_button')),
        );
        await tester.pumpAndSettle();

        expect(cubit.state.searchQuery, isEmpty);
        expect(cubit.state.selectedCategory, isNull);
      },
    );
  });

  group('CommercialServicesSearchPage - Demo Mode and Navigation', () {
    testWidgets(
      'Demo Mode renders demo banner, deterministic items with VND price, and interactive category selection',
      (tester) async {
        final repo = _FakePoiRepository();
        final cubit = CommercialServicesSearchCubit(
          getPois: GetPoisUseCase(repo),
          isDemoMode: true,
        );
        addTearDown(cubit.close);
        await cubit.loadInitial();

        await tester.pumpWidget(_wrapWithCubit(cubit));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_search_demo_banner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_service_card_901')),
          findsOneWidget,
        );
        expect(find.text('Sala Danang Beach Hotel (Demo)'), findsOneWidget);
        expect(find.text('From ₫1,450,000'), findsOneWidget);
        expect(find.text('Available'), findsWidgets);

        // Tap Vehicle Rental chip
        await tester.tap(
          find.byKey(const Key('commercial_category_chip_vehicle')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_service_card_902')),
          findsOneWidget,
        );
        expect(
          find.text('Central Coast Mobility Rental (Demo)'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('commercial_service_card_901')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Tapping an item card navigates to Screen #72 detail route with intendedDate and demo flags',
      (tester) async {
        final repo = _FakePoiRepository();
        final cubit = CommercialServicesSearchCubit(
          getPois: GetPoisUseCase(repo),
          isDemoMode: true,
        );
        addTearDown(cubit.close);
        await cubit.loadInitial();

        String? pushedPath;
        final router = GoRouter(
          initialLocation: AppRoutes.commercialServicesSearch,
          routes: [
            GoRoute(
              path: AppRoutes.commercialServicesSearchPattern,
              builder: (context, state) => BlocProvider.value(
                value: cubit,
                child: const CommercialServicesSearchPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.commercialServiceDetailPattern,
              builder: (context, state) {
                pushedPath = state.uri.toString();
                return Scaffold(
                  body: Text(
                    'Screen #72 Detail: ${state.pathParameters['poiId']}',
                  ),
                );
              },
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('commercial_service_card_901')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('commercial_service_card_901')));
        await tester.pumpAndSettle();

        expect(find.text('Screen #72 Detail: 901'), findsOneWidget);
        expect(pushedPath, contains('/traveler/services/901'));
        expect(pushedPath, contains('demo=true'));
      },
    );
  });
}
