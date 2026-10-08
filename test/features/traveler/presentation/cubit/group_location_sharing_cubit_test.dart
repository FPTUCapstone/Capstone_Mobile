import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/group_location_sharing_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/group_location_sharing_state.dart';

class _MockLocationService implements DeviceLocationService {
  _MockLocationService({
    this.permission = LocationPermission.denied,
    this.requestPermissionResult = LocationPermission.whileInUse,
    this.serviceEnabled = true,
  });

  LocationPermission permission;
  LocationPermission requestPermissionResult;
  bool serviceEnabled;
  bool openAppSettingsResult = true;
  bool openLocationSettingsResult = true;
  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  @override
  Future<DeviceLocation> getCurrentLocation() =>
      throw UnimplementedError('Not used in UC-22');

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCalls++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    permission = requestPermissionResult;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return openAppSettingsResult;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return openLocationSettingsResult;
  }
}

class _MockGroupRepository implements TravelGroupRepository {
  _MockGroupRepository({this.membersResult, this.failure});

  final TravelGroupMembers? membersResult;
  final Failure? failure;
  int getMembersCalls = 0;

  @override
  Future<TravelGroupMembers> getTravelGroupMembers({
    required int groupId,
  }) async {
    getMembersCalls++;
    if (failure != null) throw failure!;
    return membersResult!;
  }

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

class _MockStorage implements SecureStorageService {
  _MockStorage([this.token]);

  final String? token;

  @override
  Future<String?> read(String key) async {
    if (key == AppConstants.accessTokenKey) return token;
    return null;
  }

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}
}

String _jwtWithUserId(int id) {
  final header = base64Url.encode(
    utf8.encode(json.encode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(json.encode({'sub': id})));
  return '$header.$body.sig';
}

void main() {
  final sampleMembers = TravelGroupMembers(
    groupId: 42,
    groupName: 'Da Nang Explorer',
    itineraryId: 10,
    members: [
      TravelGroupMember(
        memberId: 101,
        displayName: 'Alice Traveler',
        isHost: true,
        joinedAtUtc: DateTime.utc(2026, 9, 21),
        locationSharingEnabled: false,
      ),
      TravelGroupMember(
        memberId: 102,
        displayName: 'Bob Member',
        isHost: false,
        joinedAtUtc: DateTime.utc(2026, 9, 22),
        locationSharingEnabled: true,
      ),
    ],
  );

  group('GroupLocationSharingState invariants (BR-50 & BR-51)', () {
    test(
      'effectiveSharing is TRUE only when prerequisites satisfied AND liveLocationDeliveryConfirmed is true',
      () {
        // Prerequisites met, but no live broadcast delivery confirmed (e.g. production mode)
        const prereqsMetNoBroadcast = GroupLocationSharingState(
          groupId: 42,
          isActiveMember: true,
          storedOptIn: true,
          devicePermission: LocationPermission.whileInUse,
          isLocationServiceEnabled: true,
          liveLocationDeliveryConfirmed: false,
        );
        expect(prereqsMetNoBroadcast.devicePermissionGranted, isTrue);
        expect(prereqsMetNoBroadcast.sharingPrerequisitesSatisfied, isTrue);
        expect(prereqsMetNoBroadcast.liveLocationDeliveryConfirmed, isFalse);
        expect(prereqsMetNoBroadcast.isActivelySharing, isFalse);
        expect(prereqsMetNoBroadcast.effectiveSharing, isFalse);

        // Confirmed live broadcast delivery
        final fullActive = prereqsMetNoBroadcast.copyWith(
          liveLocationDeliveryConfirmed: true,
        );
        expect(fullActive.isActivelySharing, isTrue);
        expect(fullActive.effectiveSharing, isTrue);

        // Stored opt-in false
        final noOptIn = fullActive.copyWith(storedOptIn: false);
        expect(noOptIn.sharingPrerequisitesSatisfied, isFalse);
        expect(noOptIn.effectiveSharing, isFalse);

        // Device permission denied
        final noPermission = fullActive.copyWith(
          devicePermission: LocationPermission.denied,
        );
        expect(noPermission.devicePermissionGranted, isFalse);
        expect(noPermission.sharingPrerequisitesSatisfied, isFalse);
        expect(noPermission.effectiveSharing, isFalse);

        // Location service (GPS) disabled
        final gpsOff = fullActive.copyWith(isLocationServiceEnabled: false);
        expect(gpsOff.devicePermissionGranted, isFalse);
        expect(gpsOff.sharingPrerequisitesSatisfied, isFalse);
        expect(gpsOff.effectiveSharing, isFalse);

        // Inactive membership
        final inactiveMember = fullActive.copyWith(isActiveMember: false);
        expect(inactiveMember.sharingPrerequisitesSatisfied, isFalse);
        expect(inactiveMember.effectiveSharing, isFalse);
      },
    );

    test('permission helper getters report correct flags', () {
      const stateDenied = GroupLocationSharingState(
        groupId: 42,
        devicePermission: LocationPermission.denied,
      );
      expect(stateDenied.isPermissionDenied, isTrue);
      expect(stateDenied.isPermissionPermanentlyDenied, isFalse);

      const stateForever = GroupLocationSharingState(
        groupId: 42,
        devicePermission: LocationPermission.deniedForever,
      );
      expect(stateForever.isPermissionPermanentlyDenied, isTrue);
      expect(stateForever.isPermissionDenied, isFalse);

      const stateAlways = GroupLocationSharingState(
        groupId: 42,
        devicePermission: LocationPermission.always,
        isLocationServiceEnabled: true,
      );
      expect(stateAlways.devicePermissionGranted, isTrue);
    });
  });

  group('GroupLocationSharingCubit - Initialization & Membership', () {
    test(
      'initializes and verifies active membership for authenticated member',
      () async {
        final locationService = _MockLocationService(
          permission: LocationPermission.whileInUse,
          serviceEnabled: true,
        );
        final repo = _MockGroupRepository(membersResult: sampleMembers);
        final storage = _MockStorage(_jwtWithUserId(101));

        final cubit = GroupLocationSharingCubit(
          groupId: 42,
          travelGroupRepository: repo,
          locationService: locationService,
          secureStorage: storage,
        );

        await cubit.initialize();

        expect(cubit.state.status, equals(GroupLocationSharingStatus.ready));
        expect(cubit.state.groupName, equals('Da Nang Explorer'));
        expect(cubit.state.isActiveMember, isTrue);
        expect(
          cubit.state.storedOptIn,
          isFalse,
        ); // member 101 has locationSharingEnabled: false
        expect(cubit.state.devicePermissionGranted, isTrue);
        expect(cubit.state.effectiveSharing, isFalse); // storedOptIn is false
        expect(cubit.state.pendingBeIntegration, isTrue); // production mode
      },
    );

    test(
      'loads storedOptIn true if member entity has locationSharingEnabled true',
      () async {
        final locationService = _MockLocationService(
          permission: LocationPermission.whileInUse,
        );
        final repo = _MockGroupRepository(membersResult: sampleMembers);
        final storage = _MockStorage(
          _jwtWithUserId(102),
        ); // Bob has locationSharingEnabled: true

        final cubit = GroupLocationSharingCubit(
          groupId: 42,
          travelGroupRepository: repo,
          locationService: locationService,
          secureStorage: storage,
        );

        await cubit.initialize();

        expect(cubit.state.isActiveMember, isTrue);
        expect(cubit.state.storedOptIn, isTrue);
        expect(cubit.state.sharingPrerequisitesSatisfied, isTrue);
        // Production mode has no confirmed broadcast transport, so delivery is
        // unconfirmed and effective active sharing remains strictly false.
        expect(cubit.state.liveLocationDeliveryConfirmed, isFalse);
        expect(cubit.state.isActivelySharing, isFalse);
        expect(cubit.state.effectiveSharing, isFalse);
      },
    );

    test(
      'fails closed to inactive membership when user is not in group members list',
      () async {
        final locationService = _MockLocationService();
        final repo = _MockGroupRepository(membersResult: sampleMembers);
        final storage = _MockStorage(_jwtWithUserId(999)); // Not in group

        final cubit = GroupLocationSharingCubit(
          groupId: 42,
          travelGroupRepository: repo,
          locationService: locationService,
          secureStorage: storage,
        );

        await cubit.initialize();

        expect(cubit.state.isActiveMember, isFalse);
        expect(cubit.state.effectiveSharing, isFalse);
      },
    );

    test(
      'fails closed to inactive membership when repository throws failure',
      () async {
        final locationService = _MockLocationService();
        final repo = _MockGroupRepository(
          failure: const ServerFailure('Backend unavailable'),
        );
        final storage = _MockStorage(_jwtWithUserId(101));

        final cubit = GroupLocationSharingCubit(
          groupId: 42,
          travelGroupRepository: repo,
          locationService: locationService,
          secureStorage: storage,
        );

        await cubit.initialize();

        expect(cubit.state.isActiveMember, isFalse);
        expect(cubit.state.status, equals(GroupLocationSharingStatus.ready));
      },
    );

    test('fails closed to inactive membership when unauthenticated', () async {
      final locationService = _MockLocationService();
      final repo = _MockGroupRepository(membersResult: sampleMembers);
      final storage = _MockStorage(null); // No token

      final cubit = GroupLocationSharingCubit(
        groupId: 42,
        travelGroupRepository: repo,
        locationService: locationService,
        secureStorage: storage,
      );

      await cubit.initialize();

      expect(cubit.state.isActiveMember, isFalse);
    });
  });

  group(
    'GroupLocationSharingCubit - Production Mode Truthfulness (NO_BACKEND)',
    () {
      test(
        'rejects toggle attempt with pendingBeIntegrationMessage and never mutates storedOptIn',
        () async {
          final locationService = _MockLocationService(
            permission: LocationPermission.whileInUse,
          );
          final repo = _MockGroupRepository(membersResult: sampleMembers);
          final storage = _MockStorage(_jwtWithUserId(101));

          final cubit = GroupLocationSharingCubit(
            groupId: 42,
            travelGroupRepository: repo,
            locationService: locationService,
            secureStorage: storage,
            isDemoMode: false,
          );
          await cubit.initialize();

          expect(cubit.state.isActiveMember, isTrue);
          expect(cubit.state.storedOptIn, isFalse);

          await cubit.toggleLocationSharing(true);

          // State storedOptIn must NOT change to true
          expect(cubit.state.storedOptIn, isFalse);
          expect(
            cubit.state.errorMessage,
            equals(GroupLocationSharingCubit.pendingBeIntegrationMessage),
          );
          expect(cubit.state.noticeMessage, isNull);
        },
      );

      test('rejects toggle attempt if user is not active member', () async {
        final locationService = _MockLocationService();
        final repo = _MockGroupRepository(membersResult: sampleMembers);
        final storage = _MockStorage(_jwtWithUserId(999)); // Not member

        final cubit = GroupLocationSharingCubit(
          groupId: 42,
          travelGroupRepository: repo,
          locationService: locationService,
          secureStorage: storage,
        );
        await cubit.initialize();

        await cubit.toggleLocationSharing(true);

        expect(
          cubit.state.errorMessage,
          equals(GroupLocationSharingCubit.inactiveMemberMessage),
        );
      });
    },
  );

  group('GroupLocationSharingCubit - Native OS Permission Interactions', () {
    test('checkDevicePermission updates state on app resume', () async {
      final locationService = _MockLocationService(
        permission: LocationPermission.denied,
      );
      final cubit = GroupLocationSharingCubit(
        groupId: 42,
        locationService: locationService,
        isDemoMode: true,
        initialActiveMembership: true,
      );
      await cubit.initialize();

      expect(cubit.state.devicePermissionGranted, isFalse);

      // Simulate user granting permission in OS settings
      locationService.permission = LocationPermission.whileInUse;
      await cubit.checkDevicePermission();

      expect(cubit.state.devicePermissionGranted, isTrue);
      expect(
        cubit.state.devicePermission,
        equals(LocationPermission.whileInUse),
      );
    });

    test('requestDevicePermission prompts OS and updates state', () async {
      final locationService = _MockLocationService(
        permission: LocationPermission.denied,
        requestPermissionResult: LocationPermission.whileInUse,
      );
      final cubit = GroupLocationSharingCubit(
        groupId: 42,
        locationService: locationService,
        isDemoMode: true,
        initialActiveMembership: true,
      );
      await cubit.initialize();

      await cubit.requestDevicePermission();

      expect(locationService.requestPermissionCalls, equals(1));
      expect(cubit.state.devicePermissionGranted, isTrue);
      expect(cubit.state.errorMessage, isNull);
    });

    test(
      'requestDevicePermission emits permissionRequiredMessage if user denies',
      () async {
        final locationService = _MockLocationService(
          permission: LocationPermission.denied,
          requestPermissionResult: LocationPermission.denied,
        );
        final cubit = GroupLocationSharingCubit(
          groupId: 42,
          locationService: locationService,
          isDemoMode: true,
          initialActiveMembership: true,
        );
        await cubit.initialize();

        await cubit.requestDevicePermission();

        expect(cubit.state.devicePermissionGranted, isFalse);
        expect(
          cubit.state.errorMessage,
          equals(GroupLocationSharingCubit.permissionRequiredMessage),
        );
      },
    );

    test('openAppSettings delegates to location service', () async {
      final locationService = _MockLocationService();
      final cubit = GroupLocationSharingCubit(
        groupId: 42,
        locationService: locationService,
      );

      final opened = await cubit.openAppSettings();
      expect(opened, isTrue);
      expect(locationService.openAppSettingsCalls, equals(1));
    });

    test('openLocationSettings delegates to location service', () async {
      final locationService = _MockLocationService();
      final cubit = GroupLocationSharingCubit(
        groupId: 42,
        locationService: locationService,
      );

      final opened = await cubit.openLocationSettings();
      expect(opened, isTrue);
      expect(locationService.openLocationSettingsCalls, equals(1));
    });
  });

  group('GroupLocationSharingCubit - Demo Mode Behavior', () {
    test(
      'demo mode allows toggling opt-in when permission is granted',
      () async {
        final locationService = _MockLocationService(
          permission: LocationPermission.whileInUse,
        );
        final cubit = GroupLocationSharingCubit(
          groupId: 42,
          locationService: locationService,
          isDemoMode: true,
          initialActiveMembership: true,
        );
        await cubit.initialize();

        expect(cubit.state.storedOptIn, isFalse);

        // Toggle ON
        await cubit.toggleLocationSharing(true);
        expect(cubit.state.storedOptIn, isTrue);
        expect(cubit.state.effectiveSharing, isTrue);
        expect(
          cubit.state.noticeMessage,
          equals(GroupLocationSharingCubit.sharingEnabledNotice),
        );

        // Toggle OFF
        await cubit.toggleLocationSharing(false);
        expect(cubit.state.storedOptIn, isFalse);
        expect(cubit.state.effectiveSharing, isFalse);
        expect(
          cubit.state.noticeMessage,
          equals(GroupLocationSharingCubit.sharingDisabledNotice),
        );
      },
    );

    test(
      'demo mode requests permission if permission is denied when toggling ON',
      () async {
        final locationService = _MockLocationService(
          permission: LocationPermission.denied,
          requestPermissionResult: LocationPermission.whileInUse,
        );
        final cubit = GroupLocationSharingCubit(
          groupId: 42,
          locationService: locationService,
          isDemoMode: true,
          initialActiveMembership: true,
        );
        await cubit.initialize();

        await cubit.toggleLocationSharing(true);

        expect(locationService.requestPermissionCalls, equals(1));
        expect(cubit.state.storedOptIn, isTrue);
        expect(cubit.state.effectiveSharing, isTrue);
      },
    );

    test('demo helper methods adjust state properly', () {
      final cubit = GroupLocationSharingCubit(
        groupId: 42,
        isDemoMode: true,
        initialActiveMembership: true,
      );

      cubit.setDemoPermission(LocationPermission.deniedForever);
      expect(cubit.state.isPermissionPermanentlyDenied, isTrue);

      cubit.setDemoStoredOptIn(true);
      expect(cubit.state.storedOptIn, isTrue);

      cubit.setDemoActiveMembership(false);
      expect(cubit.state.isActiveMember, isFalse);
      expect(cubit.state.effectiveSharing, isFalse);

      cubit.setDemoDeliveryConfirmed(true);
      expect(cubit.state.liveLocationDeliveryConfirmed, isTrue);
      cubit.setDemoDeliveryConfirmed(false);
      expect(cubit.state.liveLocationDeliveryConfirmed, isFalse);

      cubit.clearMessages();
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.noticeMessage, isNull);
    });
  });
}
