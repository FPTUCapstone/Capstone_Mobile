import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/repositories/partial_refund_proposal_repository.dart';

final class GetPartialRefundProposalUseCase {
  const GetPartialRefundProposalUseCase(this._repository);
  final PartialRefundProposalRepository _repository;

  Future<PartialRefundProposal> call(int complaintId) =>
      _repository.getProposal(complaintId);
}

final class RespondToPartialRefundProposalUseCase {
  const RespondToPartialRefundProposalUseCase(this._repository);
  final PartialRefundProposalRepository _repository;

  Future<PartialRefundResponseResult> call(
    int complaintId,
    PartialRefundDecision decision,
  ) => _repository.respond(complaintId, decision);
}
