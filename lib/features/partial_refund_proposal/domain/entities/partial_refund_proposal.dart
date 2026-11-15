import 'package:equatable/equatable.dart';

/// The complaint statuses of SRS entity #34 the Backend can return.
enum PartialRefundProposalStatus {
  awaitingOperatorResponse('AwaitingOperatorResponse'),
  awaitingTravelerResponse('AwaitingTravelerResponse'),
  approved('Approved'),
  rejected('Rejected'),
  expired('Expired'),
  declined('Declined');

  const PartialRefundProposalStatus(this.wireValue);
  final String wireValue;

  static PartialRefundProposalStatus? tryFromWire(String? value) {
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    return null;
  }
}

/// SRS §3.8.6.3: the Traveler can only accept or decline (no counter-offer).
enum PartialRefundDecision {
  accept('Accept'),
  decline('Decline');

  const PartialRefundDecision(this.wireValue);
  final String wireValue;
}

final class PartialRefundProposal extends Equatable {
  const PartialRefundProposal({
    required this.complaintId,
    required this.bookingId,
    required this.bookingCode,
    required this.proposedAmount,
    required this.responseDeadlineUtc,
    required this.status,
    required this.canRespond,
  });

  final int complaintId;
  final int bookingId;
  final String bookingCode;

  /// Whole VND.
  final int proposedAmount;
  final DateTime responseDeadlineUtc;
  final PartialRefundProposalStatus status;

  /// False once answered or past the 72-hour deadline (BR-153), even before the hourly job runs.
  final bool canRespond;

  PartialRefundProposal closedAs(PartialRefundProposalStatus newStatus) =>
      PartialRefundProposal(
        complaintId: complaintId,
        bookingId: bookingId,
        bookingCode: bookingCode,
        proposedAmount: proposedAmount,
        responseDeadlineUtc: responseDeadlineUtc,
        status: newStatus,
        canRespond: false,
      );

  @override
  List<Object?> get props => [
    complaintId,
    bookingId,
    bookingCode,
    proposedAmount,
    responseDeadlineUtc,
    status,
    canRespond,
  ];
}

final class PartialRefundResponseResult extends Equatable {
  const PartialRefundResponseResult({
    required this.complaintId,
    required this.status,
    required this.respondedAtUtc,
    this.approvedAmount,
  });

  final int complaintId;
  final PartialRefundProposalStatus status;

  /// Set only when the proposal was accepted.
  final int? approvedAmount;
  final DateTime respondedAtUtc;

  @override
  List<Object?> get props => [
    complaintId,
    status,
    approvedAmount,
    respondedAtUtc,
  ];
}
