import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

abstract interface class TravelGroupRepository {
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  });

  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  });

  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  });

  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  });
}
