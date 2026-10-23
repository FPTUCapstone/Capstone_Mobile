import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/demo_trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/trip_records_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/pages/trip_history_page.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/trip_record_detail_sheet.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

/// The demo repository, watched, with a hook to replace one answer.
final class _SpyRepository implements TripRecordsRepository {
  final _demo = const DemoTripRecordsRepository();
  final List<TripRecordsQuery> queries = [];
  Future<TripRecordPage> Function(TripRecordsQuery query)? onPage;

  @override
  Future<TripRecordPage> getPage(TripRecordsQuery query) {
    queries.add(query);
    return (onPage ?? _demo.getPage)(query);
  }

  @override
  Future<TripRecordDetail> getDetail(TripRecordKind kind, int id) =>
      _demo.getDetail(kind, id);
}

void main() {
  late _SpyRepository repository;
  late TripRecordsCubit cubit;
  late List<String> visited;

  setUp(() {
    repository = _SpyRepository();
    cubit = TripRecordsCubit(useCase: TripRecordsUseCase(repository));
    visited = [];
    if (serviceLocator.isRegistered<TripRecordDetailCubit>()) {
      serviceLocator.unregister<TripRecordDetailCubit>();
    }
    serviceLocator
        .registerFactoryParam<TripRecordDetailCubit, TripRecordRef, bool>(
          (ref, _) => TripRecordDetailCubit(
            useCase: TripRecordsUseCase(repository),
            reference: ref,
          ),
        );
  });

  tearDown(() async {
    await cubit.close();
    if (serviceLocator.isRegistered<TripRecordDetailCubit>()) {
      serviceLocator.unregister<TripRecordDetailCubit>();
    }
  });

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// The page inside a router that also knows the canonical review route, so
  /// the destination of Write/View review can be observed.
  Future<void> pumpPage(WidgetTester tester, {bool isDemo = true}) async {
    // Once, outside the route builder: a rebuild of the route must not reload.
    await cubit.loadInitial();
    final router = GoRouter(
      initialLocation: AppRoutes.tripHistory,
      routes: [
        GoRoute(
          path: AppRoutes.tripHistory,
          builder: (_, _) => BlocProvider<TripRecordsCubit>.value(
            value: cubit,
            child: TripHistoryPage(isDemoMode: isDemo),
          ),
        ),
        GoRoute(
          path: AppRoutes.bookingRefundPattern,
          builder: (_, state) {
            visited.add(state.uri.path);
            return const Scaffold(body: Text('Refund progress stub'));
          },
        ),
        GoRoute(
          path: AppRoutes.canonicalTripReviewPattern,
          builder: (context, state) {
            visited.add(state.uri.path);
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => context.pop(true),
                  child: const Text('Submit stub review'),
                ),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Finder card(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(Card));

  Finder inCard(String cardText, String text) =>
      find.descendant(of: card(cardText), matching: find.text(text));

  group('layout', () {
    testWidgets('shows the title, three tabs and only All / Tour / Itinerary', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text(TripHistoryStringsEn.tripHistoryTitle), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.tabUpcoming), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.tabCompleted), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.tabCancelled), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.filterAll), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.filterTour), findsWidgets);
      expect(find.text(TripHistoryStringsEn.filterItinerary), findsWidgets);
      expect(
        find.text(TripHistoryStringsEn.filterCommercialService),
        findsNothing,
      );
    });

    testWidgets('Upcoming lists the booking and the itinerary of that tab', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(repository.queries.single.tab, TripStatus.upcoming);
      expect(find.text('Son Tra Peninsula Tour'), findsOneWidget);
      expect(find.text('TM-009003'), findsOneWidget);
      expect(find.text('Hoi An weekend plan'), findsOneWidget);
      expect(
        inCard(
          'Son Tra Peninsula Tour',
          TripHistoryStringsEn.actionViewEticket,
        ),
        findsOneWidget,
      );
      expect(
        inCard('Hoi An weekend plan', TripHistoryStringsEn.actionViewEticket),
        findsNothing,
      );
    });

    testWidgets('fits phone widths without overflow', (tester) async {
      for (final size in const [
        Size(320, 640),
        Size(360, 640),
        Size(412, 915),
      ]) {
        useSize(tester, size);
        await pumpPage(tester);

        expect(
          find.text(TripHistoryStringsEn.tripHistoryTitle),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Completed tab', () {
    testWidgets('shows the summary the backend sent', (tester) async {
      useSize(tester, const Size(400, 2400));
      await pumpPage(tester);

      await openTab(tester, TripHistoryStringsEn.tabCompleted);

      final summary = (await const DemoTripRecordsRepository().getPage(
        const TripRecordsQuery(tab: TripStatus.completed),
      )).summary!;
      expect(
        find.textContaining(
          TripHistoryStringsEn.summaryCompletedTrips(
            summary.totalCompletedTrips,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          TripHistoryStringsEn.summaryVisitedPois(summary.totalVisitedPois),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Write review only where canReview, View review only where a '
        'review exists, and never Edit review', (tester) async {
      useSize(tester, const Size(400, 2400));
      await pumpPage(tester);

      await openTab(tester, TripHistoryStringsEn.tabCompleted);

      expect(
        inCard('Hoi An Lantern Tour', TripHistoryStringsEn.actionWriteReview),
        findsOneWidget,
      );
      expect(
        inCard('Hoi An Lantern Tour', TripHistoryStringsEn.actionViewReview),
        findsNothing,
      );
      expect(
        inCard('Ba Na Hills Day Tour', TripHistoryStringsEn.actionViewReview),
        findsOneWidget,
      );
      expect(
        inCard('Ba Na Hills Day Tour', TripHistoryStringsEn.actionWriteReview),
        findsNothing,
      );
      expect(find.text(TripHistoryStringsEn.actionEditReview), findsNothing);
      expect(
        inCard('Da Nang 2 days', TripHistoryStringsEn.actionWriteReview),
        findsNothing,
      );
    });

    testWidgets('an itinerary shows its stops and how many were visited', (
      tester,
    ) async {
      useSize(tester, const Size(400, 2400));
      await pumpPage(tester);

      await openTab(tester, TripHistoryStringsEn.tabCompleted);

      final detail = await const DemoTripRecordsRepository().getDetail(
        TripRecordKind.itinerary,
        5001,
      );
      final record = detail.record as ItineraryTripRecord;
      expect(
        inCard(
          'Da Nang 2 days',
          TripHistoryStringsEn.formatStopCount(record.stopCount),
        ),
        findsOneWidget,
      );
      expect(
        inCard(
          'Da Nang 2 days',
          TripHistoryStringsEn.formatVisitedOf(
            record.visitedCount!,
            record.stopCount,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Upcoming itineraries do not claim any visited stops', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.textContaining('Visited'), findsNothing);
    });
  });

  group('review routes', () {
    testWidgets('Write review opens the canonical review of the booking and '
        'a saved review refreshes the list', (tester) async {
      useSize(tester, const Size(400, 2400));
      await pumpPage(tester);
      await openTab(tester, TripHistoryStringsEn.tabCompleted);
      final before = repository.queries.length;

      await tester.tap(
        inCard('Hoi An Lantern Tour', TripHistoryStringsEn.actionWriteReview),
      );
      await tester.pumpAndSettle();

      expect(visited, ['/traveler/reviews/commerceBooking/9001']);

      await tester.tap(find.text('Submit stub review'));
      await tester.pumpAndSettle();

      expect(repository.queries.length, before + 1);
      expect(repository.queries.last.tab, TripStatus.completed);
      expect(find.text(TripHistoryStringsEn.tripHistoryTitle), findsOneWidget);
    });

    testWidgets('View review opens the canonical review and a plain back does '
        'not reload', (tester) async {
      useSize(tester, const Size(400, 2400));
      await pumpPage(tester);
      await openTab(tester, TripHistoryStringsEn.tabCompleted);
      final before = repository.queries.length;

      await tester.tap(
        inCard('Ba Na Hills Day Tour', TripHistoryStringsEn.actionViewReview),
      );
      await tester.pumpAndSettle();
      expect(visited, ['/traveler/reviews/commerceBooking/9002']);

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop();
      await tester.pumpAndSettle();

      expect(repository.queries.length, before);
    });
  });

  group('actions', () {
    testWidgets('E-ticket shows the pending notice and goes nowhere', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(
        inCard(
          'Son Tra Peninsula Tour',
          TripHistoryStringsEn.actionViewEticket,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(TripHistoryStringsEn.noticeEticketPending),
        findsOneWidget,
      );
      expect(visited, isEmpty);
    });

    testWidgets('View details opens the detail sheet for the record', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(
        inCard('Hoi An weekend plan', TripHistoryStringsEn.actionViewDetails),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripRecordDetailSheet), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.stopsSectionTitle), findsWidgets);
    });

    testWidgets('View refund appears only where canViewRefund and opens the '
        'sheet on the refund', (tester) async {
      useSize(tester, const Size(400, 1600));
      await pumpPage(tester);
      await openTab(tester, TripHistoryStringsEn.tabCancelled);

      expect(
        inCard(
          'Marble Mountains Tour',
          TripHistoryStringsEn.actionViewRefundStatus,
        ),
        findsNothing,
      );
      await tester.tap(
        inCard(
          'My Son Sanctuary Tour',
          TripHistoryStringsEn.actionViewRefundStatus,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TripRecordDetailSheet), findsOneWidget);
      expect(
        find.byKey(const Key('trip-detail-refund-highlighted')),
        findsOneWidget,
      );
    });
  });

  group('refund tracking', () {
    testWidgets('outside demo mode View refund opens the live refund progress '
        'of the booking', (tester) async {
      useSize(tester, const Size(400, 1600));
      await pumpPage(tester, isDemo: false);
      await openTab(tester, TripHistoryStringsEn.tabCancelled);

      await tester.tap(
        inCard(
          'My Son Sanctuary Tour',
          TripHistoryStringsEn.actionViewRefundStatus,
        ),
      );
      await tester.pumpAndSettle();

      expect(visited, ['/bookings/9004/refund']);
      expect(find.byType(TripRecordDetailSheet), findsNothing);
    });

    testWidgets('in demo mode a made-up id never reaches the refund route', (
      tester,
    ) async {
      useSize(tester, const Size(400, 1600));
      await pumpPage(tester);
      await openTab(tester, TripHistoryStringsEn.tabCancelled);

      await tester.tap(
        inCard(
          'My Son Sanctuary Tour',
          TripHistoryStringsEn.actionViewRefundStatus,
        ),
      );
      await tester.pumpAndSettle();

      expect(visited, isEmpty);
      expect(find.byType(TripRecordDetailSheet), findsOneWidget);
    });
  });

  group('filters and tabs', () {
    testWidgets('choosing Itinerary asks the backend for that trip type', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(
        find.widgetWithText(ChoiceChip, TripHistoryStringsEn.filterItinerary),
      );
      await tester.pumpAndSettle();

      expect(
        repository.queries.last.tripType,
        TripRecordTypeFilter.selfPlannedItinerary,
      );
      expect(find.text('Son Tra Peninsula Tour'), findsNothing);
      expect(find.text('Hoi An weekend plan'), findsOneWidget);
    });

    testWidgets('Reset clears the type in one request', (tester) async {
      await pumpPage(tester);
      await tester.tap(
        find.widgetWithText(ChoiceChip, TripHistoryStringsEn.filterTour),
      );
      await tester.pumpAndSettle();
      final before = repository.queries.length;

      await tester.tap(find.text(TripHistoryStringsEn.filterReset));
      await tester.pumpAndSettle();

      expect(repository.queries.length, before + 1);
      expect(repository.queries.last.tripType, TripRecordTypeFilter.all);
      expect(find.text(TripHistoryStringsEn.filterReset), findsNothing);
    });

    testWidgets('a reversed date range shows MSG29 and keeps the list', (
      tester,
    ) async {
      await pumpPage(tester);
      final before = repository.queries.length;

      await cubit.setDateRange(DateTime(2026, 10, 9), DateTime(2026, 10, 1));
      await tester.pumpAndSettle();

      expect(
        find.text(TripHistoryStringsEn.validationDateRangeInvalid),
        findsOneWidget,
      );
      expect(repository.queries.length, before);
      expect(find.text('Son Tra Peninsula Tour'), findsOneWidget);
    });

    testWidgets('switching tabs and back reloads that tab', (tester) async {
      await pumpPage(tester);

      await openTab(tester, TripHistoryStringsEn.tabCancelled);
      expect(repository.queries.last.tab, TripStatus.cancelled);
      expect(find.text('My Son Sanctuary Tour'), findsOneWidget);

      await openTab(tester, TripHistoryStringsEn.tabUpcoming);
      expect(repository.queries.last.tab, TripStatus.upcoming);
      expect(find.text('Son Tra Peninsula Tour'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('an empty tab shows the empty message', (tester) async {
      repository.onPage = (q) async => TripRecordPage(
        items: const [],
        page: q.page,
        pageSize: q.pageSize,
        totalCount: 0,
      );
      await pumpPage(tester);

      expect(find.text(TripHistoryStringsEn.emptyListMessage), findsOneWidget);
    });

    testWidgets('a failure shows the message and Retry, never a pending banner '
        'or fixtures', (tester) async {
      repository.onPage = (_) async => throw const NetworkFailure();
      await pumpPage(tester);

      expect(
        find.text(TripHistoryStringsEn.errorMessageGeneric),
        findsOneWidget,
      );
      expect(
        find.text(TripHistoryStringsEn.productionIntegrationPending),
        findsNothing,
      );
      expect(find.text('Son Tra Peninsula Tour'), findsNothing);

      repository.onPage = null;
      await tester.tap(find.text(TripHistoryStringsEn.actionRetry));
      await tester.pumpAndSettle();

      expect(find.text('Son Tra Peninsula Tour'), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.actionRetry), findsNothing);
    });

    testWidgets('paging shows the page indicator and asks for the next page', (
      tester,
    ) async {
      final demo = const DemoTripRecordsRepository();
      repository.onPage = (q) async {
        final one = await demo.getPage(TripRecordsQuery(tab: q.tab));
        return TripRecordPage(
          items: one.items,
          page: q.page,
          pageSize: q.pageSize,
          totalCount: 100,
        );
      };
      await pumpPage(tester);

      expect(
        find.text(TripHistoryStringsEn.formatPagination(1, 5)),
        findsOneWidget,
      );

      await tester.tap(find.text(TripHistoryStringsEn.paginationNext));
      await tester.pumpAndSettle();

      expect(repository.queries.last.page, 2);
      expect(
        find.text(TripHistoryStringsEn.formatPagination(2, 5)),
        findsOneWidget,
      );
    });
  });
}
