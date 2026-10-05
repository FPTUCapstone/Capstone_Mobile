import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_member.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/group_location_sharing_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/group_location_sharing_page.dart';

class _FakeLocationService implements DeviceLocationService {
  _FakeLocationService({
    this.permission = LocationPermission.denied,
    this.serviceEnabled = true,
  });

  LocationPermission permission;
  bool serviceEnabled;
  int checkCalls = 0;
  int requestCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  @override
  Future<DeviceLocation> getCurrentLocation() =>
      throw UnimplementedError('Not used in Screen #61');

  @override
  Future<LocationPermission> checkPermission() async {
    checkCalls++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    permission = LocationPermission.whileInUse;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return true;
  }
}

class _FakeGroupRepository implements TravelGroupRepository {
  _FakeGroupRepository(this.membersResult);

  final TravelGroupMembers membersResult;

  @override
  Future<TravelGroupMembers> getTravelGroupMembers({
    required int groupId,
  }) async {
    return membersResult;
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

class _FakeStorage implements SecureStorageService {
  _FakeStorage([this.token]);

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

String _jwtToken(int id) {
  final header = base64Url.encode(
    utf8.encode(json.encode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(json.encode({'sub': id})));
  return '$header.$body.sig';
}

void main() {
  final groupMembers = TravelGroupMembers(
    groupId: 55,
    groupName: 'Hoi An Ancient Tour',
    itineraryId: 12,
    members: [
      TravelGroupMember(
        memberId: 77,
        displayName: 'Minh Traveler',
        isHost: true,
        joinedAtUtc: DateTime.utc(2026, 9, 25),
        locationSharingEnabled: false,
      ),
    ],
  );

  Widget createWidget({
    GroupLocationSharingCubit? cubit,
    DeviceLocationService? locationService,
    TravelGroupRepository? repository,
    SecureStorageService? storage,
    bool isDemoMode = false,
    double textScaleFactor = 1.0,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
        child: GroupLocationSharingPage(
          groupId: 55,
          groupName: 'Hoi An Ancient Tour',
          cubit: cubit,
          locationService: locationService ?? _FakeLocationService(),
          travelGroupRepository:
              repository ?? _FakeGroupRepository(groupMembers),
          secureStorage: storage ?? _FakeStorage(_jwtToken(77)),
          isDemoMode: isDemoMode,
        ),
      ),
    );
  }

  testWidgets('renders all canonical elements of Screen #61 in production mode', (
    tester,
  ) async {
    final locationService = _FakeLocationService(
      permission: LocationPermission.denied,
    );
    final repo = _FakeGroupRepository(groupMembers);
    final storage = _FakeStorage(_jwtToken(77));

    await tester.pumpWidget(
      createWidget(
        locationService: locationService,
        repository: repo,
        storage: storage,
        isDemoMode: false,
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header & Title
    expect(find.text('Location Sharing'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    // 2. Production Truthful Banner
    expect(find.text('Pending Server Integration'), findsOneWidget);
    expect(
      find.textContaining(
        'Location sharing configuration is pending server integration',
      ),
      findsOneWidget,
    );

    // 3. Status Hero Card
    expect(find.text('Location Sharing Off'), findsOneWidget);

    // 4. Primary Setting Card & Switch
    expect(find.text('Share my live location'), findsOneWidget);
    expect(
      find.text(
        'With members of this group only (Editing disabled pending server integration)',
      ),
      findsOneWidget,
    );
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    final switchWidget = tester.widget<Switch>(switchFinder);
    expect(switchWidget.value, isFalse);
    expect(switchWidget.onChanged, isNull);

    // 5. Audience Card
    expect(find.text('Who can see my location'), findsOneWidget);
    expect(find.text('Members of Hoi An Ancient Tour'), findsOneWidget);

    // 6. Device Permission Card
    expect(find.text('Device Location Permission'), findsOneWidget);
    expect(find.text('Permission Denied'), findsOneWidget);
    expect(find.text('Request Permission'), findsOneWidget);

    // 7. Privacy Notice Card
    expect(
      find.textContaining(
        'Your location is shared only with active members of this travel group',
      ),
      findsOneWidget,
    );

    // 8. Demo controls should NOT be visible in production mode
    expect(find.byIcon(Icons.bug_report), findsNothing);
    expect(find.text('DEMO_ONLY Test Controls'), findsNothing);
  });

  testWidgets(
    'production mode rejects toggle attempt without mutating switch or faking MSG62/63',
    (tester) async {
      final locationService = _FakeLocationService(
        permission: LocationPermission.whileInUse,
      );
      final repo = _FakeGroupRepository(groupMembers);
      final storage = _FakeStorage(_jwtToken(77));

      await tester.pumpWidget(
        createWidget(
          locationService: locationService,
          repository: repo,
          storage: storage,
          isDemoMode: false,
        ),
      );
      await tester.pumpAndSettle();

      // Tap switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify switch is still false
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      // No success snackbars faked
      expect(
        find.text('Live location sharing is now active with group members.'),
        findsNothing,
      );
      expect(find.text('Live location sharing disabled.'), findsNothing);
    },
  );

  testWidgets('requesting permission calls location service', (tester) async {
    final locationService = _FakeLocationService(
      permission: LocationPermission.denied,
    );
    final repo = _FakeGroupRepository(groupMembers);
    final storage = _FakeStorage(_jwtToken(77));

    await tester.pumpWidget(
      createWidget(
        locationService: locationService,
        repository: repo,
        storage: storage,
        isDemoMode: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Request Permission'), findsOneWidget);
    await tester.ensureVisible(find.text('Request Permission'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request Permission'));
    await tester.pumpAndSettle();

    expect(locationService.requestCalls, equals(1));
    expect(find.text('Permission Granted'), findsOneWidget);
  });

  testWidgets('permanently denied shows Open Device Settings button', (
    tester,
  ) async {
    final locationService = _FakeLocationService(
      permission: LocationPermission.deniedForever,
    );
    final repo = _FakeGroupRepository(groupMembers);
    final storage = _FakeStorage(_jwtToken(77));

    await tester.pumpWidget(
      createWidget(
        locationService: locationService,
        repository: repo,
        storage: storage,
        isDemoMode: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permanently Denied'), findsOneWidget);
    expect(find.text('Open Device Settings'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Device Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Device Settings'));
    await tester.pumpAndSettle();

    expect(locationService.openAppSettingsCalls, equals(1));
  });

  testWidgets('location service disabled shows Open Location Settings button', (
    tester,
  ) async {
    final locationService = _FakeLocationService(
      permission: LocationPermission.whileInUse,
      serviceEnabled: false,
    );
    final repo = _FakeGroupRepository(groupMembers);
    final storage = _FakeStorage(_jwtToken(77));

    await tester.pumpWidget(
      createWidget(
        locationService: locationService,
        repository: repo,
        storage: storage,
        isDemoMode: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Location Services Disabled'), findsOneWidget);
    expect(find.text('Open Location Settings'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Location Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Location Settings'));
    await tester.pumpAndSettle();

    expect(locationService.openLocationSettingsCalls, equals(1));
  });

  testWidgets(
    'demo controls panel allows toggling permission and opt-in permutations',
    (tester) async {
      final locationService = _FakeLocationService(
        permission: LocationPermission.denied,
      );

      await tester.pumpWidget(
        createWidget(locationService: locationService, isDemoMode: true),
      );
      await tester.pumpAndSettle();

      // Demo icon in AppBar is present
      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);

      // Tap to open demo controls
      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await tester.pumpAndSettle();

      expect(find.text('DEMO_ONLY Test Controls'), findsOneWidget);

      // Grant permission via demo control chip
      await tester.ensureVisible(find.text('Grant Permission'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grant Permission'));
      await tester.pumpAndSettle();

      expect(find.text('Permission Granted'), findsOneWidget);

      // Toggle switch ON in demo mode with active membership
      // First simulate active member
      await tester.ensureVisible(find.text('Simulate Active Member'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate Active Member'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify effective sharing becomes active with truthful demo labeling
      expect(find.text('Demo Preview: Sharing Active'), findsOneWidget);
      expect(
        find.text('Live location sharing is now active with group members.'),
        findsOneWidget,
      );

      // Verify toggling simulated broadcast off changes status to Unavailable
      await tester.ensureVisible(find.text('Simulate Broadcast Off'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate Broadcast Off'));
      await tester.pumpAndSettle();

      expect(find.text('Location Sharing Unavailable'), findsOneWidget);
      expect(
        find.textContaining('server broadcast integration is pending'),
        findsOneWidget,
      );

      // Verify toggling simulated broadcast back on restores Active status
      await tester.ensureVisible(find.text('Simulate Broadcast On'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate Broadcast On'));
      await tester.pumpAndSettle();

      expect(find.text('Demo Preview: Sharing Active'), findsOneWidget);
    },
  );

  testWidgets('app resume triggers permission check', (tester) async {
    final locationService = _FakeLocationService(
      permission: LocationPermission.denied,
    );

    await tester.pumpWidget(
      createWidget(locationService: locationService, isDemoMode: true),
    );
    await tester.pumpAndSettle();

    final initialChecks = locationService.checkCalls;

    // Simulate lifecycle resume
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(locationService.checkCalls, greaterThan(initialChecks));
  });

  testWidgets(
    'renders cleanly with 200% text scale without overflow on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      final locationService = _FakeLocationService(
        permission: LocationPermission.whileInUse,
      );

      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
      };

      await tester.pumpWidget(
        createWidget(
          locationService: locationService,
          isDemoMode: false,
          textScaleFactor: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;

      // Header and cards render without RenderFlex overflow exception
      expect(find.text('Location Sharing'), findsOneWidget);
      expect(find.text('Pending Server Integration'), findsOneWidget);
      expect(caughtDetails, isNull);
    },
  );

  testWidgets(
    'production mode with storedOptIn true and granted permission renders Location Sharing Unavailable and disabled switch',
    (tester) async {
      final membersWithOptIn = TravelGroupMembers(
        groupId: 55,
        groupName: 'Hoi An Ancient Tour',
        itineraryId: 12,
        members: [
          TravelGroupMember(
            memberId: 77,
            displayName: 'Minh Traveler',
            isHost: true,
            joinedAtUtc: DateTime.utc(2026, 9, 25),
            locationSharingEnabled: true,
          ),
        ],
      );
      final locationService = _FakeLocationService(
        permission: LocationPermission.whileInUse,
      );
      final repo = _FakeGroupRepository(membersWithOptIn);
      final storage = _FakeStorage(_jwtToken(77));

      await tester.pumpWidget(
        createWidget(
          locationService: locationService,
          repository: repo,
          storage: storage,
          isDemoMode: false,
        ),
      );
      await tester.pumpAndSettle();

      // Hero card must be truthful: NOT "Sharing is Active", but "Location Sharing Unavailable"
      expect(find.text('Location Sharing Unavailable'), findsOneWidget);
      expect(
        find.textContaining('server broadcast integration is pending'),
        findsOneWidget,
      );
      expect(find.text('Sharing is Active'), findsNothing);
      expect(
        find.textContaining('Your location is shared with members'),
        findsNothing,
      );

      // Switch is visually ON but strictly disabled (onChanged == null)
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);
      expect(switchWidget.onChanged, isNull);
      expect(
        find.text(
          'With members of this group only (Consent is ON — editing disabled pending server integration)',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'inactive member in production mode disables switch and shows inactive hero',
    (tester) async {
      final locationService = _FakeLocationService(
        permission: LocationPermission.whileInUse,
      );
      final repo = _FakeGroupRepository(groupMembers);
      final storage = _FakeStorage(_jwtToken(999)); // Not in group

      await tester.pumpWidget(
        createWidget(
          locationService: locationService,
          repository: repo,
          storage: storage,
          isDemoMode: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Membership Inactive'), findsOneWidget);
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);
      expect(
        find.text(
          'With members of this group only (Editing disabled pending server integration)',
        ),
        findsOneWidget,
      );
    },
  );
}
