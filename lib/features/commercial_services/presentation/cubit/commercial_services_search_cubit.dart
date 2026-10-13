import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_messages.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_services_search_result.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/usecases/search_commercial_services.dart';
import 'package:trip_mate_mobile/features/commercial_services/presentation/cubit/commercial_services_search_state.dart';

/// Cubit managing Screen #71 (`Commercial Services Search & List`) under
/// Report 3 V2 Section 3.6.1 / UC-30.
///
/// Follows Clean Architecture:
/// Presentation -> UseCase -> Repository -> DataSource.
/// The Cubit depends solely on [SearchCommercialServices].
final class CommercialServicesSearchCubit
    extends Cubit<CommercialServicesSearchState> {
  CommercialServicesSearchCubit({
    SearchCommercialServices? searchCommercialServices,
    bool isDemoMode = false,
  }) : _searchCommercialServices = searchCommercialServices,
       super(CommercialServicesSearchState(isDemoMode: isDemoMode));

  final SearchCommercialServices? _searchCommercialServices;

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
    final searchUseCase = _searchCommercialServices;
    if (searchUseCase == null) {
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
      final result = await searchUseCase(
        keyword: state.searchQuery.isNotEmpty ? state.searchQuery : null,
        category: state.selectedCategory,
        dateIso: state.selectedDateIso.isNotEmpty
            ? state.selectedDateIso
            : null,
        maxPriceVnd: state.maxPriceVnd,
        page: state.page,
        isDemoMode: state.isDemoMode,
      );

      switch (result) {
        case CommercialServicesSearchPending(:final message):
          emit(
            state.copyWith(
              status: CommercialServicesSearchStatus.pendingIntegration,
              items: const [],
              totalCount: 0,
              page: 1,
              totalPages: 1,
              errorMessage: message,
              clearError: message == null,
            ),
          );
        case CommercialServicesSearchSuccess(
          :final items,
          :final totalCount,
          :final page,
          :final totalPages,
        ):
          if (items.isEmpty) {
            emit(
              state.copyWith(
                status: CommercialServicesSearchStatus.empty,
                items: const [],
                totalCount: 0,
                page: 1,
                totalPages: 1,
                clearError: true,
              ),
            );
          } else {
            emit(
              state.copyWith(
                status: CommercialServicesSearchStatus.success,
                items: items,
                totalCount: totalCount,
                page: page,
                totalPages: totalPages,
                clearError: true,
              ),
            );
          }
        case CommercialServicesSearchFailure(:final message):
          emit(
            state.copyWith(
              status: CommercialServicesSearchStatus.failure,
              errorMessage: message ?? CommercialServiceMessages.msg127,
              items: const [],
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
}
