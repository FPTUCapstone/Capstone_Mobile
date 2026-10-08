import 'package:equatable/equatable.dart';

/// A privacy-safe representation of an active travel-group membership.
///
/// Data Source Guarantee:
/// The underlying Backend endpoint `GET /api/v1/travel-groups/{groupId}/members`
/// delivers active group memberships exclusively. The entity contains no raw
/// inactive/deleted memberships.
final class TravelGroupMember extends Equatable {
  const TravelGroupMember({
    required this.memberId,
    required this.displayName,
    required this.isHost,
    required this.joinedAtUtc,
    required this.locationSharingEnabled,
    this.avatarUrl,
  });

  final int memberId;
  final String displayName;
  final String? avatarUrl;
  final bool isHost;
  final DateTime joinedAtUtc;
  final bool locationSharingEnabled;

  @override
  List<Object?> get props => [
    memberId,
    displayName,
    avatarUrl,
    isHost,
    joinedAtUtc,
    locationSharingEnabled,
  ];

  /// BR-49: Selects the authoritative successor Host from active remaining members,
  /// defined as the member with the unique earliest Joined Timestamp.
  ///
  /// Contract guarantees:
  /// - Excludes current Host (by [isHost] flag and [currentHostId] if provided).
  /// - If exactly one eligible member has the earliest [joinedAtUtc], that member is returned.
  /// - If multiple eligible members share the exact same earliest [joinedAtUtc],
  ///   this returns `null` (failing closed for authoritative successor preview)
  ///   because SRS Report 3 authorizes ONLY earliest Joined Timestamp and defines
  ///   no authoritative tie-break rule.
  /// - Returns `null` if no eligible candidate remains (i.e. final Host).
  static TravelGroupMember? determineSuccessor(
    List<TravelGroupMember> members, {
    int? currentHostId,
  }) {
    final candidates = getEligibleSuccessors(
      members,
      currentHostId: currentHostId,
    );
    if (candidates.isEmpty) return null;

    DateTime? earliestTime;
    for (final candidate in candidates) {
      if (earliestTime == null ||
          candidate.joinedAtUtc.isBefore(earliestTime)) {
        earliestTime = candidate.joinedAtUtc;
      }
    }

    final earliestCandidates = candidates
        .where((m) => m.joinedAtUtc.isAtSameMomentAs(earliestTime!))
        .toList();

    // If more than one candidate shares the exact earliest timestamp,
    // fail closed: no single authoritative successor exists under BR-49.
    if (earliestCandidates.length > 1) {
      return null;
    }

    return earliestCandidates.first;
  }

  /// Filters remaining active members eligible for Host succession (excluding Host).
  static List<TravelGroupMember> getEligibleSuccessors(
    List<TravelGroupMember> members, {
    int? currentHostId,
  }) {
    return members
        .where(
          (m) =>
              !m.isHost &&
              (currentHostId == null || m.memberId != currentHostId),
        )
        .toList();
  }

  /// Returns true if multiple eligible members share the exact same earliest joinedAtUtc.
  static bool hasAmbiguousSuccessorTie(
    List<TravelGroupMember> members, {
    int? currentHostId,
  }) {
    final candidates = getEligibleSuccessors(
      members,
      currentHostId: currentHostId,
    );
    if (candidates.length <= 1) return false;

    DateTime? earliestTime;
    for (final candidate in candidates) {
      if (earliestTime == null ||
          candidate.joinedAtUtc.isBefore(earliestTime)) {
        earliestTime = candidate.joinedAtUtc;
      }
    }

    final earliestCandidates = candidates
        .where((m) => m.joinedAtUtc.isAtSameMomentAs(earliestTime!))
        .toList();

    return earliestCandidates.length > 1;
  }
}
