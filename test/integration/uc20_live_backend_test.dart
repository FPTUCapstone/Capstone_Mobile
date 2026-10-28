import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/in_app_notification_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/itinerary_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/travel_group_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/in_app_inbox_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/in_app_inbox_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/travel_group_members_state.dart';
import 'package:uuid/uuid.dart';

void main() {
  final env = Platform.environment;
  final live =
      env['UC20_API_BASE_URL'] != null &&
      env['UC20_HOST_TOKEN'] != null &&
      env['UC20_MEMBER_TOKEN'] != null &&
      env['UC20_EXTRA_TOKEN'] != null &&
      env['UC20_OUTSIDER_TOKEN'] != null;

  test(
    'Mobile repositories and Cubits execute UC-20 against a real BE and SQL Server',
    () async {
      final groupId = int.parse(env['UC20_GROUP_ID']!);
      final hostId = int.parse(env['UC20_HOST_ID']!);
      final memberId = int.parse(env['UC20_MEMBER_ID']!);
      final extraId = int.parse(env['UC20_EXTRA_ID']!);
      final outsiderId = int.parse(env['UC20_OUTSIDER_ID']!);
      final host = _groupRepository(env['UC20_HOST_TOKEN']);
      final member = _groupRepository(env['UC20_MEMBER_TOKEN']);
      final extra = _groupRepository(env['UC20_EXTRA_TOKEN']);
      final outsider = _groupRepository(env['UC20_OUTSIDER_TOKEN']);
      final anonymous = _groupRepository(null);

      final initial = await host.getTravelGroupMembers(groupId: groupId);
      expect(
        initial.members.map((m) => m.memberId),
        containsAll([hostId, memberId, extraId]),
      );
      await expectLater(
        anonymous.getTravelGroupMembers(groupId: groupId),
        throwsA(isA<AuthenticationFailure>()),
      );
      await expectLater(
        outsider.removeGroupMember(
          groupId: groupId,
          memberUserId: memberId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<PermissionFailure>()),
      );
      await expectLater(
        host.removeGroupMember(
          groupId: groupId,
          memberUserId: hostId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        host.removeGroupMember(
          groupId: groupId,
          memberUserId: extraId,
          idempotencyKey: 'not-a-uuid',
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        host.removeGroupMember(
          groupId: groupId + 10000,
          memberUserId: extraId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<NotFoundFailure>()),
      );

      final key = const Uuid().v4();
      final first = await host.removeGroupMember(
        groupId: groupId,
        memberUserId: extraId,
        idempotencyKey: key,
      );
      expect(first.memberName, 'Extra UC20');
      expect(
        (await host.getTravelGroupMembers(
          groupId: groupId,
        )).members.any((m) => m.memberId == extraId),
        isFalse,
      );
      await expectLater(
        extra.getTravelGroupMembers(groupId: groupId),
        throwsA(isA<PermissionFailure>()),
      );
      await expectLater(
        host.removeGroupMember(
          groupId: groupId,
          memberUserId: extraId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<ConflictFailure>()),
      );
      await expectLater(
        host.removeGroupMember(
          groupId: groupId,
          memberUserId: memberId,
          idempotencyKey: key,
        ),
        throwsA(isA<ConflictFailure>()),
      );

      final extraInbox = _notificationRepository(env['UC20_EXTRA_TOKEN']);
      final outsiderInbox = _notificationRepository(env['UC20_OUTSIDER_TOKEN']);
      final notices = await extraInbox.getInbox(unreadOnly: true);
      expect(notices.items, hasLength(1));
      expect(notices.items.single.type, 'TravelGroupMemberRemoved');
      expect(notices.items.single.body, contains('UC20 test group'));
      expect((await outsiderInbox.getInbox()).items, isEmpty);
      await expectLater(
        outsiderInbox.markRead(notices.items.single.id),
        throwsA(isA<NotFoundFailure>()),
      );
      final inboxCubit = InAppInboxCubit(extraInbox);
      addTearDown(inboxCubit.close);
      await inboxCubit.load();
      expect(inboxCubit.state.status, InAppInboxStatus.ready);
      await inboxCubit.markRead(notices.items.single.id);
      expect(inboxCubit.state.items.single.isRead, isTrue);
      await extraInbox.markRead(notices.items.single.id);
      expect((await extraInbox.getInbox(unreadOnly: true)).items, isEmpty);

      final invitation = await host.getOrCreateGroupInvitation(
        groupId: groupId,
        idempotencyKey: const Uuid().v4(),
      );
      await extra.joinTravelGroup(
        invitationCode: invitation.inviteCode,
        idempotencyKey: const Uuid().v4(),
      );
      final replay = await host.removeGroupMember(
        groupId: groupId,
        memberUserId: extraId,
        idempotencyKey: key,
      );
      expect(replay, first);
      expect(
        (await host.getTravelGroupMembers(
          groupId: groupId,
        )).members.any((m) => m.memberId == extraId),
        isTrue,
      );
      expect((await extraInbox.getInbox()).items, hasLength(1));

      final removalCubit = TravelGroupMembersCubit(repository: host);
      addTearDown(removalCubit.close);
      await removalCubit.load(groupId: groupId);
      await removalCubit.removeMember(groupId: groupId, memberUserId: memberId);
      expect(removalCubit.state, isA<TravelGroupMembersSuccess>());
      expect(
        (removalCubit.state as TravelGroupMembersSuccess).removedMemberName,
        'Member UC20',
      );
      await expectLater(
        member.getTravelGroupMembers(groupId: groupId),
        throwsA(isA<PermissionFailure>()),
      );
      final memberNotices = await _notificationRepository(
        env['UC20_MEMBER_TOKEN'],
      ).getInbox(unreadOnly: true);
      expect(memberNotices.items, hasLength(1));
      expect(memberNotices.items.single.type, 'TravelGroupMemberRemoved');
      expect(outsiderId, isNot(memberId));
    },
    skip: live ? null : 'Requires UC20 live BE test environment.',
  );

  test(
    'Mobile maps closed, inconsistent, invalid and inactive removal cases',
    () async {
      final groupId = int.parse(env['UC20_GROUP_ID']!);
      final closedGroupId = int.parse(env['UC20_CLOSED_GROUP_ID']!);
      final inconsistentGroupId = int.parse(env['UC20_INCONSISTENT_GROUP_ID']!);
      final memberId = int.parse(env['UC20_MEMBER_ID']!);
      final outsiderId = int.parse(env['UC20_OUTSIDER_ID']!);
      final host = _groupRepository(env['UC20_HOST_TOKEN']);
      final anonymous = _groupRepository(null);
      final extra = _groupRepository(env['UC20_EXTRA_TOKEN']);

      await expectLater(
        host.removeGroupMember(
          groupId: closedGroupId,
          memberUserId: outsiderId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<ConflictFailure>()),
      );
      await expectLater(
        host.removeGroupMember(
          groupId: inconsistentGroupId,
          memberUserId: outsiderId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<ServerFailure>()),
      );
      await expectLater(
        host.removeGroupMember(
          groupId: groupId,
          memberUserId: memberId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<ConflictFailure>()),
      );
      await expectLater(
        host.removeGroupMember(
          groupId: groupId,
          memberUserId: outsiderId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<ConflictFailure>()),
      );
      await expectLater(
        host.removeGroupMember(
          groupId: 0,
          memberUserId: outsiderId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        anonymous.removeGroupMember(
          groupId: groupId,
          memberUserId: outsiderId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<AuthenticationFailure>()),
      );
      await expectLater(
        extra.removeGroupMember(
          groupId: groupId,
          memberUserId: outsiderId,
          idempotencyKey: const Uuid().v4(),
        ),
        throwsA(isA<PermissionFailure>()),
      );
    },
    skip: live ? null : 'Requires UC20 live BE test environment.',
  );

  test(
    'Removed member cannot read manual itinerary while owner retains access',
    () async {
      final removed = ItineraryRepositoryImpl(
        dioClient: _client(env['UC20_MEMBER_TOKEN']),
      );
      final owner = ItineraryRepositoryImpl(
        dioClient: _client(env['UC20_HOST_TOKEN']),
      );
      await expectLater(removed.getById(1), throwsA(isA<PermissionFailure>()));
      final detail = await owner.getById(1);
      expect(detail.itineraryId, 1);
    },
    skip: live ? null : 'Requires UC20 live BE test environment.',
  );
}

TravelGroupRepositoryImpl _groupRepository(String? token) =>
    TravelGroupRepositoryImpl(dioClient: _client(token));

InAppNotificationRepositoryImpl _notificationRepository(String? token) =>
    InAppNotificationRepositoryImpl(dioClient: _client(token));

DioClient _client(String? token) => DioClient(
  config: AppConfig(
    environment: Environment.production,
    apiBaseUrl: Uri.parse(Platform.environment['UC20_API_BASE_URL']!),
  ),
  secureStorage: _TokenStorage(token),
);

final class _TokenStorage implements SecureStorageService {
  const _TokenStorage(this.token);
  final String? token;

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
