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

    final parsedExpiresAt = _parseUtcTimestamp(expiresAt);
    final normalizedGroupName = groupName.trim();
    final normalizedInviteCode = inviteCode.trim();
    final normalizedQrData = qrData.trim();
    if (groupId <= 0 ||
        normalizedGroupName.isEmpty ||
        !_inviteCodePattern.hasMatch(normalizedInviteCode) ||
        normalizedQrData !=
            'tripmate://groups/join?code=$normalizedInviteCode' ||
        parsedExpiresAt == null) {
      throw const FormatException('Invalid group invitation response.');
    }

    return GroupInvitationModel(
      groupId: groupId,
      groupName: normalizedGroupName,
      inviteCode: normalizedInviteCode,
      qrData: normalizedQrData,
      expiresAt: parsedExpiresAt,
    );
  }

  static final _inviteCodePattern = RegExp(
    r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$',
  );
  static final _utcTimestampPattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
    r'(?:\.\d{1,7})?(?:Z|\+00:00)$',
  );

  static DateTime? _parseUtcTimestamp(String value) {
    final match = _utcTimestampPattern.firstMatch(value);
    final parsed = DateTime.tryParse(value);
    if (match == null || parsed == null || !parsed.isUtc) return null;

    final components = [
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    ];
    for (var index = 0; index < components.length; index++) {
      if (components[index] != int.parse(match.group(index + 1)!)) return null;
    }
    return parsed;
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
