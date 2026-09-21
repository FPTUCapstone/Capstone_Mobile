import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/poi/data/datasources/poi_remote_data_source.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';

final class PoiRepositoryImpl implements PoiRepository {
  const PoiRepositoryImpl(this._remoteDataSource);

  final PoiRemoteDataSource _remoteDataSource;

  @override
  Future<PagedPoiResult> getPois(PoiQuery query) async {
    try {
      return (await _remoteDataSource.getPois(query)).toEntity();
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<PoiDetail> getPoiDetail(int id) async {
    try {
      return (await _remoteDataSource.getPoiDetail(id)).toEntity();
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
