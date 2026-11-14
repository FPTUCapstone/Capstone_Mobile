import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/pages/tour_detail_page.dart';
import 'package:trip_mate_mobile/features/tour_discovery/domain/entities/tour_discovery_item.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/compact_horizontal_tour_card.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/featured_tour_editorial_card.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/tour_discovery_feed_states.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/traveler_tour_discovery_section.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/paged_tour_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_search_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_summary.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_list_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/traveler_home_dashboard_view.dart';
import 'package:trip_mate_mobile/shared/widgets/motion/editorial_tour_hero.dart';

final class _FakeItineraryListRepository implements ItineraryListRepository {
  @override
  Future<ItinerarySummaryPage> listMine({
    int page = 1,
    int pageSize = 20,
  }) async {
    return const ItinerarySummaryPage(
      items: [],
      page: 1,
      pageSize: 20,
      totalCount: 0,
    );
  }
}

final class _FakeTourSearchRepository implements TourSearchRepository {
  _FakeTourSearchRepository({this.result, this.failure});

  PagedTourResult? result;
  Failure? failure;
  int searchCalls = 0;

  @override
  Future<PagedTourResult> searchTours(TourSearchQuery query) async {
    searchCalls++;
    if (failure != null) throw failure!;
    return result ??
        const PagedTourResult(
          page: 1,
          pageSize: 20,
          totalCount: 0,
          totalPages: 0,
          items: [],
        );
  }
}

const _realBackendTours = [
  TourSummary(
    tourId: 'backend_tour_01',
    title: 'Tour Di Sản Cố Đô Huế',
    destinations: ['Huế', 'Đại Nội'],
    operatorName: 'Hue Heritage Operator',
    durationDays: 1,
    basePrice: 890000,
    currency: 'VND',
    representativeScheduleId: 'sch_01',
    departureAtUtc: null,
    availabilityStatus: AvailabilityStatus.available,
    remainingSlots: 10,
    thumbnailUrl: 'assets/images/destinations/hue_ngo_mon.jpg',
    aggregateRating: 4.9,
  ),
  TourSummary(
    tourId: 'backend_tour_02',
    title: 'Tour Cầu Rồng & Bà Nà Hills',
    destinations: ['Đà Nẵng', 'Bà Nà'],
    operatorName: 'Danang Travel Corp',
    durationDays: 1,
    basePrice: 1290000,
    currency: 'VND',
    representativeScheduleId: 'sch_02',
    departureAtUtc: null,
    availabilityStatus: AvailabilityStatus.available,
    remainingSlots: 6,
    thumbnailUrl: 'assets/images/destinations/bana_golden_bridge.jpg',
    aggregateRating: 4.8,
  ),
  TourSummary(
    tourId: 'backend_tour_03',
    title: 'Tour Phố Cổ Hội An',
    destinations: ['Hội An', 'Quảng Nam'],
    operatorName: 'Hoi An Eco Travel',
    durationDays: 1,
    basePrice: 690000,
    currency: 'VND',
    representativeScheduleId: 'sch_03',
    departureAtUtc: null,
    availabilityStatus: AvailabilityStatus.available,
    remainingSlots: 4,
    thumbnailUrl: 'assets/images/destinations/hoian_ancient_town.jpg',
    aggregateRating: 4.7,
  ),
];

Widget _buildHarness({required Widget child, MyTripsCubit? tripsCubit}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: BlocProvider<MyTripsCubit>.value(
      value:
          tripsCubit ??
          MyTripsCubit(repository: _FakeItineraryListRepository()),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() async {
    await serviceLocator.reset();
  });

  tearDown(serviceLocator.reset);

  group(
    'R1 & R2: Production Data Lifecycle & Feed States in TravelerHomeDashboardView',
    () {
      testWidgets(
        'binds real public tour summaries from TourSearchCubit to discovery section',
        (tester) async {
          final fakeRepo = _FakeTourSearchRepository(
            result: const PagedTourResult(
              page: 1,
              pageSize: 20,
              totalCount: 3,
              totalPages: 1,
              items: _realBackendTours,
            ),
          );

          final searchCubit = TourSearchCubit(
            searchTours: SearchToursUseCase(fakeRepo),
          );
          addTearDown(searchCubit.close);

          await searchCubit.loadInitial();

          await tester.pumpWidget(
            _buildHarness(
              child: TravelerHomeDashboardView(tourSearchCubit: searchCubit),
            ),
          );
          await tester.pumpAndSettle();

          // Verify legitimate real tour data from backend appears
          expect(find.text('Tour Di Sản Cố Đô Huế'), findsOneWidget);
          expect(find.text('Hue Heritage Operator'), findsOneWidget);
          expect(find.text('890,000 VND'), findsOneWidget);

          expect(find.text('Tour Cầu Rồng & Bà Nà Hills'), findsOneWidget);
          expect(find.text('Danang Travel Corp'), findsOneWidget);
          expect(find.text('1,290,000 VND'), findsOneWidget);

          expect(find.byType(FeaturedTourEditorialCard), findsOneWidget);
          expect(find.byType(CompactHorizontalTourCard), findsNWidgets(2));
        },
      );

      testWidgets(
        'renders honest TourDiscoveryEmptyView when search results are empty',
        (tester) async {
          final fakeRepo = _FakeTourSearchRepository(
            result: const PagedTourResult(
              page: 1,
              pageSize: 20,
              totalCount: 0,
              totalPages: 0,
              items: [],
            ),
          );

          final searchCubit = TourSearchCubit(
            searchTours: SearchToursUseCase(fakeRepo),
          );
          addTearDown(searchCubit.close);

          await searchCubit.loadInitial();

          await tester.pumpWidget(
            _buildHarness(
              child: TravelerHomeDashboardView(tourSearchCubit: searchCubit),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(TourDiscoveryEmptyView), findsOneWidget);
          expect(find.text('Chưa có tour công khai phù hợp'), findsOneWidget);
          expect(find.byType(FeaturedTourEditorialCard), findsNothing);
        },
      );

      testWidgets(
        'renders TourDiscoveryErrorView on query failure and retry triggers real reload',
        (tester) async {
          final fakeRepo = _FakeTourSearchRepository(
            failure: const ServerFailure('Lỗi kết nối máy chủ'),
          );

          final searchCubit = TourSearchCubit(
            searchTours: SearchToursUseCase(fakeRepo),
          );
          addTearDown(searchCubit.close);

          await searchCubit.loadInitial();

          await tester.pumpWidget(
            _buildHarness(
              child: TravelerHomeDashboardView(tourSearchCubit: searchCubit),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(TourDiscoveryErrorView), findsOneWidget);
          expect(find.text('Không thể tải gợi ý tour'), findsOneWidget);
          expect(find.text('Thử lại'), findsOneWidget);

          final callsBeforeRetry = fakeRepo.searchCalls;

          // Fix failure and tap retry
          fakeRepo.failure = null;
          fakeRepo.result = const PagedTourResult(
            page: 1,
            pageSize: 20,
            totalCount: 3,
            totalPages: 1,
            items: _realBackendTours,
          );

          await tester.scrollUntilVisible(find.text('Thử lại'), 100);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Thử lại'));
          await tester.pumpAndSettle();

          expect(fakeRepo.searchCalls, greaterThan(callsBeforeRetry));
          expect(find.text('Tour Di Sản Cố Đô Huế'), findsOneWidget);
        },
      );

      testWidgets(
        'defaults to honest empty state when TourSearchCubit is not registered',
        (tester) async {
          await tester.pumpWidget(
            _buildHarness(child: const TravelerHomeDashboardView()),
          );
          await tester.pumpAndSettle();

          // When no search repository is in DI, must render honest empty state without crashing
          expect(find.byType(TourDiscoveryEmptyView), findsOneWidget);
          expect(find.byType(FeaturedTourEditorialCard), findsNothing);
        },
      );

      testWidgets(
        'pull-to-refresh triggers both trips and tour discovery reload',
        (tester) async {
          final fakeRepo = _FakeTourSearchRepository(
            result: const PagedTourResult(
              page: 1,
              pageSize: 20,
              totalCount: 3,
              totalPages: 1,
              items: _realBackendTours,
            ),
          );

          final searchCubit = TourSearchCubit(
            searchTours: SearchToursUseCase(fakeRepo),
          );
          addTearDown(searchCubit.close);

          await searchCubit.loadInitial();

          await tester.pumpWidget(
            _buildHarness(
              child: TravelerHomeDashboardView(tourSearchCubit: searchCubit),
            ),
          );
          await tester.pumpAndSettle();

          final callsBefore = fakeRepo.searchCalls;

          // Pull down to refresh
          await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
          await tester.pumpAndSettle();

          expect(fakeRepo.searchCalls, greaterThan(callsBefore));
        },
      );
    },
  );

  group('R3: Tour Details Navigation & Hero Continuity', () {
    testWidgets(
      'card tap navigates with valid tour ID and mounts Frame-0 Hero in TourDetailPage',
      (tester) async {
        final summary = _realBackendTours[0];

        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => Scaffold(
                body: SingleChildScrollView(
                  child: TravelerTourDiscoverySection(
                    feedState: TourDiscoveryFeedState.content,
                    tours: [
                      _realBackendTours.first,
                    ].map(TourDiscoveryItem.fromSummary).toList(),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: AppRoutes.tourDetailPattern,
              name: AppRouteNames.tourDetail,
              builder: (_, state) {
                final tourId = state.pathParameters['tourId'] ?? '';
                final extra = state.extra is TourSummary
                    ? state.extra as TourSummary
                    : null;
                final heroTag = state.uri.queryParameters['heroTag'];
                return TourDetailPage(
                  tourId: tourId,
                  initialSummary: extra,
                  heroTag: heroTag,
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        );
        await tester.pumpAndSettle();

        // Tap the featured tour card
        await tester.tap(find.byType(FeaturedTourEditorialCard));
        await tester.pump(); // Frame 0 of route push

        // Assert Hero is mounted immediately on Frame 0 before network completion
        expect(find.byType(EditorialTourHero), findsOneWidget);
        final heroWidget = tester.widget<Hero>(find.byType(Hero));
        expect(heroWidget.tag, 'home_featured_${summary.tourId}');

        await tester.pumpAndSettle();

        // Assert lossless contract data transfer to TourDetailPage initialSummary
        final detailWidget = tester.widget<TourDetailPage>(
          find.byType(TourDetailPage),
        );
        expect(detailWidget.initialSummary?.representativeScheduleId, 'sch_01');
        expect(detailWidget.initialSummary?.currency, 'VND');
        expect(detailWidget.initialSummary?.destinations, const [
          'Huế',
          'Đại Nội',
        ]);

        // Back navigation verification
        expect(find.byIcon(Icons.arrow_back), findsWidgets);
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pumpAndSettle();

        // Back on Home
        expect(find.byType(FeaturedTourEditorialCard), findsOneWidget);
      },
    );

    testWidgets(
      'TourDetailPage handles image error gracefully without layout explosion',
      (tester) async {
        const summaryWithBrokenImage = TourSummary(
          tourId: 'broken_img_tour',
          title: 'Tour Ảnh Hỏng',
          destinations: ['Đà Nẵng'],
          operatorName: 'Test Operator',
          durationDays: 1,
          basePrice: 500000,
          currency: 'VND',
          representativeScheduleId: null,
          departureAtUtc: null,
          availabilityStatus: AvailabilityStatus.available,
          remainingSlots: 5,
          thumbnailUrl: 'https://invalid.example.com/broken_photo.jpg',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const TourDetailPage(
              tourId: 'broken_img_tour',
              initialSummary: summaryWithBrokenImage,
              heroTag: 'home_featured_broken_img_tour',
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(EditorialTourHero), findsOneWidget);
      },
    );
  });
}
