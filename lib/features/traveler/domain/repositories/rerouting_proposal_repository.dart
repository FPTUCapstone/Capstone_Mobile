import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';

/// UC-15 Confirm Re-routing. Failures are [ReroutingFailure] when the proposal
/// is gone or closed (MSG44); transport and server failures use the usual
/// failure types.
abstract interface class ReroutingProposalRepository {
  Future<RerouteProposal> getProposal({
    required int sessionId,
    required int proposalId,
  });

  /// Returns the session now bound to the new itinerary version.
  Future<NavigationSession> acceptProposal({
    required int sessionId,
    required int proposalId,
  });

  Future<void> rejectProposal({
    required int sessionId,
    required int proposalId,
  });
}
