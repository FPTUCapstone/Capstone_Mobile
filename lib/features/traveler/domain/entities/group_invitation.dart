import 'package:equatable/equatable.dart';

/// [UC-18] Immutable domain entity representing a group invitation code and QR deep link.
final class GroupInvitation extends Equatable {
  const GroupInvitation({
    required this.groupId,
    required this.groupName,
    required this.inviteCode,
    required this.qrData,
    required this.expiresAt,
  });

  final int groupId;
  final String groupName;
  final String inviteCode;
  final String qrData;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [
    groupId,
    groupName,
    inviteCode,
    qrData,
    expiresAt,
  ];
}
