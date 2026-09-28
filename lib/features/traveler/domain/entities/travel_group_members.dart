import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';

/// Read-only group and active-member list returned by UC19.
final class TravelGroupMembers extends Equatable {
  const TravelGroupMembers({
    required this.groupId,
    required this.groupName,
    required this.itineraryId,
    required this.members,
  });

  final int groupId;
  final String groupName;
  final int itineraryId;
  final List<TravelGroupMember> members;

  int get memberCount => members.length;

  @override
  List<Object?> get props => [groupId, groupName, itineraryId, members];
}
