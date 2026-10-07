import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_list_item.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_state.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/demo/demo_commercial_service_store.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';

/// Cubit managing Screen #71 (`Commercial Services Search & List`) under
/// Report 3 V2 Section 3.6.1 / UC-30.
///
/// Production queries real `GET /api/v1/pois` (`REAL_BACKEND` keyword search,
/// pagination, and base POI metadata). Commercial date availability and price
/// filters are classified as `NO_BACKEND` and marked `PENDING_BE_INTEGRATION`.
///
/// In Demo mode (`kDebugMode && ?demo=true`), full multi-criteria filtering
/// (`category`, `keyword`, `date`, `price range`) is executed deterministically
/// against in-memory fixtures with display-time availability (`BR-55`).
final class CommercialServicesSearchCubit
    extends Cubit<CommercialServicesSearchState> {
  CommercialServicesSearchCubit({
    GetPoisUseCase? getPois,
    bool isDemoMode = false,
    DemoCommercialServiceStore? demoStore,
  }) : _getPois = getPois,
       _demoStore = demoStore ?? DemoCommercialServiceStore.instance,
       super(CommercialServicesSearchState(isDemoMode: isDemoMode));

  final GetPoisUseCase? _getPois;
  final DemoCommercialServiceStore _demoStore;

  Future<void> loadInitial({
    String? initialSearch,
    String? initialCategoryName,
    String? initialDateIso,
  }) async {
    final cat = CommercialServiceCategory.tryFromCategoryName(
      initialCategoryName,
    );
    final search = initialSearch?.trim() ?? '';
    final date = initialDateIso?.trim() ?? '';

    emit(
      state.copyWith(
        searchQuery: search,
        selectedCategory: cat,
        clearCategory: cat == null,
        selectedDateIso: date,
        page: 1,
      ),
    );

    await _executeSearch();
  }

  Future<void> submitSearch(String query) async {
    emit(state.copyWith(searchQuery: query.trim(), page: 1));
    await _executeSearch();
  }

  Future<void> selectCategory(CommercialServiceCategory? category) async {
    emit(
      state.copyWith(
        selectedCategory: category,
        clearCategory: category == null,
        page: 1,
      ),
    );
    await _executeSearch();
  }

  Future<void> updateDate(String dateIso) async {
    emit(state.copyWith(selectedDateIso: dateIso.trim(), page: 1));
    await _executeSearch();
  }

  Future<void> updateMaxPrice(int? maxPriceVnd) async {
    emit(
      state.copyWith(
        maxPriceVnd: maxPriceVnd,
        clearMaxPrice: maxPriceVnd == null,
        page: 1,
      ),
    );
    await _executeSearch();
  }

  Future<void> resetFilters() async {
    emit(
      state.copyWith(
        searchQuery: '',
        clearCategory: true,
        selectedDateIso: '',
        clearMaxPrice: true,
        page: 1,
      ),
    );
    await _executeSearch();
  }

  Future<void> retry() => _executeSearch();

  Future<void> _executeSearch() async {
    if (state.isDemoMode) {
      _executeDemoSearch();
      return;
    }

    final getPois = _getPois;
    if (getPois == null) {
      emit(
        state.copyWith(
          status: CommercialServicesSearchStatus.failure,
          errorMessage: CommercialServiceMessages.msg127,
          items: const [],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CommercialServicesSearchStatus.loading,
        clearError: true,
      ),
    );

    try {
      final query = PoiQuery(
        search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        page: state.page,
        pageSize: 20,
      );
      final result = await getPois(query);

      final list = result.items
          .map(CommercialServiceListItem.fromPoiSummary)
          .toList(growable: false);

      if (list.isEmpty) {
        emit(
          state.copyWith(
            status: CommercialServicesSearchStatus.empty,
            items: const [],
            totalCount: 0,
            page: result.page,
            totalPages: result.totalPages,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: CommercialServicesSearchStatus.success,
            items: list,
            totalCount: result.totalCount,
            page: result.page,
            totalPages: result.totalPages,
          ),
        );
      }
    } on Failure {
      emit(
        state.copyWith(
          status: CommercialServicesSearchStatus.failure,
          errorMessage: CommercialServiceMessages.msg127,
          items: const [],
        ),
      );
    } on Object {
      emit(
        state.copyWith(
          status: CommercialServicesSearchStatus.failure,
          errorMessage: CommercialServiceMessages.msg127,
          items: const [],
        ),
      );
    }
  }

  void _executeDemoSearch() {
    emit(
      state.copyWith(
        status: CommercialServicesSearchStatus.loading,
        clearError: true,
      ),
    );

    final items = _demoStore.getDemoCatalogItems(
      keyword: state.searchQuery.isNotEmpty ? state.searchQuery : null,
      category: state.selectedCategory,
      dateIso: state.selectedDateIso.isNotEmpty ? state.selectedDateIso : null,
      maxPriceVnd: state.maxPriceVnd,
    );

    if (items.isEmpty) {
      emit(
        state.copyWith(
          status: CommercialServicesSearchStatus.empty,
          items: const [],
          totalCount: 0,
          page: 1,
          totalPages: 1,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: CommercialServicesSearchStatus.success,
          items: items,
          totalCount: items.length,
          page: 1,
          totalPages: 1,
        ),
      );
    }
  }
}
