import 'package:equatable/equatable.dart';

final class SessionResponseDto extends Equatable {
  const SessionResponseDto({
    required this.userId,
    required this.status,
    required this.accessToken,
    required this.refreshToken,
    this.role,
    this.email,
    this.fullName,
    this.accessTokenExpiresAtUtc,
  });

  factory SessionResponseDto.fromJson(Map<String, dynamic> json) {
    final userId = json['userId'];
    final status = _accountStatusName(json['status']);
    final role = _userRoleName(json['role']);
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];

    if (userId is! int ||
        status == null ||
        accessToken is! String ||
        refreshToken is! String ||
        accessToken.isEmpty ||
        refreshToken.isEmpty) {
      throw const FormatException('Invalid authenticated response.');
    }

    return SessionResponseDto(
      userId: userId,
      status: status,
      role: role,
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: json['email'] as String?,
      fullName: json['fullName'] as String?,
      accessTokenExpiresAtUtc: json['accessTokenExpiresAtUtc'] as String?,
    );
  }

  final int userId;
  final String status;
  final String? role;
  final String accessToken;
  final String refreshToken;
  final String? email;
  final String? fullName;
  final String? accessTokenExpiresAtUtc;

  @override
  List<Object?> get props => [
    userId,
    status,
    role,
    accessToken,
    refreshToken,
    email,
    fullName,
    accessTokenExpiresAtUtc,
  ];
}

String? _userRoleName(Object? value) => switch (value) {
  'Traveler' || 1 => 'Traveler',
  'TourOperator' || 2 => 'TourOperator',
  'Administrator' || 3 => 'Administrator',
  null => null,
  _ => null,
};

String? _accountStatusName(Object? value) => switch (value) {
  'PendingEmailVerification' || 1 => 'PendingEmailVerification',
  'Active' || 2 => 'Active',
  'Locked' || 3 => 'Locked',
  'PendingApproval' || 4 => 'PendingApproval',
  'Rejected' || 5 => 'Rejected',
  'Inactive' || 6 => 'Inactive',
  _ => null,
};
