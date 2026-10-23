import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';

enum ItineraryMarkerKind { start, attraction, food, end }

/// One marker of the itinerary map. Visit markers carry their [itemId] so the
/// map and the timeline can highlight each other.
final class ItineraryMapMarker extends Equatable {
  const ItineraryMapMarker({
    required this.id,
    required this.coordinate,
    required this.kind,
    required this.label,
    required this.title,
    this.itemId,
  });

  final int id;
  final NavigationCoordinate coordinate;
  final ItineraryMarkerKind kind;

  /// Stop number, or "Xuất phát" / "Kết thúc".
  final String label;
  final String title;
  final int? itemId;

  @override
  List<Object?> get props => [id, coordinate, kind, label, title, itemId];
}

/// A leg to draw, routed with its own transport.
final class ItineraryMapLeg extends Equatable {
  const ItineraryMapLeg({required this.from, required this.to, this.mode});

  final NavigationCoordinate from;
  final NavigationCoordinate to;
  final TransportMode? mode;

  @override
  List<Object?> get props => [from, to, mode];
}

/// Markers and legs of an itinerary: start, numbered visit stops (food vs
/// attraction by cost kind), end. Stops without coordinates are left out.
final class ItineraryMapData extends Equatable {
  const ItineraryMapData({required this.markers, required this.legs});

  factory ItineraryMapData.fromDetail(ItineraryDetail detail) {
    final markers = <ItineraryMapMarker>[];
    final legs = <ItineraryMapLeg>[];
    final start = _coordinate(detail.startLocation);
    final end = _coordinate(detail.endLocation);
    final returnsToStart = start != null && end == start;
    if (start != null) {
      markers.add(
        ItineraryMapMarker(
          id: _startId,
          coordinate: start,
          kind: ItineraryMarkerKind.start,
          label: returnsToStart ? 'Xuất phát · Kết thúc' : 'Xuất phát',
          title: detail.startLocation?.address ?? 'Điểm xuất phát',
        ),
      );
    }
    var previous = start;
    final visits = detail.visitItems;
    for (var i = 0; i < visits.length; i++) {
      final item = visits[i];
      final latitude = item.latitude;
      final longitude = item.longitude;
      if (latitude == null || longitude == null) continue;
      final point = NavigationCoordinate(
        latitude: latitude,
        longitude: longitude,
      );
      markers.add(
        ItineraryMapMarker(
          id: item.itemId,
          coordinate: point,
          kind: item.isFood
              ? ItineraryMarkerKind.food
              : ItineraryMarkerKind.attraction,
          label: '${i + 1}',
          title: item.poiName ?? 'Điểm ${i + 1}',
          itemId: item.itemId,
        ),
      );
      if (previous != null) {
        legs.add(
          ItineraryMapLeg(
            from: previous,
            to: point,
            mode: item.transportModeFromPrevious ?? detail.transportMode,
          ),
        );
      }
      previous = point;
    }
    if (end != null) {
      if (!returnsToStart) {
        markers.add(
          ItineraryMapMarker(
            id: _endId,
            coordinate: end,
            kind: ItineraryMarkerKind.end,
            label: 'Kết thúc',
            title: detail.endLocation?.address ?? 'Điểm kết thúc',
          ),
        );
      }
      if (previous != null && previous != start) {
        legs.add(
          ItineraryMapLeg(from: previous, to: end, mode: detail.transportMode),
        );
      }
    }
    return ItineraryMapData(
      markers: List.unmodifiable(markers),
      legs: List.unmodifiable(legs),
    );
  }

  // Item IDs are positive, so the trip ends cannot clash with them.
  static const _startId = -1;
  static const _endId = -2;

  final List<ItineraryMapMarker> markers;
  final List<ItineraryMapLeg> legs;

  static NavigationCoordinate? _coordinate(ItineraryLocation? location) =>
      location == null
      ? null
      : NavigationCoordinate(
          latitude: location.latitude,
          longitude: location.longitude,
        );

  @override
  List<Object?> get props => [markers, legs];
}
