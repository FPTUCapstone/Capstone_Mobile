import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';

enum NavigationLocationAccess {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// Device location access for live navigation. Positions never leave the device
/// except as Mapbox directions origins.
abstract interface class NavigationLocationTracker {
  /// Checks location services and requests permission when needed.
  Future<NavigationLocationAccess> ensureAccess();

  Stream<NavigationPosition> watchPosition();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}
