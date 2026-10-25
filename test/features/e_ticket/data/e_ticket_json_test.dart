import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/e_ticket/data/models/e_ticket_json.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';

Map<String, dynamic> ticketBody({Map<String, dynamic> over = const {}}) => {
  'ticketId': 77,
  'ticketCode': 'TK-0000000456',
  'bookingId': 456,
  'bookingCode': 'BK-20261017-00001',
  'ticketStatus': 'Valid',
  'tour': {'tourId': 45, 'title': 'Hoi An Lantern Tour'},
  'operatorName': 'Hoi An Travel Co.',
  'schedule': {
    'startAtUtc': '2026-10-30T01:00:00+00:00',
    'endAtUtc': '2026-10-30T10:00:00+00:00',
    'meetingPoint': 'Old Town gate',
  },
  'participantCount': 3,
  'participants': {'adult': 2, 'child': 1, 'infant': 0},
  'validity': {
    'departureDate': '2026-10-30',
    'timeZone': 'Asia/Ho_Chi_Minh',
    'validFromUtc': '2026-10-29T17:00:00+00:00',
    'validUntilUtc': '2026-10-30T16:59:59.9999999+00:00',
  },
  'checkedInAtUtc': null,
  'qr': {
    'content': 'TM1.token.signature',
    'issuedAtUtc': '2026-10-24T08:15:00+00:00',
  },
  ...over,
};

Object? decoded(Map<String, dynamic> body) => jsonDecode(jsonEncode(body));

void main() {
  test('parses the contract example', () {
    final ticket = ETicketJson.ticket(decoded(ticketBody()));

    expect(ticket.ticketId, 77);
    expect(ticket.ticketCode, 'TK-0000000456');
    expect(ticket.bookingId, 456);
    expect(ticket.bookingCode, 'BK-20261017-00001');
    expect(ticket.status, ETicketStatus.valid);
    expect(ticket.tourId, 45);
    expect(ticket.tourTitle, 'Hoi An Lantern Tour');
    expect(ticket.operatorName, 'Hoi An Travel Co.');
    expect(ticket.startAtUtc, DateTime.utc(2026, 10, 30, 1));
    expect(ticket.startAtUtc.isUtc, isTrue);
    expect(ticket.meetingPoint, 'Old Town gate');
    expect(ticket.participantCount, 3);
    expect((ticket.adults, ticket.children, ticket.infants), (2, 1, 0));
    expect(ticket.departureDate, DateTime.utc(2026, 10, 30));
    expect(
      ticket.validUntilUtc.isAfter(DateTime.utc(2026, 10, 30, 16, 59, 59)),
      isTrue,
    );
    expect(ticket.checkedInAtUtc, isNull);
    expect(ticket.qr?.content, 'TM1.token.signature');
    expect(ticket.qr?.issuedAtUtc, DateTime.utc(2026, 10, 24, 8, 15));
  });

  test('maps every contract status', () {
    const wire = {
      'NotYetActive': ETicketStatus.notYetActive,
      'Valid': ETicketStatus.valid,
      'Used': ETicketStatus.used,
      'Cancelled': ETicketStatus.cancelled,
      'Expired': ETicketStatus.expired,
    };
    for (final entry in wire.entries) {
      final ticket = ETicketJson.ticket(
        decoded(ticketBody(over: {'ticketStatus': entry.key})),
      );
      expect(ticket.status, entry.value);
    }
  });

  test('only NotYetActive and Valid tickets can show and refresh a QR', () {
    expect(ETicketStatus.notYetActive.showsQr, isTrue);
    expect(ETicketStatus.valid.showsQr, isTrue);
    expect(ETicketStatus.used.showsQr, isFalse);
    expect(ETicketStatus.cancelled.showsQr, isFalse);
    expect(ETicketStatus.expired.showsQr, isFalse);
  });

  test('accepts a null QR, a null meeting point and a check-in time', () {
    final ticket = ETicketJson.ticket(
      decoded(
        ticketBody(
          over: {
            'ticketStatus': 'Used',
            'qr': null,
            'checkedInAtUtc': '2026-10-30T00:20:00+00:00',
            'schedule': {
              'startAtUtc': '2026-10-30T01:00:00+00:00',
              'endAtUtc': '2026-10-30T10:00:00+00:00',
              'meetingPoint': null,
            },
          },
        ),
      ),
    );

    expect(ticket.qr, isNull);
    expect(ticket.meetingPoint, isNull);
    expect(ticket.checkedInAtUtc, DateTime.utc(2026, 10, 30, 0, 20));
  });

  test('ignores properties the contract does not define', () {
    expect(
      () => ETicketJson.ticket(
        decoded(ticketBody(over: {'internalNote': 'must not matter'})),
      ),
      returnsNormally,
    );
  });

  final invalid = <String, Object?>{
    'an unknown status': ticketBody(over: {'ticketStatus': 'Lost'}),
    'a missing ticket id': ticketBody()..remove('ticketId'),
    'a zero ticket id': ticketBody(over: {'ticketId': 0}),
    'a string ticket id': ticketBody(over: {'ticketId': '77'}),
    'a missing qr key': ticketBody()..remove('qr'),
    'a non-object qr': ticketBody(over: {'qr': 'TM1.token.signature'}),
    'a qr without content': ticketBody(
      over: {
        'qr': {'issuedAtUtc': '2026-10-24T08:15:00+00:00'},
      },
    ),
    'a malformed departure date': ticketBody(
      over: {
        'validity': {
          'departureDate': '30/10/2026',
          'timeZone': 'Asia/Ho_Chi_Minh',
          'validFromUtc': '2026-10-29T17:00:00+00:00',
          'validUntilUtc': '2026-10-30T16:59:59+00:00',
        },
      },
    ),
    'a negative participant count': ticketBody(over: {'participantCount': -1}),
    'a list body': <Object?>[],
  };

  for (final entry in invalid.entries) {
    test('rejects ${entry.key}', () {
      expect(
        () => ETicketJson.ticket(jsonDecode(jsonEncode(entry.value))),
        throwsFormatException,
      );
    });
  }
}
