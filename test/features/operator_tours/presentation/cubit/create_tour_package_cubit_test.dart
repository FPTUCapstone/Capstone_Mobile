import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_options.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/create_tour_package_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/load_tour_package_options_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';

TourPackageDraft _draft({String title = 'Da Nang day tour'}) =>
    TourPackageDraft(
      title: title,
      description: 'Description',
      basePrice: 1000000,
      durationDays: 1,
      destinationIds: const [1, 2],
      cancellationPolicyTemplateId: 7,
      itineraryItems: const [
        TourItineraryStopDraft(
          poiId: 1,
          dayNo: 1,
          sequenceNo: 1,
          stayDurationMinutes: 60,
        ),
      ],
      schedules: [
        TourScheduleDraft(
          startAtUtc: DateTime.utc(2026, 11, 1, 8),
          endAtUtc: DateTime.utc(2026, 11, 1, 16),
          totalCapacity: 20,
        ),
      ],
    );

CreateTourPackageCubit _cubit(_FakeRepository repository) =>
    CreateTourPackageCubit(
      createTour: CreateTourPackageUseCase(repository),
      loadOptions: LoadTourPackageOptionsUseCase(repository),
    );

void main() {
  test(
    'draft JSON carries the destinations and policy the backend requires',
    () {
      final json = _draft().toJson();

      expect(json['destinationIds'], [1, 2]);
      expect(json['cancellationPolicyTemplateId'], 7);
    },
  );

  blocTest<CreateTourPackageCubit, CreateTourPackageState>(
    'emits submitting then success with the created draft ID',
    build: () => _cubit(_FakeRepository()),
    act: (cubit) => cubit.submit(_draft()),
    expect: () => [
      isA<CreateTourPackageState>().having(
        (state) => state.status,
        'status',
        CreateTourPackageStatus.submitting,
      ),
      isA<CreateTourPackageState>()
          .having(
            (state) => state.status,
            'status',
            CreateTourPackageStatus.success,
          )
          .having((state) => state.tourId, 'tourId', 42),
    ],
  );

  test(
    'retrying the same payload after a failure reuses the idempotency key; an edit rotates it',
    () async {
      final repository = _FakeRepository(failCreates: 2);
      final cubit = _cubit(repository);
      addTearDown(cubit.close);

      await cubit.submit(_draft());
      expect(cubit.state.status, CreateTourPackageStatus.failure);
      await cubit.submit(_draft());
      expect(repository.keys, hasLength(2));
      expect(repository.keys[1], repository.keys[0]);

      await cubit.submit(_draft(title: 'Edited title'));
      expect(cubit.state.status, CreateTourPackageStatus.success);
      expect(repository.keys[2], isNot(repository.keys[0]));

      // A new draft after a success is a new operation.
      await cubit.submit(_draft(title: 'Edited title'));
      expect(repository.keys[3], isNot(repository.keys[2]));
    },
  );

  test('a failed save is never reported as success', () async {
    final cubit = _cubit(_FakeRepository(failCreates: 1));
    addTearDown(cubit.close);

    await cubit.submit(_draft());

    expect(cubit.state.status, CreateTourPackageStatus.failure);
    expect(cubit.state.failure, const NetworkFailure());
    expect(cubit.state.tourId, isNull);
  });

  test('loads the catalogues and surfaces a retryable failure', () async {
    final repository = _FakeRepository(failOptionLoads: 1);
    final cubit = _cubit(repository);
    addTearDown(cubit.close);

    await cubit.loadOptions();
    expect(cubit.state.optionsStatus, TourPackageOptionsStatus.failure);
    expect(cubit.state.optionsFailure, const NetworkFailure());

    await cubit.loadOptions();
    expect(cubit.state.optionsStatus, TourPackageOptionsStatus.ready);
    expect(cubit.state.options!.destinations.single.name, 'Da Nang');
    expect(cubit.state.options!.policies.single.id, 7);
    expect(cubit.state.optionsFailure, isNull);
  });
}

final class _FakeRepository implements OperatorTourRepository {
  _FakeRepository({this.failCreates = 0, this.failOptionLoads = 0});
  int failCreates;
  int failOptionLoads;
  final keys = <String>[];

  @override
  Future<int> createDraft(TourPackageDraft draft, String idempotencyKey) async {
    keys.add(idempotencyKey);
    if (failCreates > 0) {
      failCreates -= 1;
      throw const NetworkFailure();
    }
    return 42;
  }

  @override
  Future<TourPackageOptions> loadOptions() async {
    if (failOptionLoads > 0) {
      failOptionLoads -= 1;
      throw const NetworkFailure();
    }
    return const TourPackageOptions(
      destinations: [TourDestinationOption(id: 1, name: 'Da Nang')],
      policies: [CancellationPolicyOption(id: 7, name: 'Standard')],
    );
  }
}
