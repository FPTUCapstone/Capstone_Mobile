import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';

/// Why a UC-29 request failed; each kind maps to one reviewed message.
enum ETicketFailureKind {
  signIn,
  forbidden,
  notFound,
  notConfirmed,
  notIssued,
  notRefreshable,
  system,
}

/// A UC-29 failure. The core `Failure` hierarchy is sealed, so the feature keeps its own type.
final class ETicketFailure extends Equatable implements Exception {
  const ETicketFailure(this.kind, {this.ticketStatus});

  final ETicketFailureKind kind;

  /// The current status, sent with `ticket.not_refreshable`.
  final ETicketStatus? ticketStatus;

  @override
  List<Object?> get props => [kind, ticketStatus];
}
