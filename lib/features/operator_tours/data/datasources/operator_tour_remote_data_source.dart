import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';

abstract interface class OperatorTourRemoteDataSource {
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey);
  Future<TourPackageOptions> loadOptions();
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

  @override
  Future<TourPackageOptions> loadOptions() async {
    final responses = await Future.wait([
      _dio.get<Object?>('/api/v1/destinations'),
      _dio.get<Object?>('/api/v1/operator/tours/cancellation-policies'),
    ]);
    return TourPackageOptions(
      destinations: _items(responses[0].data, 'Destination')
          .map((item) {
            final id = item['destinationId'];
            final name = item['name'];
            if (id is! num ||
                id <= 0 ||
                name is! String ||
                name.trim().isEmpty) {
              throw const FormatException('Destination item is invalid.');
            }
            return TourDestinationOption(id: id.toInt(), name: name.trim());
          })
          .toList(growable: false),
      policies: _items(responses[1].data, 'Cancellation policy')
          .map((item) {
            final id = item['id'];
            final name = item['name'];
            final description = item['description'];
            if (id is! num ||
                id <= 0 ||
                name is! String ||
                name.trim().isEmpty) {
              throw const FormatException(
                'Cancellation policy item is invalid.',
              );
            }
            return CancellationPolicyOption(
              id: id.toInt(),
              name: name.trim(),
              description:
                  description is String && description.trim().isNotEmpty
                  ? description.trim()
                  : null,
            );
          })
          .toList(growable: false),
    );
  }

  List<Map<String, Object?>> _items(Object? payload, String label) {
    if (payload is! List) {
      throw FormatException('$label response must be a list.');
    }
    return payload
        .map((value) {
          if (value is! Map) throw FormatException('$label item is invalid.');
          return Map<String, Object?>.from(value);
        })
        .toList(growable: false);
  }
}
