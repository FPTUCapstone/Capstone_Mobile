import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/models/operator_bookings_json.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';

import '../operator_bookings_fixtures.dart';

Map<String, Object?> _clone(Map<String, Object?> source) => {
  for (final entry in source.entries) entry.key: _cloneValue(entry.value),
};

Object? _cloneValue(Object? value) => switch (value) {
  Map<String, Object?>() => _clone(value),
  List<Object?>() => [for (final item in value) _cloneValue(item)],
  _ => value,
};

Map<String, Object?> _firstItem(Map<String, Object?> body) =>
    (body['items']! as List<Object?>).first! as Map<String, Object?>;

Map<String, Object?> _nested(Map<String, Object?> body, String key) =>
    body[key]! as Map<String, Object?>;

Map<String, Object?> _firstParticipant(Map<String, Object?> body) =>
    (body['participants']! as List<Object?>).first! as Map<String, Object?>;

void main() {
  group('OperatorBookingsJson.page', () {
    test('parses the contract example', () {
      final page = OperatorBookingsJson.page(listPageJson());

      expect(page.page, 1);
      expect(page.pageSize, 20);
      expect(page.totalCount, 37);
      expect(page.totalPages, 2);
      expect(page.summary.totalBookings, 37);
      expect(page.summary.totalParticipants, 112);
      expect(page.summary.totalConfirmedAmount, 98400000.0);
      final item = page.items.single;
      expect(item.bookingId, '1201');
      expect(item.bookingCode, 'BK-20261020-0007');
      expect(item.tour.title, 'Ba Na Hills full-day tour');
      expect(item.schedule.startAtUtc, DateTime.utc(2026, 11, 2));
      expect(item.schedule.startAtUtc.isUtc, isTrue);
      expect(item.booker.fullName, 'Nguyen Van A');
      expect(item.booker.email, 'a@example.com');
      expect(item.booker.phoneNumber, isNull);
      expect(item.quantity, 3);
      expect(item.totalAmount, 2400000.0);
      expect(item.discountAmount, 100000.0);
      expect(item.status, OperatorBookingStatus.confirmed);
      expect(item.paymentStatus, OperatorPaymentStatus.paid);
      expect(item.checkInStatus, OperatorCheckInStatus.notCheckedIn);
      expect(item.checkedInAtUtc, isNull);
      expect(item.bookedAtUtc, DateTime.utc(2026, 10, 20, 3, 15));
    });

    test('parses an empty page with a zero summary', () {
      final body = _clone(
        listPageJson(items: [], totalCount: 0, totalPages: 0),
      );
      _nested(body, 'summary')
        ..['totalBookings'] = 0
        ..['totalParticipants'] = 0
        ..['totalConfirmedAmount'] = 0;

      final page = OperatorBookingsJson.page(body);

      expect(page.items, isEmpty);
      expect(page.summary.totalConfirmedAmount, 0);
    });

    test('keeps a null e-mail, a check-in time, and every status value', () {
      final body = _clone(
        listPageJson(
          items: [
            for (final status in OperatorBookingStatus.values)
              listBookingJson(id: '${status.index + 1}', status: status.wire),
          ],
        ),
      );
      final first = _firstItem(body);
      _nested(first, 'booker')['email'] = null;
      first['checkInStatus'] = 'CheckedIn';
      first['checkedInAtUtc'] = '2026-11-02T01:00:00+00:00';

      final page = OperatorBookingsJson.page(body);

      expect(page.items.first.booker.email, isNull);
      expect(page.items.first.checkInStatus, OperatorCheckInStatus.checkedIn);
      expect(page.items.first.checkedInAtUtc, DateTime.utc(2026, 11, 2, 1));
      expect(
        page.items.map((item) => item.status),
        OperatorBookingStatus.values,
      );
    });

    test('ignores unknown extra properties and never exposes them', () {
      final body = _clone(listPageJson());
      _firstItem(body)['internalNote'] = 'secret';
      body['debug'] = true;

      final page = OperatorBookingsJson.page(body);

      expect(page.items.single.props.toString(), isNot(contains('secret')));
    });

    group('rejects with a FormatException', () {
      void rejects(
        String label,
        void Function(Map<String, Object?> body) mutate,
      ) {
        test(label, () {
          final body = _clone(listPageJson());
          mutate(body);
          expect(() => OperatorBookingsJson.page(body), throwsFormatException);
        });
      }

      test('a body that is not an object', () {
        expect(() => OperatorBookingsJson.page(null), throwsFormatException);
        expect(
          () => OperatorBookingsJson.page(<Object?>[]),
          throwsFormatException,
        );
        expect(() => OperatorBookingsJson.page('oops'), throwsFormatException);
      });

      for (final key in [
        'pageNumber',
        'pageSize',
        'totalCount',
        'totalPages',
        'summary',
        'items',
      ]) {
        rejects('a missing $key', (body) => body.remove(key));
      }
      rejects('items that are not a list', (body) => body['items'] = {});
      rejects('a page number below one', (body) => body['pageNumber'] = 0);
      rejects('a fractional page size', (body) => body['pageSize'] = 20.5);
      rejects('a negative total', (body) => body['totalCount'] = -1);
      rejects(
        'a negative summary amount',
        (body) => _nested(body, 'summary')['totalConfirmedAmount'] = -1,
      );
      rejects(
        'an unknown status',
        (body) => _firstItem(body)['status'] = 'Open',
      );
      rejects(
        'an unknown payment status',
        (body) => _firstItem(body)['paymentStatus'] = 'Maybe',
      );
      rejects(
        'an unknown check-in status',
        (body) => _firstItem(body)['checkInStatus'] = 'Late',
      );
      rejects(
        'a numeric booking id',
        (body) => _firstItem(body)['bookingId'] = 1201,
      );
      rejects(
        'a non-digit booking id',
        (body) => _firstItem(body)['bookingId'] = 'abc',
      );
      rejects(
        'a non-digit tour id',
        (body) => _nested(_firstItem(body), 'tour')['tourId'] = 'x',
      );
      rejects(
        'a missing booker name',
        (body) => _nested(_firstItem(body), 'booker').remove('fullName'),
      );
      rejects('a zero quantity', (body) => _firstItem(body)['quantity'] = 0);
      rejects(
        'a fractional quantity',
        (body) => _firstItem(body)['quantity'] = 1.5,
      );
      rejects(
        'a negative amount',
        (body) => _firstItem(body)['totalAmount'] = -1,
      );
      rejects(
        'a text amount',
        (body) => _firstItem(body)['totalAmount'] = '2400000',
      );
      rejects(
        'a date-only schedule start',
        (body) =>
            _nested(_firstItem(body), 'schedule')['startAtUtc'] = '2026-11-02',
      );
      rejects(
        'a non-date booked-at',
        (body) => _firstItem(body)['bookedAtUtc'] = 'yesterday',
      );
    });
  });

  group('OperatorBookingsJson.detail', () {
    test('parses the contract example', () {
      final detail = OperatorBookingsJson.detail(detailJson());

      expect(detail.bookingId, '1201');
      expect(detail.status, OperatorBookingStatus.confirmed);
      expect(detail.schedule.meetingPoint, 'Da Nang Cruise Port');
      expect(detail.booker.phoneNumber, '+84901234567');
      expect(detail.quantity, 3);
      expect(detail.participants, const [
        OperatorBookingParticipant(
          fullName: 'Nguyen Van A',
          type: OperatorParticipantType.adult,
        ),
        OperatorBookingParticipant(
          fullName: 'Nguyen Thi B',
          type: OperatorParticipantType.child,
        ),
      ]);
      expect(detail.ticket!.ticketCode, 'TK-0000001201');
      expect(detail.ticket!.status, OperatorTicketStatus.valid);
      expect(detail.payment!.gateway, OperatorPaymentGateway.payOs);
      expect(detail.payment!.gatewayTransactionRef, 'FT26102012345');
      expect(detail.payment!.status, OperatorPaymentTransactionStatus.success);
      expect(detail.payment!.amount, 2400000.0);
      expect(detail.paidAmount, 2400000.0);
      expect(detail.subtotalAmount, 2500000.0);
      expect(detail.discountAmount, 100000.0);
      expect(detail.totalAmount, 2400000.0);
      expect(detail.coupon!.code, 'SUMMER10');
      expect(detail.canCancel, isTrue);
      expect(detail.cancelBlockedReason, isNull);
    });

    test('keeps decimal money as received', () {
      final body = _clone(detailJson())..['totalAmount'] = 2399999.5;

      expect(OperatorBookingsJson.detail(body).totalAmount, 2399999.5);
    });

    test(
      'accepts null ticket, payment, coupon, meeting point, phone and e-mail',
      () {
        final body = _clone(detailJson())
          ..['ticket'] = null
          ..['payment'] = null
          ..['coupon'] = null
          ..['paidAmount'] = 0;
        _nested(body, 'schedule')['meetingPoint'] = null;
        _nested(body, 'booker')
          ..['phoneNumber'] = null
          ..['email'] = null;

        final detail = OperatorBookingsJson.detail(body);

        expect(detail.ticket, isNull);
        expect(detail.payment, isNull);
        expect(detail.coupon, isNull);
        expect(detail.schedule.meetingPoint, isNull);
        expect(detail.booker.phoneNumber, isNull);
        expect(detail.booker.email, isNull);
      },
    );

    test('parses a cancelled booking and every blocked reason', () {
      final body = _clone(detailJson())
        ..['status'] = 'Cancelled'
        ..['cancelledAtUtc'] = '2026-10-25T01:00:00+00:00'
        ..['cancelReason'] = 'TourOperator: weather'
        ..['canCancel'] = false
        ..['cancelBlockedReason'] = 'InvalidStatus';

      final detail = OperatorBookingsJson.detail(body);

      expect(detail.status, OperatorBookingStatus.cancelled);
      expect(detail.cancelledAtUtc, DateTime.utc(2026, 10, 25, 1));
      expect(detail.cancelReason, 'TourOperator: weather');
      expect(detail.canCancel, isFalse);
      expect(
        detail.cancelBlockedReason,
        OperatorCancelBlockedReason.invalidStatus,
      );

      body['cancelBlockedReason'] = 'CheckedIn';
      expect(
        OperatorBookingsJson.detail(body).cancelBlockedReason,
        OperatorCancelBlockedReason.checkedIn,
      );
    });

    test('never exposes fields the contract says are not returned', () {
      final body = _clone(detailJson());
      _firstParticipant(body)
        ..['idDocumentNumber'] = 'P1234567'
        ..['phoneNumber'] = '+84900000001'
        ..['email'] = 'a@secret.example'
        ..['nationality'] = 'VNM'
        ..['age'] = 41;
      _nested(body, 'payment')
        ..['rawResponse'] = 'gateway-secret'
        ..['checkoutUrl'] = 'https://pay.example/secret';

      final text = OperatorBookingsJson.detail(body).props.toString();

      for (final secret in [
        'P1234567',
        '+84900000001',
        'a@secret.example',
        'VNM',
        'gateway-secret',
        'pay.example',
      ]) {
        expect(text, isNot(contains(secret)));
      }
    });

    group('rejects with a FormatException', () {
      void rejects(
        String label,
        void Function(Map<String, Object?> body) mutate,
      ) {
        test(label, () {
          final body = _clone(detailJson());
          mutate(body);
          expect(
            () => OperatorBookingsJson.detail(body),
            throwsFormatException,
          );
        });
      }

      test('a body that is not an object', () {
        expect(() => OperatorBookingsJson.detail(null), throwsFormatException);
        expect(
          () => OperatorBookingsJson.detail(<Object?>[]),
          throwsFormatException,
        );
      });

      for (final key in [
        'bookingId',
        'status',
        'paymentStatus',
        'tour',
        'schedule',
        'booker',
        'participants',
        'checkInStatus',
        'paidAmount',
        'subtotalAmount',
        'totalAmount',
        'canCancel',
      ]) {
        rejects('a missing $key', (body) => body.remove(key));
      }
      rejects(
        'an unknown participant type',
        (body) => _firstParticipant(body)['participantType'] = 'Senior',
      );
      rejects(
        'a participant without a name',
        (body) => _firstParticipant(body).remove('fullName'),
      );
      rejects(
        'participants that are not a list',
        (body) => body['participants'] = 'none',
      );
      rejects(
        'an unknown gateway',
        (body) => _nested(body, 'payment')['gateway'] = 'Bitcoin',
      );
      rejects(
        'an unknown payment transaction status',
        (body) => _nested(body, 'payment')['status'] = 'Done',
      );
      rejects(
        'an unknown ticket status',
        (body) => _nested(body, 'ticket')['status'] = 'Torn',
      );
      rejects(
        'an unknown blocked reason',
        (body) => body['cancelBlockedReason'] = 'Weather',
      );
      rejects('a non-boolean canCancel', (body) => body['canCancel'] = 'yes');
      rejects('a negative paid amount', (body) => body['paidAmount'] = -5);
      rejects(
        'a negative coupon discount',
        (body) => _nested(body, 'coupon')['discountAmount'] = -1,
      );
      rejects(
        'a non-date ticket issue time',
        (body) => _nested(body, 'ticket')['issuedAtUtc'] = 'x',
      );
      rejects(
        'a non-date payment time',
        (body) => _nested(body, 'payment')['succeededAtUtc'] = 'x',
      );
      rejects(
        'a non-digit booker id',
        (body) => _nested(body, 'booker')['userId'] = 'u1',
      );
      rejects('a zero quantity', (body) => body['quantity'] = 0);
    });
  });

  group('OperatorBookingsJson.tourOptions', () {
    test('keeps the id and the title only', () {
      final options = OperatorBookingsJson.tourOptions(tourOptionsJson());

      expect(options, const [
        OperatorBookingTourOption(
          id: '101',
          title: 'Ba Na Hills full-day tour',
        ),
        OperatorBookingTourOption(id: '55', title: 'Food trail'),
      ]);
    });

    final malformed = <(String, Object?)>[
      ('not a list', <String, Object?>{}),
      (
        'an entry without an id',
        [
          {'code': 'X', 'title': 'T'},
        ],
      ),
      (
        'an entry without a title',
        [
          {'id': 1, 'code': 'X'},
        ],
      ),
      (
        'a non-positive id',
        [
          {'id': 0, 'code': 'X', 'title': 'T'},
        ],
      ),
      (
        'a text id',
        [
          {'id': '1', 'code': 'X', 'title': 'T'},
        ],
      ),
    ];
    for (final (label, body) in malformed) {
      test('rejects $label', () {
        expect(
          () => OperatorBookingsJson.tourOptions(body),
          throwsFormatException,
        );
      });
    }
  });
}
