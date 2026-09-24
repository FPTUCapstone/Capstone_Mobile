import 'dart:async';

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

  test('does not emit a late GPS result after the cubit is closed', () async {
    final locationService = _ControlledLocationService();
    final cubit = PoiSearchCubit(
      locationService: locationService,
      repository: _PoiRepository(),
    );

    final locating = cubit.useCurrentLocation();
    await cubit.close();
    locationService.completer.complete(
      const DeviceLocation(latitude: 16.0544, longitude: 108.2022),
    );
    await locating;

    expect(cubit.state.status, PoiSearchStatus.locating);
  });

  test('ignores GPS completion after a newer POI search', () async {
    final locationService = _ControlledLocationService();
    final repository = _ControlledPoiRepository();
    final cubit = PoiSearchCubit(
      locationService: locationService,
      repository: repository,
    );

    final locating = cubit.useCurrentLocation();
    final search = cubit.search(query: 'newer');
    repository.complete('newer', [
      const SelectablePoi(
        id: 2,
        name: 'Newer result',
        latitude: 16,
        longitude: 108,
        averageVisitDurationMinutes: 30,
        openingHoursKnown: true,
        hasShelter: true,
      ),
    ]);
    await search;
    locationService.completer.complete(
      const DeviceLocation(latitude: 16.0544, longitude: 108.2022),
    );
    await locating;

    expect(cubit.state.status, PoiSearchStatus.ready);
    expect(cubit.state.results.single.name, 'Newer result');
    await cubit.close();
  });

  test(
    'ignores an older search result that completes after the latest query',
    () async {
      final repository = _ControlledPoiRepository();
      final cubit = PoiSearchCubit(
        locationService: _LocationService(),
        repository: repository,
      );

      final first = cubit.search(query: 'first');
      final second = cubit.search(query: 'second');
      repository.complete('second', [
        const SelectablePoi(
          id: 2,
          name: 'Second result',
          latitude: 16,
          longitude: 108,
          averageVisitDurationMinutes: 30,
          openingHoursKnown: true,
          hasShelter: true,
        ),
      ]);
      await second;
      repository.complete('first', [
        const SelectablePoi(
          id: 1,
          name: 'Stale result',
          latitude: 16,
          longitude: 108,
          averageVisitDurationMinutes: 30,
          openingHoursKnown: true,
          hasShelter: true,
        ),
      ]);
      await first;

      expect(cubit.state.results.single.name, 'Second result');
      await cubit.close();
    },
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

final class _ControlledLocationService implements DeviceLocationService {
  final completer = Completer<DeviceLocation>();

  @override
  Future<DeviceLocation> getCurrentLocation() => completer.future;
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

final class _ControlledPoiRepository implements PointOfInterestRepository {
  final _completers = <String, Completer<List<SelectablePoi>>>{};

  @override
  Future<List<SelectablePoi>> search({
    double? latitude,
    double? longitude,
    int? radiusKm,
    String? query,
  }) => (_completers[query ?? ''] ??= Completer<List<SelectablePoi>>()).future;

  void complete(String query, List<SelectablePoi> results) {
    _completers[query]!.complete(results);
  }
}
