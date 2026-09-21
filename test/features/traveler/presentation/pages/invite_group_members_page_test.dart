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
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/invite_group_members_page.dart';

final class _MockRepository implements TravelGroupRepository {
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
      expect(find.text('GROUP HOST'), findsOneWidget);
      expect(find.text('TM7X9K2A'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Share Invitation'), findsOneWidget);
      expect(find.text('Valid until: 08/10/2026 07:00 ICT'), findsOneWidget);
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
        'TripMate is temporarily unable to process your request. Please check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    // Click retry with success
    repository.shouldFail = false;
    await tester.tap(find.text('Retry'));
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

    final copyButton = find.byTooltip('Copy Code');
    expect(copyButton, findsOneWidget);

    await tester.tap(copyButton);
    await tester.pumpAndSettle();

    expect(find.text('Mã mời đã được sao chép vào bộ nhớ tạm.'), findsNothing);
    expect(
      find.text('Invite code "TM7X9K2A" copied to clipboard.'),
      findsOneWidget,
    );
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

    await tester.tap(find.text('Regenerate Invitation'));
    await tester.pumpAndSettle();

    expect(find.text('Regenerate invitation?'), findsOneWidget);
    expect(
      find.text('The current invitation code will stop working immediately.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Regenerate invitation?'), findsNothing);
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
    await tester.tap(find.byTooltip('Copy Code'));
    await tester.pump();
    expect(find.textContaining('copied to clipboard'), findsNothing);

    clipboardWrite.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('copied to clipboard'), findsOneWidget);
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
    await tester.tap(find.byTooltip('Copy Code'));
    await tester.pump();
    expect(find.textContaining('copied to clipboard'), findsNothing);
    expect(find.textContaining('temporarily unable'), findsOneWidget);
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
    await tester.tap(find.text('Close'));
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
      await tester.tap(find.text('Regenerate Invitation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regenerate').last);
      await tester.pumpAndSettle();

      expect(find.text('TM7X9K2A'), findsNothing);
      expect(find.byTooltip('Copy Code'), findsNothing);
      expect(find.text('Share Invitation'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.regenerationCallCount, 2);
      expect(find.text('ABCD2345'), findsOneWidget);
      expect(find.byTooltip('Copy Code'), findsOneWidget);
      expect(find.text('Share Invitation'), findsOneWidget);
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

    await tester.tap(find.text('Share Invitation'));
    await tester.pumpAndSettle();

    expect(sharedPayload, 'tripmate://groups/join?code=TM7X9K2A');
    expect(sharedOrigin, isNotNull);
    expect(sharedOrigin!.isEmpty, isFalse);
  });
}
