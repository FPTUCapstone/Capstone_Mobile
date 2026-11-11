import 'package:equatable/equatable.dart';

/// Why a UC-41 request failed; each kind maps to one reviewed message.
enum BookingCancellationFailureKind {
  signIn,
  forbidden,
  notFound,
  invalidState,
  reasonRequired,
  confirmationRequired,
  paymentNotRefundable,
  windowClosed,
  idempotencyMismatch,
  system,
}

/// A UC-41 failure. The core `Failure` hierarchy is sealed, so the feature keeps its own type
/// (same reasoning as `ETicketFailure`).
final class BookingCancellationFailure extends Equatable implements Exception {
  const BookingCancellationFailure(this.kind);

  final BookingCancellationFailureKind kind;

  @override
  List<Object?> get props => [kind];
}
