import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_generation_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';

final class ItineraryRepositoryImpl implements ItineraryRepository {
  const ItineraryRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  static const _path = '/api/v1/scheduling-requests';
  final DioClient _dioClient;

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        _path,
        data: request.toJson(),
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty itinerary generation response.');
      }
      return ItineraryGenerationModel.fromJson(data).toEntity();
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
