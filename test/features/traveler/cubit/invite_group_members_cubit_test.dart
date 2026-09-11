import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_state.dart';

// -- Fakes ------------------------------------------------------------------

final class _SuccessRepository implements TravelGroupRepository {
  const _SuccessRepository(this._invitation);
  final GroupInvitation _invitation;

  @override
  Future<TravelGroup> createTravelGroup(
    String name, {
    int itineraryId = 1,
  }) async => const TravelGroup(id: 1, name: 'Group', inviteCode: 'ABC12345');

  @override
  Future<GroupInvitation> getGroupInvitation(int groupId) async => _invitation;
}

final class _FailureRepository implements TravelGroupRepository {
  const _FailureRepository();

  @override
  Future<TravelGroup> createTravelGroup(
    String name, {
    int itineraryId = 1,
  }) async => throw Exception('server error');

  @override
  Future<GroupInvitation> getGroupInvitation(int groupId) async =>
      throw Exception('server error');
}

final class _AuthenticationFailureRepository implements TravelGroupRepository {
  const _AuthenticationFailureRepository();

  @override
  Future<TravelGroup> createTravelGroup(
    String name, {
    int itineraryId = 1,
  }) async => throw UnimplementedError();

  @override
  Future<GroupInvitation> getGroupInvitation(int groupId) async =>
      throw const AuthenticationFailure();
}

final class _PermissionFailureRepository implements TravelGroupRepository {
  const _PermissionFailureRepository();

  @override
  Future<TravelGroup> createTravelGroup(
    String name, {
    int itineraryId = 1,
  }) async => throw UnimplementedError();

  @override
  Future<GroupInvitation> getGroupInvitation(int groupId) async =>
      throw const PermissionFailure();
}

// --------------------------------------------------------------------------

void main() {
  final testInvitation = GroupInvitation(
    groupId: 1,
    groupName: 'Da Nang Summer Trip',
    inviteCode: 'TM7X9K2A',
    qrData: 'tripmate://groups/join?code=TM7X9K2A',
    expiresAt: DateTime(2026, 10, 8, 10, 30),
  );

  group('InviteGroupMembersCubit', () {
    test('initial state is InviteGroupMembersStatus.initial', () {
      final cubit = InviteGroupMembersCubit(
        repository: _SuccessRepository(testInvitation),
      );
      expect(cubit.state.status, InviteGroupMembersStatus.initial);
      expect(cubit.state.invitation, isNull);
      cubit.close();
    });

    blocTest<InviteGroupMembersCubit, InviteGroupMembersState>(
      'emits [loading, success] when getGroupInvitation succeeds',
      build: () => InviteGroupMembersCubit(
        repository: _SuccessRepository(testInvitation),
      ),
      act: (cubit) => cubit.loadInvitation(1),
      expect: () => [
        const InviteGroupMembersState.loading(),
        InviteGroupMembersState.success(testInvitation),
      ],
    );

    blocTest<InviteGroupMembersCubit, InviteGroupMembersState>(
      'emits [loading, failure] when getGroupInvitation throws',
      build: () =>
          InviteGroupMembersCubit(repository: const _FailureRepository()),
      act: (cubit) => cubit.loadInvitation(1),
      expect: () => [
        const InviteGroupMembersState.loading(),
        isA<InviteGroupMembersState>()
            .having((s) => s.status, 'status', InviteGroupMembersStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains(
                'TripMate is temporarily unable to process your request',
              ),
            ),
      ],
    );

    blocTest<InviteGroupMembersCubit, InviteGroupMembersState>(
      'emits MSG125 when authentication has expired',
      build: () => InviteGroupMembersCubit(
        repository: const _AuthenticationFailureRepository(),
      ),
      act: (cubit) => cubit.loadInvitation(1),
      expect: () => [
        const InviteGroupMembersState.loading(),
        isA<InviteGroupMembersState>()
            .having((s) => s.status, 'status', InviteGroupMembersStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Your session has expired. Please sign in again to continue.',
            ),
      ],
    );

    blocTest<InviteGroupMembersCubit, InviteGroupMembersState>(
      'emits MSG126 when the current traveler is not the group host',
      build: () => InviteGroupMembersCubit(
        repository: const _PermissionFailureRepository(),
      ),
      act: (cubit) => cubit.loadInvitation(1),
      expect: () => [
        const InviteGroupMembersState.loading(),
        isA<InviteGroupMembersState>()
            .having((s) => s.status, 'status', InviteGroupMembersStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'You do not have permission to access this function.',
            ),
      ],
    );
  });
}
