import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/repositories/e_ticket_repository.dart';

/// Which id opens the ticket: Trip History has the ticket id, the payment result the booking id.
sealed class ETicketKey extends Equatable {
  const ETicketKey();

  const factory ETicketKey.ticket(int ticketId) = TicketIdKey;
  const factory ETicketKey.booking(int bookingId) = BookingIdKey;
}

final class TicketIdKey extends ETicketKey {
  const TicketIdKey(this.ticketId);

  final int ticketId;

  @override
  List<Object?> get props => [ticketId];
}

final class BookingIdKey extends ETicketKey {
  const BookingIdKey(this.bookingId);

  final int bookingId;

  @override
  List<Object?> get props => [bookingId];
}

/// UC-29: read the e-ticket by ticket or by booking.
final class GetETicketUseCase {
  const GetETicketUseCase(this._repository);

  final ETicketRepository _repository;

  Future<ETicket> call(ETicketKey key) => switch (key) {
    TicketIdKey(:final ticketId) => _repository.getTicket(ticketId),
    BookingIdKey(:final bookingId) => _repository.getBookingTicket(bookingId),
  };
}
