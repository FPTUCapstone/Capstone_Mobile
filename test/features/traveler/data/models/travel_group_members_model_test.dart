import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_group_members_model.dart';

void main() {
  test('maps permitted UC19 fields without fabricating private data', () {
    final result = TravelGroupMembersModel.fromJson({
      'groupId': 42,
      'groupName': 'Da Nang Weekend',
      'itineraryId': 10,
      'memberCount': 1,
      'members': [
        {
          'memberId': 101,
          'displayName': 'Khanh Phan',
          'avatarUrl': null,
          'isHost': true,
          'joinedAtUtc': '2026-09-21T09:00:00Z',
          'locationSharingEnabled': false,
        },
      ],
    }).toEntity();

    expect(result.groupId, 42);
    expect(result.members.single.isHost, isTrue);
    expect(result.members.single.avatarUrl, isNull);
    expect(result.members.single.joinedAtUtc.isUtc, isTrue);
  });

  test('rejects a response with an inconsistent member count', () {
    expect(
      () => TravelGroupMembersModel.fromJson({
        'groupId': 42,
        'groupName': 'Da Nang Weekend',
        'itineraryId': 10,
        'memberCount': 2,
        'members': const [],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
