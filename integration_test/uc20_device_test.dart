import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/in_app_notification_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/travel_group_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/in_app_inbox_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/in_app_inbox_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/in_app_inbox_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/travel_group_members_page.dart';
import 'package:uuid/uuid.dart';

const _apiBaseUrl = String.fromEnvironment('UC20_DEVICE_API_BASE_URL');
const _hostToken = String.fromEnvironment('UC20_DEVICE_HOST_TOKEN');
const _memberToken = String.fromEnvironment('UC20_DEVICE_MEMBER_TOKEN');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Host removes member and recipient reads notice on Android', (
    tester,
  ) async {
    expect(_apiBaseUrl, isNotEmpty);
    expect(_hostToken, isNotEmpty);
    expect(_memberToken, isNotEmpty);
    final host = TravelGroupRepositoryImpl(dioClient: _client(_hostToken));
    final member = TravelGroupRepositoryImpl(dioClient: _client(_memberToken));
    final inbox = InAppNotificationRepositoryImpl(
      dioClient: _client(_memberToken),
    );
    for (final notice in (await inbox.getInbox(unreadOnly: true)).items) {
      await inbox.markRead(notice.id);
    }
    if (!(await host.getTravelGroupMembers(
      groupId: 1,
    )).members.any((item) => item.memberId == 2)) {
      final invitation = await host.getOrCreateGroupInvitation(
        groupId: 1,
        idempotencyKey: const Uuid().v4(),
      );
      await member.joinTravelGroup(
        invitationCode: invitation.inviteCode,
        idempotencyKey: const Uuid().v4(),
      );
    }

    final membersCubit = TravelGroupMembersCubit(repository: host);
    addTearDown(membersCubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: membersCubit,
          child: const TravelGroupMembersPage(groupId: 1, currentUserId: 1),
        ),
      ),
    );
    await membersCubit.load(groupId: 1);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('remove_member_button_2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove_member_button_2')));
    await tester.pumpAndSettle();
    expect(
      find.text('Are you sure you want to remove Member UC20 from this group?'),
      findsOneWidget,
    );
    final removalFinished = membersCubit.stream
        .firstWhere(
          (state) =>
              (state is TravelGroupMembersSuccess &&
                  state.removedMemberName != null) ||
              state is TravelGroupMembersRemovalIssue ||
              state is TravelGroupMembersRemovalRetryable ||
              state is TravelGroupMembersPermissionDenied ||
              state is TravelGroupMembersNotFound ||
              state is TravelGroupMembersFailure,
        )
        .timeout(const Duration(seconds: 20));
    await tester.tap(find.byKey(const Key('remove_member_confirm_button')));
    expect(await removalFinished, isA<TravelGroupMembersSuccess>());
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(
      find.text('Member UC20 has been removed from the group.'),
      findsOneWidget,
    );
    expect(find.text('Member UC20'), findsNothing);

    final inboxCubit = InAppInboxCubit(inbox);
    addTearDown(inboxCubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: inboxCubit,
          child: const InAppInboxPage(),
        ),
      ),
    );
    await inboxCubit.setUnreadOnly(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('UC20 test group'), findsOneWidget);
    expect(find.text('Mark as read'), findsOneWidget);
    final readFinished = inboxCubit.stream
        .firstWhere(
          (state) =>
              state.status == InAppInboxStatus.ready &&
              state.items.isEmpty &&
              state.markingReadIds.isEmpty,
        )
        .timeout(const Duration(seconds: 20));
    await tester.tap(find.text('Mark as read'));
    await readFinished;
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('No unread notifications.'), findsOneWidget);
  });
}

DioClient _client(String token) => DioClient(
  config: AppConfig(
    environment: Environment.production,
    apiBaseUrl: Uri.parse(_apiBaseUrl),
  ),
  secureStorage: _TokenStorage(token),
);

final class _TokenStorage implements SecureStorageService {
  const _TokenStorage(this.token);
  final String token;

  @override
  Future<String?> read(String key) async =>
      key == AppConstants.accessTokenKey ? token : null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}
