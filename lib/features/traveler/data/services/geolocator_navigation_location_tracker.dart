import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';

final class GeolocatorNavigationLocationTracker
    implements NavigationLocationTracker {
  const GeolocatorNavigationLocationTracker();

  @override
  Future<NavigationLocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return NavigationLocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => NavigationLocationAccess.granted,
      LocationPermission.deniedForever =>
        NavigationLocationAccess.deniedForever,
      _ => NavigationLocationAccess.denied,
    };
  }

  /// Navigation settings for [platform]. On Android the stream runs inside a
  /// location foreground service with an ongoing notification, so arrival
  /// detection keeps working while the screen is off or another app is open.
  /// "While using the app" permission is enough: the service starts while the
  /// navigation screen is in the foreground, so no background-location
  /// permission is requested. It stops when the trip's stream is cancelled.
  static LocationSettings settingsFor(TargetPlatform platform) =>
      platform == TargetPlatform.android
      ? AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'TripMate đang dẫn đường',
            notificationText:
                'Vị trí được dùng để báo khi bạn đến điểm dừng tiếp theo.',
            notificationChannelName: 'Dẫn đường',
            enableWakeLock: true,
            setOngoing: true,
          ),
        )
      : const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        );

  @override
  Stream<NavigationPosition> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: settingsFor(defaultTargetPlatform),
    ).map(
      (position) => NavigationPosition(
        coordinate: NavigationCoordinate(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        timestamp: position.timestamp,
        accuracyMeters: position.accuracy,
      ),
    );
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
