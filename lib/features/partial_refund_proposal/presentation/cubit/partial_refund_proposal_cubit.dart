import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/usecases/partial_refund_proposal_use_cases.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/presentation/cubit/partial_refund_proposal_state.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/resources/partial_refund_proposal_en.dart';

/// UC-75 Respond to Partial Refund Proposal (SRS §3.8.6.3).
final class PartialRefundProposalCubit
    extends Cubit<PartialRefundProposalState> {
  PartialRefundProposalCubit({
    required this.complaintId,
    required GetPartialRefundProposalUseCase getProposal,
    required RespondToPartialRefundProposalUseCase respond,
  }) : _getProposal = getProposal,
       _respond = respond,
       super(const PartialRefundProposalState());

  final int complaintId;
  final GetPartialRefundProposalUseCase _getProposal;
  final RespondToPartialRefundProposalUseCase _respond;

  Future<void> load() async {
    emit(
      const PartialRefundProposalState(
        loadStatus: PartialRefundProposalLoadStatus.loading,
      ),
    );
    try {
      final proposal = await _getProposal(complaintId);
      if (isClosed) return;
      emit(
        PartialRefundProposalState(
          loadStatus: PartialRefundProposalLoadStatus.loaded,
          proposal: proposal,
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      final (message, canRetry) = _copy(error);
      emit(
        PartialRefundProposalState(
          loadStatus: PartialRefundProposalLoadStatus.failure,
          message: message,
          canRetry: canRetry,
        ),
      );
    }
  }

  Future<void> respond(PartialRefundDecision decision) async {
    final proposal = state.proposal;
    if (proposal == null ||
        !proposal.canRespond ||
        state.submitStatus == PartialRefundSubmitStatus.submitting) {
      return;
    }
    emit(
      state.copyWith(
        submitStatus: PartialRefundSubmitStatus.submitting,
        clearMessage: true,
      ),
    );
    try {
      final result = await _respond(complaintId, decision);
      if (isClosed) return;
      emit(
        state.copyWith(
          submitStatus: PartialRefundSubmitStatus.recorded,
          proposal: proposal.closedAs(result.status),
          answeredHere: true,
        ),
      );
    } on ConflictFailure {
      // 1.a1, G1, G5: the window has closed; make no change and show the current state.
      await _reloadAfterClosed(proposal);
    } on Object catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          submitStatus: PartialRefundSubmitStatus.failed,
          message: _copy(error).$1,
        ),
      );
    }
  }

  Future<void> _reloadAfterClosed(PartialRefundProposal stale) async {
    PartialRefundProposal current;
    try {
      current = await _getProposal(complaintId);
    } on Object {
      current = stale;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        submitStatus: PartialRefundSubmitStatus.closed,
        // The Backend has just said no; never offer the buttons again on this screen.
        proposal: current.closedAs(current.status),
      ),
    );
  }

  static (String, bool) _copy(Object error) => switch (error) {
    AuthenticationFailure() ||
    PermissionFailure() => (PartialRefundProposalStrings.accessDenied, false),
    NotFoundFailure() => (PartialRefundProposalStrings.notFound, false),
    ConflictFailure() => (PartialRefundProposalStrings.responseClosed, false),
    _ => (PartialRefundProposalStrings.systemError, true),
  };
}
