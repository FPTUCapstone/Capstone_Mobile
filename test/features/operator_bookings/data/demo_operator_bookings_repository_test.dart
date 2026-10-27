import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/repositories/demo_operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';

void main() {
  const repository = DemoOperatorBookingsRepository();

  group('getPage', () {
    test(
      'lists every demo booking newest first, shaped like the contract',
      () async {
        final page = await repository.getPage(const OperatorBookingsQuery());

        expect(page.page, 1);
        expect(page.pageSize, 20);
        expect(page.totalCount, 6);
        expect(page.totalPages, 1);
        final booked = page.items.map((item) => item.bookedAtUtc).toList();
        expect(booked, [...booked]..sort((a, b) => b.compareTo(a)));
        expect(
          page.items.map((item) => item.status).toSet(),
          containsAll(OperatorBookingStatus.values),
        );
        expect(page.items.first.booker.phoneNumber, isNull);
      },
    );

    test(
      'the summary counts every status, but participants and amount only Confirmed and Completed',
      () async {
        final page = await repository.getPage(const OperatorBookingsQuery());

        final travelling = page.items.where(
          (item) =>
              item.status == OperatorBookingStatus.confirmed ||
              item.status == OperatorBookingStatus.completed,
        );
        expect(page.summary.totalBookings, page.totalCount);
        expect(
          page.summary.totalParticipants,
          travelling.fold<int>(0, (sum, item) => sum + item.quantity),
        );
        expect(
          page.summary.totalConfirmedAmount,
          travelling.fold<double>(0, (sum, item) => sum + item.totalAmount),
        );
      },
    );

    test('filters by status', () async {
      final page = await repository.getPage(
        const OperatorBookingsQuery(status: OperatorBookingStatus.expired),
      );

      expect(page.items, hasLength(1));
      expect(page.items.single.status, OperatorBookingStatus.expired);
      expect(page.summary.totalBookings, 1);
      expect(page.summary.totalParticipants, 0);
    });

    test('filters by tour', () async {
      final all = await repository.getPage(const OperatorBookingsQuery());
      final tourId = all.items.first.tour.tourId;

      final page = await repository.getPage(
        OperatorBookingsQuery(tourId: tourId),
      );

      expect(page.items, isNotEmpty);
      expect(page.items.every((item) => item.tour.tourId == tourId), isTrue);
    });

    test(
      'searches the code, the booker name and the booker e-mail case-insensitively',
      () async {
        final all = await repository.getPage(const OperatorBookingsQuery());
        final sample = all.items.first;

        for (final keyword in [
          sample.bookingCode.toLowerCase(),
          sample.booker.fullName.toUpperCase(),
          sample.booker.email!.toUpperCase(),
        ]) {
          final page = await repository.getPage(
            OperatorBookingsQuery(keyword: keyword),
          );
          expect(
            page.items.map((item) => item.bookingId),
            contains(sample.bookingId),
          );
        }
        final none = await repository.getPage(
          const OperatorBookingsQuery(keyword: 'nobody-matches-this'),
        );
        expect(none.items, isEmpty);
        expect(none.summary.totalBookings, 0);
      },
    );

    test(
      'the departure range uses Vietnam-time days, both bounds inclusive',
      () async {
        final all = await repository.getPage(const OperatorBookingsQuery());
        final target = all.items.first;
        // The Vietnam day of the departure: UTC+7.
        final vietnamDay = target.schedule.startAtUtc.add(
          const Duration(hours: 7),
        );
        final day = DateTime.utc(
          vietnamDay.year,
          vietnamDay.month,
          vietnamDay.day,
        );

        final inside = await repository.getPage(
          OperatorBookingsQuery(departureFrom: day, departureTo: day),
        );
        final before = await repository.getPage(
          OperatorBookingsQuery(
            departureTo: day.subtract(const Duration(days: 1)),
          ),
        );

        expect(
          inside.items.map((item) => item.bookingId),
          contains(target.bookingId),
        );
        expect(
          before.items.map((item) => item.bookingId),
          isNot(contains(target.bookingId)),
        );
      },
    );

    test('pages with the requested size', () async {
      final first = await repository.getPage(
        const OperatorBookingsQuery(pageSize: 4),
      );
      final second = await repository.getPage(
        const OperatorBookingsQuery(pageSize: 4, page: 2),
      );

      expect(first.items, hasLength(4));
      expect(second.items, hasLength(2));
      expect(first.totalPages, 2);
      expect({
        ...first.items.map((i) => i.bookingId),
        ...second.items.map((i) => i.bookingId),
      }, hasLength(6));
    });
  });

  group('getDetail', () {
    test(
      'returns the booking with its manifest, payment and cancel decision',
      () async {
        final list = await repository.getPage(const OperatorBookingsQuery());
        final withPayment = list.items.firstWhere(
          (item) => item.paymentStatus == OperatorPaymentStatus.paid,
        );

        final detail = await repository.getDetail(withPayment.bookingId);

        expect(detail.bookingId, withPayment.bookingId);
        expect(detail.bookingCode, withPayment.bookingCode);
        expect(detail.participants, isNotEmpty);
        expect(detail.participants.length, detail.quantity);
        expect(detail.booker.phoneNumber, isNotNull);
        expect(detail.schedule.meetingPoint, isNotNull);
        expect(
          detail.subtotalAmount,
          detail.totalAmount + detail.discountAmount,
        );
      },
    );

    test(
      'the canCancel decision follows the BE rule for every demo status',
      () async {
        final list = await repository.getPage(const OperatorBookingsQuery());
        for (final item in list.items) {
          final detail = await repository.getDetail(item.bookingId);
          final cancellable =
              (detail.status == OperatorBookingStatus.pendingPayment ||
                  detail.status == OperatorBookingStatus.confirmed) &&
              detail.checkInStatus == OperatorCheckInStatus.notCheckedIn;
          expect(detail.canCancel, cancellable, reason: detail.bookingCode);
          if (!cancellable) {
            expect(
              detail.cancelBlockedReason,
              isNotNull,
              reason: detail.bookingCode,
            );
          }
        }
      },
    );

    test('an unknown id is not found', () {
      expect(repository.getDetail('999999'), throwsA(isA<NotFoundFailure>()));
      expect(repository.getDetail('abc'), throwsA(isA<NotFoundFailure>()));
    });
  });

  test('offers the demo tours for the tour filter', () async {
    final options = await repository.getTourOptions();

    expect(options, isNotEmpty);
    final all = await repository.getPage(const OperatorBookingsQuery());
    for (final item in all.items) {
      expect(options.map((option) => option.id), contains(item.tour.tourId));
    }
  });
}
