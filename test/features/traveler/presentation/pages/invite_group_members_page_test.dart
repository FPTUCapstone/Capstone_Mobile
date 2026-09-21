import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_invitation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_group.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/travel_group_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/invite_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/invite_group_members_page.dart';

mixin _JoinGroupStub {
  Future<TravelGroup> joinTravelGroup({
    required String invitationCode,
    required String idempotencyKey,
  }) async => throw UnimplementedError();
}

final class _MockRepository
    with _JoinGroupStub
    implements TravelGroupRepository {
  bool shouldFail = false;
  int getInvitationCallCount = 0;

  final testInvitation = GroupInvitation(
    groupId: 42,
    groupName: 'Da Nang Summer 2026',
    inviteCode: 'TM7X9K2A',
    qrData: 'tripmate://groups/join?code=TM7X9K2A',
    expiresAt: DateTime(2026, 10, 8),
  );

  @override
  Future<TravelGroup> createTravelGroup({
    required String name,
    required int itineraryId,
  }) async => const TravelGroup(id: 1, name: 'Group');

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
  }) async => testInvitation;
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

  Widget buildSubject({int groupId = 42}) {
    return MaterialApp(
      home: BlocProvider<InviteGroupMembersCubit>.value(
        value: cubit,
        child: InviteGroupMembersPage(groupId: groupId),
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
}
