import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_location.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_location_service.dart';

final class GeolocatorPoiLocationService implements PoiLocationService {
  const GeolocatorPoiLocationService();

  @override
  Future<PoiLocation> requestCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationPermissionFailure(
        'Dịch vụ vị trí đang tắt. Bạn vẫn có thể khám phá địa điểm.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationPermissionFailure();
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return PoiLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
