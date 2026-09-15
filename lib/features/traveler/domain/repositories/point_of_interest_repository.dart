import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';

abstract interface class PointOfInterestRepository {
  Future<List<SelectablePoi>> search({
    double? latitude,
    double? longitude,
    int? radiusKm,
    String? query,
  });
}
