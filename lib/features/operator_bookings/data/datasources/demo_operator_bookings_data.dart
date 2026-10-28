import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';

/// DEMO-ONLY fixtures for the Tour Operator bookings screens, shaped like the UC-40 backend contract.
/// They are served only by `DemoOperatorBookingsRepository`, which dependency injection selects for an
/// explicit debug demo flag; they are never a fallback for a failed live call.
const demoOperatorBookingTourOptions = <OperatorBookingTourOption>[
  OperatorBookingTourOption(id: '142', title: 'Ba Na Hills full-day tour'),
  OperatorBookingTourOption(
    id: '148',
    title: 'Hoi An Old Town & Bay Mau coconut forest',
  ),
  OperatorBookingTourOption(id: '55', title: 'Da Nang night food trail'),
];

const _banaHills = OperatorBookingTour(
  tourId: '142',
  title: 'Ba Na Hills full-day tour',
);
const _hoiAn = OperatorBookingTour(
  tourId: '148',
  title: 'Hoi An Old Town & Bay Mau coconut forest',
);
const _foodTrail = OperatorBookingTour(
  tourId: '55',
  title: 'Da Nang night food trail',
);

OperatorBookingSchedule _schedule(
  String id,
  DateTime start,
  Duration length,
  String? meetingPoint,
) => OperatorBookingSchedule(
  scheduleId: id,
  startAtUtc: start,
  endAtUtc: start.add(length),
  meetingPoint: meetingPoint,
);

OperatorBookingParticipant _adult(String name) => OperatorBookingParticipant(
  fullName: name,
  type: OperatorParticipantType.adult,
);

OperatorBookingParticipant _child(String name) => OperatorBookingParticipant(
  fullName: name,
  type: OperatorParticipantType.child,
);

OperatorBookingPayment _vnPay(String reference, double amount, DateTime at) =>
    OperatorBookingPayment(
      gateway: OperatorPaymentGateway.vnPay,
      gatewayTransactionRef: reference,
      status: OperatorPaymentTransactionStatus.success,
      amount: amount,
      succeededAtUtc: at,
    );

/// Newest booking first is applied by the repository; the order here is by id.
final List<OperatorBookingDetail> demoOperatorBookings = [
  // Confirmed and paid with a coupon, 5 travellers, not yet checked in.
  OperatorBookingDetail(
    bookingId: '1141',
    bookingCode: 'BK-20260919-0141',
    status: OperatorBookingStatus.confirmed,
    paymentStatus: OperatorPaymentStatus.paid,
    bookedAtUtc: DateTime.utc(2026, 9, 10, 7, 15),
    tour: _banaHills,
    schedule: _schedule(
      '3142',
      DateTime.utc(2026, 9, 19, 1),
      const Duration(hours: 10),
      'Da Nang Cruise Port',
    ),
    booker: const OperatorBookingBooker(
      userId: '5001',
      fullName: 'Nguyen Van An',
      email: 'an.nguyen@example.com',
      phoneNumber: '0901234567',
    ),
    quantity: 5,
    participants: [
      _adult('Nguyen Van An'),
      _adult('Tran Thi Mai'),
      _child('Nguyen Minh Quan'),
      _child('Nguyen Gia Han'),
      _adult('Le Van Phuc'),
    ],
    ticket: OperatorBookingTicket(
      ticketCode: 'TK-0000001141',
      status: OperatorTicketStatus.valid,
      issuedAtUtc: DateTime.utc(2026, 9, 10, 7, 23),
    ),
    checkInStatus: OperatorCheckInStatus.notCheckedIn,
    payment: _vnPay(
      'VNPAY-20260910-884920',
      5600000,
      DateTime.utc(2026, 9, 10, 7, 22, 15),
    ),
    paidAmount: 5600000,
    subtotalAmount: 5800000,
    discountAmount: 200000,
    totalAmount: 5600000,
    coupon: const OperatorBookingCoupon(
      code: 'HE2026',
      name: 'Summer 2026',
      discountAmount: 200000,
    ),
    canCancel: true,
  ),
  // Confirmed, paid, checked in at the meeting point. The Vietnam day is the 12th (UTC 17:30 on the 11th).
  OperatorBookingDetail(
    bookingId: '1148',
    bookingCode: 'BK-20260912-0148',
    status: OperatorBookingStatus.confirmed,
    paymentStatus: OperatorPaymentStatus.paid,
    bookedAtUtc: DateTime.utc(2026, 9, 5, 2, 5),
    tour: _banaHills,
    schedule: _schedule(
      '3143',
      DateTime.utc(2026, 9, 11, 17, 30),
      const Duration(hours: 10),
      'Da Nang Cruise Port',
    ),
    booker: const OperatorBookingBooker(
      userId: '5002',
      fullName: 'Le Hoang Nam',
      email: 'nam.le@example.com',
      phoneNumber: '0912345678',
    ),
    quantity: 3,
    participants: [
      _adult('Le Hoang Nam'),
      _adult('Vu Thuy Linh'),
      _child('Le Tuan Khang'),
    ],
    ticket: OperatorBookingTicket(
      ticketCode: 'TK-0000001148',
      status: OperatorTicketStatus.used,
      issuedAtUtc: DateTime.utc(2026, 9, 5, 2, 11),
    ),
    checkInStatus: OperatorCheckInStatus.checkedIn,
    checkedInAtUtc: DateTime.utc(2026, 9, 11, 17, 45),
    payment: _vnPay(
      'VNPAY-20260905-112233',
      3500000,
      DateTime.utc(2026, 9, 5, 2, 10),
    ),
    paidAmount: 3500000,
    subtotalAmount: 3500000,
    discountAmount: 0,
    totalAmount: 3500000,
    canCancel: false,
    cancelBlockedReason: OperatorCancelBlockedReason.checkedIn,
  ),
  // Waiting for payment: no ticket and no payment yet.
  OperatorBookingDetail(
    bookingId: '1146',
    bookingCode: 'BK-20260913-0146',
    status: OperatorBookingStatus.pendingPayment,
    paymentStatus: OperatorPaymentStatus.unpaid,
    bookedAtUtc: DateTime.utc(2026, 9, 11, 9, 20),
    tour: _hoiAn,
    schedule: _schedule(
      '3148',
      DateTime.utc(2026, 9, 13, 6, 30),
      const Duration(hours: 8),
      'Hoi An Ancient Town Gate',
    ),
    booker: const OperatorBookingBooker(
      userId: '5003',
      fullName: 'Pham Minh Tuan',
      email: 'tuan.pm@example.com',
      phoneNumber: '0933445566',
    ),
    quantity: 4,
    participants: [
      _adult('Pham Minh Tuan'),
      _adult('Hoang Kim Oanh'),
      _child('Pham Ngoc Anh'),
      _child('Pham Dang Khoi'),
    ],
    checkInStatus: OperatorCheckInStatus.notCheckedIn,
    paidAmount: 0,
    subtotalAmount: 2800000,
    discountAmount: 0,
    totalAmount: 2800000,
    canCancel: true,
  ),
  // The payment window lapsed: never paid.
  OperatorBookingDetail(
    bookingId: '1144',
    bookingCode: 'BK-20260914-0144',
    status: OperatorBookingStatus.expired,
    paymentStatus: OperatorPaymentStatus.unpaid,
    bookedAtUtc: DateTime.utc(2026, 9, 13, 12, 45),
    tour: _foodTrail,
    schedule: _schedule(
      '3055',
      DateTime.utc(2026, 9, 14, 11),
      const Duration(hours: 4),
      'Dragon Bridge',
    ),
    booker: const OperatorBookingBooker(
      userId: '5004',
      fullName: 'Dang Quoc Bao',
      email: 'bao.dang@example.com',
      phoneNumber: '0977889900',
    ),
    quantity: 2,
    participants: [_adult('Dang Quoc Bao'), _adult('Nguyen Thi Hong')],
    checkInStatus: OperatorCheckInStatus.notCheckedIn,
    paidAmount: 0,
    subtotalAmount: 1100000,
    discountAmount: 0,
    totalAmount: 1100000,
    canCancel: false,
    cancelBlockedReason: OperatorCancelBlockedReason.invalidStatus,
  ),
  // Cancelled and refunded.
  OperatorBookingDetail(
    bookingId: '1110',
    bookingCode: 'BK-20260820-0110',
    status: OperatorBookingStatus.cancelled,
    paymentStatus: OperatorPaymentStatus.refunded,
    bookedAtUtc: DateTime.utc(2026, 8, 10, 3, 50),
    cancelledAtUtc: DateTime.utc(2026, 8, 15, 3),
    cancelReason: 'Customer had an urgent family matter',
    tour: _banaHills,
    schedule: _schedule(
      '3144',
      DateTime.utc(2026, 8, 20, 1),
      const Duration(hours: 10),
      'Da Nang Cruise Port',
    ),
    booker: const OperatorBookingBooker(
      userId: '5005',
      fullName: 'Bui Thanh Huong',
      email: 'huong.bui@example.com',
      phoneNumber: '0988112233',
    ),
    quantity: 2,
    participants: [_adult('Bui Thanh Huong'), _adult('Tran Van Duc')],
    ticket: OperatorBookingTicket(
      ticketCode: 'TK-0000001110',
      status: OperatorTicketStatus.cancelled,
      issuedAtUtc: DateTime.utc(2026, 8, 10, 4, 1),
    ),
    checkInStatus: OperatorCheckInStatus.notCheckedIn,
    payment: _vnPay(
      'VNPAY-20260810-445566',
      2800000,
      DateTime.utc(2026, 8, 10, 4),
    ),
    paidAmount: 2800000,
    subtotalAmount: 2800000,
    discountAmount: 0,
    totalAmount: 2800000,
    canCancel: false,
    cancelBlockedReason: OperatorCancelBlockedReason.invalidStatus,
  ),
  // Completed departure, checked in.
  OperatorBookingDetail(
    bookingId: '1095',
    bookingCode: 'BK-20260815-0095',
    status: OperatorBookingStatus.completed,
    paymentStatus: OperatorPaymentStatus.paid,
    bookedAtUtc: DateTime.utc(2026, 8, 5, 8, 20),
    tour: _hoiAn,
    schedule: _schedule(
      '3149',
      DateTime.utc(2026, 8, 15, 6, 30),
      const Duration(hours: 8),
      'Hoi An Ancient Town Gate',
    ),
    booker: const OperatorBookingBooker(
      userId: '5006',
      fullName: 'Hoang Van Vinh',
      email: 'vinh.hoang@example.com',
      phoneNumber: '0909556677',
    ),
    quantity: 3,
    participants: [
      _adult('Hoang Van Vinh'),
      _adult('Trinh Thu Ha'),
      _child('Hoang Nhat Minh'),
    ],
    ticket: OperatorBookingTicket(
      ticketCode: 'TK-0000001095',
      status: OperatorTicketStatus.used,
      issuedAtUtc: DateTime.utc(2026, 8, 5, 8, 31),
    ),
    checkInStatus: OperatorCheckInStatus.checkedIn,
    checkedInAtUtc: DateTime.utc(2026, 8, 15, 6, 10),
    payment: _vnPay(
      'VNPAY-20260805-334455',
      2100000,
      DateTime.utc(2026, 8, 5, 8, 30),
    ),
    paidAmount: 2100000,
    subtotalAmount: 2100000,
    discountAmount: 0,
    totalAmount: 2100000,
    canCancel: false,
    cancelBlockedReason: OperatorCancelBlockedReason.invalidStatus,
  ),
];
