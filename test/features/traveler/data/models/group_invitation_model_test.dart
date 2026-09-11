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
  });
}
