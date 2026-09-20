import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_travel_group_state.dart';

// -- Fakes ------------------------------------------------------------------

final class _SuccessRepository implements TravelGroupRepository {
  const _SuccessRepository(this._result);
  final TravelGroup _result;

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) async => _result;

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async => _result;
}

final class _FailureRepository implements TravelGroupRepository {
  const _FailureRepository();

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) async => throw Exception('server error');

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async => throw Exception('server error');
}

final class _TypedFailureRepository implements TravelGroupRepository {
  const _TypedFailureRepository(this.failure);
  final Failure failure;

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) async => throw failure;

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async => throw failure;
}

final class _TrackingRepository implements TravelGroupRepository {
  final calls = <({String name, int itineraryId, String idempotencyKey})>[];
  bool shouldFail = true;
  Completer<TravelGroup>? slowCompleter;

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) async {
    calls.add((
      name: name,
      itineraryId: itineraryId,
      idempotencyKey: idempotencyKey,
    ));
    if (slowCompleter != null) {
      return slowCompleter!.future;
    }
    if (shouldFail) {
      throw Exception('network error');
    }
    return TravelGroup(id: 1, name: name);
  }

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

// --------------------------------------------------------------------------

void main() {
  const validName = 'My Trip Group';
  final tooLongName = 'A' * 151;
  const testItineraryId = 10;
  const travelGroup = TravelGroup(id: 1, name: validName);

  group('CreateTravelGroupCubit', () {
    test('initial state is CreateTravelGroupStatus.initial', () {
      final cubit = CreateTravelGroupCubit(
        repository: const _SuccessRepository(travelGroup),
      );
      expect(cubit.state.status, CreateTravelGroupStatus.initial);
      cubit.close();
    });

    blocTest<CreateTravelGroupCubit, CreateTravelGroupState>(
      'non-positive itinerary emits validationFailure without calling repository',
      build: () => CreateTravelGroupCubit(
        repository: const _SuccessRepository(travelGroup),
      ),
      act: (cubit) => cubit.submit(name: validName, itineraryId: 0),
      expect: () => [
        isA<CreateTravelGroupState>()
            .having(
              (s) => s.status,
              'status',
              CreateTravelGroupStatus.validationFailure,
            )
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Please select an itinerary.',
            ),
        isA<CreateTravelGroupState>().having(
          (s) => s.status,
          'status',
          CreateTravelGroupStatus.initial,
        ),
      ],
    );

    blocTest<CreateTravelGroupCubit, CreateTravelGroupState>(
      'empty name emits validationFailure with MSG01 then resets to initial',
      build: () =>
          CreateTravelGroupCubit(repository: const _FailureRepository()),
      act: (cubit) => cubit.submit(name: '', itineraryId: testItineraryId),
      expect: () => [
        isA<CreateTravelGroupState>()
            .having(
              (s) => s.status,
              'status',
              CreateTravelGroupStatus.validationFailure,
            )
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'This field is required.',
            ),
        isA<CreateTravelGroupState>().having(
          (s) => s.status,
          'status',
          CreateTravelGroupStatus.initial,
        ),
      ],
    );

    blocTest<CreateTravelGroupCubit, CreateTravelGroupState>(
      'authentication failure emits MSG125',
      build: () => CreateTravelGroupCubit(
        repository: const _TypedFailureRepository(AuthenticationFailure()),
      ),
      act: (cubit) =>
          cubit.submit(name: validName, itineraryId: testItineraryId),
      expect: () => [
        isA<CreateTravelGroupState>().having(
          (s) => s.status,
          'status',
          CreateTravelGroupStatus.submitting,
        ),
        isA<CreateTravelGroupState>()
            .having((s) => s.status, 'status', CreateTravelGroupStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Your session has expired. Please sign in again to continue.',
            ),
      ],
    );

    blocTest<CreateTravelGroupCubit, CreateTravelGroupState>(
      'permission failure emits MSG126',
      build: () => CreateTravelGroupCubit(
        repository: const _TypedFailureRepository(PermissionFailure()),
      ),
      act: (cubit) =>
          cubit.submit(name: validName, itineraryId: testItineraryId),
      expect: () => [
        isA<CreateTravelGroupState>().having(
          (s) => s.status,
          'status',
          CreateTravelGroupStatus.submitting,
        ),
        isA<CreateTravelGroupState>()
            .having((s) => s.status, 'status', CreateTravelGroupStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'You do not have permission to access this function.',
            ),
      ],
    );

    blocTest<CreateTravelGroupCubit, CreateTravelGroupState>(
      'name > 150 chars emits validationFailure then resets to initial',
      build: () =>
          CreateTravelGroupCubit(repository: const _FailureRepository()),
      act: (cubit) =>
          cubit.submit(name: tooLongName, itineraryId: testItineraryId),
      expect: () => [
        isA<CreateTravelGroupState>()
            .having(
              (s) => s.status,
              'status',
              CreateTravelGroupStatus.validationFailure,
            )
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Group name must not exceed 150 characters.',
            ),
        isA<CreateTravelGroupState>().having(
          (s) => s.status,
          'status',
          CreateTravelGroupStatus.initial,
        ),
      ],
    );

    blocTest<CreateTravelGroupCubit, CreateTravelGroupState>(
      'valid name on success emits [submitting, success] with result',
      build: () => CreateTravelGroupCubit(
        repository: const _SuccessRepository(travelGroup),
      ),
      act: (cubit) =>
          cubit.submit(name: validName, itineraryId: testItineraryId),
      expect: () => [
        isA<CreateTravelGroupState>().having(
          (s) => s.status,
          'status',
          CreateTravelGroupStatus.submitting,
        ),
        isA<CreateTravelGroupState>()
            .having((s) => s.status, 'status', CreateTravelGroupStatus.success)
            .having((s) => s.result, 'result', travelGroup),
      ],
    );

    blocTest<CreateTravelGroupCubit, CreateTravelGroupState>(
      'valid name on repository error emits [submitting, failure] with MSG127',
      build: () =>
          CreateTravelGroupCubit(repository: const _FailureRepository()),
      act: (cubit) =>
          cubit.submit(name: validName, itineraryId: testItineraryId),
      expect: () => [
        isA<CreateTravelGroupState>().having(
          (s) => s.status,
          'status',
          CreateTravelGroupStatus.submitting,
        ),
        isA<CreateTravelGroupState>()
            .having((s) => s.status, 'status', CreateTravelGroupStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'TripMate is temporarily unable to process your request. Please check your connection and try again.',
            ),
      ],
    );

    blocTest<CreateTravelGroupCubit, CreateTravelGroupState>(
      'validation failure from backend emits failure with backend message',
      build: () => CreateTravelGroupCubit(
        repository: const _TypedFailureRepository(
          ValidationFailure('A valid Idempotency-Key header is required.'),
        ),
      ),
      act: (cubit) =>
          cubit.submit(name: validName, itineraryId: testItineraryId),
      expect: () => [
        isA<CreateTravelGroupState>().having(
          (s) => s.status,
          'status',
          CreateTravelGroupStatus.submitting,
        ),
        isA<CreateTravelGroupState>()
            .having((s) => s.status, 'status', CreateTravelGroupStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'A valid Idempotency-Key header is required.',
            ),
      ],
    );

    blocTest<CreateTravelGroupCubit, CreateTravelGroupState>(
      'conflict failure from backend emits failure with conflict message',
      build: () => CreateTravelGroupCubit(
        repository: const _TypedFailureRepository(
          ConflictFailure('Idempotency key payload mismatch.'),
        ),
      ),
      act: (cubit) =>
          cubit.submit(name: validName, itineraryId: testItineraryId),
      expect: () => [
        isA<CreateTravelGroupState>().having(
          (s) => s.status,
          'status',
          CreateTravelGroupStatus.submitting,
        ),
        isA<CreateTravelGroupState>()
            .having((s) => s.status, 'status', CreateTravelGroupStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Idempotency key payload mismatch.',
            ),
      ],
    );

    // -- Idempotency contract tests (P1 & P2) --------------------------------

    test('exact retry reuses the same idempotency key after failure', () async {
      final repository = _TrackingRepository();
      var keyCounter = 0;
      final cubit = CreateTravelGroupCubit(
        repository: repository,
        operationKeyFactory: () => 'key-${++keyCounter}',
      );

      // First submit fails
      await cubit.submit(name: 'Trip A', itineraryId: 10);
      expect(repository.calls, hasLength(1));
      expect(repository.calls[0].idempotencyKey, 'key-1');
      expect(cubit.state.status, CreateTravelGroupStatus.failure);

      // Exact retry with same normalized payload reuses key-1
      await cubit.submit(name: '  Trip A  ', itineraryId: 10);
      expect(repository.calls, hasLength(2));
      expect(repository.calls[1].idempotencyKey, 'key-1');
      expect(keyCounter, 1);

      await cubit.close();
    });

    test(
      'changing group name after failure generates a new idempotency key',
      () async {
        final repository = _TrackingRepository();
        var keyCounter = 0;
        final cubit = CreateTravelGroupCubit(
          repository: repository,
          operationKeyFactory: () => 'key-${++keyCounter}',
        );

        // First submit fails with Trip A
        await cubit.submit(name: 'Trip A', itineraryId: 10);
        expect(repository.calls, hasLength(1));
        expect(repository.calls[0].idempotencyKey, 'key-1');

        // User changes form to Trip B and submits again -> generates key-2
        await cubit.submit(name: 'Trip B', itineraryId: 10);
        expect(repository.calls, hasLength(2));
        expect(repository.calls[1].idempotencyKey, 'key-2');
        expect(keyCounter, 2);

        await cubit.close();
      },
    );

    test(
      'changing itineraryId after failure generates a new idempotency key',
      () async {
        final repository = _TrackingRepository();
        var keyCounter = 0;
        final cubit = CreateTravelGroupCubit(
          repository: repository,
          operationKeyFactory: () => 'key-${++keyCounter}',
        );

        // First submit fails with itinerary 10
        await cubit.submit(name: 'Trip A', itineraryId: 10);
        expect(repository.calls, hasLength(1));
        expect(repository.calls[0].idempotencyKey, 'key-1');

        // User changes itinerary to 20 -> generates key-2
        await cubit.submit(name: 'Trip A', itineraryId: 20);
        expect(repository.calls, hasLength(2));
        expect(repository.calls[1].idempotencyKey, 'key-2');
        expect(keyCounter, 2);

        await cubit.close();
      },
    );

    test(
      'success clears the pending operation so next submission uses new key',
      () async {
        final repository = _TrackingRepository()..shouldFail = false;
        var keyCounter = 0;
        final cubit = CreateTravelGroupCubit(
          repository: repository,
          operationKeyFactory: () => 'key-${++keyCounter}',
        );

        // First submit succeeds
        await cubit.submit(name: 'Trip A', itineraryId: 10);
        expect(repository.calls, hasLength(1));
        expect(repository.calls[0].idempotencyKey, 'key-1');
        expect(cubit.state.status, CreateTravelGroupStatus.success);

        // Next submit (even with same name and itinerary) generates new key
        await cubit.submit(name: 'Trip A', itineraryId: 10);
        expect(repository.calls, hasLength(2));
        expect(repository.calls[1].idempotencyKey, 'key-2');
        expect(keyCounter, 2);

        await cubit.close();
      },
    );

    test(
      'concurrent or double submit cannot create a second in-flight operation',
      () async {
        final repository = _TrackingRepository()
          ..slowCompleter = Completer<TravelGroup>();
        var keyCounter = 0;
        final cubit = CreateTravelGroupCubit(
          repository: repository,
          operationKeyFactory: () => 'key-${++keyCounter}',
        );

        // Start first submit (remains in-flight due to slowCompleter)
        final firstSubmitFuture = cubit.submit(name: 'Trip A', itineraryId: 10);
        expect(cubit.state.status, CreateTravelGroupStatus.submitting);
        expect(repository.calls, hasLength(1));

        // Second submit while in-flight should be ignored
        final secondSubmitFuture = cubit.submit(
          name: 'Trip A',
          itineraryId: 10,
        );
        expect(repository.calls, hasLength(1));

        // Complete the in-flight operation
        repository.slowCompleter!.complete(
          const TravelGroup(id: 1, name: 'Trip A'),
        );
        await firstSubmitFuture;
        await secondSubmitFuture;

        expect(repository.calls, hasLength(1));
        expect(cubit.state.status, CreateTravelGroupStatus.success);

        await cubit.close();
      },
    );
  });
}
