import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

/// Abstract contract for travel group data operations.
///
/// Input: group name string.
/// Output: [TravelGroup] on success, or throws on failure.
abstract interface class TravelGroupRepository {
  /// Creates a new travel group with [name] linked to [itineraryId].
  ///
  /// Throws [ServerFailure] on HTTP errors and [NetworkFailure] on connectivity issues.
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  });

  /// Retrieves the current invitation, creating one only when the group has none usable.
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  });

  /// Immediately invalidates the current invitation and returns its replacement.
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  });
}
