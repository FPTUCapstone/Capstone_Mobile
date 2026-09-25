import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/paged_tour_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/repositories/tour_search_repository.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';

void main() {
  group('TourSearchCubit', () {
    blocTest<TourSearchCubit, TourSearchState>(
      'loadInitial loads page 1 items successfully',
      build: () => TourSearchCubit(
        searchTours: SearchToursUseCase(_PagingTourRepository()),
      ),
      act: (cubit) => cubit.loadInitial(),
      verify: (cubit) {
        expect(cubit.state.status, TourSearchStatus.success);
        expect(cubit.state.page, 1);
        expect(cubit.state.items.map((item) => item.tourId), ['1']);
        expect(cubit.state.canLoadMore, isTrue);
      },
    );

    blocTest<TourSearchCubit, TourSearchState>(
      'loadNextPage appends results and removes duplicate tourId',
      build: () => TourSearchCubit(
        searchTours: SearchToursUseCase(_PagingTourRepository()),
      ),
      act: (cubit) async {
        await cubit.loadInitial();
        await cubit.loadNextPage();
      },
      verify: (cubit) {
        expect(cubit.state.status, TourSearchStatus.success);
        expect(cubit.state.page, 2);
        expect(cubit.state.items.map((item) => item.tourId), ['1', '2']);
        expect(cubit.state.canLoadMore, isFalse);
      },
    );

    blocTest<TourSearchCubit, TourSearchState>(
      'applyFilters resets page to 1 and applies new filters',
      build: () => TourSearchCubit(
        searchTours: SearchToursUseCase(_PagingTourRepository()),
      ),
      act: (cubit) => cubit.applyFilters(
        destination: 'Hội An',
        departureDate: DateTime(2026, 11, 1),
        minPrice: 500000,
        maxPrice: 2000000,
      ),
      verify: (cubit) {
        expect(cubit.state.query.destination, 'Hội An');
        expect(cubit.state.query.departureDate, DateTime(2026, 11, 1));
        expect(cubit.state.query.minPrice, 500000);
        expect(cubit.state.query.maxPrice, 2000000);
        expect(cubit.state.page, 1);
      },
    );

    blocTest<TourSearchCubit, TourSearchState>(
      'resetFilters clears filters and resets to page 1',
      build: () => TourSearchCubit(
        searchTours: SearchToursUseCase(_PagingTourRepository()),
      ),
      act: (cubit) async {
        await cubit.applyFilters(destination: 'Đà Nẵng');
        await cubit.resetFilters();
      },
      verify: (cubit) {
        expect(cubit.state.query, const TourSearchQuery());
        expect(cubit.state.page, 1);
      },
    );

    blocTest<TourSearchCubit, TourSearchState>(
      'refresh re-queries with current query filters at page 1',
      build: () => TourSearchCubit(
        searchTours: SearchToursUseCase(_PagingTourRepository()),
      ),
      act: (cubit) async {
        await cubit.applyFilters(destination: 'Đà Nẵng');
        await cubit.refresh();
      },
      verify: (cubit) {
        expect(cubit.state.query.destination, 'Đà Nẵng');
        expect(cubit.state.page, 1);
        expect(cubit.state.status, TourSearchStatus.success);
      },
    );

    blocTest<TourSearchCubit, TourSearchState>(
      'emits failure status when repository throws Failure',
      build: () => TourSearchCubit(
        searchTours: SearchToursUseCase(
          _ErrorTourRepository(const ServerFailure('Server down')),
        ),
      ),
      act: (cubit) => cubit.loadInitial(),
      verify: (cubit) {
        expect(cubit.state.status, TourSearchStatus.failure);
        expect(cubit.state.failure, isA<ServerFailure>());
        expect(cubit.state.items, isEmpty);
      },
    );

    blocTest<TourSearchCubit, TourSearchState>(
      'preserves existing items when validation failure occurs on subsequent action',
      build: () => TourSearchCubit(
        searchTours: SearchToursUseCase(_ConditionalErrorTourRepository()),
      ),
      act: (cubit) async {
        await cubit.loadInitial();
        await cubit.applyFilters(destination: 'invalid');
      },
      verify: (cubit) {
        expect(cubit.state.status, TourSearchStatus.success);
        expect(cubit.state.items, isNotEmpty);
        expect(cubit.state.validationFailure, isA<ValidationFailure>());
      },
    );

    test('a filter request supersedes an in-flight initial load', () async {
      final repository = _DeferredTourRepository();
      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
      );

      final initial = cubit.loadInitial();
      final filtered = cubit.applyFilters(destination: 'Hội An');
      repository.complete('Hội An', _resultFor(_tour2));
      await filtered;
      repository.complete(null, _resultFor(_tour1));
      await initial;

      expect(cubit.state.query.destination, 'Hội An');
      expect(cubit.state.items, [_tour2]);
      await cubit.close();
    });

    test(
      'latest of two filter requests wins when responses arrive out of order',
      () async {
        final repository = _DeferredTourRepository();
        final cubit = TourSearchCubit(
          searchTours: SearchToursUseCase(repository),
        );

        final first = cubit.applyFilters(destination: 'Đà Nẵng');
        final second = cubit.applyFilters(destination: 'Hội An');
        repository.complete('Hội An', _resultFor(_tour2));
        await second;
        repository.complete('Đà Nẵng', _resultFor(_tour1));
        await first;

        expect(cubit.state.query.destination, 'Hội An');
        expect(cubit.state.items, [_tour2]);
        await cubit.close();
      },
    );

    test('a stale failure cannot overwrite a newer filter result', () async {
      final repository = _DeferredTourRepository();
      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
      );

      final initial = cubit.loadInitial();
      final filtered = cubit.applyFilters(destination: 'Hội An');
      repository.complete('Hội An', _resultFor(_tour2));
      await filtered;
      repository.completeError(null, const ServerFailure('stale failure'));
      await initial;

      expect(cubit.state.status, TourSearchStatus.success);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.items, [_tour2]);
      await cubit.close();
    });

    test('a filter request supersedes an in-flight refresh', () async {
      final repository = _DeferredTourRepository();
      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
      );

      final initial = cubit.applyFilters(destination: 'Đà Nẵng');
      repository.complete('Đà Nẵng', _resultFor(_tour1));
      await initial;
      final refresh = cubit.refresh();
      final filtered = cubit.applyFilters(destination: 'Hội An');
      repository.complete('Hội An', _resultFor(_tour2));
      await filtered;
      repository.complete('Đà Nẵng', _resultFor(_tour1));
      await refresh;

      expect(cubit.state.query.destination, 'Hội An');
      expect(cubit.state.items, [_tour2]);
      await cubit.close();
    });

    test(
      'a stale pagination response cannot attach to a replacement query',
      () async {
        final repository = _DeferredTourRepository();
        final cubit = TourSearchCubit(
          searchTours: SearchToursUseCase(repository),
        );

        final initial = cubit.loadInitial();
        repository.complete(null, _resultFor(_tour1, totalPages: 2));
        await initial;
        final nextPage = cubit.loadNextPage();
        final filtered = cubit.applyFilters(destination: 'Hội An');
        repository.complete('Hội An', _resultFor(_tour2));
        await filtered;
        repository.complete(null, _resultFor(_tour1, page: 2, totalPages: 2));
        await nextPage;

        expect(cubit.state.query.destination, 'Hội An');
        expect(cubit.state.items, [_tour2]);
        await cubit.close();
      },
    );

    test('an in-flight response after close does not emit', () async {
      final repository = _DeferredTourRepository();
      final cubit = TourSearchCubit(
        searchTours: SearchToursUseCase(repository),
      );

      final pending = cubit.loadInitial();
      await cubit.close();
      repository.complete(null, _resultFor(_tour1));
      await pending;
    });
  });
}

const _tour1 = TourSummary(
  tourId: '1',
  title: 'Tour 1',
  destinations: ['Đà Nẵng'],
  operatorName: 'Op 1',
  durationDays: 2,
  basePrice: 500000,
  currency: 'VND',
  representativeScheduleId: '101',
  departureAtUtc: null,
  availabilityStatus: AvailabilityStatus.available,
  remainingSlots: 5,
);

const _tour2 = TourSummary(
  tourId: '2',
  title: 'Tour 2',
  destinations: ['Hội An'],
  operatorName: 'Op 2',
  durationDays: 3,
  basePrice: 1000000,
  currency: 'VND',
  representativeScheduleId: '102',
  departureAtUtc: null,
  availabilityStatus: AvailabilityStatus.soldOut,
  remainingSlots: 0,
);

final class _PagingTourRepository implements TourSearchRepository {
  @override
  Future<PagedTourResult> searchTours(TourSearchQuery query) async {
    if (query.page == 1) {
      return const PagedTourResult(
        page: 1,
        pageSize: 1,
        totalCount: 2,
        totalPages: 2,
        items: [_tour1],
      );
    }
    // Include duplicate of _tour1 to test deduplication
    return const PagedTourResult(
      page: 2,
      pageSize: 1,
      totalCount: 2,
      totalPages: 2,
      items: [_tour1, _tour2],
    );
  }
}

final class _ErrorTourRepository implements TourSearchRepository {
  _ErrorTourRepository(this.failure);
  final Failure failure;

  @override
  Future<PagedTourResult> searchTours(TourSearchQuery query) async {
    throw failure;
  }
}

final class _ConditionalErrorTourRepository implements TourSearchRepository {
  @override
  Future<PagedTourResult> searchTours(TourSearchQuery query) async {
    if (query.destination == 'invalid') {
      throw const ValidationFailure('Validation error');
    }
    return const PagedTourResult(
      page: 1,
      pageSize: 20,
      totalCount: 1,
      totalPages: 1,
      items: [_tour1],
    );
  }
}

PagedTourResult _resultFor(
  TourSummary item, {
  int page = 1,
  int totalPages = 1,
}) => PagedTourResult(
  page: page,
  pageSize: 20,
  totalCount: totalPages == 1 ? 1 : 2,
  totalPages: totalPages,
  items: [item],
);

final class _DeferredTourRepository implements TourSearchRepository {
  final Map<String?, List<Completer<PagedTourResult>>> _requests = {};

  @override
  Future<PagedTourResult> searchTours(TourSearchQuery query) {
    final completer = Completer<PagedTourResult>();
    _requests.putIfAbsent(query.destination, () => []).add(completer);
    return completer.future;
  }

  void complete(String? destination, PagedTourResult result) {
    _requests[destination]!.removeAt(0).complete(result);
  }

  void completeError(String? destination, Failure error) {
    _requests[destination]!.removeAt(0).completeError(error);
  }
}
