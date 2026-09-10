import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';

/// Abstract contract for travel group data operations.
///
/// Input: group name string.
/// Output: [TravelGroup] on success, or throws on failure.
abstract interface class TravelGroupRepository {
  /// Creates a new travel group with [name] linked to [itineraryId].
  ///
  /// Throws [ServerFailure] on HTTP errors and [NetworkFailure] on connectivity issues.
  Future<TravelGroup> createTravelGroup(String name, {int itineraryId = 1});
}
