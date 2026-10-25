import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/repositories/e_ticket_repository.dart';

/// UC-29 [Refresh QR Code]: the previous QR stops working at check-in.
final class RefreshETicketQrUseCase {
  const RefreshETicketQrUseCase(this._repository);

  final ETicketRepository _repository;

  Future<ETicket> call(int ticketId) => _repository.refreshQr(ticketId);
}
