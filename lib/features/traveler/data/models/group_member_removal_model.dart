import 'package:trip_mate_mobile/features/traveler/domain/entities/group_member_removal.dart';

final class GroupMemberRemovalModel {
  const GroupMemberRemovalModel({
    required this.groupId,
    required this.memberUserId,
    required this.memberName,
    required this.removedAtUtc,
  });

  factory GroupMemberRemovalModel.fromJson(Map<String, dynamic> json) =>
      GroupMemberRemovalModel(
        groupId: json['groupId'] as int,
        memberUserId: json['memberUserId'] as int,
        memberName: json['memberName'] as String,
        removedAtUtc: DateTime.parse(json['removedAtUtc'] as String).toUtc(),
      );

  final int groupId;
  final int memberUserId;
  final String memberName;
  final DateTime removedAtUtc;

  GroupMemberRemoval toEntity() => GroupMemberRemoval(
    groupId: groupId,
    memberUserId: memberUserId,
    memberName: memberName,
    removedAtUtc: removedAtUtc,
  );
}
