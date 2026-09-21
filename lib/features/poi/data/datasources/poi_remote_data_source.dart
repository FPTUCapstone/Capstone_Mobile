import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_detail_model.dart';
import 'package:trip_mate_mobile/features/poi/data/models/poi_page_model.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';

abstract interface class PoiRemoteDataSource {
  Future<PoiPageModel> getPois(PoiQuery query);
  Future<PoiDetailModel> getPoiDetail(int id);
}

final class DioPoiRemoteDataSource implements PoiRemoteDataSource {
  DioPoiRemoteDataSource(DioClient client) : _dio = client.dio;

  final Dio _dio;

  @override
  Future<PoiPageModel> getPois(PoiQuery query) async {
    final response = await _dio.get<Object?>(
      '/api/v1/pois',
      queryParameters: query.toQueryParameters(),
      options: Options(extra: const {'skipAuth': true}),
    );
    return PoiPageModel.fromJson(_jsonObject(response.data));
  }

  @override
  Future<PoiDetailModel> getPoiDetail(int id) async {
    final response = await _dio.get<Object?>(
      '/api/v1/pois/$id',
      options: Options(extra: const {'skipAuth': true}),
    );
    return PoiDetailModel.fromJson(_jsonObject(response.data));
  }

  Map<String, Object?> _jsonObject(Object? data) {
    if (data is Map<String, Object?>) return data;
    if (data is Map) return Map<String, Object?>.from(data);
    throw const FormatException('The API response must be a JSON object.');
  }
}
