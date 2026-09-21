import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/usecases/search_tours_use_case.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';

final class TourSearchCubit extends Cubit<TourSearchState> {
  TourSearchCubit({required SearchToursUseCase searchTours})
    : _searchTours = searchTours,
      super(const TourSearchState());

  final SearchToursUseCase _searchTours;
  bool _requestInFlight = false;

  Future<void> loadInitial() => _replace(state.query.copyWith(page: 1));

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

  Future<void> resetFilters() => _replace(const TourSearchQuery());

  Future<void> loadNextPage() async {
    if (_requestInFlight || state.isLoadingMore || !state.canLoadMore) return;
    _requestInFlight = true;
    emit(state.copyWith(isLoadingMore: true, failure: null));
    try {
      final nextPage = state.page + 1;
      final result = await _searchTours(state.query.copyWith(page: nextPage));
      final byId = {for (final item in state.items) item.tourId: item};
      for (final item in result.items) {
        byId[item.tourId] = item;
      }
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
      emit(state.copyWith(isLoadingMore: false, validationFailure: failure));
    } on Failure catch (failure) {
      emit(state.copyWith(isLoadingMore: false, failure: failure));
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> _replace(TourSearchQuery query) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    final hasData = state.items.isNotEmpty;
    emit(
      state.copyWith(
        status: hasData ? TourSearchStatus.success : TourSearchStatus.loading,
        query: query,
        isLoadingMore: false,
        failure: null,
        validationFailure: null,
      ),
    );
    try {
      final result = await _searchTours(query);
      emit(
        state.copyWith(
          status: TourSearchStatus.success,
          items: result.items,
          query: query.copyWith(page: result.page),
          page: result.page,
          totalCount: result.totalCount,
          totalPages: result.totalPages,
          failure: null,
          validationFailure: null,
        ),
      );
    } on ValidationFailure catch (failure) {
      emit(
        state.copyWith(
          status: hasData ? TourSearchStatus.success : TourSearchStatus.failure,
          validationFailure: failure,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: hasData ? TourSearchStatus.success : TourSearchStatus.failure,
          failure: failure,
        ),
      );
    } finally {
      _requestInFlight = false;
    }
  }
}
