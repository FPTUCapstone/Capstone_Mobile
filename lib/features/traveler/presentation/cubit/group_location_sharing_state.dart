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
    this.liveLocationDeliveryConfirmed = false,
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

  /// Whether the device has an active location stream and confirmed coordinate
  /// delivery to the server/group.
  ///
  /// In current production, no broadcast transport exists, so this is strictly
  /// false in production mode.
  final bool liveLocationDeliveryConfirmed;

  /// Whether device location permission is currently granted and GPS is on.
  bool get devicePermissionGranted =>
      isLocationServiceEnabled &&
      (devicePermission == LocationPermission.whileInUse ||
          devicePermission == LocationPermission.always);

  /// Canonical prerequisites per BR-50 and BR-51:
  /// Active membership, explicit stored opt-in consent, and granted device OS
  /// location permissions with GPS enabled.
  ///
  /// Note: Fulfilling prerequisites proves user eligibility and consent, but
  /// does not prove that live coordinates are actively transmitting or delivered.
  bool get sharingPrerequisitesSatisfied =>
      isActiveMember && storedOptIn && devicePermissionGranted;

  /// Truthful active sharing state. Requires both all prerequisites satisfied
  /// AND confirmed live coordinate delivery to the server/group.
  bool get isActivelySharing =>
      sharingPrerequisitesSatisfied && liveLocationDeliveryConfirmed;

  /// Operational sharing state. Requires both prerequisites satisfied AND
  /// confirmed live coordinate delivery.
  ///
  /// In production mode, since no live location transport is yet integrated,
  /// this remains strictly false.
  bool get effectiveSharing => isActivelySharing;

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
    bool? liveLocationDeliveryConfirmed,
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
      liveLocationDeliveryConfirmed:
          liveLocationDeliveryConfirmed ?? this.liveLocationDeliveryConfirmed,
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
    liveLocationDeliveryConfirmed,
  ];
}
