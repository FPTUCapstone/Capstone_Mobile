import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';

abstract interface class PartialRefundProposalRepository {
  Future<PartialRefundProposal> getProposal(int complaintId);

  Future<PartialRefundResponseResult> respond(
    int complaintId,
    PartialRefundDecision decision,
  );
}
