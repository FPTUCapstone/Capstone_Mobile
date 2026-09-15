import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/point_of_interest_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/poi_search_state.dart';

void main() {
  blocTest<PoiSearchCubit, PoiSearchState>(
    'uses the device location only after the traveler requests it',
    build: () => PoiSearchCubit(
      locationService: _LocationService(),
      repository: _PoiRepository(),
    ),
    act: (cubit) => cubit.useCurrentLocation(),
    expect: () => const [
      PoiSearchState.locating(),
      PoiSearchState.locationReady(
        DeviceLocation(latitude: 16.0544, longitude: 108.2022),
      ),
    ],
  );

  blocTest<PoiSearchCubit, PoiSearchState>(
    'searches without coordinates when location is unavailable',
    build: () => PoiSearchCubit(
      locationService: _LocationService(),
      repository: _PoiRepository(),
    ),
    act: (cubit) => cubit.search(query: 'Cham'),
    expect: () => [
      const PoiSearchState.searching(),
      isA<PoiSearchState>()
          .having((state) => state.status, 'status', PoiSearchStatus.ready)
          .having((state) => state.results, 'results', hasLength(1)),
    ],
  );
}

final class _LocationService implements DeviceLocationService {
  @override
  Future<DeviceLocation> getCurrentLocation() async =>
      const DeviceLocation(latitude: 16.0544, longitude: 108.2022);
}

final class _PoiRepository implements PointOfInterestRepository {
  @override
  Future<List<SelectablePoi>> search({
    double? latitude,
    double? longitude,
    int? radiusKm,
    String? query,
  }) async => [
    const SelectablePoi(
      id: 1,
      name: 'Cham Museum',
      latitude: 16.0,
      longitude: 108.2,
      averageVisitDurationMinutes: 90,
      openingHoursKnown: true,
      hasShelter: true,
    ),
  ];
}
