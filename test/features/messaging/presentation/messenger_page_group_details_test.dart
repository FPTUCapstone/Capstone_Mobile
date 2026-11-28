import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/cubit/messenger_cubit.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/pages/messenger_page.dart';

void main() {
  testWidgets(
    'active group chat header and group icon open TravelGroupDetails route',
    (tester) async {
      final joinedAt = DateTime.utc(2026, 11, 20);
      const groupThread = ChatThread(
        ref: ChatThreadRef(kind: ChatKind.group, id: 40002),
        title: 'Đà Nẵng - Hội An 3N2Đ',
        unreadCount: 0,
        memberCount: 4,
      );
      final repo = _FakeMessagingRepository(
        groupThreads: const [groupThread],
        groupMembers: [
          ChatMember(
            userId: 1,
            displayName: 'Nguyễn Minh Anh',
            isHost: true,
            joinedAtUtc: joinedAt,
            locationSharingEnabled: true,
          ),
          ChatMember(
            userId: 2,
            displayName: 'Trần Gia Bảo',
            isHost: false,
            joinedAtUtc: joinedAt,
            locationSharingEnabled: true,
          ),
          ChatMember(
            userId: 3,
            displayName: 'Lê Quỳnh Hương',
            isHost: false,
            joinedAtUtc: joinedAt,
            locationSharingEnabled: false,
          ),
          ChatMember(
            userId: 4,
            displayName: 'Phạm Đức Minh',
            isHost: false,
            joinedAtUtc: joinedAt,
            locationSharingEnabled: true,
          ),
        ],
      );
      final cubit = MessengerCubit(MessagingUseCases(repo), _FakeRealtime(), 1);

      final pushedLocations = <String>[];
      final router = GoRouter(
        initialLocation: AppRoutes.travelerMessages,
        routes: [
          GoRoute(
            path: AppRoutes.travelerMessages,
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const MessengerPage(userId: 1, initialGroupId: 40002),
            ),
          ),
          GoRoute(
            path: AppRoutes.travelGroupDetails,
            builder: (_, state) {
              final id = state.pathParameters['groupId'] ?? '';
              pushedLocations.add('${AppRoutes.travelerTravelGroups}/$id');
              return Scaffold(
                appBar: AppBar(title: Text('Details $id')),
                body: const Text('Group Details Route'),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await cubit.refresh();
      await cubit.select(groupThread);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('group_chat_header_button')), findsOneWidget);
      expect(
        find.byKey(const Key('open_group_details_button')),
        findsOneWidget,
      );
      expect(find.text('4 thành viên'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_group_details_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Group Details Route'), findsOneWidget);
      expect(pushedLocations, ['${AppRoutes.travelerTravelGroups}/40002']);

      // Pop back and verify tapping the header also opens Group Details.
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('group_chat_header_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(pushedLocations, [
        '${AppRoutes.travelerTravelGroups}/40002',
        '${AppRoutes.travelerTravelGroups}/40002',
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
    },
  );

  testWidgets(
    'closed group chat does not expose group details navigation actions',
    (tester) async {
      const closedThread = ChatThread(
        ref: ChatThreadRef(kind: ChatKind.group, id: 99),
        title: 'Nhóm đã đóng',
        unreadCount: 0,
        memberCount: 2,
        status: ChatThreadStatus.closed,
      );
      final repo = _FakeMessagingRepository(groupThreads: const [closedThread]);
      final cubit = MessengerCubit(MessagingUseCases(repo), _FakeRealtime(), 1);

      await cubit.refresh();
      await cubit.select(closedThread);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const MessengerPage(userId: 1, initialGroupId: 99),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('group_chat_header_button')), findsNothing);
      expect(find.byKey(const Key('open_group_details_button')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
    },
  );
}

final class _FakeMessagingRepository implements MessagingRepository {
  _FakeMessagingRepository({
    this.groupThreads = const [],
    this.groupMembers = const [],
  });

  final List<ChatThread> groupThreads;
  final List<ChatMember> groupMembers;

  @override
  Future<ChatPage<ChatThread>> listThreads(
    ChatKind kind, {
    int? beforeId,
  }) async {
    return ChatPage(
      items: kind == ChatKind.group ? groupThreads : const [],
      nextBeforeId: null,
    );
  }

  @override
  Future<ChatPage<ChatMessage>> history(
    ChatThreadRef thread, {
    int? beforeMessageId,
  }) async => ChatPage(items: const [], nextBeforeId: null);

  @override
  Future<List<ChatMember>> members(ChatThreadRef thread) async => groupMembers;

  @override
  Future<void> markRead(ChatThreadRef thread, int throughMessageId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeRealtime implements ChatRealtime {
  @override
  Stream<ChatInvalidation> get invalidations => const Stream.empty();
  @override
  Future<void> start() async {}
  @override
  Future<void> watchThread(ChatThreadRef? thread) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
