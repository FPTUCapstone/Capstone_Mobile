import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_summary.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_list_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_state.dart';

ItinerarySummary tripSummary(
  int id, {
  String status = 'Active',
  int? openSessionId,
  bool canManage = true,
}) => ItinerarySummary(
  itineraryId: id,
  title: 'Trip $id',
  version: 1,
  status: status,
  validFrom: DateTime.utc(2026, 10, 10, 2, 3),
  validTo: DateTime.utc(2026, 10, 10, 4, 40),
  canManage: canManage,
  stopCount: 2,
  openNavigationSessionId: openSessionId,
);

final class FakeItineraryListRepository implements ItineraryListRepository {
  FakeItineraryListRepository(this.pages);

  final Map<int, ItinerarySummaryPage> pages;
  final requestedPages = <int>[];
  Object? failure;
  Completer<void>? gate;

  @override
  Future<ItinerarySummaryPage> listMine({
    int page = 1,
    int pageSize = 20,
  }) async {
    requestedPages.add(page);
    await gate?.future;
    if (failure != null) throw failure!;
    return pages[page]!;
  }
}

ItinerarySummaryPage tripPage(
  List<ItinerarySummary> items, {
  int page = 1,
  int? totalCount,
}) => ItinerarySummaryPage(
  items: items,
  page: page,
  pageSize: MyTripsCubit.pageSize,
  totalCount: totalCount ?? items.length,
);

void main() {
  test('load shows the Traveler trips', () async {
    final repository = FakeItineraryListRepository({
      1: tripPage([tripSummary(1, openSessionId: 9), tripSummary(2)]),
    });
    final cubit = MyTripsCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, MyTripsStatus.ready);
    expect(cubit.state.trips.map((trip) => trip.itineraryId), [1, 2]);
    expect(cubit.state.hasMore, isFalse);
  });

  test('a failed refresh keeps the trips already shown', () async {
    final repository = FakeItineraryListRepository({
      1: tripPage([tripSummary(1)]),
    });
    final cubit = MyTripsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    repository.failure = const NetworkFailure();
    await cubit.load();

    expect(cubit.state.status, MyTripsStatus.failure);
    expect(cubit.state.message, 'Please check your connection.');
    expect(cubit.state.trips.single.itineraryId, 1);
  });

  test('loadMore appends the next page without duplicates', () async {
    final repository = FakeItineraryListRepository({
      1: tripPage([tripSummary(1), tripSummary(2)], totalCount: 3),
      2: tripPage([tripSummary(2), tripSummary(3)], page: 2, totalCount: 3),
    });
    final cubit = MyTripsCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.loadMore();

    expect(repository.requestedPages, [1, 2]);
    expect(cubit.state.trips.map((trip) => trip.itineraryId), [1, 2, 3]);
    expect(cubit.state.hasMore, isFalse);
  });

  test('a newer load wins over a slower earlier one', () async {
    final repository = FakeItineraryListRepository({
      1: tripPage([tripSummary(1)]),
    });
    final cubit = MyTripsCubit(repository: repository);
    addTearDown(cubit.close);
    final gate = repository.gate = Completer<void>();

    final first = cubit.load();
    repository.gate = null;
    repository.pages[1] = tripPage([tripSummary(2)]);
    await cubit.load();
    gate.complete();
    await first;

    expect(cubit.state.trips.single.itineraryId, 2);
  });
}
