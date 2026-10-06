import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_cubit.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/cubit/tour_detail_state.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

void main() {
  group('TourDetailCubit', () {
    test('initial state has initial status and preserves initialSummary', () {
      final summary = TourSummary(
        tourId: 't-1',
        title: 'Tour Hạ Long',
        destinations: const ['Hạ Long'],
        operatorName: 'Halong Cruise',
        durationDays: 2,
        basePrice: 2000000,
        currency: 'VND',
        representativeScheduleId: 'sch-1',
        departureAtUtc: DateTime.utc(2026, 10, 15, 2, 0),
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 10,
      );
      final cubit = TourDetailCubit(initialSummary: summary, isDemoMode: false);
      addTearDown(cubit.close);

      expect(cubit.state.status, TourDetailStatus.initial);
      expect(cubit.state.initialSummary, summary);
      expect(cubit.state.isDemoMode, isFalse);
    });

    test(
      'production mode emits pendingIntegration on load without fake details',
      () async {
        final cubit = TourDetailCubit(isDemoMode: false);
        addTearDown(cubit.close);

        await cubit.load('tour-123');

        expect(cubit.state.status, TourDetailStatus.pendingIntegration);
        expect(cubit.state.tourDetail, isNull);
        expect(cubit.state.isDemoMode, isFalse);
      },
    );

    test(
      'demo mode loads deterministic detail fixture with available schedules',
      () async {
        final cubit = TourDetailCubit(isDemoMode: true);
        addTearDown(cubit.close);

        await cubit.load('tour-123');

        expect(cubit.state.status, TourDetailStatus.success);
        expect(cubit.state.tourDetail, isNotNull);
        final detail = cubit.state.tourDetail!;
        expect(detail.title, isNotEmpty);
        expect(detail.schedules, isNotEmpty);
        expect(detail.itineraryDays, isNotEmpty);
        expect(detail.inclusions, isNotEmpty);
        expect(detail.cancellationPolicy, isNotEmpty);
        expect(cubit.state.selectedScheduleId, 'sch-001');
        expect(cubit.state.scheduleError, isNull);
      },
    );

    test('selecting a sold-out schedule sets MSG65 scheduleError', () async {
      final cubit = TourDetailCubit(isDemoMode: true);
      addTearDown(cubit.close);

      await cubit.load('tour-123');
      expect(cubit.state.scheduleError, isNull);

      // Select sold out schedule (sch-003)
      cubit.selectSchedule('sch-003');
      expect(cubit.state.selectedScheduleId, 'sch-003');
      expect(cubit.state.scheduleError, TourDetailState.msg65);

      // Select available schedule again
      cubit.selectSchedule('sch-001');
      expect(cubit.state.selectedScheduleId, 'sch-001');
      expect(cubit.state.scheduleError, isNull);
    });

    test('simulateNoReviews empties reviews list to test MSG128', () async {
      final cubit = TourDetailCubit(isDemoMode: true);
      addTearDown(cubit.close);

      await cubit.load('tour-123');
      expect(cubit.state.tourDetail!.reviews, isNotEmpty);

      cubit.simulateNoReviews();
      expect(cubit.state.tourDetail!.reviews, isEmpty);
      expect(cubit.state.tourDetail!.reviewCount, 0);
    });

    test(
      'simulateSoldOut marks all departures sold out and emits MSG65',
      () async {
        final cubit = TourDetailCubit(isDemoMode: true);
        addTearDown(cubit.close);

        await cubit.load('tour-123');
        cubit.simulateSoldOut();

        expect(cubit.state.scheduleError, TourDetailState.msg65);
        for (final s in cubit.state.tourDetail!.schedules) {
          expect(s.isSoldOut, isTrue);
        }
      },
    );

    test('simulateError emits error status with MSG127', () async {
      final cubit = TourDetailCubit(isDemoMode: true);
      addTearDown(cubit.close);

      cubit.simulateError();

      expect(cubit.state.status, TourDetailStatus.error);
      expect(cubit.state.errorMessage, TourDetailState.msg127);
    });
  });
}
