import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/group_location_sharing_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/session_identity_helper.dart';

/// Cubit managing UC-22 Group Location Sharing consent and OS permission state.
///
/// Invariants:
/// - effectiveSharing = activeMembership AND storedOptIn AND devicePermissionGranted
/// - Canonical Backend currently has no merged write endpoint (NO_BACKEND).
///   Production mode exposes PENDING_BE_INTEGRATION and refuses fake persistence.
/// - Demo mode enables previewing permission permutations and opt-in toggles.
final class GroupLocationSharingCubit extends Cubit<GroupLocationSharingState> {
  GroupLocationSharingCubit({
    required int groupId,
    String? groupName,
    TravelGroupRepository? travelGroupRepository,
    DeviceLocationService? locationService,
    SecureStorageService? secureStorage,
    bool isDemoMode = false,
    bool initialOptIn = false,
    bool initialActiveMembership = false,
    TravelGroup? initialGroup,
  }) : _travelGroupRepository = travelGroupRepository,
       _locationService = locationService,
       _secureStorage = secureStorage,
       super(
         GroupLocationSharingState(
           groupId: groupId,
           groupName: groupName ?? initialGroup?.name,
           storedOptIn: initialOptIn,
           isActiveMember: isDemoMode ? initialActiveMembership : false,
           isDemoMode: isDemoMode,
           pendingBeIntegration: !isDemoMode,
         ),
       );

  final TravelGroupRepository? _travelGroupRepository;
  final DeviceLocationService? _locationService;
  final SecureStorageService? _secureStorage;

  static const String pendingBeIntegrationMessage =
      'Location sharing configuration is pending server integration. '
      'Settings cannot be updated at this time.';

  static const String inactiveMemberMessage =
      'Only active members of this travel group can configure location sharing.';

  static const String permissionRequiredMessage =
      'Location permission is required for real-time navigation and trip tracking. '
      'Please enable it in Settings.';

  static const String sharingEnabledNotice =
      'Live location sharing is now active with group members.';

  static const String sharingDisabledNotice = 'Live location sharing disabled.';

  DeviceLocationService get _effectiveLocationService {
    if (_locationService != null) return _locationService;
    if (serviceLocator.isRegistered<DeviceLocationService>()) {
      return serviceLocator<DeviceLocationService>();
    }
    return const GeolocatorDeviceLocationService();
  }

  /// Initializes the screen by verifying membership and OS permissions.
  Future<void> initialize() async {
    emit(state.copyWith(status: GroupLocationSharingStatus.loading));

    // 1. Check native device location permission and service enabled
    LocationPermission permission = LocationPermission.denied;
    bool serviceEnabled = true;
    try {
      permission = await _effectiveLocationService.checkPermission();
      serviceEnabled = await _effectiveLocationService
          .isLocationServiceEnabled();
    } catch (_) {
      // Keep safe defaults if check fails
    }

    // 2. Authoritative membership verification
    bool activeMember = state.isActiveMember;
    String? resolvedGroupName = state.groupName;
    bool initialOptIn = state.storedOptIn;

    if (!state.isDemoMode) {
      final repo =
          _travelGroupRepository ??
          (serviceLocator.isRegistered<TravelGroupRepository>()
              ? serviceLocator<TravelGroupRepository>()
              : null);

      if (repo != null) {
        try {
          final groupMembers = await repo.getTravelGroupMembers(
            groupId: state.groupId,
          );
          resolvedGroupName ??= groupMembers.groupName;

          final currentUserId = await SessionIdentityHelper.getCurrentUserId(
            _secureStorage,
          );
          if (currentUserId != null) {
            final myMember = groupMembers.members
                .where((m) => m.memberId == currentUserId)
                .firstOrNull;
            if (myMember != null) {
              activeMember = true;
              initialOptIn = myMember.locationSharingEnabled;
            } else {
              activeMember = false;
            }
          } else {
            // Fail closed if user identity cannot be verified
            activeMember = false;
          }
        } catch (_) {
          // If membership retrieval fails, fail closed
          activeMember = false;
        }
      }
    }

    emit(
      state.copyWith(
        status: GroupLocationSharingStatus.ready,
        groupName: resolvedGroupName,
        devicePermission: permission,
        isLocationServiceEnabled: serviceEnabled,
        isActiveMember: activeMember,
        storedOptIn: initialOptIn,
        pendingBeIntegration: !state.isDemoMode,
      ),
    );
  }

  /// Re-checks OS permissions on app resume.
  Future<void> checkDevicePermission() async {
    try {
      final permission = await _effectiveLocationService.checkPermission();
      final serviceEnabled = await _effectiveLocationService
          .isLocationServiceEnabled();

      final wasGranted = state.devicePermissionGranted;
      final nowGranted =
          serviceEnabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always);

      emit(
        state.copyWith(
          devicePermission: permission,
          isLocationServiceEnabled: serviceEnabled,
          clearErrorMessage: nowGranted && !wasGranted,
        ),
      );
    } catch (_) {
      // Retain previous state on exception
    }
  }

  /// Requests device location permission from the OS.
  Future<void> requestDevicePermission() async {
    try {
      final permission = await _effectiveLocationService.requestPermission();
      final serviceEnabled = await _effectiveLocationService
          .isLocationServiceEnabled();

      final isGranted =
          serviceEnabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always);

      emit(
        state.copyWith(
          devicePermission: permission,
          isLocationServiceEnabled: serviceEnabled,
          errorMessage: isGranted ? null : permissionRequiredMessage,
          clearErrorMessage: isGranted,
        ),
      );
    } catch (_) {
      emit(state.copyWith(errorMessage: permissionRequiredMessage));
    }
  }

  /// Opens the device settings page for the app.
  Future<bool> openAppSettings() async {
    try {
      return await _effectiveLocationService.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Opens the system location services settings page.
  Future<bool> openLocationSettings() async {
    try {
      return await _effectiveLocationService.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Toggles location sharing.
  ///
  /// In production mode, mutations fail closed with [pendingBeIntegrationMessage]
  /// because the backend mutation endpoint is not yet merged.
  /// In demo mode, allows previewing opt-in toggles and permission gates.
  Future<void> toggleLocationSharing(bool targetOptIn) async {
    // Check 1: Active membership authority
    if (!state.isActiveMember) {
      emit(
        state.copyWith(
          errorMessage: inactiveMemberMessage,
          clearNoticeMessage: true,
        ),
      );
      return;
    }

    // Check 2: Production NO_BACKEND guard
    if (!state.isDemoMode) {
      emit(
        state.copyWith(
          errorMessage: pendingBeIntegrationMessage,
          clearNoticeMessage: true,
        ),
      );
      return;
    }

    // Demo Mode toggle progression:
    if (targetOptIn) {
      // If enabling, verify device location permission
      if (!state.devicePermissionGranted) {
        await requestDevicePermission();
        if (!state.devicePermissionGranted) {
          emit(
            state.copyWith(
              errorMessage: permissionRequiredMessage,
              clearNoticeMessage: true,
            ),
          );
          return;
        }
      }

      emit(
        state.copyWith(
          storedOptIn: true,
          noticeMessage: sharingEnabledNotice,
          clearErrorMessage: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          storedOptIn: false,
          noticeMessage: sharingDisabledNotice,
          clearErrorMessage: true,
        ),
      );
    }
  }

  /// Demo helper: simulate OS permission state change.
  void setDemoPermission(
    LocationPermission permission, {
    bool isServiceEnabled = true,
  }) {
    if (!state.isDemoMode) return;
    emit(
      state.copyWith(
        devicePermission: permission,
        isLocationServiceEnabled: isServiceEnabled,
        clearErrorMessage: true,
      ),
    );
  }

  /// Demo helper: simulate membership change.
  void setDemoActiveMembership(bool isActive) {
    if (!state.isDemoMode) return;
    emit(state.copyWith(isActiveMember: isActive, clearErrorMessage: true));
  }

  /// Demo helper: directly set storedOptIn.
  void setDemoStoredOptIn(bool optIn) {
    if (!state.isDemoMode) return;
    emit(state.copyWith(storedOptIn: optIn, clearErrorMessage: true));
  }

  /// Clears inline notification and error messages.
  void clearMessages() {
    emit(state.copyWith(clearErrorMessage: true, clearNoticeMessage: true));
  }
}
