import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/repositories/operator_tour_repository.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/create_tour_package_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_state.dart';

void main() {
  final draft = TourPackageDraft(
    title: 'Da Nang day tour',
    description: 'Description',
    basePrice: 1000000,
    durationDays: 1,
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

  blocTest<CreateTourPackageCubit, CreateTourPackageState>(
    'emits submitting then success with the created draft ID',
    build: () => CreateTourPackageCubit(
      createTour: CreateTourPackageUseCase(_SuccessRepository()),
    ),
    act: (cubit) => cubit.submit(draft),
    expect: () => const [
      CreateTourPackageState(status: CreateTourPackageStatus.submitting),
      CreateTourPackageState(
        status: CreateTourPackageStatus.success,
        tourId: 42,
      ),
    ],
  );
}

final class _SuccessRepository implements OperatorTourRepository {
  @override
  Future<int> createDraft(
    TourPackageDraft draft,
    String idempotencyKey,
  ) async => 42;
}
