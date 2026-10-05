import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

enum GroupLocationSharingStatus { initial, loading, ready, saving, error }

final class GroupLocationSharingState extends Equatable {
  const GroupLocationSharingState({
    required this.groupId,
    this.status = GroupLocationSharingStatus.initial,
    this.groupName,
    this.storedOptIn = false,
    this.devicePermission = LocationPermission.denied,
    this.isLocationServiceEnabled = true,
    this.isActiveMember = false,
    this.isDemoMode = false,
    this.errorMessage,
    this.noticeMessage,
    this.pendingBeIntegration = false,
  });

  final int groupId;
  final GroupLocationSharingStatus status;
  final String? groupName;

  /// Explicit user consent preference stored on backend/session.
  final bool storedOptIn;

  /// Native OS device location permission.
  final LocationPermission devicePermission;

  /// Whether device GPS/location services are turned on.
  final bool isLocationServiceEnabled;

  /// Authoritative membership verified against travel group active members.
  final bool isActiveMember;

  /// Isolated demo simulation mode.
  final bool isDemoMode;

  /// Inline error or validation message (e.g. MSG46, MSG127).
  final String? errorMessage;

  /// Informational toast or banner notice (e.g. MSG62, MSG63).
  final String? noticeMessage;

  /// Flag indicating backend preference mutation is pending server integration.
  final bool pendingBeIntegration;

  /// Whether device location permission is currently granted.
  bool get devicePermissionGranted =>
      isLocationServiceEnabled &&
      (devicePermission == LocationPermission.whileInUse ||
          devicePermission == LocationPermission.always);

  /// Canonical invariant per BR-50:
  /// effectiveSharing = activeMembership AND storedOptIn AND devicePermissionGranted
  bool get effectiveSharing =>
      isActiveMember && storedOptIn && devicePermissionGranted;

  bool get isPermissionPermanentlyDenied =>
      devicePermission == LocationPermission.deniedForever;

  bool get isPermissionDenied => devicePermission == LocationPermission.denied;

  GroupLocationSharingState copyWith({
    int? groupId,
    GroupLocationSharingStatus? status,
    String? groupName,
    bool? storedOptIn,
    LocationPermission? devicePermission,
    bool? isLocationServiceEnabled,
    bool? isActiveMember,
    bool? isDemoMode,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? noticeMessage,
    bool clearNoticeMessage = false,
    bool? pendingBeIntegration,
  }) {
    return GroupLocationSharingState(
      groupId: groupId ?? this.groupId,
      status: status ?? this.status,
      groupName: groupName ?? this.groupName,
      storedOptIn: storedOptIn ?? this.storedOptIn,
      devicePermission: devicePermission ?? this.devicePermission,
      isLocationServiceEnabled:
          isLocationServiceEnabled ?? this.isLocationServiceEnabled,
      isActiveMember: isActiveMember ?? this.isActiveMember,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      noticeMessage: clearNoticeMessage
          ? null
          : (noticeMessage ?? this.noticeMessage),
      pendingBeIntegration: pendingBeIntegration ?? this.pendingBeIntegration,
    );
  }

  @override
  List<Object?> get props => [
    groupId,
    status,
    groupName,
    storedOptIn,
    devicePermission,
    isLocationServiceEnabled,
    isActiveMember,
    isDemoMode,
    errorMessage,
    noticeMessage,
    pendingBeIntegration,
  ];
}
