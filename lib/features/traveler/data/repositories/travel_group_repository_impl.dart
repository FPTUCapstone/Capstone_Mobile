import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_group_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';

/// Concrete implementation of [TravelGroupRepository] that calls the REST API.
///
/// Input: [DioClient] for HTTP transport.
/// Output: [TravelGroup] entity on 201 Created; rethrows [DioException] on error.
final class TravelGroupRepositoryImpl implements TravelGroupRepository {
  const TravelGroupRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  final DioClient _dioClient;

  static const _path = '/api/v1/travel-groups';

  @override
  Future<TravelGroup> createTravelGroup(
    String name, {
    int itineraryId = 1,
  }) async {
    final response = await _dioClient.dio.post<Map<String, dynamic>>(
      _path,
      data: {'groupName': name, 'name': name, 'itineraryId': itineraryId},
    );
    final model = TravelGroupModel.fromJson(response.data!);
    return model.toEntity();
  }
}
