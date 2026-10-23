import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/create_tour_package_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/load_tour_package_options_use_case.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/tour_package_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/create_tour_package_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/operator_tours_cubit.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/create_tour_package_page.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/pages/operator_tours_page.dart';

import '../../operator_tours_fakes.dart';

Future<CreateTourPackageCubit> _loadedCubit(
  FakeOperatorTourRepository repository,
) async {
  final cubit = CreateTourPackageCubit(
    createTour: CreateTourPackageUseCase(repository),
    loadOptions: LoadTourPackageOptionsUseCase(repository),
    getTour: GetTourPackageUseCase(repository),
    updateTour: UpdateTourPackageUseCase(repository),
    submitForReview: SubmitTourForReviewUseCase(repository),
    media: ManageTourMediaUseCase(repository),
  );
  await cubit.loadOptions();
  await cubit.loadDetail(42);
  return cubit;
}

Future<void> _pumpEditor(
  WidgetTester tester,
  CreateTourPackageCubit cubit,
) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // The editor pops itself after a successful submission, so it needs a real route stack.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('list')),
      ),
      GoRoute(
        path: '/edit',
        builder: (_, _) => BlocProvider.value(
          value: cubit,
          child: CreateTourPackagePage(initial: cubit.state.detail),
        ),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  unawaited(router.push<Object?>('/edit'));
  await tester.pumpAndSettle();
}

void main() {
  group('editor', () {
    testWidgets('prefills an existing draft and offers save and submit', (
      tester,
    ) async {
      final cubit = await _loadedCubit(FakeOperatorTourRepository());
      addTearDown(cubit.close);

      await _pumpEditor(tester, cubit);

      expect(find.text('Edit tour package'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Da Nang day tour'),
        findsOneWidget,
      );
      expect(find.text('Itinerary (1)'), findsOneWidget);
      expect(find.text('Schedules (1)'), findsOneWidget);
      await tester.tap(find.text('Preview & save'));
      await tester.pumpAndSettle();
      expect(find.text('Save draft'), findsOneWidget);
      expect(find.text('Submit for review'), findsOneWidget);
      expect(find.textContaining('Add a cover photo'), findsOneWidget);
      expect(find.textContaining('already appears earlier'), findsOneWidget);
      expect(find.textContaining('Cable car'), findsWidgets);
    });

    testWidgets('a package awaiting review is shown but cannot be changed', (
      tester,
    ) async {
      final cubit = await _loadedCubit(
        FakeOperatorTourRepository(
          detail: sampleDetail(
            status: TourPackageStatus.pending,
            blockers: const [],
          ),
        ),
      );
      addTearDown(cubit.close);

      await _pumpEditor(tester, cubit);
      await tester.tap(find.text('Preview & save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot be edited'), findsOneWidget);
      expect(find.text('Save draft'), findsNothing);
      expect(find.text('Submit for review'), findsNothing);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse,
      );
    });

    testWidgets('a rejected package shows the administrator reason', (
      tester,
    ) async {
      final cubit = await _loadedCubit(
        FakeOperatorTourRepository(
          detail: sampleDetail(
            status: TourPackageStatus.rejected,
            rejectionReason: 'Description is too vague',
          ),
        ),
      );
      addTearDown(cubit.close);

      await _pumpEditor(tester, cubit);

      expect(find.textContaining('Description is too vague'), findsOneWidget);
      await tester.tap(find.text('Preview & save'));
      await tester.pumpAndSettle();
      expect(find.text('Submit for review'), findsOneWidget);
    });

    testWidgets('submitting asks for confirmation and then saves and submits', (
      tester,
    ) async {
      final repository = FakeOperatorTourRepository(
        detail: sampleDetail(blockers: const []),
      );
      final cubit = await _loadedCubit(repository);
      addTearDown(cubit.close);
      await _pumpEditor(tester, cubit);
      await tester.tap(find.text('Preview & save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      expect(find.text('Submit for review?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.submitted, isEmpty);

      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(repository.updates, hasLength(1));
      expect(repository.updates.single.$2.cancellationPolicyTemplateId, 7);
      expect(repository.updates.single.$2.timeZoneId, 'Asia/Bangkok');
      expect(repository.updates.single.$2.categoryId, 3);
      expect(repository.submitted, [42]);
    });

    testWidgets(
      'keeps the stored stops and departures when saving an unchanged draft',
      (tester) async {
        final repository = FakeOperatorTourRepository();
        final cubit = await _loadedCubit(repository);
        addTearDown(cubit.close);
        await _pumpEditor(tester, cubit);
        await tester.tap(find.text('Preview & save'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save draft'));
        await tester.pumpAndSettle();

        final saved = repository.updates.single.$2;
        expect(saved.itineraryItems.single.poiId, 11);
        expect(saved.itineraryItems.single.plannedTime, '08:00:00');
        expect(saved.schedules.single.minimumCapacity, 4);
        expect(saved.schedules.single.adultPrice, 1200000);
        expect(
          saved.schedules.single.startAtUtc.toUtc(),
          DateTime.utc(2027, 3, 1, 1),
        );
        expect(saved.destinationIds, [1, 2]);
      },
    );
  });

  group('tour list', () {
    Future<OperatorToursCubit> pumpList(
      WidgetTester tester,
      FakeOperatorTourRepository repository,
    ) async {
      // Wide enough that every status chip is built (the chip row scrolls horizontally).
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = OperatorToursCubit(
        listTours: ListTourPackagesUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.load();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const OperatorToursPage(),
            ),
          ),
          GoRoute(
            path: '/operator/tours/:tourId/edit',
            builder: (_, state) =>
                Scaffold(body: Text('edit ${state.pathParameters['tourId']}')),
          ),
          GoRoute(
            path: '/operator/tours/create',
            builder: (_, _) => const Scaffold(body: Text('create')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return cubit;
    }

    testWidgets('lists packages with their status and opens one to edit', (
      tester,
    ) async {
      final repository = FakeOperatorTourRepository()
        ..allTours = const [
          TourPackageSummary(
            id: 5,
            title: 'Ba Na day trip',
            status: TourPackageStatus.approved,
            basePrice: 900000,
            durationDays: 1,
            destination: 'Da Nang',
          ),
        ];
      await pumpList(tester, repository);

      expect(find.text('Ba Na day trip'), findsOneWidget);
      expect(find.textContaining('Approved (not published)'), findsWidgets);

      await tester.tap(find.text('Ba Na day trip'));
      await tester.pumpAndSettle();
      expect(find.text('edit 5'), findsOneWidget);
    });

    testWidgets('a status chip asks the server for that status', (
      tester,
    ) async {
      final repository = FakeOperatorTourRepository();
      await pumpList(tester, repository);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Rejected'));
      await tester.pumpAndSettle();

      expect(repository.listCalls.last, (status: 'Rejected', page: 1));
    });

    testWidgets('a load failure is shown with a retry, not as an empty list', (
      tester,
    ) async {
      final repository = FakeOperatorTourRepository()
        ..allTours = const [
          TourPackageSummary(
            id: 1,
            title: 'FAIL',
            status: TourPackageStatus.draft,
            basePrice: 1,
            durationDays: 1,
            destination: '',
          ),
        ];
      await pumpList(tester, repository);

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No tour packages yet.'), findsNothing);
    });

    testWidgets('the create button opens the create screen', (tester) async {
      await pumpList(tester, FakeOperatorTourRepository());

      await tester.tap(find.text('Create tour package'));
      await tester.pumpAndSettle();

      expect(find.text('create'), findsOneWidget);
    });
  });
}
