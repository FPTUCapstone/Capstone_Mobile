import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_detail_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_generation_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';

final class ItineraryRepositoryImpl implements ItineraryRepository {
  const ItineraryRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  static const _path = '/api/v1/scheduling-requests';
  static const _itineraryPath = '/api/v1/itineraries';
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
      if (error is DioException && error.response?.statusCode == 429) {
        throw RoutingProviderFailure();
      }
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        '$_itineraryPath/$itineraryId',
      );
      return _detail(response.data);
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<ItineraryDetail> accept(int itineraryId) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '$_itineraryPath/$itineraryId/accept',
      );
      return _detail(response.data);
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        '$_itineraryPath/$itineraryId/regenerate',
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return _detail(response.data);
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<ItineraryDetail> adjustItems({
    required int itineraryId,
    required List<int> orderedVisitPoiIds,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dioClient.dio.put<Map<String, dynamic>>(
        '$_itineraryPath/$itineraryId/items',
        data: {'orderedVisitPoiIds': orderedVisitPoiIds},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return _detail(response.data);
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  ItineraryDetail _detail(Map<String, dynamic>? data) {
    if (data == null) {
      throw const FormatException('Empty itinerary detail response.');
    }
    return ItineraryDetailModel.fromJson(data).toEntity();
  }
}
