import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';

enum QrEticketStatus {
  initial,
  loading,
  ready,
  unconfirmedBooking,
  unauthorized,
  pendingIntegration,
  error,
}

final class QrEticketState extends Equatable {
  const QrEticketState({
    required this.status,
    required this.bookingId,
    this.booking,
    this.statusMessage,
    this.isWarningOrError = false,
    this.errorMessage,
    this.isDemoMode = false,
  });

  // Canonical messages for UC-29
  static const String msg74 = 'This booking has already been cancelled.';
  static const String msg90 =
      'Payment status has not been confirmed yet. Please wait or refresh your booking status.';
  static const String msg93 = 'Your QR e-ticket is ready for check-in.';
  static const String msg95 =
      'This QR e-ticket has already been used for check-in.';
  static const String msg98 =
      'This QR e-ticket is not yet active for check-in.';
  static const String msg99 =
      'This QR e-ticket has expired because the departure window has passed.';
  static const String msg126 = 'You are not allowed to perform this action.';
  static const String msg127 =
      'A system error occurred. Please try again later.';

  final QrEticketStatus status;
  final String bookingId;
  final TourBookingRecord? booking;
  final String? statusMessage;
  final bool isWarningOrError;
  final String? errorMessage;
  final bool isDemoMode;

  QrEticketRecord? get eticket => booking?.eticket;

  TicketLifecycleStatus? get ticketStatus => eticket?.ticketStatus;

  /// Only Confirmed bookings with a Valid or Not-Yet-Active ticket render the
  /// scannable QR widget; Cancelled/Expired/Unconfirmed/Unauthorized do not
  /// expose an active check-in QR code (BR-82, BR-86, BR-90).
  bool get shouldRenderQrCode =>
      isDemoMode &&
      status == QrEticketStatus.ready &&
      booking?.status == BookingLifecycleStatus.confirmed &&
      eticket != null &&
      eticket!.ticketStatus != TicketLifecycleStatus.cancelled;

  QrEticketState copyWith({
    QrEticketStatus? status,
    TourBookingRecord? booking,
    String? statusMessage,
    bool clearStatusMessage = false,
    bool? isWarningOrError,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isDemoMode,
  }) {
    return QrEticketState(
      status: status ?? this.status,
      bookingId: bookingId,
      booking: booking ?? this.booking,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      isWarningOrError: isWarningOrError ?? this.isWarningOrError,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    bookingId,
    booking,
    statusMessage,
    isWarningOrError,
    errorMessage,
    isDemoMode,
  ];
}
