import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
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

  testWidgets('lists trips with their schedule and progress', (tester) async {
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
    expect(find.text('Trip in progress'), findsOneWidget);
    expect(find.text('Shared with you'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    // 02:03 UTC is 09:03 in Vietnam, whatever the device time zone.
    expect(find.text('Sat, 10 Oct · 09:03–11:40 · 2 stops'), findsNWidgets(2));
  });

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
    expect(find.text('Trip in progress'), findsOneWidget);
  });

  testWidgets('shows an empty state with the create action', (tester) async {
    await pumpTrips(tester, FakeItineraryListRepository({1: tripPage([])}));

    expect(
      find.text('No trips yet. Create an itinerary to plan your first trip.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Create an itinerary'));
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
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Trip 60014'), findsOneWidget);
  });
}
