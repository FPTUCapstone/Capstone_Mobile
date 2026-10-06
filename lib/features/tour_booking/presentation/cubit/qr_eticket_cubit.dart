import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/qr_eticket_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';

/// Cubit managing UC-29 View QR E-ticket (Screen #69).
///
/// Key Business Rules Enforced:
/// - **Production Truthfulness (`!isDemoMode`)**: Never generates or renders a
///   fake QR e-ticket payload in production mode. Strictly emits
///   [QrEticketStatus.pendingIntegration].
/// - **BR-80 & BR-82**: Only `Confirmed` bookings may display an active QR e-ticket.
///   Unconfirmed (`Pending Payment`) bookings emit [QrEticketStatus.unconfirmedBooking]
///   with `MSG90`.
/// - **BR-86**: Cancelled bookings invalidate the QR e-ticket (`MSG74`).
/// - **BR-90**: Enforces booking ownership (`MSG126`).
final class QrEticketCubit extends Cubit<QrEticketState> {
  QrEticketCubit({
    required String bookingId,
    TourBookingRecord? initialBooking,
    this.isDemoMode = false,
    DemoBookingFunnelStore? demoStore,
  }) : _demoStore = demoStore ?? DemoBookingFunnelStore.instance,
       super(
         QrEticketState(
           status: QrEticketStatus.initial,
           bookingId: bookingId,
           booking: initialBooking,
           isDemoMode: isDemoMode,
         ),
       );

  final bool isDemoMode;
  final DemoBookingFunnelStore _demoStore;

  Future<void> load() async {
    emit(state.copyWith(status: QrEticketStatus.loading));

    if (!isDemoMode) {
      // Production truthfulness: Never forge a QR e-ticket without Backend verification.
      emit(
        state.copyWith(
          status: QrEticketStatus.pendingIntegration,
          clearStatusMessage: true,
          clearErrorMessage: true,
        ),
      );
      return;
    }

    final booking =
        _demoStore.getBooking(state.bookingId) ??
        state.booking ??
        _demoStore.ensureSeedBookingForDemo(
          state.bookingId,
          confirmedWithTicket: true,
        );

    _emitStateForBooking(booking);
  }

  /// Refreshes the QR code payload in Demo mode (`[Refresh QR Code]`).
  ///
  /// Strictly preserves the current [TicketLifecycleStatus] (`Used` stays `Used`,
  /// `Cancelled` stays `Cancelled`, `Expired` stays `Expired`, `Not Yet Active`
  /// stays `Not Yet Active`, `Valid` stays `Valid`).
  void refreshQrCode() {
    if (!isDemoMode || state.booking == null) return;

    final current = state.booking!;
    if (current.ownerTravelerId != _demoStore.activeTravelerId) {
      emit(
        state.copyWith(
          status: QrEticketStatus.unauthorized,
          statusMessage: QrEticketState.msg126,
          isWarningOrError: true,
        ),
      );
      return;
    }

    if (current.status == BookingLifecycleStatus.pendingPayment ||
        current.eticket == null) {
      emit(
        state.copyWith(
          status: QrEticketStatus.unconfirmedBooking,
          statusMessage: QrEticketState.msg90,
          isWarningOrError: true,
        ),
      );
      return;
    }

    final updated =
        _demoStore.refreshEticketPayload(current.bookingId) ?? current;
    _emitStateForBooking(updated);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Demo Lifecycle Simulations (Debug + ?demo=true only)
  // ───────────────────────────────────────────────────────────────────────────

  void simulateTicketStatus(TicketLifecycleStatus ticketStatus) {
    if (!isDemoMode || state.booking == null) return;
    _demoStore.setActiveTravelerId(DemoBookingFunnelStore.defaultTravelerId);
    _demoStore.setBookingOwner(
      state.booking!.bookingId,
      DemoBookingFunnelStore.defaultTravelerId,
    );

    // Ensure ticket exists before simulating status
    if (state.booking!.eticket == null) {
      _demoStore.recordVerifiedServerPayment(state.booking!.bookingId);
    }

    final updated = _demoStore.simulateTicketStatus(
      state.booking!.bookingId,
      ticketStatus,
    );
    if (updated != null) {
      _emitStateForBooking(updated);
    }
  }

  void simulateUnconfirmedBooking() {
    if (!isDemoMode || state.booking == null) return;
    final current = state.booking!;
    final unconfirmed = current.copyWith(
      status: BookingLifecycleStatus.pendingPayment,
      clearEticket: true,
    );
    emit(
      state.copyWith(
        status: QrEticketStatus.unconfirmedBooking,
        booking: unconfirmed,
        statusMessage: QrEticketState.msg90,
        isWarningOrError: true,
      ),
    );
  }

  void simulateNonOwnerAccess() {
    if (!isDemoMode || state.booking == null) return;
    final updated = _demoStore.setBookingOwner(
      state.booking!.bookingId,
      DemoBookingFunnelStore.nonOwnerTravelerId,
    );
    emit(
      state.copyWith(
        status: QrEticketStatus.unauthorized,
        booking: updated,
        statusMessage: QrEticketState.msg126,
        isWarningOrError: true,
      ),
    );
  }

  void simulateSystemError() {
    if (!isDemoMode) return;
    emit(
      state.copyWith(
        status: QrEticketStatus.error,
        errorMessage: QrEticketState.msg127,
      ),
    );
  }

  void resetDemoTicket() {
    if (!isDemoMode) return;
    _demoStore.setActiveTravelerId(DemoBookingFunnelStore.defaultTravelerId);
    if (state.booking != null) {
      _demoStore.setBookingOwner(
        state.booking!.bookingId,
        DemoBookingFunnelStore.defaultTravelerId,
      );
      _demoStore.recordVerifiedServerPayment(state.booking!.bookingId);
      final updated = _demoStore.simulateTicketStatus(
        state.booking!.bookingId,
        TicketLifecycleStatus.valid,
      );
      if (updated != null) {
        _emitStateForBooking(updated);
        return;
      }
    }
    load();
  }

  void _emitStateForBooking(TourBookingRecord booking) {
    // Ownership check (BR-90)
    if (booking.ownerTravelerId != _demoStore.activeTravelerId) {
      emit(
        state.copyWith(
          status: QrEticketStatus.unauthorized,
          booking: booking,
          statusMessage: QrEticketState.msg126,
          isWarningOrError: true,
        ),
      );
      return;
    }

    // Confirmed check (BR-82)
    if (booking.status == BookingLifecycleStatus.pendingPayment ||
        booking.status == BookingLifecycleStatus.expired ||
        booking.eticket == null) {
      emit(
        state.copyWith(
          status: QrEticketStatus.unconfirmedBooking,
          booking: booking,
          statusMessage: QrEticketState.msg90,
          isWarningOrError: true,
        ),
      );
      return;
    }

    final ticketStatus = booking.eticket!.ticketStatus;
    final (message, isWarning) = switch (ticketStatus) {
      TicketLifecycleStatus.valid => (QrEticketState.msg93, false),
      TicketLifecycleStatus.notYetActive => (QrEticketState.msg98, true),
      TicketLifecycleStatus.used => (QrEticketState.msg95, true),
      TicketLifecycleStatus.cancelled => (QrEticketState.msg74, true),
      TicketLifecycleStatus.expired => (QrEticketState.msg99, true),
    };

    emit(
      state.copyWith(
        status: QrEticketStatus.ready,
        booking: booking,
        statusMessage: message,
        isWarningOrError: isWarning,
        clearErrorMessage: true,
      ),
    );
  }
}
