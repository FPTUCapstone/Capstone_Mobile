import 'package:trip_mate_mobile/features/traveler/domain/entities/leave_travel_group_result.dart';

abstract interface class LeaveTravelGroupRepository {
  Future<LeaveTravelGroupResult> leaveTravelGroup({
    required int groupId,
    required String idempotencyKey,
  });
}
