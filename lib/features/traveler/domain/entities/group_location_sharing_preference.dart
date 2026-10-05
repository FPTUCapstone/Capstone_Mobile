import 'package:equatable/equatable.dart';

/// Privacy-safe preference representation for UC-22 Group Location Sharing.
///
/// Encapsulates the explicit stored opt-in state for sharing real-time GPS
/// location with active members of a specific travel group.
final class GroupLocationSharingPreference extends Equatable {
  const GroupLocationSharingPreference({
    required this.groupId,
    required this.storedOptIn,
    this.updatedAtUtc,
  });

  final int groupId;
  final bool storedOptIn;
  final DateTime? updatedAtUtc;

  GroupLocationSharingPreference copyWith({
    int? groupId,
    bool? storedOptIn,
    DateTime? updatedAtUtc,
  }) {
    return GroupLocationSharingPreference(
      groupId: groupId ?? this.groupId,
      storedOptIn: storedOptIn ?? this.storedOptIn,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  @override
  List<Object?> get props => [groupId, storedOptIn, updatedAtUtc];
}
