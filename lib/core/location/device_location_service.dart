import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

final class DeviceLocation extends Equatable {
  const DeviceLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object> get props => [latitude, longitude];
}

sealed class DeviceLocationException implements Exception {
  const DeviceLocationException();
}

final class LocationServiceDisabledException extends DeviceLocationException {
  const LocationServiceDisabledException();
}

final class LocationPermissionDeniedException extends DeviceLocationException {
  const LocationPermissionDeniedException({required this.permanentlyDenied});

  final bool permanentlyDenied;
}

abstract interface class DeviceLocationService {
  Future<DeviceLocation> getCurrentLocation();

  /// Checks the current location permission state on the device.
  Future<LocationPermission> checkPermission();

  /// Requests location permission from the operating system.
  Future<LocationPermission> requestPermission();

  /// Checks whether location services (GPS) are enabled on the device.
  Future<bool> isLocationServiceEnabled();

  /// Opens the application settings screen so the user can grant permissions.
  Future<bool> openAppSettings();

  /// Opens the device location settings screen to enable GPS.
  Future<bool> openLocationSettings();
}

final class GeolocatorDeviceLocationService implements DeviceLocationService {
  const GeolocatorDeviceLocationService();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    if (!await isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedException(
        permanentlyDenied: permission == LocationPermission.deniedForever,
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
