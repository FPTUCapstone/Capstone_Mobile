import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi_search_result.dart';

abstract interface class PointOfInterestRepository {
  Future<SelectablePoiSearchResult> search({
    double? latitude,
    double? longitude,
    int? radiusKm,
    String? query,
    int page = 1,
    int pageSize = 50,
  });
}
