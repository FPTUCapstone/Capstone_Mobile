import 'package:trip_mate_mobile/features/traveler/domain/entities/leave_travel_group_result.dart';

final class LeaveTravelGroupModel {
  const LeaveTravelGroupModel({
    required this.groupId,
    required this.membershipStatus,
    required this.groupClosed,
    required this.newHostUserId,
    required this.leftAtUtc,
  });

  factory LeaveTravelGroupModel.fromJson(Map<String, dynamic> json) {
    final groupId = json['groupId'] as int;
    final membershipStatus = json['membershipStatus'] as String;
    final groupClosed = json['groupClosed'] as bool;
    final newHostUserId = json['newHostUserId'] as int?;
    if (groupId <= 0 ||
        membershipStatus != 'Left' ||
        (groupClosed && newHostUserId != null)) {
      throw const FormatException('Invalid leave response.');
    }
    return LeaveTravelGroupModel(
      groupId: groupId,
      membershipStatus: membershipStatus,
      groupClosed: groupClosed,
      newHostUserId: newHostUserId,
      leftAtUtc: DateTime.parse(json['leftAtUtc'] as String).toUtc(),
    );
  }

  final int groupId;
  final String membershipStatus;
  final bool groupClosed;
  final int? newHostUserId;
  final DateTime leftAtUtc;

  LeaveTravelGroupResult toEntity() => LeaveTravelGroupResult(
    groupId: groupId,
    membershipStatus: membershipStatus,
    groupClosed: groupClosed,
    newHostUserId: newHostUserId,
    leftAtUtc: leftAtUtc,
  );
}
