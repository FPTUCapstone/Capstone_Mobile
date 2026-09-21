import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/data/mappers/auth_mapper.dart';
import 'package:trip_mate_mobile/features/auth/data/models/register_traveler_response.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';

void main() {
  group('AuthMapper', () {
    test('maps domain credentials to the login DTO', () {
      const credentials = AuthCredentials(
        email: 'traveler@example.com',
        password: 'secret',
      );

      final dto = credentials.toDto();

      expect(dto.email, credentials.email);
      expect(dto.password, credentials.password);
    });

    test('maps every traveler registration field to the request DTO', () {
      const registration = TravelerRegistration(
        fullName: 'Trip Mate',
        email: 'traveler@example.com',
        password: 'secret',
        acceptedTerms: true,
        phoneNumber: '0900000000',
      );

      expect(registration.toDto().toJson(), {
        'fullName': registration.fullName,
        'email': registration.email,
        'password': registration.password,
        'phoneNumber': registration.phoneNumber,
        'acceptedTerms': registration.acceptedTerms,
      });
    });

    test('maps every session DTO field to the domain session', () {
      const dto = SessionResponseDto(
        userId: 42,
        status: 'Active',
        role: 'TourOperator',
        applicationStatus: 'Approved',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        email: 'operator@example.com',
        fullName: 'Tour Operator',
        accessTokenExpiresAtUtc: '2026-09-16T10:00:00Z',
      );

      final session = dto.toDomain();

      expect(session.userId, dto.userId);
      expect(session.status, dto.status);
      expect(session.role, dto.role);
      expect(session.applicationStatus, TourOperatorApplicationStatus.approved);
      expect(session.accessToken, dto.accessToken);
      expect(session.refreshToken, dto.refreshToken);
      expect(session.email, dto.email);
      expect(session.fullName, dto.fullName);
      expect(session.accessTokenExpiresAtUtc, dto.accessTokenExpiresAtUtc);
    });

    test('maps API application status values and fails closed', () {
      for (final scenario in <(String?, TourOperatorApplicationStatus)>[
        ('Approved', TourOperatorApplicationStatus.approved),
        ('PendingApproval', TourOperatorApplicationStatus.pendingApproval),
        ('Rejected', TourOperatorApplicationStatus.rejected),
        (null, TourOperatorApplicationStatus.unresolved),
        ('Bogus', TourOperatorApplicationStatus.unresolved),
        ('', TourOperatorApplicationStatus.unresolved),
      ]) {
        expect(
          _sessionDto(scenario.$1).toDomain().applicationStatus,
          scenario.$2,
          reason: 'raw value: ${scenario.$1}',
        );
      }
    });

    test('maps every registration response field to the domain result', () {
      const dto = RegisterTravelerResponse(
        userId: 42,
        email: 'traveler@example.com',
        fullName: 'Trip Mate',
        role: 'Traveler',
        status: 'PendingEmailVerification',
        emailSent: true,
        messageCode: 'MSG_REGISTERED',
      );

      final result = dto.toDomain();

      expect(result.userId, dto.userId);
      expect(result.email, dto.email);
      expect(result.fullName, dto.fullName);
      expect(result.role, dto.role);
      expect(result.status, dto.status);
      expect(result.emailSent, dto.emailSent);
      expect(result.messageCode, dto.messageCode);
    });
  });
}

SessionResponseDto _sessionDto(String? applicationStatus) => SessionResponseDto(
  userId: 42,
  status: 'Active',
  role: 'TourOperator',
  applicationStatus: applicationStatus,
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
);
