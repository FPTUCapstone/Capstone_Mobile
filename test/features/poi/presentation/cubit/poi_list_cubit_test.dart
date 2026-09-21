import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';

void main() {
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
    build: () => PoiListCubit(getPois: GetPoisUseCase(_ValidationRepository())),
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
