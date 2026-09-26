import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';

enum PoiSearchStatus { initial, locating, searching, ready, failure }

final class PoiSearchScope extends Equatable {
  const PoiSearchScope({this.latitude, this.longitude, this.radiusKm});

  factory PoiSearchScope.fromLocation({DeviceLocation? near, int? radiusKm}) =>
      PoiSearchScope(
        latitude: near?.latitude,
        longitude: near?.longitude,
        radiusKm: near == null ? null : radiusKm ?? 50,
      );

  final double? latitude;
  final double? longitude;
  final int? radiusKm;

  @override
  List<Object?> get props => [latitude, longitude, radiusKm];
}

final class PoiSearchState extends Equatable {
  const PoiSearchState._({
    required this.status,
    this.currentLocation,
    this.results = const [],
    this.totalCount = 0,
    this.isLoadingMore = false,
    this.scope,
    this.message,
  });

  const PoiSearchState.initial({PoiSearchScope? scope})
    : this._(status: PoiSearchStatus.initial, scope: scope);
  const PoiSearchState.locating() : this._(status: PoiSearchStatus.locating);
  const PoiSearchState.searching({PoiSearchScope? scope})
    : this._(status: PoiSearchStatus.searching, scope: scope);
  const PoiSearchState.locationReady(DeviceLocation location)
    : this._(status: PoiSearchStatus.ready, currentLocation: location);
  const PoiSearchState.resultsReady(
    List<SelectablePoi> results, {
    required int totalCount,
    PoiSearchScope? scope,
    bool isLoadingMore = false,
  }) : this._(
         status: PoiSearchStatus.ready,
         results: results,
         totalCount: totalCount,
         isLoadingMore: isLoadingMore,
         scope: scope,
       );
  const PoiSearchState.failure(String message, {PoiSearchScope? scope})
    : this._(status: PoiSearchStatus.failure, message: message, scope: scope);

  final PoiSearchStatus status;
  final DeviceLocation? currentLocation;
  final List<SelectablePoi> results;
  final int totalCount;
  final bool isLoadingMore;
  final PoiSearchScope? scope;
  final String? message;

  @override
  List<Object?> get props => [
    status,
    currentLocation,
    results,
    totalCount,
    isLoadingMore,
    scope,
    message,
  ];
}
