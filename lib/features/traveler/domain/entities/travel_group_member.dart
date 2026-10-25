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
  /// defined by earliest join time, then smallest user ID for an exact tie.
  ///
  /// Contract guarantees:
  /// - Excludes current Host (by [isHost] flag and [currentHostId] if provided).
  /// - An exact timestamp tie is resolved by smallest [memberId].
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

    candidates.sort((a, b) {
      final byJoinedAt = a.joinedAtUtc.compareTo(b.joinedAtUtc);
      return byJoinedAt != 0 ? byJoinedAt : a.memberId.compareTo(b.memberId);
    });
    return candidates.first;
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
}
