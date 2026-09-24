import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';

enum PoiSearchStatus { initial, locating, searching, ready, failure }

final class PoiSearchState extends Equatable {
  const PoiSearchState._({
    required this.status,
    this.currentLocation,
    this.results = const [],
    this.totalCount = 0,
    this.isLoadingMore = false,
    this.message,
  });

  const PoiSearchState.initial() : this._(status: PoiSearchStatus.initial);
  const PoiSearchState.locating() : this._(status: PoiSearchStatus.locating);
  const PoiSearchState.searching() : this._(status: PoiSearchStatus.searching);
  const PoiSearchState.locationReady(DeviceLocation location)
    : this._(status: PoiSearchStatus.ready, currentLocation: location);
  const PoiSearchState.resultsReady(
    List<SelectablePoi> results, {
    required int totalCount,
    bool isLoadingMore = false,
  }) : this._(
         status: PoiSearchStatus.ready,
         results: results,
         totalCount: totalCount,
         isLoadingMore: isLoadingMore,
       );
  const PoiSearchState.failure(String message)
    : this._(status: PoiSearchStatus.failure, message: message);

  final PoiSearchStatus status;
  final DeviceLocation? currentLocation;
  final List<SelectablePoi> results;
  final int totalCount;
  final bool isLoadingMore;
  final String? message;

  @override
  List<Object?> get props => [
    status,
    currentLocation,
    results,
    totalCount,
    isLoadingMore,
    message,
  ];
}
