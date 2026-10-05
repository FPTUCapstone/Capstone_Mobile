import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/leave_travel_group_dialog.dart';

void main() {
  final hostMember = TravelGroupMember(
    memberId: 101,
    displayName: 'Nguyen Minh Phuc',
    isHost: true,
    joinedAtUtc: DateTime.utc(2026, 9, 1, 8),
    locationSharingEnabled: true,
  );

  final olderMember = TravelGroupMember(
    memberId: 102,
    displayName: 'Minh Anh',
    isHost: false,
    joinedAtUtc: DateTime.utc(2026, 9, 2, 10),
    locationSharingEnabled: false,
  );

  final newerMember = TravelGroupMember(
    memberId: 103,
    displayName: 'Duc Long',
    isHost: false,
    joinedAtUtc: DateTime.utc(2026, 9, 3, 14),
    locationSharingEnabled: true,
  );

  group('LeaveTravelGroupDialog (UC-21 Screen #60)', () {
    testWidgets('UC21-1: Non-Host gets Case A confirmation with MSG130', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LeaveTravelGroupDialog(
              groupId: 42,
              groupName: 'Da Nang crew',
              isHost: false,
            ),
          ),
        ),
      );

      // Dialog title for non-host
      expect(find.text('Leave travel group'), findsOneWidget);

      // Locked MSG130 body
      expect(
        find.text(
          'Are you sure you want to continue? This action may not be reversible.',
        ),
        findsOneWidget,
      );

      // Capability notice
      expect(
        find.byKey(const Key('leave_group_capability_notice')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Server support pending: Leaving travel group is waiting for backend capability and cannot be completed yet.',
        ),
        findsOneWidget,
      );

      // Buttons
      expect(
        find.byKey(const Key('leave_group_cancel_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('leave_group_confirm_button')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('leave_group_confirm_button')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets(
      'UC21-2, UC21-3, UC21-4: Host with other members gets Case B with earliest Joined Timestamp successor (MSG61)',
      (tester) async {
        // Members order in list is deliberately reversed (newer before older)
        final members = [hostMember, newerMember, olderMember];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeaveTravelGroupDialog(
                groupId: 42,
                groupName: 'Da Nang crew',
                isHost: true,
                currentUserId: 101,
                members: members,
              ),
            ),
          ),
        );

        // Case B Dialog title
        expect(find.text('Transfer host privileges and leave'), findsOneWidget);

        // Successor card previews earliest joined active member (Minh Anh, joined Sept 2)
        expect(find.byKey(const Key('successor_member_card')), findsOneWidget);
        expect(find.text('Minh Anh'), findsOneWidget);
        expect(find.text('New Host'), findsOneWidget);

        // Locked MSG61 body naming successor
        expect(
          find.text(
            'You are the Group Host. Leaving will transfer Host privileges to Minh Anh. Confirm leave?',
          ),
          findsOneWidget,
        );

        // Host itself is strictly excluded from successor preview
        expect(find.text('Nguyen Minh Phuc'), findsNothing);

        // Action button
        expect(
          find.byKey(const Key('transfer_and_leave_confirm_button')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('transfer_and_leave_confirm_button')),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'UC21-5: Final Host (no other active members) gets Case C with closure warning and MSG130',
      (tester) async {
        final singleHostMembers = [hostMember];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeaveTravelGroupDialog(
                groupId: 42,
                groupName: 'Da Nang crew',
                isHost: true,
                currentUserId: 101,
                members: singleHostMembers,
              ),
            ),
          ),
        );

        // Case C Dialog title
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Close group and leave'),
          ),
          findsNWidgets(2), // Title and action button
        );
        expect(
          find.byKey(const Key('leave_travel_group_dialog_case_c')),
          findsOneWidget,
        );

        // Closure consequence explanation
        expect(
          find.text(
            'You are the final member of this travel group. Leaving will close the group for everyone.',
          ),
          findsOneWidget,
        );

        // Locked MSG130 body
        expect(
          find.text(
            'Are you sure you want to continue? This action may not be reversible.',
          ),
          findsOneWidget,
        );

        // Close action button
        expect(
          find.byKey(const Key('close_group_and_leave_confirm_button')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('close_group_and_leave_confirm_button')),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'UC21-6: Inconsistent / failed member resolution fails closed with error and cancel only',
      (tester) async {
        final failingRepo = _FailingRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeaveTravelGroupDialog(
                groupId: 42,
                groupName: 'Da Nang crew',
                isHost: true,
                currentUserId: 101,
                members: null,
                repository: failingRepo,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('leave_group_error_dialog')),
          findsOneWidget,
        );
        expect(
          find.text(
            'We could not determine group members. Leaving cannot be completed right now.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('leave_group_cancel_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('transfer_and_leave_confirm_button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'UC21-7, UC21-8, UC21-9, UC21-10: Confirm button in Case B is disabled when server support is absent',
      (tester) async {
        bool? dialogResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showDialog<bool>(
                      context: context,
                      builder: (_) => LeaveTravelGroupDialog(
                        groupId: 42,
                        groupName: 'Da Nang crew',
                        isHost: true,
                        currentUserId: 101,
                        members: [hostMember, olderMember],
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Transfer host privileges and leave'), findsOneWidget);

        // Confirm button is disabled
        final confirmButton = tester.widget<FilledButton>(
          find.byKey(const Key('transfer_and_leave_confirm_button')),
        );
        expect(confirmButton.onPressed, isNull);

        // Cancel button is active and dismisses dialog
        await tester.tap(find.byKey(const Key('leave_group_cancel_button')));
        await tester.pumpAndSettle();

        expect(dialogResult, isFalse);

        // Absolutely NO fake MSG129 success
        expect(find.text('Operation completed successfully.'), findsNothing);
      },
    );

    testWidgets(
      'When isServerSupported is true, Case B confirm button is enabled and returns true',
      (tester) async {
        bool? dialogResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showDialog<bool>(
                      context: context,
                      builder: (_) => LeaveTravelGroupDialog(
                        groupId: 42,
                        groupName: 'Da Nang crew',
                        isHost: true,
                        currentUserId: 101,
                        members: [hostMember, olderMember],
                        isServerSupported: true,
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        final confirmButton = tester.widget<FilledButton>(
          find.byKey(const Key('transfer_and_leave_confirm_button')),
        );
        expect(confirmButton.onPressed, isNotNull);

        await tester.tap(
          find.byKey(const Key('transfer_and_leave_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(dialogResult, isTrue);
      },
    );

    testWidgets(
      'UC21-Tie: Host with members having identical earliest Joined Timestamp fails closed with ambiguous successor state',
      (tester) async {
        final sameTimestamp = DateTime.utc(2026, 9, 2, 8);
        final member1 = TravelGroupMember(
          memberId: 102,
          displayName: 'Member One',
          isHost: false,
          joinedAtUtc: sameTimestamp,
          locationSharingEnabled: false,
        );
        final member2 = TravelGroupMember(
          memberId: 103,
          displayName: 'Member Two',
          isHost: false,
          joinedAtUtc: sameTimestamp,
          locationSharingEnabled: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeaveTravelGroupDialog(
                groupId: 42,
                groupName: 'Da Nang crew',
                isHost: true,
                currentUserId: 101,
                members: [hostMember, member1, member2],
              ),
            ),
          ),
        );

        // Fails closed with ambiguous dialog
        expect(
          find.byKey(const Key('leave_travel_group_dialog_ambiguous')),
          findsOneWidget,
        );
        expect(find.text('Cannot determine next host'), findsOneWidget);
        expect(
          find.text(
            'Multiple members share the earliest join timestamp. '
            'Host succession cannot be determined unambiguously without server resolution.',
          ),
          findsOneWidget,
        );

        // Cancel button available
        expect(
          find.byKey(const Key('leave_group_cancel_button')),
          findsOneWidget,
        );

        // Action buttons are NOT available
        expect(
          find.byKey(const Key('transfer_and_leave_confirm_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('leave_group_confirm_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('close_group_and_leave_confirm_button')),
          findsNothing,
        );
      },
    );

    testWidgets('Touch targets satisfy >= 48dp across all buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaveTravelGroupDialog(
              groupId: 42,
              groupName: 'Da Nang crew',
              isHost: false,
            ),
          ),
        ),
      );

      final cancelBox = tester.getRect(
        find.byKey(const Key('leave_group_cancel_button')),
      );
      expect(cancelBox.height, greaterThanOrEqualTo(48.0));

      final confirmBox = tester.getRect(
        find.byKey(const Key('leave_group_confirm_button')),
      );
      expect(confirmBox.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
      'Renders Case B without overflow on small screen with 200% text scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Da Nang crew with very long group name',
                  isHost: true,
                  currentUserId: 101,
                  members: [hostMember, olderMember],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('transfer_and_leave_confirm_button')),
          findsOneWidget,
        );
      },
    );

    group('Fail-closed Host Identity (Review Remediation Round 2)', () {
      testWidgets(
        'Test A: widget.isHost is true but currentUserId is null -> Host status is NOT granted (Case A)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Da Nang crew',
                  isHost: true,
                  currentUserId: null,
                  members: [hostMember, olderMember],
                ),
              ),
            ),
          );

          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_b')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_c')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_a')),
            findsOneWidget,
          );
          expect(find.text('Leave travel group'), findsOneWidget);
        },
      );

      testWidgets(
        'Test B: widget.isHost is true but currentUserId does not match authoritative Host -> Host status is NOT granted (Case A)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Da Nang crew',
                  isHost: true,
                  currentUserId: 999, // Mismatched user ID
                  members: [hostMember, olderMember],
                ),
              ),
            ),
          );

          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_b')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_c')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_a')),
            findsOneWidget,
          );
          expect(find.text('Leave travel group'), findsOneWidget);
        },
      );

      testWidgets(
        'Test C: currentUserId exists but zero authoritative Hosts exist in member data -> Host status is NOT granted (Case A)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Da Nang crew',
                  isHost: true,
                  currentUserId: 101,
                  members: [olderMember, newerMember], // zero hosts
                ),
              ),
            ),
          );

          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_b')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_c')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_a')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Test D: currentUserId exists but multiple authoritative Hosts exist in member data -> Host status is NOT granted (Case A)',
        (tester) async {
          final secondHostMember = TravelGroupMember(
            memberId: 104,
            displayName: 'Second Host',
            isHost: true,
            joinedAtUtc: DateTime.utc(2026, 9, 1, 9),
            locationSharingEnabled: false,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Da Nang crew',
                  isHost: true,
                  currentUserId: 101,
                  members: [hostMember, secondHostMember, olderMember],
                ),
              ),
            ),
          );

          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_b')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_c')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_a')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'Test E: widget.isHost is false but authenticated currentUserId matches the one authoritative Host -> Host is derived from authoritative data (Case B)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Da Nang crew',
                  isHost: false, // stale UI flag
                  currentUserId: 101, // matches authoritative hostMember
                  members: [hostMember, olderMember],
                ),
              ),
            ),
          );

          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_a')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_b')),
            findsOneWidget,
          );
          expect(
            find.text('Transfer host privileges and leave'),
            findsOneWidget,
          );
          expect(find.text('Minh Anh'), findsOneWidget);
        },
      );

      testWidgets(
        'Test F: exactly one Host and currentUserId matches -> Host behavior is allowed (Case B)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Da Nang crew',
                  isHost: true,
                  currentUserId: 101,
                  members: [hostMember, olderMember],
                ),
              ),
            ),
          );

          expect(
            find.byKey(const Key('leave_travel_group_dialog_case_b')),
            findsOneWidget,
          );
          expect(
            find.text('Transfer host privileges and leave'),
            findsOneWidget,
          );
        },
      );
    });
  });
}

final class _FailingRepository implements TravelGroupRepository {
  @override
  Future<TravelGroupMembers> getTravelGroupMembers({required int groupId}) =>
      Future.error(Exception('Simulated network error'));

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}
