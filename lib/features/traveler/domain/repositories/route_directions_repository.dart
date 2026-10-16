import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';

abstract interface class RouteDirectionsRepository {
  /// Whether turn-by-turn directions are available in this build.
  bool get isAvailable;

  /// Routes for [transportMode] (the mode the itinerary was planned with);
  /// null uses the default road profile. Throws a `Failure` when no route can
  /// be produced.
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    TransportMode? transportMode,
  });
}
