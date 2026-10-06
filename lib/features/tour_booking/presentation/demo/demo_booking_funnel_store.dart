import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_contact_info.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';

/// Result of evaluating a promotional voucher code in Demo mode (BR-97..BR-100).
final class DemoVoucherEvaluation {
  const DemoVoucherEvaluation({
    required this.isValid,
    this.normalizedCode,
    this.discountAmount = 0,
    this.message,
  });

  final bool isValid;
  final String? normalizedCode;
  final int discountAmount;
  final String? message;
}

/// Shared in-memory Demo funnel state for UC-27, UC-28, and UC-29.
///
/// Strictly used ONLY when `isDemoMode == true` (`kDebugMode && ?demo=true`).
/// Production mode (`!isDemoMode`) never reads from or writes to this store.
final class DemoBookingFunnelStore {
  DemoBookingFunnelStore._();

  static final DemoBookingFunnelStore instance = DemoBookingFunnelStore._();

  static const String defaultTravelerId = 'demo-traveler-001';
  static const String nonOwnerTravelerId = 'demo-other-traveler-999';
  static const int maxConcurrentUnpaidBookings = 3;

  // Canonical messages for voucher evaluation
  static const String msg100 = 'The voucher has been applied successfully.';
  static const String msg101 =
      'The voucher code is invalid, expired, or no longer available.';
  static const String msg102 =
      'The booking does not meet the minimum spend requirement for this voucher.';

  String _activeTravelerId = defaultTravelerId;
  int _bookingCounter = 1000;
  int _transactionCounter = 2000;
  int _ticketCounter = 3000;
  bool _simulateMaxUnpaidReached = false;

  final Map<String, TourBookingRecord> _bookingsById = {};
  final Map<String, int> _heldSlotsByScheduleId = {};
  final Map<String, int> _confirmedSlotsByScheduleId = {};

  String get activeTravelerId => _activeTravelerId;

  bool get simulateMaxUnpaidReached => _simulateMaxUnpaidReached;

  int get totalBookingsCount => _bookingsById.length;

  /// Resets all in-memory Demo state for deterministic test isolation.
  void reset() {
    _activeTravelerId = defaultTravelerId;
    _bookingCounter = 1000;
    _transactionCounter = 2000;
    _ticketCounter = 3000;
    _simulateMaxUnpaidReached = false;
    _bookingsById.clear();
    _heldSlotsByScheduleId.clear();
    _confirmedSlotsByScheduleId.clear();
  }

  void setActiveTravelerId(String travelerId) {
    _activeTravelerId = travelerId;
  }

  void setSimulateMaxUnpaidReached(bool value) {
    _simulateMaxUnpaidReached = value;
  }

  /// Returns how many slots are currently held or confirmed for [scheduleId] in Demo mode.
  int reservedSlotsForSchedule(String scheduleId) {
    final held = _heldSlotsByScheduleId[scheduleId] ?? 0;
    final confirmed = _confirmedSlotsByScheduleId[scheduleId] ?? 0;
    return held + confirmed;
  }

  int heldSlotsForSchedule(String scheduleId) =>
      _heldSlotsByScheduleId[scheduleId] ?? 0;

  /// Returns the number of active unpaid (`Pending Payment`) bookings for [_activeTravelerId].
  int activeUnpaidBookingsCount() {
    return _bookingsById.values
        .where(
          (b) =>
              b.ownerTravelerId == _activeTravelerId &&
              b.status == BookingLifecycleStatus.pendingPayment,
        )
        .length;
  }

  bool hasReachedMaxConcurrentUnpaidBookings() {
    if (_simulateMaxUnpaidReached) return true;
    return activeUnpaidBookingsCount() >= maxConcurrentUnpaidBookings;
  }

  /// Evaluates a promotional voucher code in Demo mode following BR-97, BR-98, BR-99, BR-100.
  DemoVoucherEvaluation evaluateVoucher({
    required String rawCode,
    required int subtotal,
  }) {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      return const DemoVoucherEvaluation(isValid: false, message: msg101);
    }

    switch (code) {
      case 'SUMMER2026':
        if (subtotal < 1500000) {
          return const DemoVoucherEvaluation(isValid: false, message: msg102);
        }
        final discount = 200000 > subtotal ? subtotal : 200000;
        return DemoVoucherEvaluation(
          isValid: true,
          normalizedCode: code,
          discountAmount: discount,
          message: msg100,
        );
      case 'WELCOME10':
        if (subtotal < 1000000) {
          return const DemoVoucherEvaluation(isValid: false, message: msg102);
        }
        final rawDiscount = (subtotal * 10) ~/ 100;
        final capped = rawDiscount > 500000 ? 500000 : rawDiscount;
        final discount = capped > subtotal ? subtotal : capped;
        return DemoVoucherEvaluation(
          isValid: true,
          normalizedCode: code,
          discountAmount: discount,
          message: msg100,
        );
      case 'BIGSAVE':
        // Demonstrates BR-100: discount cannot exceed subtotal; total never negative.
        const fixedDiscount = 5000000;
        final discount = fixedDiscount > subtotal ? subtotal : fixedDiscount;
        return DemoVoucherEvaluation(
          isValid: true,
          normalizedCode: code,
          discountAmount: discount,
          message: msg100,
        );
      case 'VIP500':
        if (subtotal < 15000000) {
          return const DemoVoucherEvaluation(isValid: false, message: msg102);
        }
        final discount = 500000 > subtotal ? subtotal : 500000;
        return DemoVoucherEvaluation(
          isValid: true,
          normalizedCode: code,
          discountAmount: discount,
          message: msg100,
        );
      case 'EXPIRED2025':
      case 'USEDUP':
      case 'OTHEROP':
      default:
        return const DemoVoucherEvaluation(isValid: false, message: msg101);
    }
  }

  /// Creates a `Pending Payment` booking and holds slots for 15 minutes (BR-66).
  TourBookingRecord createPendingBooking({
    required String tourId,
    required String tourTitle,
    required String operatorName,
    required String scheduleId,
    required DateTime departureAtUtc,
    required int durationDays,
    required String meetingPoint,
    required int participantCount,
    required List<BookingParticipant> participants,
    required BookingContactInfo contactInfo,
    required int unitPrice,
    required int discountAmount,
    String? appliedVoucherCode,
    DateTime? nowUtc,
  }) {
    _bookingCounter += 1;
    final bookingId = 'BK-DEMO-$_bookingCounter';
    final createdAt = nowUtc ?? DateTime.now().toUtc();
    final expiresAt = createdAt.add(const Duration(minutes: 15));
    final subtotal = unitPrice * participantCount;
    final clampedDiscount = discountAmount > subtotal
        ? subtotal
        : (discountAmount < 0 ? 0 : discountAmount);
    final totalAmount = subtotal - clampedDiscount;

    final record = TourBookingRecord(
      bookingId: bookingId,
      ownerTravelerId: _activeTravelerId,
      tourId: tourId,
      tourTitle: tourTitle,
      operatorName: operatorName,
      scheduleId: scheduleId,
      departureAtUtc: departureAtUtc,
      returnAtUtc: departureAtUtc.add(Duration(days: durationDays)),
      durationDays: durationDays,
      meetingPoint: meetingPoint,
      participantCount: participantCount,
      participants: List.unmodifiable(participants),
      contactInfo: contactInfo,
      unitPrice: unitPrice,
      subtotal: subtotal,
      discountAmount: clampedDiscount,
      totalAmount: totalAmount,
      currency: 'VND',
      appliedVoucherCode: appliedVoucherCode,
      status: BookingLifecycleStatus.pendingPayment,
      createdAtUtc: createdAt,
      paymentExpiresAtUtc: expiresAt,
    );

    _bookingsById[bookingId] = record;
    _heldSlotsByScheduleId[scheduleId] =
        (_heldSlotsByScheduleId[scheduleId] ?? 0) + participantCount;

    return record;
  }

  TourBookingRecord? getBooking(String bookingId) => _bookingsById[bookingId];

  /// Ensures a deterministic seed booking exists when navigating directly to
  /// UC-28 or UC-29 in Demo mode (`?demo=true`).
  TourBookingRecord ensureSeedBookingForDemo(
    String bookingId, {
    bool confirmedWithTicket = false,
    DateTime? nowUtc,
  }) {
    final existing = _bookingsById[bookingId];
    if (existing != null) {
      if (confirmedWithTicket &&
          existing.status != BookingLifecycleStatus.confirmed) {
        return recordVerifiedServerPayment(bookingId, nowUtc: nowUtc) ??
            existing;
      }
      return existing;
    }

    final createdAt = nowUtc ?? DateTime.now().toUtc();
    final departureAt = DateTime.utc(2026, 10, 15, 2, 0);
    const scheduleId = 'sch-001';
    const participantCount = 2;
    const unitPrice = 2890000;
    const subtotal = unitPrice * participantCount;
    const discountAmount = 200000;
    const totalAmount = subtotal - discountAmount;

    var record = TourBookingRecord(
      bookingId: bookingId,
      ownerTravelerId: defaultTravelerId,
      tourId: 'demo-tour-1',
      tourTitle: 'Khám phá Đà Nẵng – Bán đảo Sơn Trà – Ngũ Hành Sơn 3N2Đ',
      operatorName: 'Saigontourist Miền Trung',
      scheduleId: scheduleId,
      departureAtUtc: departureAt,
      returnAtUtc: departureAt.add(const Duration(days: 3)),
      durationDays: 3,
      meetingPoint: 'Sân bay Quốc tế Đà Nẵng (Cổng ga đến quốc nội A2)',
      participantCount: participantCount,
      participants: const [
        BookingParticipant(
          fullName: 'Nguyễn Minh Quân',
          dateOfBirth: '15/05/1996',
          identityDocumentNumber: '048096001234',
          phoneNumber: '0905123456',
        ),
        BookingParticipant(
          fullName: 'Trần Bảo Ngọc',
          dateOfBirth: '20/08/1998',
          identityDocumentNumber: '048198005678',
          phoneNumber: '0905987654',
        ),
      ],
      contactInfo: const BookingContactInfo(
        fullName: 'Nguyễn Minh Quân',
        email: 'minhquan.traveler@example.com',
        phoneNumber: '0905123456',
      ),
      unitPrice: unitPrice,
      subtotal: subtotal,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      currency: 'VND',
      appliedVoucherCode: 'SUMMER2026',
      status: BookingLifecycleStatus.pendingPayment,
      createdAtUtc: createdAt,
      paymentExpiresAtUtc: createdAt.add(const Duration(minutes: 15)),
    );

    _bookingsById[bookingId] = record;
    _heldSlotsByScheduleId[scheduleId] =
        (_heldSlotsByScheduleId[scheduleId] ?? 0) + participantCount;

    if (confirmedWithTicket) {
      record =
          recordVerifiedServerPayment(bookingId, nowUtc: createdAt) ?? record;
    }

    return record;
  }

  /// Creates a payment transaction record when the Traveler initiates payment (BR-71).
  TourBookingRecord? initiatePayment(
    String bookingId,
    PaymentGatewayMethod method, {
    DateTime? nowUtc,
  }) {
    final booking = _bookingsById[bookingId];
    if (booking == null) return null;

    _transactionCounter += 1;
    final now = nowUtc ?? DateTime.now().toUtc();
    final tx = PaymentTransactionRecord(
      transactionId: 'TX-DEMO-$_transactionCounter',
      bookingId: bookingId,
      method: method,
      amountVnd: booking.totalAmount,
      currency: booking.currency,
      status: PaymentVerificationStatus.redirectingToGateway,
      createdAtUtc: now,
      updatedAtUtc: now,
      gatewayReference: '${method.name.toUpperCase()}-REF-$_transactionCounter',
    );

    final updated = booking.copyWith(latestTransaction: tx);
    _bookingsById[bookingId] = updated;
    return updated;
  }

  /// Records a client/gateway return redirect.
  ///
  /// Per **BR-73** and **PC-06**, client redirect is NON-AUTHORITATIVE:
  /// Booking status MUST remain [BookingLifecycleStatus.pendingPayment] until
  /// verified server IPN/query confirmation completes.
  TourBookingRecord? recordGatewayReturnNonAuthoritative(
    String bookingId, {
    PaymentGatewayMethod? fallbackMethod,
    DateTime? nowUtc,
  }) {
    var booking = _bookingsById[bookingId];
    if (booking == null) return null;

    final now = nowUtc ?? DateTime.now().toUtc();
    var tx = booking.latestTransaction;
    if (tx == null) {
      _transactionCounter += 1;
      tx = PaymentTransactionRecord(
        transactionId: 'TX-DEMO-$_transactionCounter',
        bookingId: bookingId,
        method: fallbackMethod ?? PaymentGatewayMethod.vnpay,
        amountVnd: booking.totalAmount,
        currency: booking.currency,
        status: PaymentVerificationStatus.pendingVerification,
        createdAtUtc: now,
        updatedAtUtc: now,
      );
    } else {
      tx = tx.copyWith(
        status: PaymentVerificationStatus.pendingVerification,
        updatedAtUtc: now,
      );
    }

    booking = booking.copyWith(
      status: BookingLifecycleStatus.pendingPayment,
      latestTransaction: tx,
    );
    _bookingsById[bookingId] = booking;
    return booking;
  }

  /// Records verified server IPN/query confirmation (BR-73) and issues QR e-ticket (BR-80, BR-82).
  TourBookingRecord? recordVerifiedServerPayment(
    String bookingId, {
    PaymentGatewayMethod? fallbackMethod,
    DateTime? nowUtc,
  }) {
    var booking = _bookingsById[bookingId];
    if (booking == null) return null;

    final now = nowUtc ?? DateTime.now().toUtc();
    var tx = booking.latestTransaction;
    if (tx == null) {
      _transactionCounter += 1;
      tx = PaymentTransactionRecord(
        transactionId: 'TX-DEMO-$_transactionCounter',
        bookingId: bookingId,
        method: fallbackMethod ?? PaymentGatewayMethod.vnpay,
        amountVnd: booking.totalAmount,
        currency: booking.currency,
        status: PaymentVerificationStatus.verifiedSuccess,
        createdAtUtc: now,
        updatedAtUtc: now,
        gatewayReference: 'VERIFIED-IPN-$_transactionCounter',
      );
    } else {
      tx = tx.copyWith(
        status: PaymentVerificationStatus.verifiedSuccess,
        updatedAtUtc: now,
      );
    }

    // Move slots from held to confirmed
    if (booking.status == BookingLifecycleStatus.pendingPayment) {
      final currentHeld = _heldSlotsByScheduleId[booking.scheduleId] ?? 0;
      final nextHeld = currentHeld - booking.participantCount;
      _heldSlotsByScheduleId[booking.scheduleId] = nextHeld < 0 ? 0 : nextHeld;
      _confirmedSlotsByScheduleId[booking.scheduleId] =
          (_confirmedSlotsByScheduleId[booking.scheduleId] ?? 0) +
          booking.participantCount;
    }

    _ticketCounter += 1;
    final eticket =
        booking.eticket ??
        QrEticketRecord(
          ticketId: 'ETK-DEMO-$_ticketCounter',
          bookingId: bookingId,
          opaqueQrPayload: 'DEMO-QR-PAYLOAD::$bookingId::v1',
          ticketStatus: TicketLifecycleStatus.valid,
          issuedAtUtc: now,
          lastRefreshedAtUtc: now,
          refreshVersion: 1,
          validityWindowNote:
              'Hiệu lực mở cổng: 24 giờ trước giờ khởi hành đến khi hoàn tất điểm danh tại điểm tập trung.',
        );

    booking = booking.copyWith(
      status: BookingLifecycleStatus.confirmed,
      latestTransaction: tx,
      eticket: eticket,
    );
    _bookingsById[bookingId] = booking;
    return booking;
  }

  /// Records failed or user-cancelled gateway attempt (BR-74: stays Pending Payment while window active).
  TourBookingRecord? recordGatewayFailureOrCancel(
    String bookingId, {
    PaymentGatewayMethod? fallbackMethod,
    DateTime? nowUtc,
  }) {
    final booking = _bookingsById[bookingId];
    if (booking == null) return null;

    final now = nowUtc ?? DateTime.now().toUtc();
    final tx =
        (booking.latestTransaction ??
                PaymentTransactionRecord(
                  transactionId: 'TX-DEMO-${++_transactionCounter}',
                  bookingId: bookingId,
                  method: fallbackMethod ?? PaymentGatewayMethod.vnpay,
                  amountVnd: booking.totalAmount,
                  currency: booking.currency,
                  status: PaymentVerificationStatus.failedOrCancelled,
                  createdAtUtc: now,
                  updatedAtUtc: now,
                ))
            .copyWith(
              status: PaymentVerificationStatus.failedOrCancelled,
              updatedAtUtc: now,
            );

    final updated = booking.copyWith(latestTransaction: tx);
    _bookingsById[bookingId] = updated;
    return updated;
  }

  /// Records gateway timeout (`MSG89`). Booking stays `Pending Payment`.
  TourBookingRecord? recordGatewayTimeout(
    String bookingId, {
    PaymentGatewayMethod? fallbackMethod,
    DateTime? nowUtc,
  }) {
    final booking = _bookingsById[bookingId];
    if (booking == null) return null;

    final now = nowUtc ?? DateTime.now().toUtc();
    final tx =
        (booking.latestTransaction ??
                PaymentTransactionRecord(
                  transactionId: 'TX-DEMO-${++_transactionCounter}',
                  bookingId: bookingId,
                  method: fallbackMethod ?? PaymentGatewayMethod.vnpay,
                  amountVnd: booking.totalAmount,
                  currency: booking.currency,
                  status: PaymentVerificationStatus.timeout,
                  createdAtUtc: now,
                  updatedAtUtc: now,
                ))
            .copyWith(
              status: PaymentVerificationStatus.timeout,
              updatedAtUtc: now,
            );

    final updated = booking.copyWith(latestTransaction: tx);
    _bookingsById[bookingId] = updated;
    return updated;
  }

  /// Records amount/reference reconciliation mismatch (`MSG92` / `MSG91`).
  /// Booking MUST NOT transition to `Confirmed`.
  TourBookingRecord? recordReconciliationMismatch(
    String bookingId, {
    PaymentGatewayMethod? fallbackMethod,
    DateTime? nowUtc,
  }) {
    final booking = _bookingsById[bookingId];
    if (booking == null) return null;

    final now = nowUtc ?? DateTime.now().toUtc();
    final tx =
        (booking.latestTransaction ??
                PaymentTransactionRecord(
                  transactionId: 'TX-DEMO-${++_transactionCounter}',
                  bookingId: bookingId,
                  method: fallbackMethod ?? PaymentGatewayMethod.vnpay,
                  amountVnd: booking.totalAmount,
                  currency: booking.currency,
                  status: PaymentVerificationStatus.reconciliationRequired,
                  createdAtUtc: now,
                  updatedAtUtc: now,
                ))
            .copyWith(
              status: PaymentVerificationStatus.reconciliationRequired,
              updatedAtUtc: now,
            );

    final updated = booking.copyWith(
      status: BookingLifecycleStatus.pendingPayment,
      latestTransaction: tx,
    );
    _bookingsById[bookingId] = updated;
    return updated;
  }

  /// Expires an unpaid booking and releases held slots (BR-66, MSG80).
  TourBookingRecord? expireBooking(String bookingId, {DateTime? nowUtc}) {
    final booking = _bookingsById[bookingId];
    if (booking == null) return null;

    if (booking.status == BookingLifecycleStatus.pendingPayment) {
      _releaseHeldSlots(booking.scheduleId, booking.participantCount);
    }

    final expiredTime = (nowUtc ?? DateTime.now().toUtc()).subtract(
      const Duration(seconds: 1),
    );
    final updated = booking.copyWith(
      status: BookingLifecycleStatus.expired,
      paymentExpiresAtUtc: expiredTime,
    );
    _bookingsById[bookingId] = updated;
    return updated;
  }

  /// Cancels a booking and releases held slots (BR-66, BR-86, MSG81).
  TourBookingRecord? cancelBooking(String bookingId, {DateTime? nowUtc}) {
    final booking = _bookingsById[bookingId];
    if (booking == null) return null;

    if (booking.status == BookingLifecycleStatus.pendingPayment) {
      _releaseHeldSlots(booking.scheduleId, booking.participantCount);
    }

    final now = nowUtc ?? DateTime.now().toUtc();
    final updatedEticket = booking.eticket?.copyWith(
      ticketStatus: TicketLifecycleStatus.cancelled,
      lastRefreshedAtUtc: now,
    );

    final updated = booking.copyWith(
      status: BookingLifecycleStatus.cancelled,
      eticket: updatedEticket,
    );
    _bookingsById[bookingId] = updated;
    return updated;
  }

  /// Refreshes the QR code payload in Demo mode while strictly preserving the
  /// ticket's current [TicketLifecycleStatus].
  TourBookingRecord? refreshEticketPayload(
    String bookingId, {
    DateTime? nowUtc,
  }) {
    final booking = _bookingsById[bookingId];
    if (booking == null || booking.eticket == null) return null;

    final currentTicket = booking.eticket!;
    final nextVersion = currentTicket.refreshVersion + 1;
    final now = nowUtc ?? DateTime.now().toUtc();

    final refreshedTicket = currentTicket.copyWith(
      opaqueQrPayload: 'DEMO-QR-PAYLOAD::$bookingId::v$nextVersion',
      lastRefreshedAtUtc: now,
      refreshVersion: nextVersion,
      // Explicitly preserve current ticketStatus
      ticketStatus: currentTicket.ticketStatus,
    );

    final updated = booking.copyWith(eticket: refreshedTicket);
    _bookingsById[bookingId] = updated;
    return updated;
  }

  /// Simulates a specific [TicketLifecycleStatus] in Demo mode for UC-29.
  TourBookingRecord? simulateTicketStatus(
    String bookingId,
    TicketLifecycleStatus ticketStatus, {
    DateTime? nowUtc,
  }) {
    final booking = _bookingsById[bookingId];
    if (booking == null || booking.eticket == null) return null;

    final now = nowUtc ?? DateTime.now().toUtc();
    final updatedTicket = booking.eticket!.copyWith(
      ticketStatus: ticketStatus,
      lastRefreshedAtUtc: now,
    );

    final updatedBookingStatus = ticketStatus == TicketLifecycleStatus.cancelled
        ? BookingLifecycleStatus.cancelled
        : BookingLifecycleStatus.confirmed;

    final updated = booking.copyWith(
      status: updatedBookingStatus,
      eticket: updatedTicket,
    );
    _bookingsById[bookingId] = updated;
    return updated;
  }

  /// Simulates ownership mismatch or restores ownership for BR-90 testing.
  TourBookingRecord? setBookingOwner(String bookingId, String ownerTravelerId) {
    final booking = _bookingsById[bookingId];
    if (booking == null) return null;
    final updated = booking.copyWith(ownerTravelerId: ownerTravelerId);
    _bookingsById[bookingId] = updated;
    return updated;
  }

  void _releaseHeldSlots(String scheduleId, int count) {
    final current = _heldSlotsByScheduleId[scheduleId] ?? 0;
    final next = current - count;
    _heldSlotsByScheduleId[scheduleId] = next < 0 ? 0 : next;
  }
}
