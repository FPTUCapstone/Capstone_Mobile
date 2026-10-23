import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_location.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_location_service.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_location_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';

void main() {
  group('PoiListCubit original tests', () {
    blocTest<PoiListCubit, PoiListState>(
      'appends the next page and removes duplicate ids',
      build: () => PoiListCubit(getPois: GetPoisUseCase(_PagingRepository())),
      act: (cubit) async {
        await cubit.loadInitial();
        await cubit.loadNextPage();
      },
      verify: (cubit) {
        expect(cubit.state.items.map((item) => item.id), [1, 2]);
        expect(cubit.state.page, 2);
      },
    );

    blocTest<PoiListCubit, PoiListState>(
      'keeps valid results when a validation failure occurs',
      build: () =>
          PoiListCubit(getPois: GetPoisUseCase(_ValidationRepository())),
      act: (cubit) async {
        await cubit.loadInitial();
        await cubit.submitSearch('invalid');
      },
      verify: (cubit) {
        expect(cubit.state.items, hasLength(1));
        expect(cubit.state.validationFailure, isA<ValidationFailure>());
      },
    );

    blocTest<PoiListCubit, PoiListState>(
      'resetFilters clears submitted filters and returns to the first page',
      build: () => PoiListCubit(getPois: GetPoisUseCase(_PagingRepository())),
      act: (cubit) async {
        await cubit.loadInitial();
        await cubit.submitSearch('Sơn Trà');
        await cubit.selectCategory(3);
        await cubit.setOpenNow(true);
        await cubit.setSort(PoiSort.rating);
        await cubit.resetFilters();
      },
      verify: (cubit) {
        expect(cubit.state.query, const PoiQuery());
        expect(cubit.state.page, 1);
      },
    );
  });

  group('P1-01 Lifecycle (Prevent emit after close)', () {
    test(
      'close while initial loading is pending does not throw on completion',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.loadInitial());
        expect(repo.calls, hasLength(1));

        await cubit.close();
        expect(cubit.isClosed, isTrue);

        expect(
          () => repo.calls[0].completer.complete(_resultFor([_poi(1, 'A')])),
          returnsNormally,
        );
      },
    );

    test(
      'close while request is pending does not throw on error completion',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.loadInitial());
        expect(repo.calls, hasLength(1));

        await cubit.close();
        expect(cubit.isClosed, isTrue);

        expect(
          () => repo.calls[0].completer.completeError(
            const ServerFailure('Network error'),
          ),
          returnsNormally,
        );
      },
    );

    test(
      'close while loadNextPage is pending does not throw on completion',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.loadInitial());
        repo.calls[0].completer.complete(
          _resultFor([_poi(1, 'A')], totalPages: 2),
        );
        await pumpEventQueue();

        unawaited(cubit.loadNextPage());
        expect(repo.calls, hasLength(2));

        await cubit.close();
        expect(cubit.isClosed, isTrue);

        expect(
          () => repo.calls[1].completer.complete(
            _resultFor([_poi(2, 'B')], page: 2, totalPages: 2),
          ),
          returnsNormally,
        );
      },
    );

    test(
      'close while loadNextPage is pending does not throw on error',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.loadInitial());
        repo.calls[0].completer.complete(
          _resultFor([_poi(1, 'A')], totalPages: 2),
        );
        await pumpEventQueue();

        unawaited(cubit.loadNextPage());
        expect(repo.calls, hasLength(2));

        await cubit.close();
        expect(cubit.isClosed, isTrue);

        expect(
          () => repo.calls[1].completer.completeError(
            const ServerFailure('Page load error'),
          ),
          returnsNormally,
        );
      },
    );

    test(
      'close while requestLocation is fetching GPS does not throw on completion',
      () async {
        final repo = _ControlledPoiRepository();
        final locationService = _ControlledLocationService();
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(repo),
          getLocation: GetPoiLocationUseCase(locationService),
        );

        unawaited(cubit.requestLocation());
        expect(locationService.calls, hasLength(1));

        await cubit.close();
        expect(cubit.isClosed, isTrue);

        expect(
          () => locationService.calls[0].complete(
            const PoiLocation(latitude: 16.0, longitude: 108.0),
          ),
          returnsNormally,
        );
      },
    );

    test(
      'close while requestLocation is fetching GPS does not throw on location error',
      () async {
        final repo = _ControlledPoiRepository();
        final locationService = _ControlledLocationService();
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(repo),
          getLocation: GetPoiLocationUseCase(locationService),
        );

        unawaited(cubit.requestLocation());
        expect(locationService.calls, hasLength(1));

        await cubit.close();
        expect(cubit.isClosed, isTrue);

        expect(
          () => locationService.calls[0].completeError(
            const LocationPermissionFailure('GPS Denied'),
          ),
          returnsNormally,
        );
      },
    );
  });

  group('P1-02 Latest-request-wins Concurrency', () {
    test(
      'concurrent filter: category selection supersedes pending initial request',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.loadInitial());
        expect(repo.calls, hasLength(1));

        unawaited(cubit.selectCategory(2));
        expect(repo.calls, hasLength(2));
        expect(repo.calls[1].query.categoryId, 2);

        // Complete initial request (older) with Item A
        repo.calls[0].completer.complete(_resultFor([_poi(1, 'Initial Item')]));
        await pumpEventQueue();

        // State should NOT have initial item because newer request is in flight
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.query.categoryId, 2);

        // Complete category request (newer) with Item B
        repo.calls[1].completer.complete(
          _resultFor([_poi(2, 'Category 2 Item', categoryId: 2)]),
        );
        await pumpEventQueue();

        expect(cubit.state.items.map((i) => i.id), [2]);
        expect(cubit.state.query.categoryId, 2);
        expect(cubit.state.status, PoiListStatus.success);

        await cubit.close();
      },
    );

    test(
      'rapid interactions: Category A -> B -> C in any completion order preserves C',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.selectCategory(1));
        unawaited(cubit.selectCategory(2));
        unawaited(cubit.selectCategory(3));
        expect(repo.calls, hasLength(3));

        // Complete in reverse: C first, then B, then A
        repo.calls[2].completer.complete(
          _resultFor([_poi(3, 'Cat 3', categoryId: 3)]),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [3]);
        expect(cubit.state.query.categoryId, 3);

        repo.calls[1].completer.complete(
          _resultFor([_poi(2, 'Cat 2', categoryId: 2)]),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [3]);

        repo.calls[0].completer.complete(
          _resultFor([_poi(1, 'Cat 1', categoryId: 1)]),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [3]);

        await cubit.close();
      },
    );

    test(
      'rapid interactions: Search A -> Search B completes B as authoritative',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.submitSearch('Da Nang'));
        unawaited(cubit.submitSearch('Hoi An'));
        expect(repo.calls, hasLength(2));

        // Complete A last
        repo.calls[1].completer.complete(
          _resultFor([_poi(20, 'Hoi An Ancient Town')]),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [20]);
        expect(cubit.state.query.search, 'Hoi An');

        repo.calls[0].completer.complete(
          _resultFor([_poi(10, 'Dragon Bridge')]),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [20]);
        expect(cubit.state.query.search, 'Hoi An');

        await cubit.close();
      },
    );

    test(
      'rapid interactions: Search -> Sort completes with sort applied',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.submitSearch('Hue'));
        unawaited(cubit.setSort(PoiSort.rating));
        expect(repo.calls, hasLength(2));

        repo.calls[0].completer.complete(_resultFor([_poi(1, 'Hue Unsorted')]));
        await pumpEventQueue();
        expect(cubit.state.query.sort, PoiSort.rating);

        repo.calls[1].completer.complete(
          _resultFor([_poi(2, 'Hue Top Rated')]),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [2]);
        expect(cubit.state.query.sort, PoiSort.rating);

        await cubit.close();
      },
    );

    test(
      'rapid interactions: Refresh -> Category change preserves Category results',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.refresh());
        unawaited(cubit.selectCategory(4));
        expect(repo.calls, hasLength(2));

        repo.calls[0].completer.complete(
          _resultFor([_poi(1, 'Refreshed All')]),
        );
        await pumpEventQueue();
        expect(cubit.state.items, isEmpty);

        repo.calls[1].completer.complete(
          _resultFor([_poi(4, 'Museum', categoryId: 4)]),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [4]);
        expect(cubit.state.query.categoryId, 4);

        await cubit.close();
      },
    );

    test(
      'pagination -> new filter: obsolete page result is discarded and not appended',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        // Load page 1
        unawaited(cubit.loadInitial());
        repo.calls[0].completer.complete(
          _resultFor(
            [_poi(1, 'Item 1')],
            page: 1,
            totalPages: 3,
            totalCount: 3,
          ),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [1]);

        // Request page 2
        unawaited(cubit.loadNextPage());
        expect(repo.calls, hasLength(2));
        expect(repo.calls[1].query.page, 2);

        // Before page 2 completes, user selects category 5
        unawaited(cubit.selectCategory(5));
        expect(repo.calls, hasLength(3));
        expect(repo.calls[2].query.categoryId, 5);

        // Page 2 of old query finishes
        repo.calls[1].completer.complete(
          _resultFor(
            [_poi(2, 'Item 2 (Old query page 2)')],
            page: 2,
            totalPages: 3,
          ),
        );
        await pumpEventQueue();
        expect(cubit.state.items, [_poi(1, 'Item 1')]);

        // Category 5 finishes
        repo.calls[2].completer.complete(
          _resultFor(
            [_poi(50, 'Cat 5 Item', categoryId: 5)],
            page: 1,
            totalPages: 1,
          ),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [50]);
        expect(cubit.state.query.categoryId, 5);

        await cubit.close();
      },
    );

    test(
      'location request -> newer filter: location does not overwrite newer category',
      () async {
        final repo = _ControlledPoiRepository();
        final locationService = _ControlledLocationService();
        final cubit = PoiListCubit(
          getPois: GetPoisUseCase(repo),
          getLocation: GetPoiLocationUseCase(locationService),
        );

        unawaited(cubit.requestLocation());
        expect(locationService.calls, hasLength(1));
        expect(cubit.state.isLocating, isTrue);

        // User selects category while GPS is searching
        unawaited(cubit.selectCategory(6));
        expect(repo.calls, hasLength(1));
        expect(cubit.state.isLocating, isFalse);

        // GPS finishes now
        locationService.calls[0].complete(
          const PoiLocation(latitude: 16.5, longitude: 108.5),
        );
        await pumpEventQueue();

        // Location request should be aborted, no new repo call for location
        expect(repo.calls, hasLength(1));
        expect(repo.calls[0].query.categoryId, 6);
        expect(repo.calls[0].query.originLatitude, isNull);

        // Category 6 finishes
        repo.calls[0].completer.complete(
          _resultFor([_poi(6, 'Cat 6 Item', categoryId: 6)]),
        );
        await pumpEventQueue();
        expect(cubit.state.items.map((i) => i.id), [6]);
        expect(cubit.state.query.categoryId, 6);

        await cubit.close();
      },
    );

    test(
      'error ordering: old request failure does not overwrite newer successful state',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.selectCategory(1));
        unawaited(cubit.selectCategory(2));
        expect(repo.calls, hasLength(2));

        // Newer request succeeds
        repo.calls[1].completer.complete(_resultFor([_poi(2, 'Cat 2')]));
        await pumpEventQueue();
        expect(cubit.state.status, PoiListStatus.success);
        expect(cubit.state.items.map((i) => i.id), [2]);

        // Older request fails
        repo.calls[0].completer.completeError(
          const ServerFailure('Timeout on Request 1'),
        );
        await pumpEventQueue();

        // State must remain success with Request 2 items
        expect(cubit.state.status, PoiListStatus.success);
        expect(cubit.state.items.map((i) => i.id), [2]);
        expect(cubit.state.failure, isNull);

        await cubit.close();
      },
    );

    test(
      'error ordering: old request success does not overwrite newer failure state',
      () async {
        final repo = _ControlledPoiRepository();
        final cubit = PoiListCubit(getPois: GetPoisUseCase(repo));

        unawaited(cubit.selectCategory(1));
        unawaited(cubit.selectCategory(2));
        expect(repo.calls, hasLength(2));

        // Newer request fails
        repo.calls[1].completer.completeError(
          const ServerFailure('Server Error on Request 2'),
        );
        await pumpEventQueue();
        expect(cubit.state.status, PoiListStatus.failure);
        expect(cubit.state.failure?.message, 'Server Error on Request 2');

        // Older request succeeds
        repo.calls[0].completer.complete(_resultFor([_poi(1, 'Cat 1')]));
        await pumpEventQueue();

        // State must remain failure from Request 2
        expect(cubit.state.status, PoiListStatus.failure);
        expect(cubit.state.failure?.message, 'Server Error on Request 2');
        expect(cubit.state.items, isEmpty);

        await cubit.close();
      },
    );
  });
}

PagedPoiResult _resultFor(
  List<PoiSummary> items, {
  int page = 1,
  int totalPages = 1,
  int totalCount = 1,
}) {
  return PagedPoiResult(
    page: page,
    pageSize: 20,
    totalCount: totalCount,
    totalPages: totalPages,
    items: items,
  );
}

PoiSummary _poi(int id, String name, {int categoryId = 1}) {
  return PoiSummary(
    id: id,
    name: name,
    categoryId: categoryId,
    categoryName: 'Category $categoryId',
    latitude: 16.0 + id * 0.01,
    longitude: 108.0 + id * 0.01,
    indoorOutdoor: 'Outdoor',
    averageVisitDurationMinutes: 60,
    hasShelter: false,
    reviewCount: 0,
    isOpenNow: true,
  );
}

class _ControlledPoiRepository implements PoiRepository {
  final List<({PoiQuery query, Completer<PagedPoiResult> completer})> calls =
      [];

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) {
    final completer = Completer<PagedPoiResult>();
    calls.add((query: query, completer: completer));
    return completer.future;
  }

  @override
  Future<PoiDetail> getPoiDetail(int id) => throw UnimplementedError();
}

class _ControlledLocationService implements PoiLocationService {
  final List<Completer<PoiLocation>> calls = [];

  @override
  Future<PoiLocation> requestCurrentLocation() {
    final completer = Completer<PoiLocation>();
    calls.add(completer);
    return completer.future;
  }
}

const _poi1 = PoiSummary(
  id: 1,
  name: 'A',
  categoryId: 1,
  categoryName: 'Beach',
  latitude: 16,
  longitude: 108,
  indoorOutdoor: 'Outdoor',
  averageVisitDurationMinutes: 60,
  hasShelter: false,
  reviewCount: 0,
  isOpenNow: true,
);

const _poi2 = PoiSummary(
  id: 2,
  name: 'B',
  categoryId: 1,
  categoryName: 'Beach',
  latitude: 16.1,
  longitude: 108.1,
  indoorOutdoor: 'Outdoor',
  averageVisitDurationMinutes: 60,
  hasShelter: false,
  reviewCount: 0,
  isOpenNow: false,
);

class _PagingRepository implements PoiRepository {
  @override
  Future<PagedPoiResult> getPois(PoiQuery query) async => query.page == 1
      ? const PagedPoiResult(
          page: 1,
          pageSize: 20,
          totalCount: 2,
          totalPages: 2,
          items: [_poi1],
        )
      : const PagedPoiResult(
          page: 2,
          pageSize: 20,
          totalCount: 2,
          totalPages: 2,
          items: [_poi1, _poi2],
        );

  @override
  Future<PoiDetail> getPoiDetail(int id) => throw UnimplementedError();
}

class _ValidationRepository implements PoiRepository {
  var calls = 0;

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) async {
    if (calls++ == 0) {
      return const PagedPoiResult(
        page: 1,
        pageSize: 20,
        totalCount: 1,
        totalPages: 1,
        items: [_poi1],
      );
    }
    throw const ValidationFailure('Dữ liệu lọc không hợp lệ.');
  }

  @override
  Future<PoiDetail> getPoiDetail(int id) => throw UnimplementedError();
}
