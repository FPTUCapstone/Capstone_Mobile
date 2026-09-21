import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/group_invitation_model.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_group_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';

/// Concrete implementation of [TravelGroupRepository] that calls the REST API.
final class TravelGroupRepositoryImpl implements TravelGroupRepository {
  const TravelGroupRepositoryImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  final DioClient _dioClient;

  static const _path = '/api/v1/travel-groups';
  static const _joinPath = '/api/v1/travel-groups/join';

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        _path,
        data: {'groupName': name, 'itineraryId': itineraryId},
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

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        _joinPath,
        data: {'invitationCode': invitationCode.trim().toUpperCase()},
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

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => _sendInvitationRequest(
    path: '$_path/$groupId/invitation',
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => _sendInvitationRequest(
    path: '$_path/$groupId/invitation/regenerate',
    idempotencyKey: idempotencyKey,
  );

  Future<GroupInvitation> _sendInvitationRequest({
    required String path,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dioClient.dio.post<Map<String, dynamic>>(
        path,
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty group invitation response.');
      }
      return GroupInvitationModel.fromJson(data).toEntity();
    } catch (error) {
      throw ErrorMapper.toFailure(error);
    }
  }
}
