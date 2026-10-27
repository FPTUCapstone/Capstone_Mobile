import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

abstract final class OperatorBookingFormatters {
  /// Whole VND with thousands separators. The backend sends decimals (`2400000.00`); the amount is rounded
  /// to the nearest dong for display. Unlike `TripFormatters.formatVnd`, zero stays `0 VND`, never "Free".
  static String formatVnd(double amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '$buffer VND';
  }

  /// CR-07: `dd/MM/yyyy` in Asia/Ho_Chi_Minh (UTC+7).
  static String date(DateTime instant) =>
      TripFormatters.formatVietnamDate(instant);

  /// `dd/MM/yyyy HH:mm` on a 24-hour clock in UTC+7.
  static String dateTime(DateTime instant) =>
      TripFormatters.formatVietnamDateTime(instant);

  static String statusLabel(OperatorBookingStatus status) => switch (status) {
    OperatorBookingStatus.pendingPayment =>
      OperatorBookingsStringsEn.statusPendingPayment,
    OperatorBookingStatus.confirmed =>
      OperatorBookingsStringsEn.statusConfirmed,
    OperatorBookingStatus.cancelled =>
      OperatorBookingsStringsEn.statusCancelled,
    OperatorBookingStatus.completed =>
      OperatorBookingsStringsEn.statusCompleted,
    OperatorBookingStatus.expired => OperatorBookingsStringsEn.statusExpired,
  };

  static StatusBadgeType statusBadge(OperatorBookingStatus status) =>
      switch (status) {
        OperatorBookingStatus.pendingPayment => StatusBadgeType.warning,
        OperatorBookingStatus.confirmed => StatusBadgeType.success,
        OperatorBookingStatus.cancelled => StatusBadgeType.error,
        OperatorBookingStatus.completed => StatusBadgeType.info,
        OperatorBookingStatus.expired => StatusBadgeType.neutral,
      };

  static String paymentStatusLabel(OperatorPaymentStatus status) =>
      switch (status) {
        OperatorPaymentStatus.unpaid => OperatorBookingsStringsEn.paymentUnpaid,
        OperatorPaymentStatus.paid => OperatorBookingsStringsEn.paymentPaid,
        OperatorPaymentStatus.refunded =>
          OperatorBookingsStringsEn.paymentRefunded,
        OperatorPaymentStatus.partiallyRefunded =>
          OperatorBookingsStringsEn.paymentPartiallyRefunded,
      };

  static String checkInLabel(OperatorCheckInStatus status) => switch (status) {
    OperatorCheckInStatus.checkedIn => OperatorBookingsStringsEn.checkedIn,
    OperatorCheckInStatus.notCheckedIn =>
      OperatorBookingsStringsEn.notCheckedIn,
  };

  static StatusBadgeType checkInBadge(OperatorCheckInStatus status) =>
      switch (status) {
        OperatorCheckInStatus.checkedIn => StatusBadgeType.success,
        OperatorCheckInStatus.notCheckedIn => StatusBadgeType.neutral,
      };

  static String participantTypeLabel(
    OperatorParticipantType type,
  ) => switch (type) {
    OperatorParticipantType.adult => OperatorBookingsStringsEn.participantAdult,
    OperatorParticipantType.child => OperatorBookingsStringsEn.participantChild,
    OperatorParticipantType.infant =>
      OperatorBookingsStringsEn.participantInfant,
  };

  /// The gateway name as the backend knows it.
  static String gatewayLabel(OperatorPaymentGateway gateway) => gateway.wire;

  static String ticketStatusLabel(OperatorTicketStatus status) =>
      switch (status) {
        OperatorTicketStatus.valid => OperatorBookingsStringsEn.ticketValid,
        OperatorTicketStatus.used => OperatorBookingsStringsEn.ticketUsed,
        OperatorTicketStatus.cancelled =>
          OperatorBookingsStringsEn.ticketCancelled,
        OperatorTicketStatus.expired => OperatorBookingsStringsEn.ticketExpired,
      };
}
