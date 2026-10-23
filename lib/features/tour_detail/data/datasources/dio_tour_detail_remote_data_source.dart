import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/datasources/tour_detail_data_source.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/models/tour_detail_model.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

/// UC-26 public detail: `GET /api/v1/tours/{tourId}`.
///
/// A tour that is missing or not public (HTTP 404) is `null`. Every other
/// failure (network, timeout, 4xx/5xx, a body that breaks the contract) throws,
/// so the screen can offer Retry instead of claiming the tour is gone.
final class DioTourDetailRemoteDataSource implements TourDetailDataSource {
  DioTourDetailRemoteDataSource(DioClient client) : _dio = client.dio;

  final Dio _dio;

  // Backend ids are Int64: digits only, at most 19 of them.
  static final _validId = RegExp(r'^\d{1,19}$');

  @override
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  }) async {
    if (!_validId.hasMatch(tourId)) return null;
    try {
      final response = await _dio.get<Object?>(
        '/api/v1/tours/$tourId',
        options: Options(extra: const {'skipAuth': true}),
      );
      return TourDetailModel.fromJson(_jsonObject(response.data)).toEntity();
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Map<String, Object?> _jsonObject(Object? data) {
    if (data is Map<String, Object?>) return data;
    if (data is Map) return Map<String, Object?>.from(data);
    throw const FormatException('The API response must be a JSON object.');
  }
}
