import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/location/device_location_service.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_member_removal.dart';
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

  @override
  Future<GroupMemberRemoval> removeGroupMember({
    required int groupId,
    required int memberUserId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

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
    expect(find.text('Chia sẻ vị trí'), findsOneWidget);
    expect(find.byTooltip('Đóng'), findsOneWidget);

    // 2. Production Truthful Banner
    expect(find.text('Đang chờ tích hợp máy chủ'), findsOneWidget);
    expect(
      find.textContaining('Cấu hình chia sẻ vị trí đang chờ tích hợp máy chủ'),
      findsOneWidget,
    );

    // 3. Status Hero Card
    expect(find.text('Chia sẻ vị trí đang tắt'), findsOneWidget);

    // 4. Primary Setting Card & Switch
    expect(find.text('Chia sẻ vị trí trực tiếp của tôi'), findsOneWidget);
    expect(
      find.text(
        'Chỉ với thành viên của nhóm này (Tạm khóa chỉnh sửa do chờ tích hợp máy chủ)',
      ),
      findsOneWidget,
    );
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    final switchWidget = tester.widget<Switch>(switchFinder);
    expect(switchWidget.value, isFalse);
    expect(switchWidget.onChanged, isNull);

    // 5. Audience Card
    expect(find.text('Ai có thể xem vị trí của tôi'), findsOneWidget);
    expect(find.text('Thành viên của Hoi An Ancient Tour'), findsOneWidget);

    // 6. Device Permission Card
    expect(find.text('Quyền vị trí thiết bị'), findsOneWidget);
    expect(find.text('Chưa cấp quyền vị trí'), findsOneWidget);
    expect(find.text('Yêu cầu quyền'), findsOneWidget);

    // 7. Privacy Notice Card
    expect(
      find.textContaining(
        'Vị trí của bạn chỉ được chia sẻ với các thành viên đang hoạt động trong nhóm du lịch này',
      ),
      findsOneWidget,
    );

    // 8. Demo controls should NOT be visible in production mode
    expect(find.byIcon(Icons.bug_report), findsNothing);
    expect(find.text('Điều khiển thử nghiệm (Demo)'), findsNothing);
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
        find.text('Đã bật chia sẻ vị trí trực tiếp với thành viên nhóm.'),
        findsNothing,
      );
      expect(find.text('Đã tắt chia sẻ vị trí trực tiếp.'), findsNothing);
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

    expect(find.text('Yêu cầu quyền'), findsOneWidget);
    await tester.ensureVisible(find.text('Yêu cầu quyền'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yêu cầu quyền'));
    await tester.pumpAndSettle();

    expect(locationService.requestCalls, equals(1));
    expect(find.text('Đã cấp quyền vị trí'), findsOneWidget);
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

    expect(find.text('Bị từ chối vĩnh viễn'), findsOneWidget);
    expect(find.text('Mở cài đặt thiết bị'), findsOneWidget);

    await tester.ensureVisible(find.text('Mở cài đặt thiết bị'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở cài đặt thiết bị'));
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

    expect(find.text('Dịch vụ định vị đang tắt'), findsOneWidget);
    expect(find.text('Mở cài đặt định vị'), findsOneWidget);

    await tester.ensureVisible(find.text('Mở cài đặt định vị'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở cài đặt định vị'));
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

      expect(find.text('Điều khiển thử nghiệm (Demo)'), findsOneWidget);

      // Grant permission via demo control chip
      await tester.ensureVisible(find.text('Cấp quyền vị trí'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cấp quyền vị trí'));
      await tester.pumpAndSettle();

      expect(find.text('Đã cấp quyền vị trí'), findsOneWidget);

      // Toggle switch ON in demo mode with active membership
      // First simulate active member
      await tester.ensureVisible(find.text('Giả lập thành viên hoạt động'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giả lập thành viên hoạt động'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify effective sharing becomes active with truthful demo labeling
      expect(find.text('Bản xem thử: Đang chia sẻ vị trí'), findsOneWidget);
      expect(
        find.text('Đã bật chia sẻ vị trí trực tiếp với thành viên nhóm.'),
        findsOneWidget,
      );

      // Verify toggling simulated broadcast off changes status to Unavailable
      await tester.ensureVisible(find.text('Giả lập tắt phát vị trí'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giả lập tắt phát vị trí'));
      await tester.pumpAndSettle();

      expect(find.text('Chia sẻ vị trí tạm chưa khả dụng'), findsOneWidget);
      expect(find.textContaining('chờ tích hợp máy chủ'), findsOneWidget);

      // Verify toggling simulated broadcast back on restores Active status
      await tester.ensureVisible(find.text('Giả lập bật phát vị trí'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giả lập bật phát vị trí'));
      await tester.pumpAndSettle();

      expect(find.text('Bản xem thử: Đang chia sẻ vị trí'), findsOneWidget);
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
      expect(find.text('Chia sẻ vị trí'), findsOneWidget);
      expect(find.text('Đang chờ tích hợp máy chủ'), findsOneWidget);
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
      expect(find.text('Chia sẻ vị trí tạm chưa khả dụng'), findsOneWidget);
      expect(
        find.textContaining(
          'Tính năng phát vị trí trực tiếp đang tạm dừng do chờ tích hợp máy chủ',
        ),
        findsOneWidget,
      );
      expect(find.text('Bản xem thử: Đang chia sẻ vị trí'), findsNothing);
      expect(
        find.textContaining('Vị trí của bạn đang được chia sẻ'),
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
          'Chỉ với thành viên của nhóm này (Đã đồng ý — tạm khóa chỉnh sửa do chờ tích hợp máy chủ)',
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

      expect(find.text('Không còn là thành viên hoạt động'), findsOneWidget);
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);
      expect(
        find.text(
          'Chỉ với thành viên của nhóm này (Tạm khóa chỉnh sửa do chờ tích hợp máy chủ)',
        ),
        findsOneWidget,
      );
    },
  );
}
