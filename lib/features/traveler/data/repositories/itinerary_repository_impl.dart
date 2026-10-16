import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_detail_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_generation_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_suggestions_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_summary_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_summary.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_list_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_suggestion_repository.dart';

final class ItineraryRepositoryImpl
    implements
        ItineraryRepository,
        ItineraryListRepository,
        ItinerarySuggestionRepository {
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
  Future<ItinerarySummaryPage> listMine({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        _itineraryPath,
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty itinerary list response.');
      }
      return ItinerarySummaryPageModel.fromJson(data).toEntity();
    } catch (error) {
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
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dioClient.dio.put<Map<String, dynamic>>(
        '$_itineraryPath/$itineraryId/items',
        data: {
          'stops': [
            for (final stop in stops)
              {
                'poiId': stop.poiId,
                if (stop.transportModeToNext case final mode?)
                  'transportModeToNext': transportModeApiName(mode),
              },
          ],
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return _detail(response.data);
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<ItinerarySuggestions> getSuggestions({
    required int itineraryId,
    required SuggestionKind kind,
    required int itemId,
  }) async {
    try {
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        '$_itineraryPath/$itineraryId/suggestions',
        queryParameters: switch (kind) {
          SuggestionKind.food => {'kind': 'Food', 'afterItemId': itemId},
          SuggestionKind.replace => {
            'kind': 'Replace',
            'replaceItemId': itemId,
          },
        },
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty itinerary suggestions response.');
      }
      return ItinerarySuggestionsModel.fromJson(data).toEntity();
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
