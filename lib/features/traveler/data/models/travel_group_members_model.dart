import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';

final class TravelGroupMembersModel {
  const TravelGroupMembersModel({
    required this.groupId,
    required this.groupName,
    required this.itineraryId,
    required this.memberCount,
    required this.members,
  });

  factory TravelGroupMembersModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    if (rawMembers is! List) {
      throw const FormatException('Travel group members are missing.');
    }

    final model = TravelGroupMembersModel(
      groupId: _positiveInt(json['groupId'], 'groupId'),
      groupName: _requiredText(json['groupName'], 'groupName'),
      itineraryId: _positiveInt(json['itineraryId'], 'itineraryId'),
      memberCount: _nonNegativeInt(json['memberCount'], 'memberCount'),
      members: rawMembers
          .map((member) {
            if (member is! Map<String, dynamic>) {
              throw const FormatException('A travel group member is invalid.');
            }
            return TravelGroupMemberModel.fromJson(member);
          })
          .toList(growable: false),
    );

    if (model.memberCount != model.members.length) {
      throw const FormatException('Travel group member count is inconsistent.');
    }
    return model;
  }

  final int groupId;
  final String groupName;
  final int itineraryId;
  final int memberCount;
  final List<TravelGroupMemberModel> members;

  TravelGroupMembers toEntity() => TravelGroupMembers(
    groupId: groupId,
    groupName: groupName,
    itineraryId: itineraryId,
    members: members.map((member) => member.toEntity()).toList(growable: false),
  );
}

final class TravelGroupMemberModel {
  const TravelGroupMemberModel({
    required this.memberId,
    required this.displayName,
    required this.isHost,
    required this.joinedAtUtc,
    required this.locationSharingEnabled,
    this.avatarUrl,
  });

  factory TravelGroupMemberModel.fromJson(Map<String, dynamic> json) {
    final rawAvatarUrl = json['avatarUrl'];
    if (rawAvatarUrl != null && rawAvatarUrl is! String) {
      throw const FormatException('avatarUrl is invalid.');
    }
    final rawJoinedAtUtc = json['joinedAtUtc'];
    final joinedAtUtc = rawJoinedAtUtc is String
        ? DateTime.tryParse(rawJoinedAtUtc)?.toUtc()
        : null;
    if (joinedAtUtc == null) {
      throw const FormatException('joinedAtUtc is invalid.');
    }

    return TravelGroupMemberModel(
      memberId: _positiveInt(json['memberId'], 'memberId'),
      displayName: _requiredText(json['displayName'], 'displayName'),
      avatarUrl: rawAvatarUrl?.trim().isEmpty ?? true
          ? null
          : rawAvatarUrl?.trim(),
      isHost: _requiredBool(json['isHost'], 'isHost'),
      joinedAtUtc: joinedAtUtc,
      locationSharingEnabled: _requiredBool(
        json['locationSharingEnabled'],
        'locationSharingEnabled',
      ),
    );
  }

  final int memberId;
  final String displayName;
  final String? avatarUrl;
  final bool isHost;
  final DateTime joinedAtUtc;
  final bool locationSharingEnabled;

  TravelGroupMember toEntity() => TravelGroupMember(
    memberId: memberId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    isHost: isHost,
    joinedAtUtc: joinedAtUtc,
    locationSharingEnabled: locationSharingEnabled,
  );
}

int _positiveInt(Object? value, String field) {
  if (value is int && value > 0) return value;
  throw FormatException('$field must be a positive integer.');
}

int _nonNegativeInt(Object? value, String field) {
  if (value is int && value >= 0) return value;
  throw FormatException('$field must be a non-negative integer.');
}

String _requiredText(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$field is required.');
}

bool _requiredBool(Object? value, String field) {
  if (value is bool) return value;
  throw FormatException('$field must be a boolean.');
}
