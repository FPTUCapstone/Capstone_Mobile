import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/tour_package_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/operator_tours_cubit.dart';

import '../../operator_tours_fakes.dart';

TourPackageSummary _tour(int id, TourPackageStatus status, {String? title}) =>
    TourPackageSummary(
      id: id,
      title: title ?? 'Tour $id',
      status: status,
      basePrice: 1000,
      durationDays: 1,
      destination: 'Da Nang',
    );

void main() {
  test('loads the first page and exposes whether more exist', () async {
    final repository = FakeOperatorTourRepository()
      ..allTours = [
        for (var id = 1; id <= 25; id++) _tour(id, TourPackageStatus.draft),
      ];
    final cubit = OperatorToursCubit(
      listTours: ListTourPackagesUseCase(repository),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, OperatorToursStatus.ready);
    expect(cubit.state.items, hasLength(20));
    expect(cubit.state.totalCount, 25);
    expect(cubit.state.hasMore, isTrue);
  });

  test('load more appends the next page without duplicating items', () async {
    final repository = FakeOperatorTourRepository()
      ..allTours = [
        for (var id = 1; id <= 25; id++) _tour(id, TourPackageStatus.draft),
      ];
    final cubit = OperatorToursCubit(
      listTours: ListTourPackagesUseCase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.loadMore();

    expect(cubit.state.items.map((tour) => tour.id), [
      for (var id = 1; id <= 25; id++) id,
    ]);
    expect(cubit.state.hasMore, isFalse);
    expect(repository.listCalls.last, (status: null, page: 2));
  });

  test(
    'filtering asks the server for that status and restarts at page one',
    () async {
      final repository = FakeOperatorTourRepository()
        ..allTours = [
          _tour(1, TourPackageStatus.draft),
          _tour(2, TourPackageStatus.rejected),
          _tour(3, TourPackageStatus.rejected),
        ];
      final cubit = OperatorToursCubit(
        listTours: ListTourPackagesUseCase(repository),
      );
      addTearDown(cubit.close);

      await cubit.load(filter: TourPackageStatus.rejected);

      expect(repository.listCalls.single, (status: 'Rejected', page: 1));
      expect(cubit.state.items.map((tour) => tour.id), [2, 3]);
      expect(cubit.state.filter, TourPackageStatus.rejected);
    },
  );

  test('a failed load is a retryable failure, not an empty list', () async {
    final repository = FakeOperatorTourRepository()
      ..allTours = [_tour(1, TourPackageStatus.draft, title: 'FAIL')];
    final cubit = OperatorToursCubit(
      listTours: ListTourPackagesUseCase(repository),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, OperatorToursStatus.failure);
    expect(cubit.state.failure, isNotNull);
    expect(cubit.state.items, isEmpty);
  });

  test('only Draft and Rejected packages are editable', () {
    expect(TourPackageStatus.values.where((status) => status.isEditable), [
      TourPackageStatus.draft,
      TourPackageStatus.rejected,
    ]);
  });
}
