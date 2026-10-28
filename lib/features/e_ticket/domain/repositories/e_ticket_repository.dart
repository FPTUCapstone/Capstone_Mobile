import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';

/// UC-29 e-ticket reads and QR refresh. Failures are thrown as `ETicketFailure`.
abstract interface class ETicketRepository {
  /// The ticket linked from Trip History (`actions.ticketId`).
  Future<ETicket> getTicket(int ticketId);

  /// The ticket of a booking, opened after a successful payment.
  Future<ETicket> getBookingTicket(int bookingId);

  /// Revokes the Active QR and issues a new one.
  Future<ETicket> refreshQr(int ticketId);
}
