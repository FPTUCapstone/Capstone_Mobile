import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_group_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';

/// Concrete implementation of [TravelGroupRepository] that calls the REST API.
///
/// Input: [DioClient] for HTTP transport.
/// Output: [TravelGroup] entity on 201 Created; throws an application [Failure].
final class TravelGroupRepositoryImpl implements TravelGroupRepository {
  const TravelGroupRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  final DioClient _dioClient;

  static const _path = '/api/v1/travel-groups';

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        _path,
        data: {'groupName': name, 'itineraryId': itineraryId},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty travel group response.');
      }
      return TravelGroupModel.fromJson(data).toEntity();
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
