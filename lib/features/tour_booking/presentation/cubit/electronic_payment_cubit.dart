import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/electronic_payment_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';

/// Cubit managing UC-28 Make Electronic Payment (Screen #67).
///
/// Key Business Rules Enforced:
/// - **Production Truthfulness (`!isDemoMode`)**: Never fabricates gateway sessions,
///   checkout URLs, transactions, or payment confirmations. Strictly emits
///   [ElectronicPaymentStatus.pendingIntegration].
/// - **BR-71**: Initiating payment creates a [PaymentTransactionRecord].
/// - **BR-73 & PC-06**: Client redirect return is NON-AUTHORITATIVE.
///   [simulateGatewayReturnNonAuthoritative] moves the transaction to
///   [PaymentVerificationStatus.pendingVerification] (`MSG90`) while keeping the
///   booking in [BookingLifecycleStatus.pendingPayment]. Only
///   [simulateVerifiedServerPayment] transitions the booking to
///   [BookingLifecycleStatus.confirmed] (`MSG86`) and issues the QR e-ticket (`BR-80`).
/// - **BR-74**: Failed or cancelled gateway attempt (`MSG87`) keeps the booking in
///   [BookingLifecycleStatus.pendingPayment] so the Traveler can retry while the
///   15-minute window remains active.
/// - **BR-90**: Enforces booking ownership (`MSG126`).
final class ElectronicPaymentCubit extends Cubit<ElectronicPaymentState> {
  ElectronicPaymentCubit({
    required String bookingId,
    TourBookingRecord? initialBooking,
    this.isDemoMode = false,
    DemoBookingFunnelStore? demoStore,
    DateTime Function()? nowUtcProvider,
    bool enableTicker = true,
  }) : _demoStore = demoStore ?? DemoBookingFunnelStore.instance,
       _nowUtc = nowUtcProvider ?? (() => DateTime.now().toUtc()),
       _enableTicker = enableTicker,
       super(
         ElectronicPaymentState(
           status: ElectronicPaymentStatus.initial,
           bookingId: bookingId,
           booking: initialBooking,
           isDemoMode: isDemoMode,
         ),
       );

  final bool isDemoMode;
  final DemoBookingFunnelStore _demoStore;
  final DateTime Function() _nowUtc;
  final bool _enableTicker;
  Timer? _countdownTimer;

  Future<void> load() async {
    _countdownTimer?.cancel();
    emit(state.copyWith(status: ElectronicPaymentStatus.loading));

    if (!isDemoMode) {
      // Production truthfulness: No backend payment gateway integration exists yet.
      emit(
        state.copyWith(
          status: ElectronicPaymentStatus.pendingIntegration,
          clearNoticeMessage: true,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    final booking =
        _demoStore.getBooking(state.bookingId) ??
        _demoStore.ensureSeedBookingForDemo(state.bookingId, nowUtc: _nowUtc());

    // Ownership check (BR-90)
    if (booking.ownerTravelerId != _demoStore.activeTravelerId) {
      emit(
        state.copyWith(
          status: ElectronicPaymentStatus.unauthorized,
          booking: booking,
          noticeMessage: ElectronicPaymentState.msg126,
          isErrorNotice: true,
        ),
      );
      return;
    }

    final remaining = _computeRemaining(booking);
    if (booking.status == BookingLifecycleStatus.pendingPayment &&
        remaining <= Duration.zero) {
      final expired =
          _demoStore.expireBooking(booking.bookingId, nowUtc: _nowUtc()) ??
          booking.copyWith(status: BookingLifecycleStatus.expired);
      emit(
        state.copyWith(
          status: ElectronicPaymentStatus.ready,
          booking: expired,
          remainingPaymentDuration: Duration.zero,
          noticeMessage: ElectronicPaymentState.msg80,
          isErrorNotice: true,
        ),
      );
      return;
    }

    String? initialNotice;
    var isError = false;
    if (booking.status == BookingLifecycleStatus.confirmed) {
      initialNotice = ElectronicPaymentState.msg88;
    } else if (booking.status == BookingLifecycleStatus.cancelled) {
      initialNotice = ElectronicPaymentState.msg81;
      isError = true;
    } else if (booking.status == BookingLifecycleStatus.expired) {
      initialNotice = ElectronicPaymentState.msg80;
      isError = true;
    }

    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.ready,
        booking: booking,
        remainingPaymentDuration: remaining,
        noticeMessage: initialNotice,
        clearNoticeMessage: initialNotice == null,
        isErrorNotice: isError,
        clearErrorMessage: true,
      ),
    );

    _startCountdownIfNeeded();
  }

  /// Selects a payment method (`VNPay` or `PayOS`).
  void selectPaymentMethod(PaymentGatewayMethod method) {
    if (!isDemoMode || state.status != ElectronicPaymentStatus.ready) return;
    emit(state.copyWith(selectedMethod: method));
  }

  /// Initiates electronic payment (BR-71) and emits `MSG85`.
  void proceedToPayment() {
    if (!isDemoMode || state.booking == null) return;
    final current = state.booking!;

    if (current.ownerTravelerId != _demoStore.activeTravelerId) {
      emit(
        state.copyWith(
          status: ElectronicPaymentStatus.unauthorized,
          noticeMessage: ElectronicPaymentState.msg126,
          isErrorNotice: true,
        ),
      );
      return;
    }

    if (current.status == BookingLifecycleStatus.confirmed) {
      emit(
        state.copyWith(
          noticeMessage: ElectronicPaymentState.msg88,
          isErrorNotice: false,
        ),
      );
      return;
    }

    if (current.status == BookingLifecycleStatus.cancelled) {
      emit(
        state.copyWith(
          noticeMessage: ElectronicPaymentState.msg81,
          isErrorNotice: true,
        ),
      );
      return;
    }

    final remaining = _computeRemaining(current);
    if (current.status == BookingLifecycleStatus.expired ||
        remaining <= Duration.zero) {
      final expired =
          _demoStore.expireBooking(current.bookingId, nowUtc: _nowUtc()) ??
          current.copyWith(status: BookingLifecycleStatus.expired);
      emit(
        state.copyWith(
          booking: expired,
          remainingPaymentDuration: Duration.zero,
          noticeMessage: ElectronicPaymentState.msg80,
          isErrorNotice: true,
        ),
      );
      return;
    }

    final updated =
        _demoStore.initiatePayment(
          current.bookingId,
          state.selectedMethod,
          nowUtc: _nowUtc(),
        ) ??
        current;

    emit(
      state.copyWith(
        booking: updated,
        remainingPaymentDuration: remaining,
        noticeMessage: ElectronicPaymentState.msg85,
        isErrorNotice: false,
      ),
    );
  }

  /// Cancels the unpaid booking after CR-05 confirmation (`BR-66`, `MSG81`).
  void cancelBooking() {
    if (!isDemoMode || state.booking == null) return;
    final current = state.booking!;

    if (current.ownerTravelerId != _demoStore.activeTravelerId) {
      emit(
        state.copyWith(
          status: ElectronicPaymentStatus.unauthorized,
          noticeMessage: ElectronicPaymentState.msg126,
          isErrorNotice: true,
        ),
      );
      return;
    }

    if (current.status == BookingLifecycleStatus.confirmed) {
      emit(
        state.copyWith(
          noticeMessage: ElectronicPaymentState.msg88,
          isErrorNotice: false,
        ),
      );
      return;
    }

    _countdownTimer?.cancel();
    final updated =
        _demoStore.cancelBooking(current.bookingId, nowUtc: _nowUtc()) ??
        current.copyWith(status: BookingLifecycleStatus.cancelled);

    emit(
      state.copyWith(
        booking: updated,
        remainingPaymentDuration: Duration.zero,
        noticeMessage: ElectronicPaymentState.msg81,
        isErrorNotice: true,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Demo Gateway & Server Verification Simulations (Debug + ?demo=true only)
  // ───────────────────────────────────────────────────────────────────────────

  /// Simulates client redirect return from VNPay/PayOS BEFORE server IPN arrives.
  ///
  /// Per **BR-73** and **PC-06**, this MUST NOT mark the booking `Confirmed`.
  /// Emits `MSG90` and keeps booking status `Pending Payment`.
  void simulateGatewayReturnNonAuthoritative() {
    if (!isDemoMode || state.booking == null) return;
    final updated = _demoStore.recordGatewayReturnNonAuthoritative(
      state.booking!.bookingId,
      fallbackMethod: state.selectedMethod,
      nowUtc: _nowUtc(),
    );
    if (updated == null) return;

    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.ready,
        booking: updated,
        noticeMessage: ElectronicPaymentState.msg90,
        isErrorNotice: false,
      ),
    );
  }

  /// Simulates verified server IPN/query confirmation (`BR-73`, `BR-80`, `MSG86`).
  /// Transitions booking to `Confirmed` and issues Demo QR e-ticket.
  void simulateVerifiedServerPayment() {
    if (!isDemoMode || state.booking == null) return;
    final current = state.booking!;
    if (current.status == BookingLifecycleStatus.expired ||
        current.status == BookingLifecycleStatus.cancelled) {
      return;
    }

    _countdownTimer?.cancel();
    final updated = _demoStore.recordVerifiedServerPayment(
      current.bookingId,
      fallbackMethod: state.selectedMethod,
      nowUtc: _nowUtc(),
    );
    if (updated == null) return;

    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.ready,
        booking: updated,
        noticeMessage: ElectronicPaymentState.msg86,
        isErrorNotice: false,
      ),
    );
  }

  /// Simulates gateway failure or user cancellation at gateway (`BR-74`, `MSG87`).
  /// Booking remains `Pending Payment` while the 15-minute window is still active.
  void simulateGatewayFailedOrCancelled() {
    if (!isDemoMode || state.booking == null) return;
    final updated = _demoStore.recordGatewayFailureOrCancel(
      state.booking!.bookingId,
      fallbackMethod: state.selectedMethod,
      nowUtc: _nowUtc(),
    );
    if (updated == null) return;

    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.ready,
        booking: updated,
        noticeMessage: ElectronicPaymentState.msg87,
        isErrorNotice: true,
      ),
    );
  }

  /// Simulates gateway connection timeout (`MSG89`).
  void simulateGatewayTimeout() {
    if (!isDemoMode || state.booking == null) return;
    final updated = _demoStore.recordGatewayTimeout(
      state.booking!.bookingId,
      fallbackMethod: state.selectedMethod,
      nowUtc: _nowUtc(),
    );
    if (updated == null) return;

    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.ready,
        booking: updated,
        noticeMessage: ElectronicPaymentState.msg89,
        isErrorNotice: true,
      ),
    );
  }

  /// Simulates amount mismatch / manual reconciliation required (`MSG92`).
  /// Booking MUST remain `Pending Payment` and never transition to `Confirmed`.
  void simulateReconciliationMismatch() {
    if (!isDemoMode || state.booking == null) return;
    final updated = _demoStore.recordReconciliationMismatch(
      state.booking!.bookingId,
      fallbackMethod: state.selectedMethod,
      nowUtc: _nowUtc(),
    );
    if (updated == null) return;

    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.ready,
        booking: updated,
        noticeMessage: ElectronicPaymentState.msg92,
        isErrorNotice: true,
      ),
    );
  }

  /// Simulates duplicate/unmatched payment notification (`MSG91`).
  void simulateDuplicateOrUnmatchedNotification() {
    if (!isDemoMode || state.booking == null) return;
    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.ready,
        noticeMessage: ElectronicPaymentState.msg91,
        isErrorNotice: true,
      ),
    );
  }

  /// Simulates 15-minute payment window expiry (`BR-66`, `MSG80`).
  void simulatePaymentWindowExpired() {
    if (!isDemoMode || state.booking == null) return;
    _countdownTimer?.cancel();
    final updated = _demoStore.expireBooking(
      state.booking!.bookingId,
      nowUtc: _nowUtc(),
    );
    if (updated == null) return;

    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.ready,
        booking: updated,
        remainingPaymentDuration: Duration.zero,
        noticeMessage: ElectronicPaymentState.msg80,
        isErrorNotice: true,
      ),
    );
  }

  /// Simulates already paid booking (`MSG88`).
  void simulateAlreadyPaid() {
    if (!isDemoMode || state.booking == null) return;
    _countdownTimer?.cancel();
    final updated = _demoStore.recordVerifiedServerPayment(
      state.booking!.bookingId,
      fallbackMethod: state.selectedMethod,
      nowUtc: _nowUtc(),
    );
    if (updated == null) return;

    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.ready,
        booking: updated,
        noticeMessage: ElectronicPaymentState.msg88,
        isErrorNotice: false,
      ),
    );
  }

  /// Simulates non-owner access (`BR-90`, `MSG126`).
  void simulateNonOwnerAccess() {
    if (!isDemoMode || state.booking == null) return;
    _countdownTimer?.cancel();
    final updated = _demoStore.setBookingOwner(
      state.booking!.bookingId,
      DemoBookingFunnelStore.nonOwnerTravelerId,
    );
    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.unauthorized,
        booking: updated,
        noticeMessage: ElectronicPaymentState.msg126,
        isErrorNotice: true,
      ),
    );
  }

  /// Simulates system/network failure (`MSG127`).
  void simulateSystemError() {
    if (!isDemoMode) return;
    _countdownTimer?.cancel();
    emit(
      state.copyWith(
        status: ElectronicPaymentStatus.error,
        errorMessage: ElectronicPaymentState.msg127,
      ),
    );
  }

  /// Resets the Demo booking back to an active `Pending Payment` state with 15 minutes remaining.
  void resetDemoPaymentState() {
    if (!isDemoMode) return;
    _countdownTimer?.cancel();
    final currentId = state.bookingId;
    _demoStore.setActiveTravelerId(DemoBookingFunnelStore.defaultTravelerId);
    final existing = _demoStore.getBooking(currentId);
    if (existing != null) {
      final now = _nowUtc();
      final resetBooking = TourBookingRecord(
        bookingId: existing.bookingId,
        ownerTravelerId: DemoBookingFunnelStore.defaultTravelerId,
        tourId: existing.tourId,
        tourTitle: existing.tourTitle,
        operatorName: existing.operatorName,
        scheduleId: existing.scheduleId,
        departureAtUtc: existing.departureAtUtc,
        returnAtUtc: existing.returnAtUtc,
        durationDays: existing.durationDays,
        meetingPoint: existing.meetingPoint,
        participantCount: existing.participantCount,
        participants: existing.participants,
        contactInfo: existing.contactInfo,
        unitPrice: existing.unitPrice,
        subtotal: existing.subtotal,
        discountAmount: existing.discountAmount,
        totalAmount: existing.totalAmount,
        currency: existing.currency,
        appliedVoucherCode: existing.appliedVoucherCode,
        status: BookingLifecycleStatus.pendingPayment,
        createdAtUtc: now,
        paymentExpiresAtUtc: now.add(const Duration(minutes: 15)),
      );
      // Update in store via ensureSeed/setBookingOwner
      _demoStore.setBookingOwner(
        currentId,
        DemoBookingFunnelStore.defaultTravelerId,
      );
      emit(
        state.copyWith(
          status: ElectronicPaymentStatus.ready,
          booking: resetBooking,
          remainingPaymentDuration: const Duration(minutes: 15),
          clearNoticeMessage: true,
          clearErrorMessage: true,
          isErrorNotice: false,
        ),
      );
      _startCountdownIfNeeded();
      return;
    }
    load();
  }

  Duration _computeRemaining(TourBookingRecord booking) {
    final diff = booking.paymentExpiresAtUtc.difference(_nowUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _startCountdownIfNeeded() {
    if (!_enableTicker) return;
    _countdownTimer?.cancel();
    final booking = state.booking;
    if (booking == null ||
        booking.status != BookingLifecycleStatus.pendingPayment) {
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      final current = state.booking;
      if (current == null ||
          current.status != BookingLifecycleStatus.pendingPayment) {
        timer.cancel();
        return;
      }
      final remaining = _computeRemaining(current);
      if (remaining <= Duration.zero) {
        timer.cancel();
        simulatePaymentWindowExpired();
      } else {
        emit(state.copyWith(remainingPaymentDuration: remaining));
      }
    });
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }
}
