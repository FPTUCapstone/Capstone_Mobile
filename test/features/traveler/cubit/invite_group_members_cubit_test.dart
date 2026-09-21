import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_state.dart';

// -- Fakes ------------------------------------------------------------------

abstract class _TravelGroupRepositoryFake implements TravelGroupRepository {
  const _TravelGroupRepositoryFake();

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async => throw UnimplementedError();
}

final class _SuccessRepository extends _TravelGroupRepositoryFake {
  const _SuccessRepository(this._invitation);
  final GroupInvitation _invitation;

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => const TravelGroup(id: 1, name: 'Group');

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => _invitation;

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => _invitation;
}

final class _FailureRepository extends _TravelGroupRepositoryFake {
  const _FailureRepository();

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => throw Exception('server error');

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => throw Exception('server error');

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => throw Exception('server error');
}

final class _AuthenticationFailureRepository
    extends _TravelGroupRepositoryFake {
  const _AuthenticationFailureRepository();

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => throw const AuthenticationFailure();

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => throw const AuthenticationFailure();
}

final class _PermissionFailureRepository extends _TravelGroupRepositoryFake {
  const _PermissionFailureRepository();

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => throw const PermissionFailure();

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => throw const PermissionFailure();
}

final class _RegenerateRepository extends _TravelGroupRepositoryFake {
  _RegenerateRepository({required this.initial, required this.replacement});

  final GroupInvitation initial;
  final GroupInvitation replacement;
  final List<String> idempotencyKeys = [];

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => const TravelGroup(id: 1, name: 'Group');

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    return initial;
  }

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    return replacement;
  }
}

final class _UncertainRegenerationRepository
    extends _TravelGroupRepositoryFake {
  _UncertainRegenerationRepository({
    required this.initial,
    required this.replacement,
    this.replayFailure,
  });

  final GroupInvitation initial;
  final GroupInvitation replacement;
  final Failure? replayFailure;
  final List<String> regenerationKeys = [];
  bool replacementCommitted = false;

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => initial;

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async {
    regenerationKeys.add(idempotencyKey);
    if (!replacementCommitted) {
      replacementCommitted = true;
      throw const NetworkFailure();
    }
    if (replayFailure case final failure?) throw failure;
    return replacement;
  }
}

final class _DefinitiveRegenerationFailureRepository
    extends _TravelGroupRepositoryFake {
  _DefinitiveRegenerationFailureRepository(this.initial, this.failure);

  final GroupInvitation initial;
  final Failure failure;
  final List<String> regenerationKeys = [];

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async => initial;

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async {
    regenerationKeys.add(idempotencyKey);
    throw failure;
  }
}

final class _DelayedInvitationRepository extends _TravelGroupRepositoryFake {
  _DelayedInvitationRepository(this.initial);

  final GroupInvitation initial;
  final loadCompleter = Completer<GroupInvitation>();
  final regenerationCompleter = Completer<GroupInvitation>();
  int loadCalls = 0;
  int regenerationCalls = 0;

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) {
    loadCalls++;
    return loadCompleter.future;
  }

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) {
    regenerationCalls++;
    return regenerationCompleter.future;
  }
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
  final replacementInvitation = GroupInvitation(
    groupId: 1,
    groupName: 'Da Nang Summer Trip',
    inviteCode: 'NEWCODE1',
    qrData: 'tripmate://groups/join?code=NEWCODE1',
    expiresAt: DateTime(2026, 11, 8, 10, 30),
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

    test(
      'uses different UUIDv4 keys for separate load and regenerate operations',
      () async {
        final repository = _RegenerateRepository(
          initial: testInvitation,
          replacement: GroupInvitation(
            groupId: 1,
            groupName: 'Da Nang Summer Trip',
            inviteCode: 'NEWCODE1',
            qrData: 'tripmate://groups/join?code=NEWCODE1',
            expiresAt: DateTime(2026, 11, 8, 10, 30),
          ),
        );
        final cubit = InviteGroupMembersCubit(repository: repository);

        await cubit.loadInvitation(1);
        await cubit.regenerateInvitation(1);

        expect(repository.idempotencyKeys, hasLength(2));
        expect(
          repository.idempotencyKeys[0],
          isNot(repository.idempotencyKeys[1]),
        );
        for (final key in repository.idempotencyKeys) {
          expect(
            key,
            matches(
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
                caseSensitive: false,
              ),
            ),
          );
        }
        await cubit.close();
      },
    );

    blocTest<InviteGroupMembersCubit, InviteGroupMembersState>(
      'emits [regenerating, success] and uses a new idempotency key for regenerate',
      build: () {
        return InviteGroupMembersCubit(
          repository: _RegenerateRepository(
            initial: testInvitation,
            replacement: GroupInvitation(
              groupId: 1,
              groupName: 'Da Nang Summer Trip',
              inviteCode: 'NEWCODE1',
              qrData: 'tripmate://groups/join?code=NEWCODE1',
              expiresAt: DateTime(2026, 11, 8, 10, 30),
            ),
          ),
        );
      },
      seed: () => InviteGroupMembersState.success(testInvitation),
      act: (cubit) => cubit.regenerateInvitation(1),
      expect: () => [
        InviteGroupMembersState.regenerating(testInvitation),
        isA<InviteGroupMembersState>()
            .having(
              (state) => state.status,
              'status',
              InviteGroupMembersStatus.success,
            )
            .having(
              (state) => state.invitation?.inviteCode,
              'invite code',
              'NEWCODE1',
            ),
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

    test(
      'uncertain regeneration hides the old code and retries with one key',
      () async {
        final repository = _UncertainRegenerationRepository(
          initial: testInvitation,
          replacement: replacementInvitation,
        );
        final cubit = InviteGroupMembersCubit(repository: repository);
        addTearDown(cubit.close);
        final emitted = <InviteGroupMembersState>[];
        final subscription = cubit.stream.listen(emitted.add);
        addTearDown(subscription.cancel);

        await cubit.loadInvitation(1);
        await cubit.regenerateInvitation(1);

        expect(repository.replacementCommitted, isTrue);
        expect(
          cubit.state.status,
          InviteGroupMembersStatus.regenerationUncertain,
        );
        expect(cubit.state.invitation, isNull);
        expect(cubit.state.errorMessage, contains('Retry'));

        await cubit.regenerateInvitation(1);
        await Future<void>.delayed(Duration.zero);

        expect(repository.regenerationKeys, hasLength(2));
        expect(repository.regenerationKeys[1], repository.regenerationKeys[0]);
        expect(
          emitted.map((state) => state.status),
          containsAllInOrder([
            InviteGroupMembersStatus.regenerationUncertain,
            InviteGroupMembersStatus.regenerating,
            InviteGroupMembersStatus.success,
          ]),
        );
        expect(
          emitted.where(
            (state) =>
                state.status == InviteGroupMembersStatus.regenerating &&
                state.invitation == null,
          ),
          isNotEmpty,
        );
        expect(cubit.state.invitation, replacementInvitation);
      },
    );

    test('validation rejection preserves the current invitation', () async {
      final repository = _DefinitiveRegenerationFailureRepository(
        testInvitation,
        const ValidationFailure('Request rejected.'),
      );
      final cubit = InviteGroupMembersCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.loadInvitation(1);
      await cubit.regenerateInvitation(1);

      expect(cubit.state.status, InviteGroupMembersStatus.failure);
      expect(cubit.state.invitation, testInvitation);
      expect(cubit.state.errorMessage, contains('temporarily unable'));
    });

    test('definitive retry failure exits uncertain regeneration', () async {
      final repository = _UncertainRegenerationRepository(
        initial: testInvitation,
        replacement: replacementInvitation,
        replayFailure: const PermissionFailure(),
      );
      final cubit = InviteGroupMembersCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.loadInvitation(1);
      await cubit.regenerateInvitation(1);
      await cubit.regenerateInvitation(1);

      expect(repository.regenerationKeys, hasLength(2));
      expect(repository.regenerationKeys[1], repository.regenerationKeys[0]);
      expect(cubit.state.status, InviteGroupMembersStatus.failure);
      expect(cubit.state.invitation, isNull);
      expect(cubit.state.errorMessage, contains('permission'));

      await cubit.regenerateInvitation(1);
      expect(repository.regenerationKeys, hasLength(2));
    });

    test('permission rejection removes Host-only invitation actions', () async {
      final repository = _DefinitiveRegenerationFailureRepository(
        testInvitation,
        const PermissionFailure(),
      );
      final cubit = InviteGroupMembersCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.loadInvitation(1);
      await cubit.regenerateInvitation(1);

      expect(cubit.state.status, InviteGroupMembersStatus.failure);
      expect(cubit.state.invitation, isNull);
      expect(cubit.state.errorMessage, contains('permission'));
    });

    test('late initial load completion does not emit after close', () async {
      final repository = _DelayedInvitationRepository(testInvitation);
      final cubit = InviteGroupMembersCubit(repository: repository);
      final emitted = <InviteGroupMembersState>[];
      final subscription = cubit.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      final load = cubit.loadInvitation(1);
      expect(cubit.state.status, InviteGroupMembersStatus.loading);
      await cubit.close();
      repository.loadCompleter.complete(testInvitation);
      await load;

      expect(cubit.state.status, InviteGroupMembersStatus.loading);
      expect(emitted, [const InviteGroupMembersState.loading()]);
    });

    test('late regeneration completion does not emit after close', () async {
      final repository = _DelayedInvitationRepository(testInvitation);
      final cubit = InviteGroupMembersCubit(repository: repository);
      repository.loadCompleter.complete(testInvitation);
      await cubit.loadInvitation(1);
      final emitted = <InviteGroupMembersState>[];
      final subscription = cubit.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      final regeneration = cubit.regenerateInvitation(1);
      expect(cubit.state.status, InviteGroupMembersStatus.regenerating);
      await cubit.close();
      repository.regenerationCompleter.complete(replacementInvitation);
      await regeneration;

      expect(cubit.state.status, InviteGroupMembersStatus.regenerating);
      expect(emitted, [InviteGroupMembersState.regenerating(testInvitation)]);
    });

    test(
      'duplicate and overlapping requests issue only one operation',
      () async {
        final repository = _DelayedInvitationRepository(testInvitation);
        final cubit = InviteGroupMembersCubit(repository: repository);
        addTearDown(cubit.close);

        final load = cubit.loadInvitation(1);
        await cubit.loadInvitation(1);
        expect(repository.loadCalls, 1);
        repository.loadCompleter.complete(testInvitation);
        await load;

        final regeneration = cubit.regenerateInvitation(1);
        await cubit.regenerateInvitation(1);
        await cubit.loadInvitation(1);
        expect(repository.regenerationCalls, 1);
        expect(repository.loadCalls, 1);
        repository.regenerationCompleter.complete(replacementInvitation);
        await regeneration;
        expect(cubit.state.invitation, replacementInvitation);
      },
    );
  });
}
