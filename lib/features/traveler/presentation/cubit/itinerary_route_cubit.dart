import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_map_data.dart';

/// A drawn leg: the road geometry, or a straight segment when it could not
/// be routed.
final class ItineraryRouteLine extends Equatable {
  const ItineraryRouteLine({required this.points, required this.isStraight});

  final List<NavigationCoordinate> points;
  final bool isStraight;

  @override
  List<Object?> get props => [points, isStraight];
}

final class ItineraryRouteState extends Equatable {
  const ItineraryRouteState({this.lines = const [], this.isLoading = false});

  final List<ItineraryRouteLine> lines;
  final bool isLoading;

  @override
  List<Object?> get props => [lines, isLoading];
}

/// Routes every leg of the itinerary map with its own transport (walking vs
/// driving profile). Routed legs are remembered, so a redraw after an edit
/// only asks for the legs that changed.
final class ItineraryRouteCubit extends Cubit<ItineraryRouteState> {
  ItineraryRouteCubit({required RouteDirectionsRepository? directions})
    : _directions = directions,
      super(const ItineraryRouteState());

  final RouteDirectionsRepository? _directions;
  final _cache = <ItineraryMapLeg, ItineraryRouteLine>{};
  int _generation = 0;

  Future<void> load(List<ItineraryMapLeg> legs) async {
    final generation = ++_generation;
    final straight = [for (final leg in legs) _straight(leg)];
    emit(
      ItineraryRouteState(
        lines: [for (final leg in legs) _cache[leg] ?? _straight(leg)],
        isLoading: true,
      ),
    );
    final directions = _directions;
    final lines = <ItineraryRouteLine>[];
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final cached = _cache[leg];
      if (cached != null) {
        lines.add(cached);
        continue;
      }
      if (directions == null || !directions.isAvailable) {
        lines.add(straight[i]);
        continue;
      }
      try {
        final route = await directions.getRoute(
          origin: leg.from,
          destination: leg.to,
          transportMode: leg.mode,
        );
        final line = route.geometry.length >= 2
            ? ItineraryRouteLine(points: route.geometry, isStraight: false)
            : straight[i];
        _cache[leg] = line;
        lines.add(line);
      } catch (_) {
        // The map still shows the order of the stops.
        lines.add(straight[i]);
      }
      if (isClosed || generation != _generation) return;
    }
    if (isClosed || generation != _generation) return;
    emit(ItineraryRouteState(lines: List.unmodifiable(lines)));
  }

  static ItineraryRouteLine _straight(ItineraryMapLeg leg) =>
      ItineraryRouteLine(points: [leg.from, leg.to], isStraight: true);
}
