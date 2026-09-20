import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/create_itinerary_state.dart';

void main() {
  late ItineraryRepository repository;
  const request = ItineraryGenerationRequest(
    startAt: '2026-10-20T08:00:00+07:00',
    timeZoneId: 'Asia/Ho_Chi_Minh',
    startLatitude: 16.0544,
    startLongitude: 108.2022,
    explorationLatitude: 16.0471,
    explorationLongitude: 108.2068,
    returnToStart: true,
    availableMinutes: 480,
    transportMode: TransportMode.motorbike,
    searchRadiusKm: 10,
    mandatoryPoiIds: [],
    restPreference: RestPreference.auto,
  );

  blocTest<CreateItineraryCubit, CreateItineraryState>(
    'reuses the same idempotency key when retrying after a failure',
    build: () {
      repository = _FailingRepository();
      return CreateItineraryCubit(
        repository: repository,
        operationKeyFactory: () => '0b2d6b0e-3e45-4b9f-bbf4-b8ab6c9fd327',
      );
    },
    act: (cubit) async {
      await cubit.generate(request);
      await cubit.generate(request);
    },
    expect: () => [
      const CreateItineraryState.generating(),
      isA<CreateItineraryState>().having(
        (state) => state.status,
        'status',
        CreateItineraryStatus.failure,
      ),
      const CreateItineraryState.generating(),
      isA<CreateItineraryState>().having(
        (state) => state.status,
        'status',
        CreateItineraryStatus.failure,
      ),
    ],
    verify: (cubit) {
      final failing = repository as _FailingRepository;
      expect(failing.keys, hasLength(2));
      expect(failing.keys.toSet(), hasLength(1));
    },
  );

  blocTest<CreateItineraryCubit, CreateItineraryState>(
    'rotates the key after a conflict before retrying the same form',
    build: () {
      repository = _ConflictRepository();
      var keyNumber = 0;
      return CreateItineraryCubit(
        repository: repository,
        operationKeyFactory: () => 'operation-${++keyNumber}',
      );
    },
    act: (cubit) async {
      await cubit.generate(request);
      await cubit.generate(request);
    },
    expect: () => [
      const CreateItineraryState.generating(),
      isA<CreateItineraryState>().having(
        (state) => state.status,
        'status',
        CreateItineraryStatus.failure,
      ),
      const CreateItineraryState.generating(),
      isA<CreateItineraryState>().having(
        (state) => state.status,
        'status',
        CreateItineraryStatus.failure,
      ),
    ],
    verify: (_) {
      final conflict = repository as _ConflictRepository;
      expect(conflict.keys, hasLength(2));
      expect(conflict.keys.toSet(), hasLength(2));
    },
  );

  blocTest<CreateItineraryCubit, CreateItineraryState>(
    'creates a new idempotency key when the request changes after a failure',
    build: () {
      repository = _FailingRepository();
      var keyNumber = 0;
      return CreateItineraryCubit(
        repository: repository,
        operationKeyFactory: () => 'operation-${++keyNumber}',
      );
    },
    act: (cubit) async {
      await cubit.generate(request);
      await cubit.generate(
        const ItineraryGenerationRequest(
          startAt: '2026-10-20T08:00:00+07:00',
          timeZoneId: 'Asia/Ho_Chi_Minh',
          startLatitude: 16.0544,
          startLongitude: 108.2022,
          explorationLatitude: 16.0471,
          explorationLongitude: 108.2068,
          returnToStart: true,
          availableMinutes: 360,
          transportMode: TransportMode.motorbike,
          searchRadiusKm: 10,
          mandatoryPoiIds: [],
          restPreference: RestPreference.auto,
        ),
      );
    },
    expect: () => [
      const CreateItineraryState.generating(),
      isA<CreateItineraryState>().having(
        (state) => state.status,
        'status',
        CreateItineraryStatus.failure,
      ),
      const CreateItineraryState.generating(),
      isA<CreateItineraryState>().having(
        (state) => state.status,
        'status',
        CreateItineraryStatus.failure,
      ),
    ],
    verify: (cubit) {
      final failing = repository as _FailingRepository;
      expect(failing.keys, hasLength(2));
      expect(failing.keys.toSet(), hasLength(2));
    },
  );
}

final class _FailingRepository implements ItineraryRepository {
  final keys = <String>[];

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    throw Exception('offline');
  }
}

final class _ConflictRepository implements ItineraryRepository {
  final keys = <String>[];

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    throw ConflictFailure();
  }
}
