import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/demo_trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/usecases/trip_records_use_case.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_record_detail_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/trip_record_detail_sheet.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

final class _Repository implements TripRecordsRepository {
  _Repository(this.onDetail);

  Future<TripRecordDetail> Function() onDetail;
  int calls = 0;

  @override
  Future<TripRecordPage> getPage(TripRecordsQuery query) =>
      throw UnimplementedError();

  @override
  Future<TripRecordDetail> getDetail(TripRecordKind kind, int id) {
    calls++;
    return onDetail();
  }
}

const _demo = DemoTripRecordsRepository();

Future<TripRecordDetail> _fixture(TripRecordKind kind, int id) =>
    _demo.getDetail(kind, id);

TripRecordDetailCubit _cubit(_Repository repository, TripRecordRef reference) =>
    TripRecordDetailCubit(
      useCase: TripRecordsUseCase(repository),
      reference: reference,
    );

/// Hosts the sheet the way the page does: as a modal bottom sheet.
Future<void> _open(
  WidgetTester tester,
  TripRecordDetailCubit cubit, {
  required String title,
  bool highlightRefund = false,
  Size size = const Size(400, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: TripRecordDetailSheet(
                    title: title,
                    highlightRefund: highlightRefund,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  const booking = TripRecordRef(kind: TripRecordKind.commerceBooking, id: 9001);
  const cancelled = TripRecordRef(
    kind: TripRecordKind.commerceBooking,
    id: 9004,
  );
  const itinerary = TripRecordRef(kind: TripRecordKind.itinerary, id: 5001);

  group('loading and failures', () {
    testWidgets('shows a progress indicator and the title while loading', (
      tester,
    ) async {
      final completer = Completer<TripRecordDetail>();
      final cubit = _cubit(_Repository(() => completer.future), booking);
      addTearDown(cubit.close);
      unawaited(cubit.load());

      await _open(tester, cubit, title: 'Hoi An Lantern Tour');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.detailLoading), findsOneWidget);
      expect(find.text('Hoi An Lantern Tour'), findsOneWidget);
    });

    testWidgets(
      'a system failure shows the message and Retry, which loads again',
      (tester) async {
        var attempts = 0;
        final repository = _Repository(() async {
          attempts++;
          if (attempts == 1) throw const NetworkFailure();
          return _fixture(TripRecordKind.commerceBooking, 9001);
        });
        final cubit = _cubit(repository, booking);
        addTearDown(cubit.close);
        await cubit.load();
        await _open(tester, cubit, title: 'Hoi An Lantern Tour');

        expect(
          find.text(TripHistoryStringsEn.errorMessageGeneric),
          findsOneWidget,
        );
        await tester.tap(find.text(TripHistoryStringsEn.actionRetry));
        await tester.pumpAndSettle();

        expect(repository.calls, 2);
        expect(
          find.text(TripHistoryStringsEn.errorMessageGeneric),
          findsNothing,
        );
        expect(
          find.text(TripHistoryStringsEn.tourSectionTitle),
          findsOneWidget,
        );
      },
    );

    testWidgets('a record that is gone says so and offers no Retry', (
      tester,
    ) async {
      final cubit = _cubit(
        _Repository(() async => throw const NotFoundFailure()),
        booking,
      );
      addTearDown(cubit.close);
      await cubit.load();

      await _open(tester, cubit, title: 'Tour');

      expect(
        find.text(TripHistoryStringsEn.tripRecordUnavailable),
        findsOneWidget,
      );
      expect(find.text(TripHistoryStringsEn.actionRetry), findsNothing);
    });

    testWidgets('an access failure shows the permission text and no Retry', (
      tester,
    ) async {
      final cubit = _cubit(
        _Repository(() async => throw const PermissionFailure()),
        booking,
      );
      addTearDown(cubit.close);
      await cubit.load();

      await _open(tester, cubit, title: 'Tour');

      expect(find.text(TripHistoryStringsEn.permissionDenied), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.actionRetry), findsNothing);
    });
  });

  group('booking', () {
    Future<TripRecordDetailCubit> ready(TripRecordRef ref) async {
      final cubit = _cubit(_Repository(() => _fixture(ref.kind, ref.id)), ref);
      await cubit.load();
      return cubit;
    }

    testWidgets(
      'a completed booking shows tour, schedule and participants only',
      (tester) async {
        final cubit = await ready(booking);
        addTearDown(cubit.close);
        await _open(tester, cubit, title: 'Hoi An Lantern Tour');

        expect(find.text('Hoi An'), findsOneWidget);
        expect(find.text('01/10/2026 09:00'), findsOneWidget);
        expect(find.text('01/10/2026 17:00'), findsOneWidget);
        expect(find.text('Old Town gate'), findsOneWidget);
        expect(find.text(TripHistoryStringsEn.formatAdults(2)), findsOneWidget);
        expect(
          find.text(TripHistoryStringsEn.formatChildren(1)),
          findsOneWidget,
        );
        expect(find.text(TripHistoryStringsEn.formatInfants(0)), findsNothing);
        expect(
          find.text(TripHistoryStringsEn.cancellationSectionTitle),
          findsNothing,
        );
        expect(
          find.text(TripHistoryStringsEn.refundSectionTitle),
          findsNothing,
        );
      },
    );

    testWidgets('omits the meeting point when there is none', (tester) async {
      final cubit = await ready(
        const TripRecordRef(kind: TripRecordKind.commerceBooking, id: 9002),
      );
      addTearDown(cubit.close);
      await _open(tester, cubit, title: 'Ba Na Hills Day Tour');

      expect(find.text(TripHistoryStringsEn.labelMeetingPoint), findsNothing);
    });

    testWidgets('a cancelled booking shows the cancellation and the refund', (
      tester,
    ) async {
      final cubit = await ready(cancelled);
      addTearDown(cubit.close);
      await _open(tester, cubit, title: 'My Son Sanctuary Tour');

      expect(
        find.text(TripHistoryStringsEn.cancellationSectionTitle),
        findsOneWidget,
      );
      expect(find.text('10/08/2026'), findsOneWidget);
      expect(find.text('Change of plans'), findsOneWidget);
      expect(
        find.text(TripHistoryStringsEn.refundSectionTitle),
        findsOneWidget,
      );
      expect(
        find.text(TripHistoryStringsEn.refundStatusLabel('Processed')),
        findsOneWidget,
      );
      expect(find.text('800,000 VND'), findsOneWidget);
      expect(find.text('PayOS'), findsOneWidget);
    });

    testWidgets(
      'says the refund channel is not available instead of leaving it blank',
      (tester) async {
        final base =
            await _fixture(TripRecordKind.commerceBooking, 9004)
                as BookingTripDetail;
        final noChannel = BookingTripDetail(
          record: base.record,
          tour: base.tour,
          schedule: base.schedule,
          participants: base.participants,
          cancellation: base.cancellation,
          refund: TripRefundDetail(
            status: base.refund!.status,
            amount: base.refund!.amount,
          ),
        );
        final cubit = _cubit(_Repository(() async => noChannel), cancelled);
        addTearDown(cubit.close);
        await cubit.load();
        await _open(tester, cubit, title: 'Tour');

        expect(
          find.text(TripHistoryStringsEn.channelUnavailable),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'highlights the refund only when opened from the refund action',
      (tester) async {
        final plain = await ready(cancelled);
        addTearDown(plain.close);
        await _open(tester, plain, title: 'Tour');
        expect(find.byKey(const Key('trip-detail-refund')), findsOneWidget);
        expect(
          find.byKey(const Key('trip-detail-refund-highlighted')),
          findsNothing,
        );
        Navigator.of(tester.element(find.byType(TripRecordDetailSheet))).pop();
        await tester.pumpAndSettle();

        final highlighted = await ready(cancelled);
        addTearDown(highlighted.close);
        await _open(tester, highlighted, title: 'Tour', highlightRefund: true);

        expect(
          find.byKey(const Key('trip-detail-refund-highlighted')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a cancelled booking with no refund has no refund section', (
      tester,
    ) async {
      final base =
          await _fixture(TripRecordKind.commerceBooking, 9004)
              as BookingTripDetail;
      final noRefund = BookingTripDetail(
        record: base.record,
        tour: base.tour,
        schedule: base.schedule,
        participants: base.participants,
        cancellation: base.cancellation,
      );
      final cubit = _cubit(_Repository(() async => noRefund), cancelled);
      addTearDown(cubit.close);
      await cubit.load();
      await _open(tester, cubit, title: 'Tour');

      expect(find.text(TripHistoryStringsEn.refundSectionTitle), findsNothing);
      expect(
        find.text(TripHistoryStringsEn.cancellationSectionTitle),
        findsOneWidget,
      );
    });
  });

  group('itinerary', () {
    testWidgets(
      'lists stops in order with visit labels, times and the session',
      (tester) async {
        final cubit = _cubit(
          _Repository(() => _fixture(itinerary.kind, itinerary.id)),
          itinerary,
        );
        addTearDown(cubit.close);
        await cubit.load();
        await _open(tester, cubit, title: 'Da Nang 2 days');

        final names = [
          'Dragon Bridge',
          'My Khe Beach',
          'Han Market',
          'Marble Mountains',
        ];
        final tops = [
          for (final name in names) tester.getTopLeft(find.text(name)).dy,
        ];
        expect([...tops]..sort(), tops, reason: 'stops follow the sequence');
        expect(
          find.text(TripHistoryStringsEn.stopVisited.toUpperCase()),
          findsNWidgets(3),
        );
        expect(
          find.text(TripHistoryStringsEn.stopSkipped.toUpperCase()),
          findsOneWidget,
        );
        expect(
          find.text(TripHistoryStringsEn.formatReachedAt('20/09/2026 08:05')),
          findsOneWidget,
        );
        expect(
          find.text(TripHistoryStringsEn.formatSkippedAt('20/09/2026 11:35')),
          findsOneWidget,
        );
        expect(
          find.text(TripHistoryStringsEn.formatVisitedOf(3, 4)),
          findsOneWidget,
        );
        expect(find.text('20/09/2026 08:00'), findsOneWidget);
        expect(find.text('20/09/2026 16:30'), findsOneWidget);
        expect(
          find.text(
            TripHistoryStringsEn.completionReasonLabel('RouteFinished'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'names a stop that was never reached as not visited, and an expired session',
      (tester) async {
        const expired = TripRecordRef(kind: TripRecordKind.itinerary, id: 5002);
        final cubit = _cubit(
          _Repository(() => _fixture(expired.kind, expired.id)),
          expired,
        );
        addTearDown(cubit.close);
        await cubit.load();
        await _open(tester, cubit, title: 'Hue day trip');

        expect(
          find.text(TripHistoryStringsEn.stopNotVisited.toUpperCase()),
          findsNWidgets(2),
        );
        expect(
          find.text(TripHistoryStringsEn.completionReasonLabel('Expired')),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows an unknown completion reason as it is', (tester) async {
      final base =
          await _fixture(TripRecordKind.itinerary, 5001) as ItineraryTripDetail;
      final odd = ItineraryTripDetail(
        record: base.record,
        stops: base.stops,
        session: TripSessionDetail(
          startedAtUtc: base.session!.startedAtUtc,
          completionReason: 'Mystery',
        ),
      );
      final cubit = _cubit(_Repository(() async => odd), itinerary);
      addTearDown(cubit.close);
      await cubit.load();
      await _open(tester, cubit, title: 'Trip');

      expect(find.text('Mystery'), findsOneWidget);
      expect(find.text(TripHistoryStringsEn.labelSessionEnded), findsNothing);
    });

    testWidgets(
      'an upcoming itinerary shows planned stops without visit labels or a session',
      (tester) async {
        const planned = TripRecordRef(kind: TripRecordKind.itinerary, id: 5003);
        final cubit = _cubit(
          _Repository(() => _fixture(planned.kind, planned.id)),
          planned,
        );
        addTearDown(cubit.close);
        await cubit.load();
        await _open(tester, cubit, title: 'Hoi An weekend plan');

        expect(find.text('Japanese Covered Bridge'), findsOneWidget);
        expect(
          find.text(TripHistoryStringsEn.formatPlannedWindow('08:00', '09:00')),
          findsOneWidget,
        );
        expect(
          find.text(TripHistoryStringsEn.stopVisited.toUpperCase()),
          findsNothing,
        );
        expect(
          find.text(TripHistoryStringsEn.stopNotVisited.toUpperCase()),
          findsNothing,
        );
        expect(
          find.text(TripHistoryStringsEn.sessionSectionTitle),
          findsNothing,
        );
      },
    );
  });

  group('sheet behaviour', () {
    testWidgets('the close button dismisses the sheet', (tester) async {
      final cubit = _cubit(
        _Repository(() => _fixture(booking.kind, booking.id)),
        booking,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await _open(tester, cubit, title: 'Hoi An Lantern Tour');

      await tester.tap(find.byTooltip(TripHistoryStringsEn.actionClose));
      await tester.pumpAndSettle();

      expect(find.byType(TripRecordDetailSheet), findsNothing);
    });

    testWidgets(
      'fits a 320 dp wide screen at double text size without overflow',
      (tester) async {
        final cubit = _cubit(
          _Repository(() => _fixture(itinerary.kind, itinerary.id)),
          itinerary,
        );
        addTearDown(cubit.close);
        await cubit.load();

        await _open(
          tester,
          cubit,
          title:
              'A very long itinerary title that has to wrap over several lines on a small phone',
          size: const Size(320, 640),
          textScale: 2,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Dragon Bridge'), findsOneWidget);
      },
    );

    testWidgets('a long booking sheet scrolls instead of overflowing', (
      tester,
    ) async {
      final cubit = _cubit(
        _Repository(() => _fixture(cancelled.kind, cancelled.id)),
        cancelled,
      );
      addTearDown(cubit.close);
      await cubit.load();

      await _open(
        tester,
        cubit,
        title: 'My Son Sanctuary Tour',
        size: const Size(320, 480),
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
    });
  });
}
