import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';

final class AuthSession extends Equatable {
  const AuthSession({
    required this.userId,
    required this.status,
    required this.accessToken,
    required this.refreshToken,
    this.role,
    this.applicationStatus = TourOperatorApplicationStatus.unresolved,
    this.email,
    this.fullName,
    this.accessTokenExpiresAtUtc,
  });

  final int userId;
  final String status;
  final String? role;
  final TourOperatorApplicationStatus applicationStatus;
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
    applicationStatus,
    accessToken,
    refreshToken,
    email,
    fullName,
    accessTokenExpiresAtUtc,
  ];
}
