import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';

abstract interface class PoiRepository {
  Future<PagedPoiResult> getPois(PoiQuery query);
  Future<PoiDetail> getPoiDetail(int id);
}
