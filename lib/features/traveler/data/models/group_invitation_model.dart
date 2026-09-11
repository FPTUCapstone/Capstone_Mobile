import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';

/// [UC-18] JSON DTO for group invitation API response.
final class GroupInvitationModel {
  const GroupInvitationModel({
    required this.groupId,
    required this.groupName,
    required this.inviteCode,
    required this.qrData,
    required this.expiresAt,
  });

  factory GroupInvitationModel.fromJson(Map<String, dynamic> json) {
    final groupId = json['groupId'];
    final groupName = json['groupName'];
    final inviteCode = json['inviteCode'];
    final qrData = json['qrData'];
    final expiresAt = json['expiresAt'];

    if (groupId is! int ||
        groupName is! String ||
        inviteCode is! String ||
        qrData is! String ||
        expiresAt is! String) {
      throw const FormatException('Invalid group invitation response.');
    }

    final parsedExpiresAt = DateTime.tryParse(expiresAt);
    if (groupId <= 0 ||
        groupName.isEmpty ||
        inviteCode.isEmpty ||
        qrData.isEmpty ||
        parsedExpiresAt == null) {
      throw const FormatException('Invalid group invitation response.');
    }

    return GroupInvitationModel(
      groupId: groupId,
      groupName: groupName,
      inviteCode: inviteCode,
      qrData: qrData,
      expiresAt: parsedExpiresAt,
    );
  }

  final int groupId;
  final String groupName;
  final String inviteCode;
  final String qrData;
  final DateTime expiresAt;

  GroupInvitation toEntity() => GroupInvitation(
    groupId: groupId,
    groupName: groupName,
    inviteCode: inviteCode,
    qrData: qrData,
    expiresAt: expiresAt,
  );
}
