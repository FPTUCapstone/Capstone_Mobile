import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_poi_location_use_case.dart';
import 'package:trip_mate_mobile/features/poi/domain/usecases/get_pois_use_case.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';

final class PoiListCubit extends Cubit<PoiListState> {
  PoiListCubit({
    required GetPoisUseCase getPois,
    GetPoiLocationUseCase? getLocation,
  }) : _getPois = getPois,
       _getLocation = getLocation,
       super(const PoiListState());

  final GetPoisUseCase _getPois;
  final GetPoiLocationUseCase? _getLocation;
  bool _requestInFlight = false;

  Future<void> loadInitial() => _replace(state.query.copyWith(page: 1));

  Future<void> refresh() => _replace(state.query.copyWith(page: 1));

  Future<void> submitSearch(String search) =>
      _replace(state.query.copyWith(search: search.trim(), page: 1));

  Future<void> setOpenNow(bool value) =>
      _replace(state.query.copyWith(openNow: value, page: 1));

  Future<void> setSort(PoiSort sort) =>
      _replace(state.query.copyWith(sort: sort, page: 1));

  Future<void> selectCategory(int? categoryId) =>
      _replace(state.query.copyWith(categoryId: categoryId, page: 1));

  Future<void> resetFilters() => _replace(
    PoiQuery(
      originLatitude: state.query.originLatitude,
      originLongitude: state.query.originLongitude,
    ),
  );

  void setMapView(bool value) => emit(state.copyWith(isMapView: value));

  void selectPoi(int id) => emit(state.copyWith(selectedPoiId: id));

  void dismissLocationMessage() => emit(state.copyWith(locationMessage: null));

  Future<void> loadNextPage() async {
    if (_requestInFlight || state.isLoadingMore || !state.canLoadMore) return;
    _requestInFlight = true;
    emit(state.copyWith(isLoadingMore: true, failure: null));
    try {
      final nextPage = state.page + 1;
      final result = await _getPois(state.query.copyWith(page: nextPage));
      final byId = {for (final item in state.items) item.id: item};
      for (final item in result.items) {
        byId[item.id] = item;
      }
      emit(
        state.copyWith(
          status: PoiListStatus.success,
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

  Future<void> requestLocation() async {
    if (_getLocation == null || state.isLocating) return;
    emit(state.copyWith(isLocating: true, locationMessage: null));
    try {
      final location = await _getLocation();
      await _replace(
        state.query.copyWith(
          originLatitude: location.latitude,
          originLongitude: location.longitude,
          page: 1,
        ),
      );
    } on LocationPermissionFailure catch (failure) {
      emit(state.copyWith(isLocating: false, locationMessage: failure.message));
    } on Failure catch (failure) {
      emit(state.copyWith(isLocating: false, locationMessage: failure.message));
    }
  }

  Future<void> _replace(PoiQuery query) async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    final hasData = state.items.isNotEmpty;
    emit(
      state.copyWith(
        status: hasData ? PoiListStatus.success : PoiListStatus.loading,
        query: query,
        isLoadingMore: false,
        isLocating: state.isLocating,
        failure: null,
        validationFailure: null,
      ),
    );
    try {
      final result = await _getPois(query);
      emit(
        state.copyWith(
          status: PoiListStatus.success,
          items: result.items,
          query: query.copyWith(page: result.page),
          page: result.page,
          totalCount: result.totalCount,
          totalPages: result.totalPages,
          isLocating: false,
          failure: null,
          validationFailure: null,
          selectedPoiId: result.items.isEmpty ? null : result.items.first.id,
        ),
      );
    } on ValidationFailure catch (failure) {
      emit(
        state.copyWith(
          status: hasData ? PoiListStatus.success : PoiListStatus.failure,
          isLocating: false,
          validationFailure: failure,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: hasData ? PoiListStatus.success : PoiListStatus.failure,
          isLocating: false,
          failure: failure,
        ),
      );
    } finally {
      _requestInFlight = false;
    }
  }
}
