import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/data/datasources/demo_trip_history_store.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_history_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/pages/trip_history_page.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/refund_status_dialog.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

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
    cubit = TripHistoryCubit(repository: repository, defaultTravelerId: 1);
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: BlocProvider<TripHistoryCubit>.value(
        value: cubit..loadInitial(),
        child: const TripHistoryPage(),
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
  });
}
