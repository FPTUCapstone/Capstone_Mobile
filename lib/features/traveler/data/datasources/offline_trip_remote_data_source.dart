import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_detail_model.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_detail_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/offline_trip_manifest_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/mapbox_directions_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';

final class OfflineCaptureCancelled implements Exception {
  const OfflineCaptureCancelled();
}

/// Distinguishes an authoritative itinerary denial from a public POI failure.
/// The repository converts it to the public permission failure after locking.
final class OfflineItineraryAccessDenied implements Exception {
  const OfflineItineraryAccessDenied();
}

/// Captures only accessible trip data through existing domain repositories.
/// No download starts a server navigation session or changes an itinerary.
class OfflineTripRemoteDataSource {
  OfflineTripRemoteDataSource(
    this.itineraries,
    this.pois,
    this.directions, {
    this.client,
    this.mapboxAccessToken,
  });

  final ItineraryRepository itineraries;
  final PoiRepository pois;
  final RouteDirectionsRepository directions;
  final DioClient? client;
  final String? mapboxAccessToken;
  CancelToken? _activeRequest;

  void cancel() => _activeRequest?.cancel('Offline transfer cancelled');

  Future<ItineraryDetail> _detail(int id, CancelToken cancellation) async {
    final transport = client;
    try {
      if (transport == null) return await itineraries.getById(id);
      final response = await transport.dio.get<Map<String, dynamic>>(
        '/api/v1/itineraries/$id',
        cancelToken: cancellation,
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Missing itinerary response.');
      }
      return ItineraryDetailModel.fromJson(data).toEntity();
    } catch (error) {
      if (cancellation.isCancelled) throw const OfflineCaptureCancelled();
      final failure = error is Failure ? error : ErrorMapper.toFailure(error);
      if (failure is PermissionFailure) {
        throw const OfflineItineraryAccessDenied();
      }
      throw failure;
    }
  }

  Future<PoiDetail> _poi(int id, CancelToken cancellation) async {
    final transport = client;
    if (transport == null) return pois.getPoiDetail(id);
    try {
      final response = await transport.dio.get<Map<String, dynamic>>(
        '/api/v1/pois/$id',
        cancelToken: cancellation,
        options: Options(extra: const {'skipAuth': true}),
      );
      final data = response.data;
      if (data == null) throw const FormatException('Missing POI response.');
      return PoiDetailModel.fromJson(data).toEntity();
    } catch (error) {
      if (cancellation.isCancelled) throw const OfflineCaptureCancelled();
      throw ErrorMapper.toFailure(error);
    }
  }

  Future<ItineraryDetail> current(int itineraryId) async {
    final cancellation = CancelToken();
    _activeRequest = cancellation;
    try {
      return await _detail(itineraryId, cancellation);
    } on OfflineItineraryAccessDenied {
      throw const PermissionFailure(
        'You no longer have access to this itinerary.',
      );
    } finally {
      if (identical(_activeRequest, cancellation)) _activeRequest = null;
    }
  }

  Future<void> validate(OfflineTripSnapshot snapshot) async {
    final latest = await current(snapshot.requestedItineraryId);
    if (OfflineTripManifestModel.itineraryFingerprint(snapshot.itinerary) !=
        OfflineTripManifestModel.itineraryFingerprint(latest)) {
      throw const ConflictFailure(
        'The itinerary changed while downloading. Please try again.',
      );
    }
  }

  Future<OfflineTripSnapshot> capture({
    required int ownerId,
    required int itineraryId,
    bool Function()? isCancelled,
  }) async {
    final cancellation = CancelToken();
    _activeRequest = cancellation;
    try {
      return await _capture(
        ownerId: ownerId,
        itineraryId: itineraryId,
        isCancelled: isCancelled,
        cancellation: cancellation,
      );
    } catch (_) {
      if (cancellation.isCancelled) throw const OfflineCaptureCancelled();
      rethrow;
    } finally {
      if (identical(_activeRequest, cancellation)) _activeRequest = null;
    }
  }

  Future<OfflineTripSnapshot> _capture({
    required int ownerId,
    required int itineraryId,
    bool Function()? isCancelled,
    required CancelToken cancellation,
  }) async {
    void check() {
      if (cancellation.isCancelled || (isCancelled?.call() ?? false)) {
        throw const OfflineCaptureCancelled();
      }
    }

    check();
    if (ownerId <= 0 || itineraryId <= 0) {
      throw const ValidationFailure('Please select an accessible itinerary.');
    }
    final first = await _detail(itineraryId, cancellation);
    final routeProvider = client != null && mapboxAccessToken != null
        ? MapboxDirectionsRepositoryImpl(
            accessToken: mapboxAccessToken!,
            cancelToken: cancellation,
          )
        : directions;
    check();
    final visits =
        first.items.where((i) => i.itemKind == ItineraryItemKind.visit).toList()
          ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));
    final details = <int, PoiDetail>{};
    final routes = <NavigationRoute>[];
    NavigationCoordinate? previous = first.startLocation == null
        ? null
        : NavigationCoordinate(
            latitude: first.startLocation!.latitude,
            longitude: first.startLocation!.longitude,
          );
    for (final item in visits) {
      check();
      final id = item.poiId;
      final lat = item.latitude;
      final lon = item.longitude;
      if (id == null || lat == null || lon == null || !_valid(lat, lon)) {
        throw const ValidationFailure(
          'This itinerary is missing a location required for offline maps.',
        );
      }
      if (!details.containsKey(id)) details[id] = await _poi(id, cancellation);
      check();
      final poi = details[id]!;
      if (poi.id != id) {
        throw const ValidationFailure(
          'A point of interest response does not match the itinerary. Please try again.',
        );
      }
      if (!_valid(poi.latitude, poi.longitude)) {
        throw const ValidationFailure(
          'A point of interest has invalid map coordinates.',
        );
      }
      final coordinate = NavigationCoordinate(latitude: lat, longitude: lon);
      if (previous != null && previous != coordinate) {
        routes.add(
          await _route(
            previous,
            coordinate,
            item.transportModeFromPrevious ?? first.transportMode,
            routeProvider,
          ),
        );
        check();
      }
      previous = coordinate;
    }
    final end = first.endLocation;
    if (end != null && previous != null) {
      final coordinate = NavigationCoordinate(
        latitude: end.latitude,
        longitude: end.longitude,
      );
      if (coordinate != previous) {
        routes.add(
          await _route(
            previous,
            coordinate,
            first.transportMode,
            routeProvider,
          ),
        );
      }
    }
    check();
    final second = await _detail(itineraryId, cancellation);
    check();
    if (OfflineTripManifestModel.itineraryFingerprint(first) !=
        OfflineTripManifestModel.itineraryFingerprint(second)) {
      throw const ConflictFailure(
        'The itinerary changed while downloading. Please try again.',
      );
    }
    return OfflineTripSnapshot(
      ownerId: ownerId,
      requestedItineraryId: itineraryId,
      itinerary: first,
      pois: details.values.toList(growable: false),
      routes: routes,
      capturedAtUtc: DateTime.now().toUtc(),
    );
  }

  Future<NavigationRoute> _route(
    NavigationCoordinate from,
    NavigationCoordinate to,
    TransportMode? mode,
    RouteDirectionsRepository provider,
  ) async {
    if (!provider.isAvailable ||
        !_valid(from.latitude, from.longitude) ||
        !_valid(to.latitude, to.longitude)) {
      throw const RoutingProviderFailure(
        'Offline route download is not configured or a location is invalid.',
      );
    }
    final route = await provider.getRoute(
      origin: from,
      destination: to,
      transportMode: mode,
    );
    if (route.geometry.length < 2 ||
        route.geometry.any((p) => !_valid(p.latitude, p.longitude))) {
      throw const RoutingProviderFailure(
        'The route could not be saved for offline use.',
      );
    }
    return route;
  }

  static bool _valid(double lat, double lon) =>
      lat.isFinite &&
      lon.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lon >= -180 &&
      lon <= 180;
}
