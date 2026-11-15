import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/partial_refund_proposal/domain/entities/partial_refund_proposal.dart';

enum PartialRefundProposalLoadStatus { initial, loading, loaded, failure }

enum PartialRefundSubmitStatus {
  idle,
  submitting,

  /// MSG164.
  recorded,

  /// MSG165: nothing changed; the proposal was reloaded.
  closed,

  /// MSG127 or MSG126; the proposal is unchanged.
  failed,
}

final class PartialRefundProposalState extends Equatable {
  const PartialRefundProposalState({
    this.loadStatus = PartialRefundProposalLoadStatus.initial,
    this.submitStatus = PartialRefundSubmitStatus.idle,
    this.proposal,
    this.message,
    this.canRetry = false,
    this.answeredHere = false,
  });

  final PartialRefundProposalLoadStatus loadStatus;
  final PartialRefundSubmitStatus submitStatus;
  final PartialRefundProposal? proposal;

  /// Load failure or failed send, in the canonical copy only.
  final String? message;
  final bool canRetry;

  /// True after this screen recorded the answer, so MSG164 is shown instead of MSG165.
  final bool answeredHere;

  PartialRefundProposalState copyWith({
    PartialRefundSubmitStatus? submitStatus,
    PartialRefundProposal? proposal,
    String? message,
    bool clearMessage = false,
    bool? answeredHere,
  }) => PartialRefundProposalState(
    loadStatus: loadStatus,
    submitStatus: submitStatus ?? this.submitStatus,
    proposal: proposal ?? this.proposal,
    message: clearMessage ? null : message ?? this.message,
    canRetry: canRetry,
    answeredHere: answeredHere ?? this.answeredHere,
  );

  @override
  List<Object?> get props => [
    loadStatus,
    submitStatus,
    proposal,
    message,
    canRetry,
    answeredHere,
  ];
}
