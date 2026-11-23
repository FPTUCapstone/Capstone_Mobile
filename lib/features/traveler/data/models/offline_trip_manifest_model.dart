import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_detail_model.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/cost_kind.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_detail_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';

/// Explicit local schema. Never persist a raw API response or session payload.
abstract final class OfflineTripManifestModel {
  static const schemaVersion = 1;

  static List<int> encode(OfflineTripManifest manifest) => utf8.encode(
    jsonEncode({
      'schemaVersion': schemaVersion,
      'coverage': {
        'minimumZoom': OfflineTripManifest.minimumZoom,
        'maximumZoom': OfflineTripManifest.maximumZoom,
        'bufferMeters': OfflineTripManifest.coverageBufferMeters,
      },
      'ownerId': manifest.ownerId,
      'requestedItineraryId': manifest.snapshot.requestedItineraryId,
      'generation': manifest.generation,
      'publicationSequence': manifest.publicationSequence,
      'regionId': manifest.regionId,
      'styleUri': manifest.styleUri,
      'styleBytes': manifest.styleBytes,
      'tileBytes': manifest.tileBytes,
      'downloadedAtUtc': manifest.downloadedAtUtc.toIso8601String(),
      'capturedAtUtc': manifest.snapshot.capturedAtUtc.toIso8601String(),
      'itineraryFingerprint': itineraryFingerprint(manifest.snapshot.itinerary),
      'itinerary': itineraryJson(manifest.snapshot.itinerary),
      'pois': manifest.snapshot.pois.map(_poiJson).toList(),
      'routes': manifest.snapshot.routes.map(_routeJson).toList(),
    }),
  );

  /// Includes the 64-byte SHA-256 commit marker, not filesystem allocation.
  static int encodedSize(OfflineTripManifest manifest) =>
      encode(manifest).length + 64;

  static OfflineTripManifest decode(List<int> bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported offline schema.');
    }
    final coverage = _map(json['coverage']);
    if (coverage['minimumZoom'] != OfflineTripManifest.minimumZoom ||
        coverage['maximumZoom'] != OfflineTripManifest.maximumZoom ||
        coverage['bufferMeters'] != OfflineTripManifest.coverageBufferMeters) {
      throw const FormatException('Unsupported offline map coverage.');
    }
    final itinerary = ItineraryDetailModel.fromJson(
      _map(json['itinerary']),
    ).toEntity();
    if (json['itineraryFingerprint'] != itineraryFingerprint(itinerary)) {
      throw const FormatException('Offline itinerary fingerprint mismatch.');
    }
    final snapshot = OfflineTripSnapshot(
      ownerId: json['ownerId'] as int,
      requestedItineraryId: json['requestedItineraryId'] as int,
      itinerary: itinerary,
      capturedAtUtc: DateTime.parse(json['capturedAtUtc'] as String),
      pois: (json['pois'] as List)
          .map((value) => PoiDetailModel.fromJson(_map(value)).toEntity())
          .toList(),
      routes: (json['routes'] as List)
          .map((value) => _route(_map(value)))
          .toList(),
    );
    return OfflineTripManifest(
      snapshot: snapshot,
      generation: json['generation'] as String,
      publicationSequence: json['publicationSequence'] as int? ?? 0,
      regionId: json['regionId'] as String,
      styleUri: json['styleUri'] as String,
      styleBytes: json['styleBytes'] as int,
      tileBytes: json['tileBytes'] as int,
      downloadedAtUtc: DateTime.parse(json['downloadedAtUtc'] as String),
      dataBytes: bytes.length + 64,
    );
  }

  /// Stable essential fields detect in-place status/coordinate changes even
  /// when the backend retains the itinerary's version number.
  static String itineraryFingerprint(ItineraryDetail itinerary) => sha256
      .convert(utf8.encode(jsonEncode(itineraryJson(itinerary))))
      .toString();

  static Map<String, dynamic> itineraryJson(ItineraryDetail trip) => {
    'itineraryId': trip.itineraryId,
    'schedulingRequestId': trip.schedulingRequestId,
    'title': trip.title, 'version': trip.version, 'status': trip.status,
    'validFrom': trip.validFrom?.toUtc().toIso8601String(),
    'validTo': trip.validTo?.toUtc().toIso8601String(),
    // Local read-only data never confers edit or navigation permission.
    'canManage': false, 'totalEstimatedCost': trip.totalEstimatedCost,
    'totalDurationMinutes': trip.totalDurationMinutes,
    'transportMode': _transport(trip.transportMode),
    'startLocation': _locationJson(trip.startLocation),
    'endLocation': _locationJson(trip.endLocation),
    'items': trip.items
        .map(
          (item) => {
            'itemId': item.itemId,
            'sequenceNo': item.sequenceNo,
            'poiId': item.poiId,
            'poiName': item.poiName,
            'category': item.category,
            'kind': item.itemKind == ItineraryItemKind.visit ? 'Visit' : 'Rest',
            'plannedArrival': item.plannedArrival.toUtc().toIso8601String(),
            'plannedDeparture': item.plannedDeparture.toUtc().toIso8601String(),
            'travelDurationFromPreviousMinutes':
                item.travelDurationFromPreviousMinutes,
            'stayDurationMinutes': item.stayDurationMinutes,
            'estimatedCost': item.estimatedCost,
            'isMandatory': item.isMandatory,
            'recommendationReason': item.recommendationReason,
            'isUnavailable': item.isUnavailable,
            'travelDistanceFromPreviousMeters':
                item.travelDistanceFromPreviousMeters,
            'transportModeFromPrevious': _transport(
              item.transportModeFromPrevious,
            ),
            'costKind': _costKind(item.costKind),
            'address': item.address,
            'latitude': item.latitude,
            'longitude': item.longitude,
          },
        )
        .toList(),
  };

  static Map<String, dynamic> _poiJson(PoiDetail poi) => {
    'id': poi.id, 'name': poi.name, 'description': poi.description,
    'status': poi.status,
    'categoryId': poi.categoryId,
    'categoryName': poi.categoryName,
    'latitude': poi.latitude,
    'longitude': poi.longitude,
    'address': poi.address,
    'indoorOutdoor': poi.indoorOutdoor,
    'averageVisitDurationMinutes': poi.averageVisitDurationMinutes,
    'hasShelter': poi.hasShelter, 'estimatedVisitCost': poi.estimatedVisitCost,
    'costKind': _costKind(poi.costKind), 'reviewCount': 0, 'isOpenNow': false,
    'openingHours': poi.openingHours
        .map(
          (hour) => {
            'dayOfWeek': hour.dayOfWeek,
            'openTime': hour.openTime,
            'closeTime': hour.closeTime,
            'isClosed': hour.isClosed,
          },
        )
        .toList(),
    // Photos, live review aggregates and private records are not UC16 data.
    'photos': <Object?>[], 'tags': <Object?>[],
    'createdAtUtc': poi.createdAtUtc.toUtc().toIso8601String(),
    'updatedAtUtc': poi.updatedAtUtc.toUtc().toIso8601String(),
  };

  static Map<String, dynamic> _routeJson(NavigationRoute route) => {
    'geometry': route.geometry.map(_coordinateJson).toList(),
    'distanceMeters': route.distanceMeters,
    'durationSeconds': route.durationSeconds,
    'steps': route.steps
        .map(
          (step) => {
            'instruction': step.instruction,
            'direction': step.direction.name,
            'location': _coordinateJson(step.location),
            'distanceMeters': step.distanceMeters,
          },
        )
        .toList(),
  };

  static NavigationRoute _route(Map<String, dynamic> json) => NavigationRoute(
    geometry: (json['geometry'] as List)
        .map((value) => _coordinate(_map(value)))
        .toList(),
    distanceMeters: (json['distanceMeters'] as num).toDouble(),
    durationSeconds: (json['durationSeconds'] as num).toDouble(),
    steps: (json['steps'] as List).map((value) {
      final step = _map(value);
      return NavigationStep(
        instruction: step['instruction'] as String,
        direction: ManeuverDirection.values.byName(step['direction'] as String),
        location: _coordinate(_map(step['location'])),
        distanceMeters: (step['distanceMeters'] as num).toDouble(),
      );
    }).toList(),
  );

  static NavigationCoordinate _coordinate(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num).toDouble();
    final longitude = (json['longitude'] as num).toDouble();
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw const FormatException('Invalid offline coordinate.');
    }
    return NavigationCoordinate(latitude: latitude, longitude: longitude);
  }

  static Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map);
  static Map<String, double> _coordinateJson(NavigationCoordinate point) => {
    'latitude': point.latitude,
    'longitude': point.longitude,
  };
  static Map<String, Object?>? _locationJson(ItineraryLocation? location) =>
      location == null
      ? null
      : {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': location.address,
        };
  static String? _transport(TransportMode? mode) => switch (mode) {
    TransportMode.walking => 'Walking',
    TransportMode.motorbike => 'Motorbike',
    TransportMode.car => 'Car',
    TransportMode.publicTransit => 'PublicTransit',
    null => null,
  };
  static String? _costKind(CostKind? kind) => switch (kind) {
    CostKind.admissionTicket => 'AdmissionTicket',
    CostKind.averageSpend => 'AverageSpend',
    null => null,
  };
}
