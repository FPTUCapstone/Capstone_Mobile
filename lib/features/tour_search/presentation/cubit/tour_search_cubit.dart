import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/load_tour_categories_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';

final class TourSearchCubit extends Cubit<TourSearchState> {
  TourSearchCubit({
    required SearchToursUseCase searchTours,
    this.devSearchEnabled = false,
    LoadTourCategoriesUseCase? loadCategories,
  }) : _searchTours = searchTours,
       _loadCategories = loadCategories,
       super(const TourSearchState());

  final SearchToursUseCase _searchTours;
  int _requestEpoch = 0;
  TourSearchQuery _successfulQuery = const TourSearchQuery();
  final bool devSearchEnabled;
  final LoadTourCategoriesUseCase? _loadCategories;

  Future<void> loadCategories() async {
    if (!devSearchEnabled ||
        _loadCategories == null ||
        state.categoriesLoading) {
      return;
    }
    emit(state.copyWith(categoriesLoading: true, categoriesFailure: null));
    try {
      final categories = await _loadCategories();
      if (!isClosed) {
        emit(state.copyWith(categories: categories, categoriesLoading: false));
      }
    } on Failure catch (failure) {
      if (!isClosed) {
        emit(
          state.copyWith(categoriesLoading: false, categoriesFailure: failure),
        );
      }
    }
  }

  Future<void> applyV2Query(TourSearchQuery query) =>
      _replace(query.copyWith(page: 1));

  Future<void> loadInitial() async {
    await Future.wait([
      loadCategories(),
      _replace(state.query.copyWith(page: 1)),
    ]);
  }

  Future<void> refresh() => _replace(state.query.copyWith(page: 1));

  Future<void> applyFilters({
    String? destination,
    DateTime? departureDate,
    int? minPrice,
    int? maxPrice,
  }) {
    return _replace(
      TourSearchQuery(
        destination: destination,
        departureDate: departureDate,
        minPrice: minPrice,
        maxPrice: maxPrice,
      ),
    );
  }

  Future<void> resetFilters() {
    if (!devSearchEnabled) return _replace(const TourSearchQuery());
    final keyword = state.query.keyword?.trim();
    return _replace(
      TourSearchQuery(
        keyword: keyword,
        mode: state.query.mode,
        sort: keyword?.isNotEmpty == true ? 'relevance' : 'departureDate',
      ),
    );
  }

  Future<void> retryFailedQuery() =>
      _replace(state.failedQuery ?? state.query.copyWith(page: 1));

  Future<void> goToPage(int page) {
    if (page < 1 || page > state.totalPages || page == state.page) {
      return Future.value();
    }
    return _replace(state.query.copyWith(page: page));
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore || !state.canLoadMore) return;
    final requestEpoch = _requestEpoch;
    final query = state.query;
    final nextPage = state.page + 1;
    emit(state.copyWith(isLoadingMore: true, failure: null));
    try {
      final result = await _searchTours(query.copyWith(page: nextPage));
      if (isClosed || requestEpoch != _requestEpoch) return;
      final byId = {for (final item in state.items) item.tourId: item};
      for (final item in result.items) {
        byId[item.tourId] = item;
      }
      _successfulQuery = query.copyWith(page: result.page);
      emit(
        state.copyWith(
          status: TourSearchStatus.success,
          items: byId.values.toList(growable: false),
          query: state.query.copyWith(page: result.page),
          page: result.page,
          totalCount: result.totalCount,
          totalPages: result.totalPages,
          isLoadingMore: false,
          failure: null,
          validationFailure: null,
        ),
      );
    } on ValidationFailure catch (failure) {
      if (isClosed || requestEpoch != _requestEpoch) return;
      emit(state.copyWith(isLoadingMore: false, validationFailure: failure));
    } on Failure catch (failure) {
      if (isClosed || requestEpoch != _requestEpoch) return;
      emit(state.copyWith(isLoadingMore: false, failure: failure));
    }
  }

  Future<void> _replace(TourSearchQuery query) async {
    final requestEpoch = ++_requestEpoch;
    final hasData = state.items.isNotEmpty;
    final previousQuery = _successfulQuery;
    emit(
      state.copyWith(
        status: hasData ? TourSearchStatus.success : TourSearchStatus.loading,
        query: hasData ? previousQuery : query,
        pendingQuery: query,
        failedQuery: null,
        isLoadingMore: false,
        isRefreshing: true,
        failure: null,
        validationFailure: null,
      ),
    );
    try {
      final result = await _searchTours(query);
      if (isClosed || requestEpoch != _requestEpoch) return;
      _successfulQuery = query.copyWith(page: result.page);
      emit(
        state.copyWith(
          status: TourSearchStatus.success,
          items: result.items,
          query: query.copyWith(page: result.page),
          pendingQuery: null,
          failedQuery: null,
          page: result.page,
          totalCount: result.totalCount,
          totalPages: result.totalPages,
          failure: null,
          validationFailure: null,
          isRefreshing: false,
        ),
      );
    } on ValidationFailure catch (failure) {
      if (isClosed || requestEpoch != _requestEpoch) return;
      emit(
        state.copyWith(
          status: hasData ? TourSearchStatus.success : TourSearchStatus.failure,
          validationFailure: failure,
          isRefreshing: false,
          query: hasData ? previousQuery : query,
          pendingQuery: null,
          failedQuery: query,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed || requestEpoch != _requestEpoch) return;
      emit(
        state.copyWith(
          status: hasData ? TourSearchStatus.success : TourSearchStatus.failure,
          failure: failure,
          isRefreshing: false,
          query: hasData ? previousQuery : query,
          pendingQuery: null,
          failedQuery: query,
        ),
      );
    }
  }
}
