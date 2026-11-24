import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';

/// A captured read-only itinerary, independent of network and map SDK types.
final class OfflineTripSnapshot {
  OfflineTripSnapshot({
    required this.ownerId,
    required this.requestedItineraryId,
    required ItineraryDetail itinerary,
    required List<PoiDetail> pois,
    required List<NavigationRoute> routes,
    required DateTime capturedAtUtc,
  }) : itinerary = itinerary.withItems(List.unmodifiable(itinerary.items)),
       pois = List.unmodifiable(pois.map(_immutablePoi)),
       routes = List.unmodifiable(
         routes.map(
           (route) => NavigationRoute(
             geometry: List.unmodifiable(route.geometry),
             distanceMeters: route.distanceMeters,
             durationSeconds: route.durationSeconds,
             steps: List.unmodifiable(route.steps),
           ),
         ),
       ),
       capturedAtUtc = capturedAtUtc.toUtc() {
    if (ownerId <= 0 ||
        requestedItineraryId <= 0 ||
        itinerary.itineraryId <= 0 ||
        itinerary.schedulingRequestId < 0 ||
        itinerary.version <= 0) {
      throw ArgumentError('Offline snapshot identifiers are invalid.');
    }
  }

  final int ownerId;
  final int requestedItineraryId;
  final ItineraryDetail itinerary;
  final List<PoiDetail> pois;
  final List<NavigationRoute> routes;
  final DateTime capturedAtUtc;

  static PoiDetail _immutablePoi(PoiDetail poi) => PoiDetail(
    id: poi.id,
    name: poi.name,
    description: poi.description,
    status: poi.status,
    categoryId: poi.categoryId,
    categoryName: poi.categoryName,
    latitude: poi.latitude,
    longitude: poi.longitude,
    address: poi.address,
    indoorOutdoor: poi.indoorOutdoor,
    averageVisitDurationMinutes: poi.averageVisitDurationMinutes,
    hasShelter: poi.hasShelter,
    scenicScore: poi.scenicScore,
    photoRating: poi.photoRating,
    averageRating: poi.averageRating,
    estimatedVisitCost: poi.estimatedVisitCost,
    costKind: poi.costKind,
    reviewCount: poi.reviewCount,
    isOpenNow: poi.isOpenNow,
    openingHours: List.unmodifiable(poi.openingHours),
    photos: List.unmodifiable(poi.photos),
    tags: List.unmodifiable(poi.tags),
    createdAtUtc: poi.createdAtUtc,
    updatedAtUtc: poi.updatedAtUtc,
  );
}

/// A complete generation; availability additionally requires verified native
/// map resources. The local source alone cannot establish map availability.
final class OfflineTripManifest {
  OfflineTripManifest({
    required this.snapshot,
    required this.generation,
    required this.regionId,
    required this.styleUri,
    required this.styleBytes,
    required this.tileBytes,
    required DateTime downloadedAtUtc,
    this.dataBytes = 0,
    this.publicationSequence = 0,
    this.locked = false,
    this.superseded = false,
    this.mapResourcesAvailable = false,
  }) : downloadedAtUtc = downloadedAtUtc.toUtc() {
    if (styleBytes < 0 ||
        tileBytes < 0 ||
        dataBytes < 0 ||
        publicationSequence < 0) {
      throw ArgumentError('Offline resource sizes cannot be negative.');
    }
    if (regionId.isEmpty || styleUri.isEmpty) {
      throw ArgumentError('Offline map resource references are required.');
    }
  }

  static const maxBytes = 150000000;
  static const minimumZoom = 10;
  static const maximumZoom = 16;
  static const coverageBufferMeters = 1000;
  final OfflineTripSnapshot snapshot;
  final String generation;
  final String regionId;
  final String styleUri;
  final int styleBytes;
  final int tileBytes;
  final int dataBytes;

  /// Assigned by the serialized local store, independent of device wall time.
  final int publicationSequence;
  final DateTime downloadedAtUtc;
  final bool locked;
  final bool superseded;

  /// Derived from SDK verification each time, never trusted from local JSON.
  final bool mapResourcesAvailable;

  int get ownerId => snapshot.ownerId;
  int get itineraryId => snapshot.itinerary.itineraryId;
  int get version => snapshot.itinerary.version;
  String get title => snapshot.itinerary.title ?? 'Trip #$itineraryId';
  int get totalBytes => styleBytes + tileBytes + dataBytes;

  OfflineTripManifest copyWith({
    int? dataBytes,
    int? publicationSequence,
    bool? locked,
    bool? superseded,
    bool? mapResourcesAvailable,
  }) => OfflineTripManifest(
    snapshot: snapshot,
    generation: generation,
    regionId: regionId,
    styleUri: styleUri,
    styleBytes: styleBytes,
    tileBytes: tileBytes,
    downloadedAtUtc: downloadedAtUtc,
    dataBytes: dataBytes ?? this.dataBytes,
    publicationSequence: publicationSequence ?? this.publicationSequence,
    locked: locked ?? this.locked,
    superseded: superseded ?? this.superseded,
    mapResourcesAvailable: mapResourcesAvailable ?? this.mapResourcesAvailable,
  );
}
