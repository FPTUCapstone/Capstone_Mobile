import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/external_reviews_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/external_reviews.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/external_review_repository.dart';

final class ExternalReviewRepositoryImpl implements ExternalReviewRepository {
  const ExternalReviewRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  final DioClient _dioClient;

  static String _path(int poiId) => '/api/v1/pois/$poiId/external-reviews';

  @override
  Future<PoiExternalReviews> getReviews(int poiId, {int size = 5}) async {
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        _path(poiId),
        queryParameters: {'size': size},
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty external reviews response.');
      }
      return PoiExternalReviewsModel.fromJson(data).toEntity();
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<TranslatedReview> translate({
    required int poiId,
    required int reviewId,
  }) async {
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        '${_path(poiId)}/$reviewId/translation',
        queryParameters: {'target': 'vi'},
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty review translation response.');
      }
      return TranslatedReviewModel.fromJson(data).toEntity();
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
