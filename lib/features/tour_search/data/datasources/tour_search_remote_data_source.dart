import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/tour_search/data/models/tour_search_page_model.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';

abstract interface class TourSearchRemoteDataSource {
  Future<TourSearchPageModel> searchTours(TourSearchQuery query);
}

final class DioTourSearchRemoteDataSource
    implements TourSearchRemoteDataSource {
  DioTourSearchRemoteDataSource(DioClient client) : _dio = client.dio;

  final Dio _dio;

  @override
  Future<TourSearchPageModel> searchTours(TourSearchQuery query) async {
    final response = await _dio.get<Object?>(
      '/api/v1/tours',
      queryParameters: query.toQueryParameters(),
      options: Options(extra: const {'skipAuth': true}),
    );
    return TourSearchPageModel.fromJson(_jsonObject(response.data));
  }

  Map<String, Object?> _jsonObject(Object? data) {
    if (data is Map<String, Object?>) return data;
    if (data is Map) return Map<String, Object?>.from(data);
    throw const FormatException('The API response must be a JSON object.');
  }
}
