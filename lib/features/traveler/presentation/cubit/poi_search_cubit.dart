import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
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

  Future<void> useCurrentLocation() async {
    emit(const PoiSearchState.locating());
    try {
      final location = await _locationService.getCurrentLocation();
      emit(PoiSearchState.locationReady(location));
    } on LocationServiceDisabledException {
      emit(
        const PoiSearchState.failure(
          'Turn on Location Services or choose a place instead.',
        ),
      );
    } on LocationPermissionDeniedException {
      emit(
        const PoiSearchState.failure(
          'Location permission was not granted. Choose a place instead.',
        ),
      );
    } catch (_) {
      emit(
        const PoiSearchState.failure(
          'We could not get your current location. Choose a place instead.',
        ),
      );
    }
  }

  Future<void> search({String? query, DeviceLocation? near}) async {
    emit(const PoiSearchState.searching());
    try {
      final results = await _repository.search(
        query: query,
        latitude: near?.latitude,
        longitude: near?.longitude,
        radiusKm: near == null ? null : 50,
      );
      emit(PoiSearchState.resultsReady(results));
    } catch (_) {
      emit(
        const PoiSearchState.failure(
          'Places are unavailable right now. Please try again.',
        ),
      );
    }
  }
}
