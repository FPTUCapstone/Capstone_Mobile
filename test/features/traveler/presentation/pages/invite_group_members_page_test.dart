import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_member_removal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group_members.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/invite_group_members_page.dart';

final class _MockRepository implements TravelGroupRepository {
  @override
  Future<GroupMemberRemoval> removeGroupMember({
    required int groupId,
    required int memberUserId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  bool shouldFail = false;
  int getInvitationCallCount = 0;
  int regenerationFailuresRemaining = 0;
  int regenerationCallCount = 0;
  GroupInvitation? replacementInvitation;

  final testInvitation = GroupInvitation(
    groupId: 42,
    groupName: 'Da Nang Summer 2026',
    inviteCode: 'TM7X9K2A',
    qrData: 'tripmate://groups/join?code=TM7X9K2A',
    expiresAt: DateTime.utc(2026, 10, 8),
  );

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
    required String idempotencyKey,
  }) async => const TravelGroup(id: 1, name: 'Group');

  @override
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<TravelGroupMembers> getTravelGroupMembers({required int groupId}) =>
      throw UnimplementedError();

  @override
  Future<GroupInvitation> getOrCreateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async {
    getInvitationCallCount++;
    if (shouldFail) {
      throw Exception('network error');
    }
    return testInvitation;
  }

  @override
  Future<GroupInvitation> regenerateGroupInvitation({
    required int groupId,
    required String idempotencyKey,
  }) async {
    regenerationCallCount++;
    if (regenerationFailuresRemaining > 0) {
      regenerationFailuresRemaining--;
      throw const NetworkFailure();
    }
    return replacementInvitation ?? testInvitation;
  }
}

void main() {
  late _MockRepository repository;
  late InviteGroupMembersCubit cubit;

  setUp(() {
    repository = _MockRepository();
    cubit = InviteGroupMembersCubit(repository: repository);
  });

  tearDown(() {
    cubit.close();
  });

  Widget buildSubject({
    int groupId = 42,
    Future<void> Function(String, Rect?)? shareOperation,
  }) {
    return MaterialApp(
      home: BlocProvider<InviteGroupMembersCubit>.value(
        value: cubit,
        child: InviteGroupMembersPage(
          groupId: groupId,
          shareOperation: shareOperation,
        ),
      ),
    );
  }

  testWidgets(
    'renders group header, QR view, and invite code on successful fetch',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Da Nang Summer 2026'), findsOneWidget);
      expect(find.text('TRƯỞNG NHÓM'), findsOneWidget);
      expect(find.text('TM7X9K2A'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Chia sẻ lời mời'), findsOneWidget);
      expect(
        find.text('Hiệu lực đến: 08/10/2026 07:00 (GMT+7)'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows error view when loading fails, and retries on tap', (
    tester,
  ) async {
    repository.shouldFail = true;
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng kiểm tra kết nối mạng và thử lại.',
      ),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);

    // Click retry with success
    repository.shouldFail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('TM7X9K2A'), findsOneWidget);
    expect(repository.getInvitationCallCount, 2);
  });

  testWidgets('shows SnackBar when tapping copy code button', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final copyButton = find.byTooltip('Sao chép mã');
    expect(copyButton, findsOneWidget);

    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(find.text('Mã mời đã được sao chép vào bộ nhớ tạm.'), findsNothing);
    expect(find.text('Đã sao chép mã mời "TM7X9K2A".'), findsOneWidget);
  });

  testWidgets('requires confirmation before regenerating the invitation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tạo lại lời mời'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo lại lời mời?'), findsOneWidget);
    expect(
      find.text('Mã mời hiện tại sẽ ngừng hoạt động ngay lập tức.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo lại lời mời?'), findsNothing);
  });
  testWidgets('copy feedback waits for clipboard completion', (tester) async {
    final clipboardWrite = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            await clipboardWrite.future;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sao chép mã'));
    await tester.pump();
    expect(find.textContaining('Đã sao chép mã mời'), findsNothing);

    clipboardWrite.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã sao chép mã mời'), findsOneWidget);
  });

  testWidgets('clipboard failure shows failure without false success', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard-unavailable');
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sao chép mã'));
    await tester.pump();
    expect(find.textContaining('Đã sao chép mã mời'), findsNothing);
    expect(find.textContaining('tạm thời không thể'), findsOneWidget);
  });

  testWidgets('direct invitation route Close returns to traveler area', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.inviteGroupMembers.replaceFirst(
        ':groupId',
        '42',
      ),
      routes: [
        GoRoute(
          path: AppRoutes.traveler,
          builder: (_, _) => const Scaffold(body: Text('Traveler Home')),
        ),
        GoRoute(
          path: AppRoutes.inviteGroupMembers,
          builder: (_, _) => BlocProvider<InviteGroupMembersCubit>.value(
            value: cubit,
            child: const InviteGroupMembersPage(groupId: 42),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Traveler Home'), findsOneWidget);
  });

  testWidgets(
    'uncertain regeneration hides old code until retry confirms new one',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      repository.regenerationFailuresRemaining = 1;
      repository.replacementInvitation = GroupInvitation(
        groupId: 42,
        groupName: 'Da Nang Summer 2026',
        inviteCode: 'ABCD2345',
        qrData: 'tripmate://groups/join?code=ABCD2345',
        expiresAt: DateTime.utc(2026, 10, 8),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo lại lời mời'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo lại').last);
      await tester.pumpAndSettle();

      expect(find.text('TM7X9K2A'), findsNothing);
      expect(find.byTooltip('Sao chép mã'), findsNothing);
      expect(find.text('Chia sẻ lời mời'), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(repository.regenerationCallCount, 2);
      expect(find.text('ABCD2345'), findsOneWidget);
      expect(find.byTooltip('Sao chép mã'), findsOneWidget);
      expect(find.text('Chia sẻ lời mời'), findsOneWidget);
    },
  );

  testWidgets('shares the confirmed invitation payload', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    String? sharedPayload;
    Rect? sharedOrigin;
    await tester.pumpWidget(
      buildSubject(
        shareOperation: (payload, origin) async {
          sharedPayload = payload;
          sharedOrigin = origin;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chia sẻ lời mời'));
    await tester.pumpAndSettle();

    expect(sharedPayload, 'tripmate://groups/join?code=TM7X9K2A');
    expect(sharedOrigin, isNotNull);
    expect(sharedOrigin!.isEmpty, isFalse);
  });
}
