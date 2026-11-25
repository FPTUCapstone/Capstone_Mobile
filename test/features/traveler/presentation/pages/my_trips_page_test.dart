import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_summary.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/my_trips_page.dart';

import '../cubit/my_trips_cubit_test.dart';

void main() {
  Future<MyTripsCubit> pumpTrips(
    WidgetTester tester,
    FakeItineraryListRepository repository,
  ) async {
    final cubit = MyTripsCubit(repository: repository);
    addTearDown(cubit.close);
    final router = GoRouter(
      initialLocation: '/trips',
      routes: [
        GoRoute(
          path: '/trips',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(value: cubit, child: const MyTripsPage()),
          ),
        ),
        GoRoute(
          path: '/traveler/itineraries/create',
          builder: (_, _) => const Text('Create itinerary page'),
        ),
        GoRoute(
          path: '/traveler/itineraries/:itineraryId',
          builder: (_, state) =>
              Text('Itinerary ${state.pathParameters['itineraryId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await cubit.load();
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('lists trips grouped by status with schedule and progress', (
    tester,
  ) async {
    await pumpTrips(
      tester,
      FakeItineraryListRepository({
        1: tripPage([
          tripSummary(60014, openSessionId: 11),
          tripSummary(60015, status: 'Draft', canManage: false),
        ]),
      }),
    );

    expect(find.text('Trip 60014'), findsOneWidget);
    expect(find.text('Đang dẫn đường'), findsOneWidget);
    expect(find.text('Được chia sẻ'), findsWidgets);
    expect(find.text('Bản nháp'), findsWidgets);
    // 02:03–04:40 UTC is 09:03–11:40 in Vietnam (2g 37p).
    expect(find.text('09:03 – 11:40 (2g 37p) · 2 điểm'), findsNWidgets(2));
  });

  testWidgets(
    'formats generic generated titles using previewStopNames and filters tabs',
    (tester) async {
      await pumpTrips(
        tester,
        FakeItineraryListRepository({
          1: tripPage([
            ItinerarySummary(
              itineraryId: 180066,
              title: 'Generated itinerary - 25 Nov 2026',
              version: 4,
              status: 'Active',
              validFrom: DateTime.utc(2026, 11, 25, 1, 0),
              validTo: DateTime.utc(2026, 11, 25, 9, 0),
              canManage: true,
              stopCount: 5,
              openNavigationSessionId: null,
              transportMode: TransportMode.motorbike,
              previewStopNames: const [
                'Bãi biển Mỹ Khê',
                'Bảo tàng Mỹ thuật',
                'Động Âm Phủ',
              ],
            ),
            ItinerarySummary(
              itineraryId: 180062,
              title: 'Generated itinerary - 25 Nov 2026',
              version: 2,
              status: 'Draft',
              validFrom: DateTime.utc(2026, 11, 25, 1, 0),
              validTo: DateTime.utc(2026, 11, 25, 9, 0),
              canManage: true,
              stopCount: 6,
              openNavigationSessionId: null,
              transportMode: TransportMode.motorbike,
              previewStopNames: const [
                'Chùa Cầu Hội An',
                'Hội quán Quảng Đông',
              ],
            ),
          ]),
        }),
      );

      expect(find.text('Bãi biển Mỹ Khê – Bảo tàng Mỹ thuật'), findsOneWidget);
      expect(
        find.text('Chùa Cầu Hội An – Hội quán Quảng Đông'),
        findsOneWidget,
      );
      expect(find.text('Generated itinerary - 25 Nov 2026'), findsNothing);

      // Filter to confirmed only
      await tester.tap(find.text('Đã chốt').first);
      await tester.pumpAndSettle();
      expect(find.text('Bãi biển Mỹ Khê – Bảo tàng Mỹ thuật'), findsOneWidget);
      expect(find.text('Chùa Cầu Hội An – Hội quán Quảng Đông'), findsNothing);
    },
  );

  testWidgets('opening a trip leads to its itinerary detail', (tester) async {
    final repository = FakeItineraryListRepository({
      1: tripPage([tripSummary(60014)]),
    });
    await pumpTrips(tester, repository);

    await tester.tap(find.text('Trip 60014'));
    await tester.pumpAndSettle();

    expect(find.text('Itinerary 60014'), findsOneWidget);
  });

  testWidgets('returning from the detail refreshes the list', (tester) async {
    final repository = FakeItineraryListRepository({
      1: tripPage([tripSummary(60014)]),
    });
    await pumpTrips(tester, repository);
    await tester.tap(find.text('Trip 60014'));
    await tester.pumpAndSettle();

    repository.pages[1] = tripPage([tripSummary(60014, openSessionId: 12)]);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [1, 1]);
    expect(find.text('Đang dẫn đường'), findsOneWidget);
  });

  testWidgets('shows an empty state with the create action', (tester) async {
    await pumpTrips(tester, FakeItineraryListRepository({1: tripPage([])}));

    expect(
      find.text(
        'Chưa có lịch trình nào. Tạo lịch trình đầu tiên để bắt đầu khám phá.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Lập lịch mới'));
    await tester.pumpAndSettle();
    expect(find.text('Create itinerary page'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    final repository = FakeItineraryListRepository({
      1: tripPage([tripSummary(60014)]),
    })..failure = const ServerFailure();
    await pumpTrips(tester, repository);

    expect(find.text('The service is currently unavailable.'), findsOneWidget);
    repository.failure = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Trip 60014'), findsOneWidget);
  });
}
