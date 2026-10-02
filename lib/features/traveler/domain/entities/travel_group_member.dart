import 'package:equatable/equatable.dart';

/// A privacy-safe representation of an active travel-group membership.
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
}
