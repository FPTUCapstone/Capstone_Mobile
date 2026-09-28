import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';

class _MembersRepository implements TravelGroupRepository {
  _MembersRepository({this.members, this.failure, this.pending});

  final TravelGroupMembers? members;
  final Failure? failure;
  final Future<TravelGroupMembers>? pending;

  @override
  Future<TravelGroupMembers> getTravelGroupMembers({
    required int groupId,
  }) async {
    if (pending != null) return pending!;
    if (failure != null) throw failure!;
    return members!;
  }

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

void main() {
  final members = TravelGroupMembers(
    groupId: 42,
    groupName: 'Da Nang Weekend',
    itineraryId: 10,
    members: [
      TravelGroupMember(
        memberId: 101,
        displayName: 'Khanh Phan',
        isHost: true,
        joinedAtUtc: DateTime.utc(2026, 9, 21, 9),
        locationSharingEnabled: false,
      ),
    ],
  );

  blocTest<TravelGroupMembersCubit, TravelGroupMembersState>(
    'emits loading then success when the member list is returned',
    build: () => TravelGroupMembersCubit(
      repository: _MembersRepository(members: members),
    ),
    act: (cubit) => cubit.load(groupId: 42),
    expect: () => [
      const TravelGroupMembersLoading(),
      TravelGroupMembersSuccess(members),
    ],
  );

  test('late response after close does not emit or throw', () async {
    final pending = Completer<TravelGroupMembers>();
    final cubit = TravelGroupMembersCubit(
      repository: _MembersRepository(pending: pending.future),
    );
    final load = cubit.load(groupId: 42);
    expect(cubit.state, const TravelGroupMembersLoading());
    await cubit.close();
    pending.complete(members);
    await load;
  });

  test('older load cannot replace a newer group result', () async {
    final first = Completer<TravelGroupMembers>();
    final second = Completer<TravelGroupMembers>();
    final cubit = TravelGroupMembersCubit(
      repository: _QueuedMembersRepository([first.future, second.future]),
    );
    addTearDown(cubit.close);

    final firstLoad = cubit.load(groupId: 42);
    final secondLoad = cubit.load(groupId: 43);
    final latest = TravelGroupMembers(
      groupId: 43,
      groupName: 'Latest group',
      itineraryId: 11,
      members: members.members,
    );
    second.complete(latest);
    await secondLoad;
    first.complete(members);
    await firstLoad;

    expect(cubit.state, TravelGroupMembersSuccess(latest));
  });

  blocTest<TravelGroupMembersCubit, TravelGroupMembersState>(
    'emits loading then permissionDenied for a 403 failure',
    build: () => TravelGroupMembersCubit(
      repository: _MembersRepository(failure: const PermissionFailure()),
    ),
    act: (cubit) => cubit.load(groupId: 42),
    expect: () => [
      const TravelGroupMembersLoading(),
      const TravelGroupMembersPermissionDenied(),
    ],
  );

  blocTest<TravelGroupMembersCubit, TravelGroupMembersState>(
    'emits loading then notFound for a 404 failure',
    build: () => TravelGroupMembersCubit(
      repository: _MembersRepository(failure: const NotFoundFailure()),
    ),
    act: (cubit) => cubit.load(groupId: 42),
    expect: () => [
      const TravelGroupMembersLoading(),
      const TravelGroupMembersNotFound(),
    ],
  );
}

final class _QueuedMembersRepository extends _MembersRepository {
  _QueuedMembersRepository(this.responses);

  final List<Future<TravelGroupMembers>> responses;
  int _next = 0;

  @override
  Future<TravelGroupMembers> getTravelGroupMembers({required int groupId}) =>
      responses[_next++];
}
