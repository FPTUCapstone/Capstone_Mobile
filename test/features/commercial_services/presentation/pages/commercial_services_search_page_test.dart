import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/datasources/demo_commercial_services_data_source.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/datasources/pending_commercial_services_data_source.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/repositories/commercial_services_repository_impl.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_detail_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_services_search_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/demo_commercial_service_scenario.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/repositories/commercial_services_repository.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/usecases/search_commercial_services.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_cubit.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/pages/commercial_services_search_page.dart';
import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';

class _FailingCommercialServicesRepository
    implements CommercialServicesRepository {
  _FailingCommercialServicesRepository({this.failure = true});

  bool failure;

  @override
  Future<CommercialServicesSearchResult> searchServices({
    String? keyword,
    CommercialServiceCategory? category,
    String? dateIso,
    int? maxPriceVnd,
    int page = 1,
    int pageSize = 20,
    bool isDemoMode = false,
  }) async {
    if (failure) {
      throw const ServerFailure('Backend error');
    }
    return const CommercialServicesSearchPending();
  }

  @override
  Future<CommercialServiceDetailResult> getServiceDetail({
    required String rawPoiId,
    String? intendedDateIso,
    bool isDemoMode = false,
    DemoCommercialServiceScenario? demoScenario,
  }) => throw UnimplementedError();
}

SearchCommercialServices _createUseCase() {
  return SearchCommercialServices(
    CommercialServicesRepositoryImpl(
      pendingDataSource: const PendingCommercialServicesDataSource(),
      demoDataSource: const DemoCommercialServicesDataSource(),
    ),
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
  group('CommercialServicesSearchPage - Screen #71 Production Truthfulness', () {
    testWidgets(
      'renders search input, category chips, production truthfulness banner, and truthful PENDING_BE_INTEGRATION empty state without exposing ordinary POIs',
      (tester) async {
        final cubit = CommercialServicesSearchCubit(
          searchCommercialServices: _createUseCase(),
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
      },
    );

    testWidgets(
      'renders failure state with retry button on error, and recovers upon retry',
      (tester) async {
        final repo = _FailingCommercialServicesRepository(failure: true);
        final cubit = CommercialServicesSearchCubit(
          searchCommercialServices: SearchCommercialServices(repo),
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

        repo.failure = false;
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
        final cubit = CommercialServicesSearchCubit(
          searchCommercialServices: _createUseCase(),
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
        final cubit = CommercialServicesSearchCubit(
          searchCommercialServices: _createUseCase(),
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
        final cubit = CommercialServicesSearchCubit(
          searchCommercialServices: _createUseCase(),
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
