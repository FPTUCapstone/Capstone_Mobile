import 'package:equatable/equatable.dart';

final class GroupMemberRemoval extends Equatable {
  const GroupMemberRemoval({
    required this.groupId,
    required this.memberUserId,
    required this.memberName,
    required this.removedAtUtc,
  });

  final int groupId;
  final int memberUserId;
  final String memberName;
  final DateTime removedAtUtc;

  @override
  List<Object?> get props => [groupId, memberUserId, memberName, removedAtUtc];
}
