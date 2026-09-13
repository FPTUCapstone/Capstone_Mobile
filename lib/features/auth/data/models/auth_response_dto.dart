import 'package:equatable/equatable.dart';

final class AuthResponseDto extends Equatable {
  const AuthResponseDto({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAtUtc,
  });

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    final userId = json['userId'];
    final email = json['email'];
    final fullName = json['fullName'];
    final role = json['role'];
    final status = json['status'];
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresAt = json['accessTokenExpiresAtUtc'];

    if (userId is! int ||
        email is! String ||
        fullName is! String ||
        role is! String ||
        status is! String ||
        accessToken is! String ||
        refreshToken is! String ||
        expiresAt is! String ||
        accessToken.isEmpty ||
        refreshToken.isEmpty) {
      throw const FormatException('Invalid authenticated response.');
    }

    return AuthResponseDto(
      userId: userId,
      email: email,
      fullName: fullName,
      role: role,
      status: status,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAtUtc: expiresAt,
    );
  }

  final int userId;
  final String email;
  final String fullName;
  final String role;
  final String status;
  final String accessToken;
  final String refreshToken;
  final String accessTokenExpiresAtUtc;

  @override
  List<Object?> get props => [
    userId,
    email,
    fullName,
    role,
    status,
    accessToken,
    refreshToken,
    accessTokenExpiresAtUtc,
  ];
}
