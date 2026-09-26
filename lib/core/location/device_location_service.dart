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
}

final class GeolocatorDeviceLocationService implements DeviceLocationService {
  const GeolocatorDeviceLocationService();

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
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
