import 'package:trip_mate_mobile/features/poi/domain/entities/poi_location.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_location_service.dart';

final class GetPoiLocationUseCase {
  const GetPoiLocationUseCase(this._service);
  final PoiLocationService _service;

  Future<PoiLocation> call() => _service.requestCurrentLocation();
}
