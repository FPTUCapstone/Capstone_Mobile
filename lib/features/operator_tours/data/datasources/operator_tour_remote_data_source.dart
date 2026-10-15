import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';

abstract interface class OperatorTourRemoteDataSource {
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey);
}

final class DioOperatorTourRemoteDataSource
    implements OperatorTourRemoteDataSource {
  DioOperatorTourRemoteDataSource(DioClient client) : _dio = client.dio;
  final Dio _dio;

  @override
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey) async {
    final response = await _dio.post<Object?>(
      '/api/v1/operator/tours',
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
}
