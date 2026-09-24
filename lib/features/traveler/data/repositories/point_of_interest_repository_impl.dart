import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/selectable_poi_search_result_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi_search_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/point_of_interest_repository.dart';

final class PointOfInterestRepositoryImpl implements PointOfInterestRepository {
  const PointOfInterestRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  static const _path = '/api/v1/points-of-interest/search';
  final DioClient _dioClient;

  @override
  Future<SelectablePoiSearchResult> search({
    double? latitude,
    double? longitude,
    int? radiusKm,
    String? query,
    int page = 1,
    int pageSize = 50,
  }) async {
    if (page < 1 || pageSize < 1) {
      throw const FormatException('POI search page values must be positive.');
    }
    final hasCompleteLocation =
        latitude != null && longitude != null && radiusKm != null;
    if ((latitude != null || longitude != null || radiusKm != null) &&
        !hasCompleteLocation) {
      throw const FormatException(
        'Location searches require latitude, longitude, and a radius.',
      );
    }

    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          if (hasCompleteLocation) ...{
            'latitude': latitude,
            'longitude': longitude,
            'radiusKm': radiusKm,
          },
          if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        },
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty selectable POI search response.');
      }
      final result = SelectablePoiSearchResultModel.fromJson(data);
      return SelectablePoiSearchResult(
        items: result.items,
        totalCount: result.totalCount,
      );
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
