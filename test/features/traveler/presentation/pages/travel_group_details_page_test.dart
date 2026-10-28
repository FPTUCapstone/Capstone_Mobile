import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/leave_travel_group_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/leave_travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_details_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/leave_travel_group_dialog.dart';

void main() {
  const group = TravelGroup(
    id: 42,
    name: 'Da Nang Group',
    inviteCode: 'HOIAN8KP',
    itineraryId: 10,
  );

  testWidgets(
    'successor sees current Host role from member API, not stale route data',
    (tester) async {
      final repository = _MembersRepository([
        TravelGroupMember(
          memberId: 102,
          displayName: 'Successor',
          isHost: true,
          joinedAtUtc: DateTime.utc(2026, 10, 2),
          locationSharingEnabled: false,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: TravelGroupDetailsPage(
            groupId: 42,
            currentUserId: 102,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You are the Group Host.'), findsOneWidget);
      expect(find.text('Invite Members'), findsOneWidget);
    },
  );

  testWidgets('former member is redirected away from stale group details', (
    tester,
  ) async {
    final repository = _MembersRepository([])
      ..failure = const PermissionFailure();
    final router = GoRouter(
      initialLocation: '/traveler/groups/42',
      routes: [
        GoRoute(
          path: AppRoutes.travelGroupDetails,
          builder: (_, _) => TravelGroupDetailsPage(
            groupId: 42,
            group: group,
            currentUserId: 101,
            repository: repository,
          ),
        ),
        GoRoute(
          path: AppRoutes.traveler,
          builder: (_, _) => const Scaffold(body: Text('Traveler home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Traveler home'), findsOneWidget);
    expect(find.text('Da Nang Group'), findsNothing);
  });

  testWidgets('committed leave exits group details and reports closure', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/traveler/groups/42',
      routes: [
        GoRoute(
          path: AppRoutes.travelGroupDetails,
          builder: (_, _) => TravelGroupDetailsPage(
            groupId: 42,
            group: group,
            isHost: true,
            currentUserId: 101,
            members: [
              TravelGroupMember(
                memberId: 101,
                displayName: 'Host',
                isHost: true,
                joinedAtUtc: DateTime.utc(2026, 10, 1),
                locationSharingEnabled: false,
              ),
            ],
            leaveRepository: _SuccessfulLeaveRepository(),
          ),
        ),
        GoRoute(
          path: AppRoutes.traveler,
          builder: (_, _) => const Scaffold(body: Text('Traveler home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byKey(const Key('leave_group_button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('close_group_and_leave_confirm_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Traveler home'), findsOneWidget);
    expect(find.byType(TravelGroupDetailsPage), findsNothing);
  });

  testWidgets('View members preserves details in the back stack', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/traveler/groups/42',
      routes: [
        GoRoute(
          path: AppRoutes.travelGroupDetails,
          name: AppRouteNames.travelGroupDetails,
          builder: (_, _) =>
              const TravelGroupDetailsPage(groupId: 42, group: group),
        ),
        GoRoute(
          path: AppRoutes.travelGroupMembers,
          name: AppRouteNames.travelGroupMembers,
          builder: (_, _) => const Scaffold(body: Text('Members screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('View members'));
    await tester.pumpAndSettle();

    expect(find.text('Members screen'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Da Nang Group'), findsOneWidget);
  });

  testWidgets(
    'Host sees invitation action, members action, and existing code',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TravelGroupDetailsPage(groupId: 42, group: group, isHost: true),
        ),
      );

      expect(find.text('You are the Group Host.'), findsOneWidget);
      expect(find.text('Invite code: HOIAN8KP'), findsOneWidget);
      expect(find.text('View members'), findsOneWidget);
      expect(find.text('Invite Members'), findsOneWidget);
    },
  );

  testWidgets('member never sees Host controls even with invite code', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TravelGroupDetailsPage(groupId: 42, group: group, isHost: false),
      ),
    );

    expect(find.text('You are a Group Member.'), findsOneWidget);
    expect(find.text('You are the Group Host.'), findsNothing);
    expect(find.textContaining('Invite code:'), findsNothing);
    expect(find.text('View members'), findsOneWidget);
    expect(find.text('Invite Members'), findsNothing);
  });

  testWidgets('unknown membership does not claim Host or allow invitations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TravelGroupDetailsPage(groupId: 42)),
    );

    expect(find.text('You are the Group Host.'), findsNothing);
    expect(find.text('View members'), findsOneWidget);
    expect(find.text('Invite Members'), findsNothing);
  });

  testWidgets('mismatched Host route data does not expose Host controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TravelGroupDetailsPage(groupId: 99, group: group, isHost: true),
      ),
    );

    expect(find.text('Travel Group #99'), findsOneWidget);
    expect(find.text('You are the Group Host.'), findsNothing);
    expect(find.textContaining('Invite code:'), findsNothing);
    expect(find.text('View members'), findsOneWidget);
    expect(find.text('Invite Members'), findsNothing);
  });

  testWidgets('Host opens correct group invitation and returns to details', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/group/42',
      routes: [
        GoRoute(
          path: '/group/:groupId',
          builder: (_, state) => const TravelGroupDetailsPage(
            groupId: 42,
            group: group,
            isHost: true,
          ),
        ),
        GoRoute(
          path: '/group/:groupId/invitation',
          name: AppRouteNames.inviteGroupMembers,
          builder: (_, state) => Scaffold(
            appBar: AppBar(title: const Text('Invitation')),
            body: Text('Invitation for ${state.pathParameters['groupId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Invite Members'));
    await tester.pumpAndSettle();
    expect(find.text('Invitation for 42'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Da Nang Group'), findsOneWidget);
    expect(find.text('Invite Members'), findsOneWidget);
    expect(find.text('View members'), findsOneWidget);
  });

  testWidgets(
    'Tapping Leave Group opens LeaveTravelGroupDialog for Non-Host (Case A)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TravelGroupDetailsPage(
            groupId: 42,
            group: group,
            isHost: false,
          ),
        ),
      );

      expect(find.byKey(const Key('leave_group_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('leave_group_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LeaveTravelGroupDialog), findsOneWidget);
      expect(
        find.byKey(const Key('leave_travel_group_dialog_case_a')),
        findsOneWidget,
      );
      expect(
        find.text(LeaveTravelGroupDialog.confirmationWarningMessage),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Tapping Leave Group opens LeaveTravelGroupDialog for Host with members (Case B)',
    (tester) async {
      final members = [
        TravelGroupMember(
          memberId: 101,
          displayName: 'Alice Host',
          isHost: true,
          joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
          locationSharingEnabled: false,
        ),
        TravelGroupMember(
          memberId: 102,
          displayName: 'Bob Member',
          isHost: false,
          joinedAtUtc: DateTime.utc(2026, 9, 21, 10),
          locationSharingEnabled: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: TravelGroupDetailsPage(
            groupId: 42,
            group: group,
            isHost: true,
            currentUserId: 101,
            members: members,
          ),
        ),
      );

      expect(find.byKey(const Key('leave_group_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('leave_group_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LeaveTravelGroupDialog), findsOneWidget);
      expect(
        find.byKey(const Key('leave_travel_group_dialog_case_b')),
        findsOneWidget,
      );
      expect(
        find.text(LeaveTravelGroupDialog.hostSuccessionMessage('Bob Member')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Tapping Leave Group opens LeaveTravelGroupDialog for Final Host (Case C)',
    (tester) async {
      final members = [
        TravelGroupMember(
          memberId: 101,
          displayName: 'Solo Host',
          isHost: true,
          joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
          locationSharingEnabled: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: TravelGroupDetailsPage(
            groupId: 42,
            group: group,
            isHost: true,
            currentUserId: 101,
            members: members,
          ),
        ),
      );

      expect(find.byKey(const Key('leave_group_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('leave_group_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LeaveTravelGroupDialog), findsOneWidget);
      expect(
        find.byKey(const Key('leave_travel_group_dialog_case_c')),
        findsOneWidget,
      );
      expect(
        find.text(
          'You are the final member of this travel group. Leaving will close the group for everyone.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Location Sharing button navigates to group location sharing settings',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/traveler/groups/42',
        routes: [
          GoRoute(
            path: AppRoutes.travelGroupDetails,
            name: AppRouteNames.travelGroupDetails,
            builder: (_, _) =>
                const TravelGroupDetailsPage(groupId: 42, group: group),
          ),
          GoRoute(
            path: AppRoutes.groupLocationSharing,
            name: AppRouteNames.groupLocationSharing,
            builder: (_, _) =>
                const Scaffold(body: Text('Location sharing settings')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(find.byKey(const Key('location_sharing_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('location_sharing_button')));
      await tester.pumpAndSettle();

      expect(find.text('Location sharing settings'), findsOneWidget);
      expect(router.canPop(), isTrue);
    },
  );
}

final class _SuccessfulLeaveRepository implements LeaveTravelGroupRepository {
  @override
  Future<LeaveTravelGroupResult> leaveTravelGroup({
    required int groupId,
    required String idempotencyKey,
  }) async => LeaveTravelGroupResult(
    groupId: groupId,
    membershipStatus: 'Left',
    groupClosed: true,
    newHostUserId: null,
    leftAtUtc: DateTime.utc(2026, 10, 25),
  );
}

final class _MembersRepository implements TravelGroupRepository {
  _MembersRepository(this.members);

  final List<TravelGroupMember> members;
  Failure? failure;

  @override
  Future<TravelGroupMembers> getTravelGroupMembers({
    required int groupId,
  }) async {
    if (failure != null) throw failure!;
    return TravelGroupMembers(
      groupId: groupId,
      groupName: 'Current group',
      itineraryId: 7,
      members: members,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
