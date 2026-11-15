import 'dart:async';

import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/repositories/partial_refund_proposal_repository.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/usecases/partial_refund_proposal_use_cases.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/cubit/partial_refund_proposal_cubit.dart';

PartialRefundProposalCubit buildCubit(
  PartialRefundProposalRepository repository, {
  int complaintId = 501,
}) => PartialRefundProposalCubit(
  complaintId: complaintId,
  getProposal: GetPartialRefundProposalUseCase(repository),
  respond: RespondToPartialRefundProposalUseCase(repository),
);

PartialRefundProposal openProposal({
  PartialRefundProposalStatus status =
      PartialRefundProposalStatus.awaitingTravelerResponse,
  bool canRespond = true,
}) => PartialRefundProposal(
  complaintId: 501,
  bookingId: 301,
  bookingCode: 'BK-UC75',
  proposedAmount: 500000,
  responseDeadlineUtc: DateTime.utc(2026, 11, 9, 3),
  status: status,
  canRespond: canRespond,
);

/// Answers each call with the next queued value; an [Object] that is not a value is thrown.
final class FakePartialRefundProposalRepository
    implements PartialRefundProposalRepository {
  final List<Object> reads = [];
  final List<Object> responses = [];
  final List<String> calls = [];
  Completer<void>? holdResponse;

  @override
  Future<PartialRefundProposal> getProposal(int complaintId) async {
    calls.add('get:$complaintId');
    final next = reads.removeAt(0);
    if (next is PartialRefundProposal) return next;
    throw next;
  }

  @override
  Future<PartialRefundResponseResult> respond(
    int complaintId,
    PartialRefundDecision decision,
  ) async {
    calls.add('respond:$complaintId:${decision.wireValue}');
    await holdResponse?.future;
    final next = responses.removeAt(0);
    if (next is PartialRefundResponseResult) return next;
    throw next;
  }
}

PartialRefundResponseResult recorded(PartialRefundDecision decision) =>
    PartialRefundResponseResult(
      complaintId: 501,
      status: decision == PartialRefundDecision.accept
          ? PartialRefundProposalStatus.approved
          : PartialRefundProposalStatus.declined,
      approvedAmount: decision == PartialRefundDecision.accept ? 500000 : null,
      respondedAtUtc: DateTime.utc(2026, 11, 7, 3),
    );
