import 'package:trip_mate_mobile/features/poi/domain/entities/poi_location.dart';

abstract interface class PoiLocationService {
  Future<PoiLocation> requestCurrentLocation();
}
