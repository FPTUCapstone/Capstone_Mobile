import 'package:equatable/equatable.dart';

/// The committed outcome returned by the group leave endpoint.
final class LeaveTravelGroupResult extends Equatable {
  const LeaveTravelGroupResult({
    required this.groupId,
    required this.membershipStatus,
    required this.groupClosed,
    required this.newHostUserId,
    required this.leftAtUtc,
  });

  final int groupId;
  final String membershipStatus;
  final bool groupClosed;
  final int? newHostUserId;
  final DateTime leftAtUtc;

  @override
  List<Object?> get props => [
    groupId,
    membershipStatus,
    groupClosed,
    newHostUserId,
    leftAtUtc,
  ];
}
