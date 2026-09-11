import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
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
  }) async => _result;

  @override
  Future<GroupInvitation> getGroupInvitation(int groupId) async =>
      throw UnimplementedError();
}

final class _FailureRepository implements TravelGroupRepository {
  const _FailureRepository();

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => throw Exception('server error');

  @override
  Future<GroupInvitation> getGroupInvitation(int groupId) async =>
      throw UnimplementedError();
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
  });
}
