import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_history_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_review_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_history_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_review_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/pages/trip_history_page.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/pages/trip_review_page.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/refund_status_dialog.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

class _SpyTripHistoryRepository implements TripHistoryRepository {
  _SpyTripHistoryRepository(this._delegate);

  final TripHistoryRepository _delegate;
  int getTripsCallCount = 0;
  TripStatus? lastQueriedStatus;
  TripType? lastQueriedType;

  @override
  Future<TripHistoryPageResult> getTrips({
    int? travelerId,
    TripStatus? status,
    TripType? type,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  }) {
    getTripsCallCount++;
    lastQueriedStatus = status;
    lastQueriedType = type;
    return _delegate.getTrips(
      travelerId: travelerId,
      status: status,
      type: type,
      startDate: startDate,
      endDate: endDate,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<TripHistoryItem?> getTripById({
    int? travelerId,
    required String tripId,
  }) {
    return _delegate.getTripById(travelerId: travelerId, tripId: tripId);
  }
}

void main() {
  late DateTime fixedNow;
  late DemoTripHistoryStore demoStore;
  late TripHistoryRepositoryImpl repository;
  late TripHistoryCubit cubit;

  setUp(() {
    fixedNow = DateTime(2026, 10, 8, 12, 0, 0);
    demoStore = DemoTripHistoryStore(now: fixedNow);
    repository = TripHistoryRepositoryImpl(
      demoStore: demoStore,
      isDemoMode: true,
    );
    cubit = TripHistoryCubit(
      repository: repository,
      isDemoMode: true,
      demoTravelerId: DemoTripHistoryStore.demoTravelerId,
    );
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildTestWidget({bool isDemoMode = true}) {
    return MaterialApp(
      home: BlocProvider<TripHistoryCubit>.value(
        value: cubit..loadInitial(),
        child: TripHistoryPage(isDemoMode: isDemoMode),
      ),
    );
  }

  group('TripHistoryPage (Screen #73) Widget Tests', () {
    testWidgets(
      'renders title, tabs, filters, and upcoming records by default',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Title & Tabs
        expect(
          find.text(TripHistoryStringsEn.tripHistoryTitle),
          findsOneWidget,
        );
        expect(find.text(TripHistoryStringsEn.tabUpcoming), findsOneWidget);
        expect(find.text(TripHistoryStringsEn.tabCompleted), findsOneWidget);
        expect(find.text(TripHistoryStringsEn.tabCancelled), findsOneWidget);

        // Filter chips
        expect(find.text(TripHistoryStringsEn.filterAll), findsOneWidget);
        expect(find.text(TripHistoryStringsEn.filterTour), findsOneWidget);
        expect(
          find.text(TripHistoryStringsEn.filterCommercialService),
          findsOneWidget,
        );
        expect(find.text(TripHistoryStringsEn.filterItinerary), findsOneWidget);

        // Upcoming bookings
        expect(find.text('BK-TOUR-001'), findsOneWidget);
        expect(find.text('BK-SRV-002'), findsOneWidget);
        expect(
          find.text(TripHistoryStringsEn.actionViewEticket),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'switching to Completed tab shows completed cards and review actions',
      (tester) async {
        tester.view.physicalSize = const Size(400, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tap Completed tab
        await tester.tap(find.text(TripHistoryStringsEn.tabCompleted));
        await tester.pumpAndSettle();

        expect(
          find.text('BK-TOUR-003'),
          findsOneWidget,
        ); // unreviewed -> Write Review
        expect(
          find.text(TripHistoryStringsEn.actionWriteReview),
          findsOneWidget,
        );

        expect(
          find.text('BK-TOUR-004'),
          findsOneWidget,
        ); // reviewed < 7d -> Edit Review
        expect(
          find.text(TripHistoryStringsEn.actionEditReview),
          findsOneWidget,
        );

        expect(
          find.text('BK-SRV-005'),
          findsOneWidget,
        ); // reviewed > 7d -> View Review
        expect(
          find.text(TripHistoryStringsEn.actionViewReview),
          findsOneWidget,
        );

        expect(find.text('ITIN-2026-006'), findsOneWidget); // Itinerary
      },
    );

    testWidgets('tapping View E-ticket displays notice', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final eticketButton = find
          .text(TripHistoryStringsEn.actionViewEticket)
          .first;
      await tester.tap(eticketButton);
      await tester.pumpAndSettle();

      expect(
        find.text(TripHistoryStringsEn.noticeEticketPending),
        findsOneWidget,
      );
    });

    testWidgets('tapping View Details opens booking details dialog', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final detailsBtn = find
          .text(TripHistoryStringsEn.actionViewDetails)
          .first;
      await tester.tap(detailsBtn);
      await tester.pumpAndSettle();

      expect(
        find.text(TripHistoryStringsEn.detailsDialogTitle),
        findsOneWidget,
      );
      expect(find.text(TripHistoryStringsEn.actionClose), findsOneWidget);

      await tester.tap(find.text(TripHistoryStringsEn.actionClose));
      await tester.pumpAndSettle();
      expect(find.text(TripHistoryStringsEn.detailsDialogTitle), findsNothing);
    });

    testWidgets(
      'switching to Cancelled tab displays refund status buttons and dialog',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Tap Cancelled tab
        await tester.tap(find.text(TripHistoryStringsEn.tabCancelled));
        await tester.pumpAndSettle();

        expect(find.text('BK-TOUR-007'), findsOneWidget);
        expect(find.text('BK-SRV-008'), findsOneWidget);
        expect(find.text('BK-TOUR-009'), findsOneWidget);

        final refundBtn = find
            .text(TripHistoryStringsEn.actionViewRefundStatus)
            .first;
        await tester.tap(refundBtn);
        await tester.pumpAndSettle();

        expect(find.byType(RefundStatusDialog), findsOneWidget);
        expect(
          find.text(TripHistoryStringsEn.refundDialogTitle),
          findsOneWidget,
        );
        expect(
          find.text(
            TripHistoryStringsEn.refundStateNonRefundable.toUpperCase(),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text(TripHistoryStringsEn.actionClose));
        await tester.pumpAndSettle();
        expect(find.byType(RefundStatusDialog), findsNothing);
      },
    );

    testWidgets(
      'empty state renders domain message when filter produces zero records',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // In upcoming tab, filter by Itinerary (there are no upcoming itineraries)
        await tester.tap(find.text(TripHistoryStringsEn.filterItinerary));
        await tester.pumpAndSettle();

        expect(
          find.text(TripHistoryStringsEn.emptyListMessage),
          findsOneWidget,
        );
      },
    );

    testWidgets('responsive layout on different device widths', (tester) async {
      final sizes = [
        const Size(360, 640),
        const Size(390, 844),
        const Size(412, 915),
      ];

      for (final size in sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.text(TripHistoryStringsEn.tripHistoryTitle),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'production mode: displays PENDING_BE_INTEGRATION banner and hides demo fixtures and retry button',
      (tester) async {
        final prodRepo = TripHistoryRepositoryImpl(isDemoMode: false);
        final prodCubit = TripHistoryCubit(
          repository: prodRepo,
          isDemoMode: false,
        );
        addTearDown(prodCubit.close);

        await prodCubit.loadInitial();

        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<TripHistoryCubit>.value(
              value: prodCubit,
              child: const TripHistoryPage(isDemoMode: false),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(TripHistoryStringsEn.productionIntegrationPending),
          findsOneWidget,
        );
        // Does not show fake demo fixtures
        expect(find.text('BK-TOUR-001'), findsNothing);
        expect(find.text('BK-SRV-002'), findsNothing);
        // Does not show retry button
        expect(find.text(TripHistoryStringsEn.actionRetry), findsNothing);
      },
    );

    testWidgets(
      'route-level regression: Write Review -> submit Demo review -> pops true -> refreshes Completed tab via new repository query',
      (tester) async {
        tester.view.physicalSize = const Size(400, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final spyRepo = _SpyTripHistoryRepository(repository);
        final testCubit = TripHistoryCubit(
          repository: spyRepo,
          isDemoMode: true,
          demoTravelerId: DemoTripHistoryStore.demoTravelerId,
        );
        addTearDown(testCubit.close);

        // Initialize once outside the route builder
        await testCubit.loadInitial();
        expect(spyRepo.getTripsCallCount, equals(1));
        expect(spyRepo.lastQueriedStatus, equals(TripStatus.upcoming));

        final reviewRepo = TripReviewRepositoryImpl(
          demoStore: demoStore,
          isDemoMode: true,
        );
        final reviewCubit = TripReviewCubit(
          repository: reviewRepo,
          isDemoMode: true,
        );
        addTearDown(reviewCubit.close);

        final router = GoRouter(
          initialLocation: AppRoutes.tripHistoryPath(isDemo: true),
          routes: [
            GoRoute(
              path: AppRoutes.tripHistory,
              builder: (_, state) {
                final isDemo = state.uri.queryParameters['demo'] == 'true';
                return BlocProvider<TripHistoryCubit>.value(
                  value: testCubit,
                  child: TripHistoryPage(isDemoMode: isDemo),
                );
              },
            ),
            GoRoute(
              path: AppRoutes.tripReviewPattern,
              builder: (_, state) {
                final isDemo = state.uri.queryParameters['demo'] == 'true';
                final trip = state.extra as TripHistoryItem;
                return BlocProvider<TripReviewCubit>.value(
                  value: reviewCubit,
                  child: TripReviewPage(
                    trip: trip,
                    isDemoMode: isDemo,
                    demoTravelerId: DemoTripHistoryStore.demoTravelerId,
                    referenceTime: fixedNow,
                  ),
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        // Building the route did NOT trigger another loadInitial()
        expect(spyRepo.getTripsCallCount, equals(1));

        // 1. Switch to Completed tab where unreviewed BK-TOUR-003 exists
        await tester.tap(find.text(TripHistoryStringsEn.tabCompleted));
        await tester.pumpAndSettle();

        expect(spyRepo.getTripsCallCount, equals(2));
        expect(spyRepo.lastQueriedStatus, equals(TripStatus.completed));

        expect(find.text('BK-TOUR-003'), findsOneWidget);
        final writeReviewBtn = find.text(
          TripHistoryStringsEn.actionWriteReview,
        );
        expect(writeReviewBtn, findsOneWidget);
        expect(
          find.text(TripHistoryStringsEn.actionEditReview),
          findsOneWidget,
        );

        // 2. Tap Write Review to push Screen #74
        await tester.ensureVisible(writeReviewBtn);
        await tester.tap(writeReviewBtn);
        await tester.pumpAndSettle();

        expect(find.byType(TripReviewPage), findsOneWidget);
        expect(find.text(TripHistoryStringsEn.tripReviewTitle), findsOneWidget);

        // 3. Fill in rating and required fields
        final stars = find.byIcon(Icons.star_outline_rounded);
        await tester.tap(stars.last); // 5 stars
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, TripHistoryStringsEn.reviewTitleHint),
          'Unforgettable Journey',
        );
        await tester.enterText(
          find.widgetWithText(
            TextField,
            TripHistoryStringsEn.reviewContentHint,
          ),
          'The tour was exceptionally well-organized and inspiring.',
        );
        await tester.pumpAndSettle();

        // 4. Submit review
        final submitBtn = find.text(TripHistoryStringsEn.actionSubmitReview);
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // 5. Verify regression requirements:
        // - Review success pops true (TripReviewPage is dismissed)
        expect(find.byType(TripReviewPage), findsNothing);
        // - TripHistoryPage reacts to true (remains mounted)
        expect(find.byType(TripHistoryPage), findsOneWidget);
        // - Completed tab is active and a NEW repository query (call #3) was executed
        expect(testCubit.state.selectedTab, equals(TripStatus.completed));
        expect(spyRepo.getTripsCallCount, equals(3));
        expect(spyRepo.lastQueriedStatus, equals(TripStatus.completed));
        // - Newly submitted review is reflected: BK-TOUR-003 changes from "Write Review" to "Edit Review"
        expect(find.text('BK-TOUR-003'), findsOneWidget);
        expect(find.text(TripHistoryStringsEn.actionWriteReview), findsNothing);
        expect(
          find.text(TripHistoryStringsEn.actionEditReview),
          findsNWidgets(2),
        );
      },
    );
  });
}
