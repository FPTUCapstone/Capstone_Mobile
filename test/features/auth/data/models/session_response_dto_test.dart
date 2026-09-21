import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';

Map<String, dynamic> _base([Map<String, dynamic> override = const {}]) => {
  'userId': 7,
  'email': 'user@example.com',
  'fullName': 'User',
  'role': 'Traveler',
  'status': 'Active',
  'accessToken': 'access-token',
  'refreshToken': 'refresh-token',
  'accessTokenExpiresAtUtc': '2026-09-15T10:00:00Z',
  ...override,
};

void main() {
  group('SessionResponseDto A1/A2 identity parsing', () {
    test('parses recognized applicationStatus values', () {
      for (final value in ['Approved', 'PendingApproval', 'Rejected']) {
        final dto = SessionResponseDto.fromJson(
          _base({'role': 'TourOperator', 'applicationStatus': value}),
        );
        expect(dto.role, 'TourOperator');
        expect(dto.applicationStatus, value);
      }
    });

    test('null applicationStatus parses to null (Traveler / unresolved)', () {
      final dto = SessionResponseDto.fromJson(
        _base({'applicationStatus': null}),
      );
      expect(dto.applicationStatus, isNull);
    });

    test('missing applicationStatus key parses to null', () {
      final dto = SessionResponseDto.fromJson(_base());
      expect(dto.applicationStatus, isNull);
    });

    test('preserves an unrecognized applicationStatus for Data mapping', () {
      final dto = SessionResponseDto.fromJson(
        _base({'role': 'TourOperator', 'applicationStatus': 'Bogus'}),
      );
      expect(dto.role, 'TourOperator');
      expect(dto.applicationStatus, 'Bogus');
    });

    test('Administrator parses as a known role, not malformed', () {
      final dto = SessionResponseDto.fromJson(_base({'role': 'Administrator'}));
      expect(dto.role, 'Administrator');
    });

    test('unknown or missing role fails at the response boundary', () {
      expect(
        () => SessionResponseDto.fromJson(_base({'role': 'Robot'})),
        throwsFormatException,
      );
      expect(
        () => SessionResponseDto.fromJson(_base({'role': null})),
        throwsFormatException,
      );
    });

    test('legacy numeric role/status still map', () {
      final dto = SessionResponseDto.fromJson(
        _base({'role': 2, 'status': 2, 'applicationStatus': 'Approved'}),
      );
      expect(dto.role, 'TourOperator');
      expect(dto.status, 'Active');
      expect(dto.applicationStatus, 'Approved');
    });

    test('missing tokens are a format failure', () {
      expect(
        () => SessionResponseDto.fromJson(_base({'accessToken': ''})),
        throwsFormatException,
      );
    });
  });
}
