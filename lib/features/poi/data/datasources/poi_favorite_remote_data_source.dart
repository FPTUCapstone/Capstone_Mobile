import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';

abstract interface class PoiFavoriteRemoteDataSource {
  Future<bool> isFavorite(int poiId);
  Future<bool> setFavorite(int poiId, {required bool isFavorite});
}

/// Unlike the public POI reads, these calls keep the traveler's bearer token
/// (no `skipAuth`).
final class DioPoiFavoriteRemoteDataSource
    implements PoiFavoriteRemoteDataSource {
  DioPoiFavoriteRemoteDataSource(DioClient client) : _dio = client.dio;

  final Dio _dio;

  static String _path(int poiId) => '/api/v1/pois/$poiId/favorite';

  @override
  Future<bool> isFavorite(int poiId) async =>
      _read(await _dio.get<Object?>(_path(poiId)));

  @override
  Future<bool> setFavorite(int poiId, {required bool isFavorite}) async =>
      _read(
        isFavorite
            ? await _dio.put<Object?>(_path(poiId))
            : await _dio.delete<Object?>(_path(poiId)),
      );

  bool _read(Response<Object?> response) {
    final data = response.data;
    if (data is Map && data['isFavorite'] is bool) {
      return data['isFavorite'] as bool;
    }
    throw const FormatException('The favorite response must say isFavorite.');
  }
}
