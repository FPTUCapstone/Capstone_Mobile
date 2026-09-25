import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi_search_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/point_of_interest_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_state.dart';

final class PoiSearchCubit extends Cubit<PoiSearchState> {
  PoiSearchCubit({
    required DeviceLocationService locationService,
    required PointOfInterestRepository repository,
  }) : _locationService = locationService,
       _repository = repository,
       super(const PoiSearchState.initial());

  final DeviceLocationService _locationService;
  final PointOfInterestRepository _repository;
  int _operationGeneration = 0;
  _PoiSearchParameters? _activeSearch;
  bool _isLoadingMore = false;
  int _currentPage = 0;

  Future<void> useCurrentLocation() async {
    final generation = ++_operationGeneration;
    if (isClosed) return;
    emit(const PoiSearchState.locating());
    try {
      final location = await _locationService.getCurrentLocation();
      if (generation != _operationGeneration || isClosed) return;
      emit(PoiSearchState.locationReady(location));
    } on LocationServiceDisabledException {
      if (generation != _operationGeneration || isClosed) return;
      emit(
        const PoiSearchState.failure(
          'Turn on Location Services or choose a place instead.',
        ),
      );
    } on LocationPermissionDeniedException {
      if (generation != _operationGeneration || isClosed) return;
      emit(
        const PoiSearchState.failure(
          'Location permission was not granted. Choose a place instead.',
        ),
      );
    } catch (_) {
      if (generation != _operationGeneration || isClosed) return;
      emit(
        const PoiSearchState.failure(
          'We could not get your current location. Choose a place instead.',
        ),
      );
    }
  }

  void reset({PoiSearchScope? scope}) {
    _operationGeneration++;
    _activeSearch = null;
    _isLoadingMore = false;
    _currentPage = 0;
    emit(PoiSearchState.initial(scope: scope));
  }

  void prepareScope({DeviceLocation? near, int? radiusKm}) {
    final targetScope = PoiSearchScope.fromLocation(
      near: near,
      radiusKm: radiusKm,
    );
    if (state.scope != targetScope || state.status != PoiSearchStatus.initial) {
      reset(scope: targetScope);
    }
  }

  Future<void> search({
    String? query,
    DeviceLocation? near,
    int? radiusKm,
  }) async {
    final generation = ++_operationGeneration;
    final parameters = _PoiSearchParameters(
      query: query?.trim(),
      near: near,
      radiusKm: near == null ? null : radiusKm ?? 50,
    );
    final scope = PoiSearchScope.fromLocation(near: near, radiusKm: radiusKm);
    _activeSearch = parameters;
    _isLoadingMore = false;
    _currentPage = 0;
    if (isClosed) return;
    emit(PoiSearchState.searching(scope: scope));
    try {
      final results = await _search(parameters, page: 1);
      if (generation != _operationGeneration || isClosed) return;
      _currentPage = 1;
      emit(
        PoiSearchState.resultsReady(
          results.items,
          totalCount: results.totalCount,
          scope: scope,
        ),
      );
    } catch (_) {
      if (generation != _operationGeneration || isClosed) return;
      emit(
        PoiSearchState.failure(
          'Places are unavailable right now. Please try again.',
          scope: scope,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final parameters = _activeSearch;
    if (parameters == null || _isLoadingMore || isClosed) return;
    final current = state;
    if (current.status != PoiSearchStatus.ready ||
        current.results.length >= current.totalCount) {
      return;
    }

    final generation = _operationGeneration;
    _isLoadingMore = true;
    emit(
      PoiSearchState.resultsReady(
        current.results,
        totalCount: current.totalCount,
        scope: current.scope,
        isLoadingMore: true,
      ),
    );
    try {
      final nextPage = _currentPage + 1;
      final next = await _search(parameters, page: nextPage);
      if (generation != _operationGeneration || isClosed) return;
      final existingIds = current.results.map((poi) => poi.id).toSet();
      final merged = [
        ...current.results,
        ...next.items.where((poi) => existingIds.add(poi.id)),
      ];
      _currentPage = nextPage;
      emit(
        PoiSearchState.resultsReady(
          merged,
          totalCount: next.totalCount,
          scope: current.scope,
        ),
      );
    } catch (_) {
      if (generation == _operationGeneration && !isClosed) {
        emit(
          PoiSearchState.resultsReady(
            current.results,
            totalCount: current.totalCount,
            scope: current.scope,
          ),
        );
      }
    } finally {
      if (generation == _operationGeneration) _isLoadingMore = false;
    }
  }

  Future<SelectablePoiSearchResult> _search(
    _PoiSearchParameters parameters, {
    required int page,
  }) => _repository.search(
    query: parameters.query,
    latitude: parameters.near?.latitude,
    longitude: parameters.near?.longitude,
    radiusKm: parameters.radiusKm,
    page: page,
  );
}

final class _PoiSearchParameters {
  const _PoiSearchParameters({this.query, this.near, this.radiusKm});

  final String? query;
  final DeviceLocation? near;
  final int? radiusKm;
}
