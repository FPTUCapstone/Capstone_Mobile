import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';

void main() {
  group('TravelGroupMember.determineSuccessor (BR-49)', () {
    final t1 = DateTime.utc(2026, 9, 21, 8, 0, 0);
    final t2 = DateTime.utc(2026, 9, 21, 9, 0, 0);
    final t3 = DateTime.utc(2026, 9, 21, 10, 0, 0);

    final hostMember = TravelGroupMember(
      memberId: 101,
      displayName: 'Host Alice',
      isHost: true,
      joinedAtUtc: t1,
      locationSharingEnabled: false,
    );

    final memberBob = TravelGroupMember(
      memberId: 102,
      displayName: 'Bob Earliest',
      isHost: false,
      joinedAtUtc: t2,
      locationSharingEnabled: false,
    );

    final memberCharlie = TravelGroupMember(
      memberId: 103,
      displayName: 'Charlie Later',
      isHost: false,
      joinedAtUtc: t3,
      locationSharingEnabled: false,
    );

    test('returns null for empty members list', () {
      expect(TravelGroupMember.determineSuccessor([]), isNull);
      expect(TravelGroupMember.hasAmbiguousSuccessorTie([]), isFalse);
    });

    test('returns null if host is the only member in the group', () {
      expect(
        TravelGroupMember.determineSuccessor([hostMember], currentHostId: 101),
        isNull,
      );
      expect(
        TravelGroupMember.hasAmbiguousSuccessorTie([
          hostMember,
        ], currentHostId: 101),
        isFalse,
      );
    });

    test('selects unique member with earliest joinedAtUtc', () {
      final successor = TravelGroupMember.determineSuccessor([
        memberCharlie,
        hostMember,
        memberBob,
      ], currentHostId: 101);

      expect(successor, isNotNull);
      expect(successor!.memberId, equals(102));
      expect(successor.displayName, equals('Bob Earliest'));
      expect(
        TravelGroupMember.hasAmbiguousSuccessorTie([
          memberCharlie,
          hostMember,
          memberBob,
        ], currentHostId: 101),
        isFalse,
      );
    });

    test(
      'fails closed (returns null, reports ambiguous tie) when multiple members share identical earliest joinedAtUtc',
      () {
        final memberDan = TravelGroupMember(
          memberId: 105,
          displayName: 'Dan Tie Member',
          isHost: false,
          joinedAtUtc: t2, // identical to memberBob's t2
          locationSharingEnabled: false,
        );

        final membersWithTie = [
          memberCharlie,
          memberDan,
          memberBob,
          hostMember,
        ];

        // Fail closed for authoritative successor preview: do not arbitrarily pick one by memberId
        final successor = TravelGroupMember.determineSuccessor(
          membersWithTie,
          currentHostId: 101,
        );
        expect(successor, isNull);

        // Explicit ambiguous tie detection
        expect(
          TravelGroupMember.hasAmbiguousSuccessorTie(
            membersWithTie,
            currentHostId: 101,
          ),
          isTrue,
        );
      },
    );

    test(
      'ignores current host even if currentHostId is omitted, based on isHost flag',
      () {
        final successor = TravelGroupMember.determineSuccessor([
          hostMember,
          memberCharlie,
        ]);

        expect(successor, isNotNull);
        expect(successor!.memberId, equals(103));
      },
    );

    test(
      'ignores currentHostId even if member isHost flag is false in inconsistent data',
      () {
        final inconsistentHost = TravelGroupMember(
          memberId: 101,
          displayName: 'Host Marked Member',
          isHost: false,
          joinedAtUtc: t1,
          locationSharingEnabled: false,
        );

        final successor = TravelGroupMember.determineSuccessor([
          inconsistentHost,
          memberCharlie,
        ], currentHostId: 101);

        expect(successor, isNotNull);
        expect(successor!.memberId, equals(103));
      },
    );
  });
}
