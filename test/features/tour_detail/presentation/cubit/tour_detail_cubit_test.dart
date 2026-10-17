import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_detail.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/repositories/tour_detail_repository.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/usecases/get_tour_detail.dart';
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

    test('demo mode emits not found error for unknown tour ID', () async {
      final cubit = TourDetailCubit(isDemoMode: true);
      addTearDown(cubit.close);

      await cubit.load('unknown-tour-999');

      expect(cubit.state.status, TourDetailStatus.error);
      expect(cubit.state.errorMessage, TourDetailState.notFoundMessage);
      expect(cubit.state.tourDetail, isNull);
    });
  });

  group('TourDetailCubit with a real data source', () {
    TourScheduleItem schedule(
      String id, {
      bool? bookable,
      AvailabilityStatus status = AvailabilityStatus.available,
      int? remaining = 5,
    }) => TourScheduleItem(
      scheduleId: id,
      departureAtUtc: DateTime.utc(2026, 11, 6, 1),
      price: 1000000,
      currency: 'VND',
      remainingSlots: remaining,
      availabilityStatus: status,
      bookable: bookable,
    );

    TourDetail detail(List<TourScheduleItem> schedules) => TourDetail(
      tourId: '1',
      title: 'Tour',
      description: '',
      destinations: const ['Da Nang'],
      durationDays: 2,
      operatorName: 'Op',
      basePrice: 1000000,
      currency: 'VND',
      cancellationPolicy: '',
      schedules: schedules,
    );

    TourDetailCubit cubitFor(_FakeRepository repository) {
      final cubit = TourDetailCubit(getTourDetail: GetTourDetail(repository));
      addTearDown(cubit.close);
      return cubit;
    }

    test(
      'preselects the first bookable departure, skipping closed ones',
      () async {
        final cubit = cubitFor(
          _FakeRepository.returning(
            detail([
              schedule('closed', bookable: false),
              schedule(
                'soldout',
                bookable: false,
                status: AvailabilityStatus.soldOut,
                remaining: 0,
              ),
              schedule('open', bookable: true),
              schedule('later', bookable: true),
            ]),
          ),
        );

        await cubit.load('1');

        expect(cubit.state.status, TourDetailStatus.success);
        expect(cubit.state.selectedScheduleId, 'open');
        expect(cubit.state.scheduleError, isNull);
      },
    );

    test(
      'with no bookable departure nothing is preselected and MSG65 shows',
      () async {
        final cubit = cubitFor(
          _FakeRepository.returning(
            detail([
              schedule('closed', bookable: false),
              schedule(
                'unknown',
                bookable: false,
                status: AvailabilityStatus.unknown,
                remaining: null,
              ),
            ]),
          ),
        );

        await cubit.load('1');

        expect(cubit.state.status, TourDetailStatus.success);
        expect(cubit.state.selectedScheduleId, isNull);
        expect(cubit.state.scheduleError, TourDetailState.msg65);
      },
    );

    test(
      'a tour without departures succeeds without an error banner',
      () async {
        final cubit = cubitFor(_FakeRepository.returning(detail(const [])));

        await cubit.load('1');

        expect(cubit.state.status, TourDetailStatus.success);
        expect(cubit.state.selectedScheduleId, isNull);
        expect(cubit.state.scheduleError, isNull);
      },
    );

    test('the server flag wins over slot arithmetic', () async {
      final cubit = cubitFor(
        _FakeRepository.returning(
          detail([
            schedule('closed-with-slots', bookable: false, remaining: 9),
            schedule('open', bookable: true, remaining: 1),
          ]),
        ),
      );

      await cubit.load('1');
      expect(cubit.state.selectedScheduleId, 'open');

      cubit.selectSchedule('closed-with-slots');
      expect(cubit.state.selectedScheduleId, 'closed-with-slots');
      expect(cubit.state.scheduleError, TourDetailState.msg65);
      expect(cubit.state.selectedSchedule?.isSelectable, isFalse);

      cubit.selectSchedule('open');
      expect(cubit.state.scheduleError, isNull);
    });

    test(
      'without a server flag a sold-out departure is not selectable',
      () async {
        final cubit = cubitFor(
          _FakeRepository.returning(
            detail([
              schedule(
                'sold',
                status: AvailabilityStatus.soldOut,
                remaining: 0,
              ),
              schedule('free'),
            ]),
          ),
        );

        await cubit.load('1');

        expect(cubit.state.selectedScheduleId, 'free');
      },
    );

    test('a missing tour is reported as not found, not as a failure', () async {
      final cubit = cubitFor(_FakeRepository.returning(null));

      await cubit.load('1');

      expect(cubit.state.status, TourDetailStatus.error);
      expect(cubit.state.failureKind, TourDetailFailureKind.notFound);
      expect(cubit.state.errorMessage, TourDetailState.notFoundMessage);
    });

    test('a data source failure is MSG127 and retryable', () async {
      final cubit = cubitFor(_FakeRepository.failing());

      await cubit.load('1');

      expect(cubit.state.status, TourDetailStatus.error);
      expect(cubit.state.failureKind, TourDetailFailureKind.unavailable);
      expect(cubit.state.errorMessage, TourDetailState.msg127);
    });

    test(
      'leaving the screen while loading does not emit after close',
      () async {
        final completer = Completer<TourDetail?>();
        final cubit = TourDetailCubit(
          getTourDetail: GetTourDetail(_DeferredRepository(completer)),
        );

        final loading = cubit.load('1');
        await cubit.close();
        completer.complete(detail([schedule('open', bookable: true)]));

        await expectLater(loading, completes);
      },
    );

    test('leaving the screen while a load fails does not throw', () async {
      final completer = Completer<TourDetail?>();
      final cubit = TourDetailCubit(
        getTourDetail: GetTourDetail(_DeferredRepository(completer)),
      );

      final loading = cubit.load('1');
      await cubit.close();
      completer.completeError(Exception('offline'));

      await expectLater(loading, completes);
    });

    test('never shows the pending view for a real source', () async {
      final cubit = cubitFor(_FakeRepository.failing());

      await cubit.load('1');

      expect(cubit.state.status, isNot(TourDetailStatus.pendingIntegration));
    });

    test('loading again after a failure recovers', () async {
      final repository = _FakeRepository.failing();
      final cubit = cubitFor(repository);
      final states = <TourDetailStatus>[];
      final subscription = cubit.stream.listen(
        (state) => states.add(state.status),
      );
      addTearDown(subscription.cancel);

      await cubit.load('1');
      repository.result = detail([schedule('open', bookable: true)]);
      repository.fail = false;
      await cubit.load('1');
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        TourDetailStatus.loading,
        TourDetailStatus.error,
        TourDetailStatus.loading,
        TourDetailStatus.success,
      ]);
      expect(cubit.state.failureKind, isNull);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.selectedScheduleId, 'open');
      expect(repository.calls, 2);
    });
  });
}

final class _FakeRepository implements TourDetailRepository {
  _FakeRepository.returning(this.result) : fail = false;
  _FakeRepository.failing() : result = null, fail = true;

  TourDetail? result;
  bool fail;
  int calls = 0;

  @override
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  }) async {
    calls++;
    if (fail) throw Exception('network down');
    return result;
  }
}

final class _DeferredRepository implements TourDetailRepository {
  _DeferredRepository(this._completer);

  final Completer<TourDetail?> _completer;

  @override
  Future<TourDetail?> getTourDetail(
    String tourId, {
    TourSummary? initialSummary,
  }) => _completer.future;
}
