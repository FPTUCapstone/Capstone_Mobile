import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/repositories/tour_detail_repository.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/usecases/get_tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

final class _RecordingRepository implements TourDetailRepository {
  final List<String> requestedIds = [];
  final List<TourSummary?> summaries = [];

  @override
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  }) async {
    requestedIds.add(tourId);
    summaries.add(initialSummary);
    return TourDetail(
      tourId: tourId,
      title: 'Loaded $tourId',
      description: '',
      destinations: const ['Da Nang'],
      durationDays: 2,
      operatorName: 'Op',
      basePrice: 1000000,
      currency: 'VND',
      cancellationPolicy: '',
    );
  }
}

void main() {
  late _RecordingRepository repository;

  setUp(() {
    repository = _RecordingRepository();
    serviceLocator.registerFactory<GetTourDetail>(
      () => GetTourDetail(repository),
    );
  });

  tearDown(() async {
    await serviceLocator.unregister<GetTourDetail>();
  });

  Future<void> open(
    WidgetTester tester,
    String location, {
    Object? extra,
  }) async {
    final session = AuthSessionCubit();
    final router = createAppRouter(session);
    addTearDown(router.dispose);
    addTearDown(session.close);
    await tester.pumpWidget(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go(location, extra: extra);
    await tester.pumpAndSettle();
  }

  testWidgets('a guest opens a tour by id without a summary', (tester) async {
    await open(tester, AppRoutes.tourDetail('9007199254740993'));

    expect(repository.requestedIds, ['9007199254740993']);
    expect(repository.summaries.single, isNull);
    expect(find.text('Loaded 9007199254740993'), findsOneWidget);
  });

  testWidgets('the summary passed from search reaches the use case', (
    tester,
  ) async {
    final summary = TourSummary(
      tourId: '7',
      title: 'From search',
      destinations: const ['Da Nang'],
      operatorName: 'Op',
      durationDays: 2,
      basePrice: 1000000,
      currency: 'VND',
      representativeScheduleId: null,
      departureAtUtc: null,
      availabilityStatus: AvailabilityStatus.available,
      remainingSlots: 3,
    );

    await open(tester, AppRoutes.tourDetail('7'), extra: summary);

    expect(repository.requestedIds, ['7']);
    expect(repository.summaries.single, summary);
  });

  testWidgets('the debug demo flag bypasses the real repository', (
    tester,
  ) async {
    await open(tester, AppRoutes.tourDetail('8', demo: true));

    // Debug builds (and tests) honour ?demo=true; release builds never do.
    expect(repository.requestedIds, isEmpty);
  });
}
