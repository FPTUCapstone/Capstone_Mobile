import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/group_invitation_model.dart';

void main() {
  group('GroupInvitationModel.fromJson', () {
    test('maps the UC18 API contract exactly', () {
      final model = GroupInvitationModel.fromJson({
        'groupId': 42,
        'groupName': 'Da Nang Summer 2026',
        'inviteCode': 'TM7X9K2A',
        'qrData': 'tripmate://groups/join?code=TM7X9K2A',
        'expiresAt': '2026-10-08T10:30:00Z',
      });

      expect(model.groupId, 42);
      expect(model.groupName, 'Da Nang Summer 2026');
      expect(model.inviteCode, 'TM7X9K2A');
      expect(model.qrData, 'tripmate://groups/join?code=TM7X9K2A');
      expect(model.expiresAt, DateTime.utc(2026, 10, 8, 10, 30));
    });

    test(
      'rejects an incomplete API response instead of fabricating values',
      () {
        expect(
          () => GroupInvitationModel.fromJson({
            'groupId': 42,
            'groupName': 'Da Nang Summer 2026',
          }),
          throwsFormatException,
        );
      },
    );

    test('rejects a whitespace-only group name', () {
      expect(
        () => GroupInvitationModel.fromJson({
          'groupId': 42,
          'groupName': '   ',
          'inviteCode': 'TM7X9K2A',
          'qrData': 'tripmate://groups/join?code=TM7X9K2A',
          'expiresAt': '2026-10-08T10:30:00Z',
        }),
        throwsFormatException,
      );
    });

    Map<String, dynamic> validResponse() => {
      'groupId': 42,
      'groupName': 'Da Nang Summer 2026',
      'inviteCode': 'TM7X9K2A',
      'qrData': 'tripmate://groups/join?code=TM7X9K2A',
      'expiresAt': '2026-10-08T10:30:00Z',
    };

    test('rejects blank and non-backend invitation codes', () {
      for (final code in ['   ', 'TM7X9K2', 'TM7X9K2I', 'tm7x9k2a']) {
        expect(
          () => GroupInvitationModel.fromJson({
            ...validResponse(),
            'inviteCode': code,
            'qrData': 'tripmate://groups/join?code=$code',
          }),
          throwsFormatException,
          reason: 'Invalid code: $code',
        );
      }
    });

    test('rejects a blank, mismatched, or altered QR payload', () {
      for (final qrData in [
        '   ',
        'tripmate://groups/join?code=TM7X9K2B',
        'https://groups/join?code=TM7X9K2A',
        'tripmate://groups/join?code=TM7X9K2A&extra=1',
      ]) {
        expect(
          () => GroupInvitationModel.fromJson({
            ...validResponse(),
            'qrData': qrData,
          }),
          throwsFormatException,
          reason: 'Invalid QR payload: $qrData',
        );
      }
    });

    test('requires an explicit UTC expiry timestamp', () {
      for (final expiresAt in [
        '2026-10-08T10:30:00',
        '2026-10-08T17:30:00+07:00',
        'not-a-date',
      ]) {
        expect(
          () => GroupInvitationModel.fromJson({
            ...validResponse(),
            'expiresAt': expiresAt,
          }),
          throwsFormatException,
          reason: 'Invalid expiry: $expiresAt',
        );
      }
    });

    test('accepts the backend zero-offset timestamp representation', () {
      final model = GroupInvitationModel.fromJson({
        ...validResponse(),
        'expiresAt': '2026-10-08T10:30:00.1234567+00:00',
      });

      expect(model.expiresAt.isUtc, isTrue);
      expect(model.expiresAt, DateTime.utc(2026, 10, 8, 10, 30, 0, 123, 456));
    });

    test('trims valid textual fields before storing them', () {
      final model = GroupInvitationModel.fromJson({
        ...validResponse(),
        'groupName': '  Da Nang Summer 2026  ',
        'inviteCode': '  TM7X9K2A  ',
        'qrData': '  tripmate://groups/join?code=TM7X9K2A  ',
      });

      expect(model.groupName, 'Da Nang Summer 2026');
      expect(model.inviteCode, 'TM7X9K2A');
      expect(model.qrData, 'tripmate://groups/join?code=TM7X9K2A');
    });

    test('rejects a non-positive group ID', () {
      expect(
        () => GroupInvitationModel.fromJson({...validResponse(), 'groupId': 0}),
        throwsFormatException,
      );
    });
  });
}
