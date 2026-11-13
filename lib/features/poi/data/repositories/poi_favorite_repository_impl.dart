import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/features/poi/data/datasources/poi_favorite_remote_data_source.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_favorite_repository.dart';

final class PoiFavoriteRepositoryImpl implements PoiFavoriteRepository {
  const PoiFavoriteRepositoryImpl(this._remoteDataSource);

  final PoiFavoriteRemoteDataSource _remoteDataSource;

  @override
  Future<bool> isFavorite(int poiId) async {
    try {
      return await _remoteDataSource.isFavorite(poiId);
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<bool> setFavorite(int poiId, {required bool isFavorite}) async {
    try {
      return await _remoteDataSource.setFavorite(poiId, isFavorite: isFavorite);
    } on Object catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
