import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/join_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/join_travel_group_state.dart';

final class _MockTravelGroupRepository implements TravelGroupRepository {
  _MockTravelGroupRepository({this.joinResult, this.failure});

  final TravelGroup? joinResult;
  final Failure? failure;
  final List<(String code, String key)> recordedCalls = [];

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) => throw UnimplementedError();

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async {
    recordedCalls.add((invitationCode, idempotencyKey));
    if (failure != null) {
      throw failure!;
    }
    return joinResult!;
  }
}

void main() {
  const testGroup = TravelGroup(id: 42, name: 'Da Nang Trip', itineraryId: 10);

  group('JoinTravelGroupCubit', () {
    test('initial state is JoinTravelGroupStatus.initial', () {
      final repository = _MockTravelGroupRepository(joinResult: testGroup);
      final cubit = JoinTravelGroupCubit(repository: repository);
      expect(cubit.state.status, JoinTravelGroupStatus.initial);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.result, isNull);
    });

    blocTest<JoinTravelGroupCubit, JoinTravelGroupState>(
      'emits validationFailure when input is empty or whitespace',
      build: () => JoinTravelGroupCubit(
        repository: _MockTravelGroupRepository(joinResult: testGroup),
      ),
      act: (cubit) => cubit.submit('   '),
      expect: () => [
        const JoinTravelGroupState.validationFailure('This field is required.'),
      ],
    );

    blocTest<JoinTravelGroupCubit, JoinTravelGroupState>(
      'emits failure with MSG56 when input is not valid code or QR payload',
      build: () => JoinTravelGroupCubit(
        repository: _MockTravelGroupRepository(joinResult: testGroup),
      ),
      act: (cubit) => cubit.submit('INVALID_SHORT'),
      expect: () => [
        const JoinTravelGroupState.failure(
          'This invitation is invalid, expired, or no longer available. Please check the invitation and try again.',
        ),
      ],
    );

    blocTest<JoinTravelGroupCubit, JoinTravelGroupState>(
      'emits [submitting, success] when valid code succeeds',
      build: () => JoinTravelGroupCubit(
        repository: _MockTravelGroupRepository(joinResult: testGroup),
      ),
      act: (cubit) => cubit.submit('A7K4P2QX'),
      expect: () => [
        const JoinTravelGroupState.submitting(),
        const JoinTravelGroupState.success(testGroup),
      ],
    );

    blocTest<JoinTravelGroupCubit, JoinTravelGroupState>(
      'parses valid QR deep link and submits normalized code',
      build: () => JoinTravelGroupCubit(
        repository: _MockTravelGroupRepository(joinResult: testGroup),
      ),
      act: (cubit) => cubit.submit('tripmate://groups/join?code=a7k4p2qx'),
      expect: () => [
        const JoinTravelGroupState.submitting(),
        const JoinTravelGroupState.success(testGroup),
      ],
    );

    blocTest<JoinTravelGroupCubit, JoinTravelGroupState>(
      'maps AuthenticationFailure to MSG125',
      build: () => JoinTravelGroupCubit(
        repository: _MockTravelGroupRepository(
          failure: const AuthenticationFailure(),
        ),
      ),
      act: (cubit) => cubit.submit('A7K4P2QX'),
      expect: () => [
        const JoinTravelGroupState.submitting(),
        const JoinTravelGroupState.failure(
          'Your session has expired. Please sign in again to continue.',
        ),
      ],
    );

    blocTest<JoinTravelGroupCubit, JoinTravelGroupState>(
      'maps PermissionFailure to MSG126',
      build: () => JoinTravelGroupCubit(
        repository: _MockTravelGroupRepository(
          failure: const PermissionFailure(),
        ),
      ),
      act: (cubit) => cubit.submit('A7K4P2QX'),
      expect: () => [
        const JoinTravelGroupState.submitting(),
        const JoinTravelGroupState.failure(
          'You do not have permission to access this function.',
        ),
      ],
    );

    blocTest<JoinTravelGroupCubit, JoinTravelGroupState>(
      'maps ValidationFailure to mapped message',
      build: () => JoinTravelGroupCubit(
        repository: _MockTravelGroupRepository(
          failure: const ValidationFailure(
            'This invitation is invalid, expired, or no longer available. Please check the invitation and try again.',
          ),
        ),
      ),
      act: (cubit) => cubit.submit('A7K4P2QX'),
      expect: () => [
        const JoinTravelGroupState.submitting(),
        const JoinTravelGroupState.failure(
          'This invitation is invalid, expired, or no longer available. Please check the invitation and try again.',
        ),
      ],
    );

    blocTest<JoinTravelGroupCubit, JoinTravelGroupState>(
      'maps ConflictFailure to MSG57 and preserves existingGroupId',
      build: () => JoinTravelGroupCubit(
        repository: _MockTravelGroupRepository(
          failure: const ConflictFailure(
            'You are already a member of this travel group.',
            99,
          ),
        ),
      ),
      act: (cubit) => cubit.submit('A7K4P2QX'),
      expect: () => [
        const JoinTravelGroupState.submitting(),
        const JoinTravelGroupState.failure(
          'You are already a member of this travel group.',
          99,
        ),
      ],
    );

    test('ignores concurrent submit calls while in-flight', () async {
      final repository = _MockTravelGroupRepository(joinResult: testGroup);
      final cubit = JoinTravelGroupCubit(repository: repository);

      final first = cubit.submit('A7K4P2QX');
      final second = cubit.submit('A7K4P2QX');
      await Future.wait([first, second]);

      expect(repository.recordedCalls.length, 1);
    });

    blocTest<JoinTravelGroupCubit, JoinTravelGroupState>(
      'maps ServerFailure to MSG127',
      build: () => JoinTravelGroupCubit(
        repository: _MockTravelGroupRepository(failure: const ServerFailure()),
      ),
      act: (cubit) => cubit.submit('A7K4P2QX'),
      expect: () => [
        const JoinTravelGroupState.submitting(),
        const JoinTravelGroupState.failure(
          'TripMate is temporarily unable to process your request. Please check your connection and try again.',
        ),
      ],
    );

    test('reuses same idempotency key for retry of identical code', () async {
      final repository = _MockTravelGroupRepository(
        failure: const ServerFailure(),
      );
      final cubit = JoinTravelGroupCubit(repository: repository);

      await cubit.submit('A7K4P2QX');
      final firstKey = cubit.currentIdempotencyKey;
      expect(firstKey, isNotNull);

      await cubit.submit('A7K4P2QX');
      final secondKey = cubit.currentIdempotencyKey;
      expect(secondKey, equals(firstKey));

      expect(repository.recordedCalls.length, 2);
      expect(repository.recordedCalls[0].$2, repository.recordedCalls[1].$2);
    });

    test(
      'generates new idempotency key when submitting different code',
      () async {
        final repository = _MockTravelGroupRepository(
          failure: const ServerFailure(),
        );
        final cubit = JoinTravelGroupCubit(repository: repository);

        await cubit.submit('A7K4P2QX');
        final firstKey = cubit.currentIdempotencyKey;

        await cubit.submit('HOIAN8KP');
        final secondKey = cubit.currentIdempotencyKey;

        expect(secondKey, isNot(equals(firstKey)));
        expect(
          repository.recordedCalls[0].$2,
          isNot(equals(repository.recordedCalls[1].$2)),
        );
      },
    );
  });
}
