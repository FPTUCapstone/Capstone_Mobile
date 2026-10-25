import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/leave_travel_group_result.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/leave_travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/leave_travel_group_dialog.dart';

void main() {
  final members = [
    TravelGroupMember(
      memberId: 101,
      displayName: 'Host',
      isHost: true,
      joinedAtUtc: DateTime.utc(2026, 10, 1),
      locationSharingEnabled: false,
    ),
    TravelGroupMember(
      memberId: 102,
      displayName: 'Next Host',
      isHost: false,
      joinedAtUtc: DateTime.utc(2026, 10, 2),
      locationSharingEnabled: false,
    ),
  ];

  testWidgets('confirmed leave returns server result and never edits tickets', (
    tester,
  ) async {
    final repository = _LeaveRepository();
    LeaveTravelGroupResult? outcome;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                outcome = await showDialog<LeaveTravelGroupResult>(
                  context: context,
                  builder: (_) => LeaveTravelGroupDialog(
                    groupId: 42,
                    groupName: 'Trip',
                    currentUserId: 101,
                    members: members,
                    leaveRepository: repository,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tickets'), findsWidgets);
    await tester.tap(
      find.byKey(const Key('transfer_and_leave_confirm_button')),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(outcome?.newHostUserId, 102);
    expect(outcome?.membershipStatus, 'Left');
  });

  testWidgets('network uncertainty stays in dialog and retry keeps key', (
    tester,
  ) async {
    final repository = _LeaveRepository()..failure = const NetworkFailure();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<LeaveTravelGroupResult>(
                context: context,
                builder: (_) => LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Trip',
                  currentUserId: 102,
                  members: members,
                  leaveRepository: repository,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave_group_confirm_button')));
    await tester.pumpAndSettle();
    expect(find.byType(LeaveTravelGroupDialog), findsOneWidget);
    expect(find.textContaining('could not confirm'), findsOneWidget);
    final firstKey = repository.keys.single;

    repository.failure = null;
    await tester.tap(find.byKey(const Key('leave_group_confirm_button')));
    await tester.pumpAndSettle();
    expect(repository.keys, [firstKey, firstKey]);
    expect(find.byType(LeaveTravelGroupDialog), findsNothing);
  });

  testWidgets('pending leave cannot be cancelled or submitted twice', (
    tester,
  ) async {
    final repository = _LeaveRepository()..pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<LeaveTravelGroupResult>(
                context: context,
                builder: (_) => LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Trip',
                  currentUserId: 102,
                  members: members,
                  leaveRepository: repository,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave_group_confirm_button')));
    await tester.pump();

    expect(repository.calls, 1);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const Key('leave_group_cancel_button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('leave_group_confirm_button')),
          )
          .onPressed,
      isNull,
    );
    repository.pending!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('conflict reloads member preview without claiming success', (
    tester,
  ) async {
    final leaveRepository = _LeaveRepository()
      ..failure = const ConflictFailure();
    final membersRepository = _MembersRepository(members);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<LeaveTravelGroupResult>(
                context: context,
                builder: (_) => LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Trip',
                  currentUserId: 101,
                  members: members,
                  repository: membersRepository,
                  leaveRepository: leaveRepository,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('transfer_and_leave_confirm_button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LeaveTravelGroupDialog), findsOneWidget);
    expect(membersRepository.calls, 1);
    expect(find.textContaining('membership has changed'), findsOneWidget);
  });

  testWidgets('stale leave exits dialog when membership access is gone', (
    tester,
  ) async {
    final leaveRepository = _LeaveRepository()
      ..failure = const ConflictFailure();
    final membersRepository = _MembersRepository(members)
      ..failure = const PermissionFailure();
    var accessLost = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<LeaveTravelGroupResult>(
                context: context,
                builder: (_) => LeaveTravelGroupDialog(
                  groupId: 42,
                  groupName: 'Trip',
                  currentUserId: 101,
                  members: members,
                  repository: membersRepository,
                  leaveRepository: leaveRepository,
                  onAccessLost: () => accessLost = true,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('transfer_and_leave_confirm_button')),
    );
    await tester.pumpAndSettle();

    expect(accessLost, isTrue);
    expect(find.byType(LeaveTravelGroupDialog), findsNothing);
  });
}

final class _MembersRepository implements TravelGroupRepository {
  _MembersRepository(this.members);

  final List<TravelGroupMember> members;
  int calls = 0;
  Failure? failure;

  @override
  Future<TravelGroupMembers> getTravelGroupMembers({
    required int groupId,
  }) async {
    calls++;
    if (failure != null) throw failure!;
    return TravelGroupMembers(
      groupId: groupId,
      groupName: 'Trip',
      itineraryId: 7,
      members: members,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _LeaveRepository implements LeaveTravelGroupRepository {
  int calls = 0;
  final keys = <String>[];
  Failure? failure;
  Completer<void>? pending;

  @override
  Future<LeaveTravelGroupResult> leaveTravelGroup({
    required int groupId,
    required String idempotencyKey,
  }) async {
    calls++;
    keys.add(idempotencyKey);
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    return LeaveTravelGroupResult(
      groupId: groupId,
      membershipStatus: 'Left',
      groupClosed: false,
      newHostUserId: 102,
      leftAtUtc: DateTime.utc(2026, 10, 25),
    );
  }
}
