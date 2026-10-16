import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/tour_search/data/models/tour_search_page_model.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_category.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';

abstract interface class TourSearchRemoteDataSource {
  Future<TourSearchPageModel> searchTours(TourSearchQuery query);
}

final class DioTourSearchRemoteDataSource
    implements TourSearchRemoteDataSource {
  DioTourSearchRemoteDataSource(DioClient client, {AppConfig? config})
    : _dio = client.dio,
      _config = config;

  final Dio _dio;
  final AppConfig? _config;
  CancelToken? _searchCancellation;
  bool get _enabled => _config?.devSearchEnabled ?? false;
  Options get _options => Options(
    extra: const {'skipAuth': true},
    followRedirects: !_enabled,
    headers: {if (_enabled) 'X-TM70-Dev-Key': _config!.devSearchKey},
  );

  Future<List<TourCategory>> loadCategories() async {
    if (!_enabled) return const [];
    final response = await _dio.get<Object?>(
      '/api/dev/tours/categories',
      options: _options,
    );
    if (response.data is! List) {
      throw const FormatException('Invalid category response.');
    }
    return (response.data as List)
        .map((value) {
          final item = _jsonObject(value);
          if (item['code'] is! String || item['name'] is! String) {
            throw const FormatException('Invalid category.');
          }
          return TourCategory(
            code: item['code'] as String,
            name: item['name'] as String,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<TourSearchPageModel> searchTours(TourSearchQuery query) async {
    if (_enabled) {
      _searchCancellation?.cancel('Superseded search');
      _searchCancellation = CancelToken();
    }
    final response = await _dio.get<Object?>(
      _enabled ? '/api/dev/tours/search' : '/api/v1/tours',
      queryParameters: _enabled
          ? query.toV2QueryParameters()
          : query.toQueryParameters(),
      options: _options,
      cancelToken: _enabled ? _searchCancellation : null,
    );
    return TourSearchPageModel.fromJson(_jsonObject(response.data));
  }

  Map<String, Object?> _jsonObject(Object? data) {
    if (data is Map<String, Object?>) return data;
    if (data is Map) return Map<String, Object?>.from(data);
    throw const FormatException('The API response must be a JSON object.');
  }
}
