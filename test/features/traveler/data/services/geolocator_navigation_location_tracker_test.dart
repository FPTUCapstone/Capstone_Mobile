import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/features/traveler/data/services/geolocator_navigation_location_tracker.dart';

void main() {
  test('Android navigation tracks inside a location foreground service', () {
    final settings = GeolocatorNavigationLocationTracker.settingsFor(
      TargetPlatform.android,
    );

    expect(settings, isA<AndroidSettings>());
    final android = settings as AndroidSettings;
    expect(android.accuracy, LocationAccuracy.high);
    expect(android.distanceFilter, 5);
    final notification = android.foregroundNotificationConfig;
    expect(notification, isNotNull);
    expect(notification!.notificationTitle, 'TripMate đang dẫn đường');
    expect(notification.setOngoing, isTrue);
    expect(notification.enableWakeLock, isTrue);
  });

  test('other platforms keep the plain foreground stream', () {
    final settings = GeolocatorNavigationLocationTracker.settingsFor(
      TargetPlatform.iOS,
    );

    expect(settings, isNot(isA<AndroidSettings>()));
    expect(settings.accuracy, LocationAccuracy.high);
    expect(settings.distanceFilter, 5);
  });
}
