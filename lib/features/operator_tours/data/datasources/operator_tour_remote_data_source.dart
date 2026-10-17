import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/models/tour_package_parsers.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';

abstract interface class OperatorTourRemoteDataSource {
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey);
  Future<TourPackageOptions> loadOptions();
  Future<TourPackagePage> listTours({
    String? status,
    int page = 1,
    int pageSize = 20,
  });
  Future<TourPackageDetail> getTour(int tourId);
  Future<void> updateDraft(int tourId, TourPackageDraft draft);
  Future<void> submitForReview(int tourId);
  Future<List<TourMediaItem>> listMedia(int tourId);
  Future<void> uploadMedia(
    int tourId,
    TourImageUpload image, {
    required String altText,
    required bool makePrimary,
    required String idempotencyKey,
  });
  Future<void> setPrimaryMedia(int tourId, int mediaId);
  Future<void> deleteMedia(int tourId, int mediaId);
}

final class DioOperatorTourRemoteDataSource
    implements OperatorTourRemoteDataSource {
  DioOperatorTourRemoteDataSource(DioClient client) : _dio = client.dio;
  final Dio _dio;

  static const _toursPath = '/api/v1/operator/tours';

  @override
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey) async {
    final response = await _dio.post<Object?>(
      _toursPath,
      data: draft.toJson(),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    final payload = response.data;
    if (payload is! Map) {
      throw const FormatException('Tour creation response is invalid.');
    }
    final id = payload['tourId'];
    if (id is! num || id <= 0) {
      throw const FormatException('Created tour ID is missing.');
    }
    return id.toInt();
  }

  @override
  Future<TourPackageOptions> loadOptions() async {
    final responses = await Future.wait([
      _dio.get<Object?>('/api/v1/destinations'),
      _dio.get<Object?>('$_toursPath/cancellation-policies'),
    ]);
    return parseTourPackageOptions(responses[0].data, responses[1].data);
  }

  @override
  Future<TourPackagePage> listTours({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Object?>(
      _toursPath,
      queryParameters: {'page': page, 'pageSize': pageSize, 'status': ?status},
    );
    return parseTourPackagePage(response.data);
  }

  @override
  Future<TourPackageDetail> getTour(int tourId) async {
    final response = await _dio.get<Object?>('$_toursPath/$tourId');
    return parseTourPackageDetail(response.data);
  }

  @override
  Future<void> updateDraft(int tourId, TourPackageDraft draft) async {
    await _dio.put<Object?>('$_toursPath/$tourId', data: draft.toJson());
  }

  @override
  Future<void> submitForReview(int tourId) async {
    await _dio.post<Object?>('$_toursPath/$tourId/submit-review');
  }

  @override
  Future<List<TourMediaItem>> listMedia(int tourId) async {
    final response = await _dio.get<Object?>('$_toursPath/$tourId/media');
    return parseTourMediaList(response.data);
  }

  @override
  Future<void> uploadMedia(
    int tourId,
    TourImageUpload image, {
    required String altText,
    required bool makePrimary,
    required String idempotencyKey,
  }) async {
    await _dio.post<Object?>(
      '$_toursPath/$tourId/media',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          image.bytes,
          filename: image.fileName,
          contentType: DioMediaType.parse(image.contentType),
        ),
        'altText': altText,
        'isPrimary': makePrimary.toString(),
      }),
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
        contentType: 'multipart/form-data',
      ),
    );
  }

  @override
  Future<void> setPrimaryMedia(int tourId, int mediaId) async {
    final current = await listMedia(tourId);
    await _dio.put<Object?>(
      '$_toursPath/$tourId/media/order',
      data: {
        'mediaIds': [for (final item in current) item.id],
        'primaryMediaId': mediaId,
      },
    );
  }

  @override
  Future<void> deleteMedia(int tourId, int mediaId) async {
    await _dio.delete<Object?>('$_toursPath/$tourId/media/$mediaId');
  }
}
