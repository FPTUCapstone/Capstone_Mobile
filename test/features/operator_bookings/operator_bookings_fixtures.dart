// Contract bodies copied from Capstone_BE/docs/UC-40-api-contract.md, shared by the UC-40 tests.

Map<String, Object?> listBookingJson({
  String id = '1201',
  String code = 'BK-20261020-0007',
  String tourTitle = 'Ba Na Hills full-day tour',
  String bookerName = 'Nguyen Van A',
  String status = 'Confirmed',
  String checkInStatus = 'NotCheckedIn',
}) => {
  'bookingId': id,
  'bookingCode': code,
  'tour': <String, Object?>{'tourId': '101', 'title': tourTitle},
  'schedule': <String, Object?>{
    'scheduleId': '311',
    'startAtUtc': '2026-11-02T00:00:00+00:00',
    'endAtUtc': '2026-11-02T10:00:00+00:00',
  },
  'booker': <String, Object?>{
    'userId': '55',
    'fullName': bookerName,
    'email': 'a@example.com',
  },
  'quantity': 3,
  'totalAmount': 2400000.0,
  'discountAmount': 100000.0,
  'status': status,
  'paymentStatus': 'Paid',
  'checkInStatus': checkInStatus,
  'checkedInAtUtc': null,
  'bookedAtUtc': '2026-10-20T03:15:00+00:00',
};

Map<String, Object?> listPageJson({
  List<Map<String, Object?>>? items,
  int pageNumber = 1,
  int pageSize = 20,
  int totalCount = 37,
  int totalPages = 2,
}) => {
  'pageNumber': pageNumber,
  'pageSize': pageSize,
  'totalCount': totalCount,
  'totalPages': totalPages,
  'summary': <String, Object?>{
    'totalBookings': 37,
    'totalParticipants': 112,
    'totalConfirmedAmount': 98400000.0,
  },
  'items': items ?? [listBookingJson()],
};

Map<String, Object?> detailJson({String id = '1201'}) => {
  'bookingId': id,
  'bookingCode': 'BK-20261020-0007',
  'status': 'Confirmed',
  'paymentStatus': 'Paid',
  'bookedAtUtc': '2026-10-20T03:15:00+00:00',
  'cancelledAtUtc': null,
  'cancelReason': null,
  'tour': <String, Object?>{
    'tourId': '101',
    'title': 'Ba Na Hills full-day tour',
  },
  'schedule': <String, Object?>{
    'scheduleId': '311',
    'startAtUtc': '2026-11-02T00:00:00+00:00',
    'endAtUtc': '2026-11-02T10:00:00+00:00',
    'meetingPoint': 'Da Nang Cruise Port',
  },
  'booker': <String, Object?>{
    'userId': '55',
    'fullName': 'Nguyen Van A',
    'email': 'a@example.com',
    'phoneNumber': '+84901234567',
  },
  'quantity': 3,
  'participants': [
    <String, Object?>{'fullName': 'Nguyen Van A', 'participantType': 'Adult'},
    <String, Object?>{'fullName': 'Nguyen Thi B', 'participantType': 'Child'},
  ],
  'ticket': <String, Object?>{
    'ticketCode': 'TK-0000001201',
    'status': 'Valid',
    'issuedAtUtc': '2026-10-20T03:16:00+00:00',
    'expiresAtUtc': null,
  },
  'checkInStatus': 'NotCheckedIn',
  'checkedInAtUtc': null,
  'payment': <String, Object?>{
    'gateway': 'PayOS',
    'gatewayTransactionRef': 'FT26102012345',
    'status': 'Success',
    'amount': 2400000.0,
    'succeededAtUtc': '2026-10-20T03:15:40+00:00',
  },
  'paidAmount': 2400000.0,
  'subtotalAmount': 2500000.0,
  'discountAmount': 100000.0,
  'totalAmount': 2400000.0,
  'coupon': <String, Object?>{
    'code': 'SUMMER10',
    'name': 'Summer 10%',
    'discountAmount': 100000.0,
  },
  'canCancel': true,
  'cancelBlockedReason': null,
};

List<Map<String, Object?>> tourOptionsJson() => [
  {
    'id': 101,
    'code': 'TOUR-00101',
    'title': 'Ba Na Hills full-day tour',
    'isActive': true,
  },
  {'id': 55, 'code': 'TOUR-00055', 'title': 'Food trail', 'isActive': false},
];
