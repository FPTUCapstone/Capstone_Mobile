import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';

extension AuthCredentialsMapper on AuthCredentials {
  LoginRequest toDto() => LoginRequest(email: email, password: password);
}

extension TravelerRegistrationMapper on TravelerRegistration {
  RegisterTravelerRequest toDto() => RegisterTravelerRequest(
    fullName: fullName,
    email: email,
    password: password,
    acceptedTerms: acceptedTerms,
    phoneNumber: phoneNumber,
  );
}

extension RegisterTravelerResponseMapper on RegisterTravelerResponse {
  TravelerRegistrationResult toDomain() => TravelerRegistrationResult(
    userId: userId,
    email: email,
    fullName: fullName,
    role: role,
    status: status,
    emailSent: emailSent,
    messageCode: messageCode,
  );
}

extension SessionResponseMapper on SessionResponseDto {
  AuthSession toDomain() => AuthSession(
    userId: userId,
    status: status,
    role: role,
    applicationStatus: _mapApplicationStatus(applicationStatus),
    accessToken: accessToken,
    refreshToken: refreshToken,
    email: email,
    fullName: fullName,
    accessTokenExpiresAtUtc: accessTokenExpiresAtUtc,
  );
}

TourOperatorApplicationStatus _mapApplicationStatus(String? value) =>
    switch (value) {
      'Approved' => TourOperatorApplicationStatus.approved,
      'PendingApproval' => TourOperatorApplicationStatus.pendingApproval,
      'Rejected' => TourOperatorApplicationStatus.rejected,
      _ => TourOperatorApplicationStatus.unresolved,
    };
