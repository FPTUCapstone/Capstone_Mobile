import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_group_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';

/// Concrete implementation of [TravelGroupRepository] that calls the REST API.
///
/// Input: [DioClient] for HTTP transport.
/// Output: [TravelGroup] entity on 201 Created; throws [Failure] on error.
final class TravelGroupRepositoryImpl implements TravelGroupRepository {
  const TravelGroupRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  final DioClient _dioClient;

  static const _path = '/api/v1/travel-groups';

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        _path,
        data: {'groupName': name, 'itineraryId': itineraryId, 'hostUserId': 1},
      );
      final model = TravelGroupModel.fromJson(response.data!);
      return model.toEntity();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final serverDetail =
            data['detail'] as String? ?? data['title'] as String?;
        if (serverDetail != null && serverDetail.isNotEmpty) {
          throw ServerFailure(serverDetail);
        }
      }
      throw const NetworkFailure(
        'TripMate is temporarily unable to process your request. Please check your connection and try again.',
      );
    }
  }
}
