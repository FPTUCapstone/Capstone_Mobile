import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/cubit/messenger_cubit.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/pages/messenger_page.dart';

void main() {
  Widget buildPage({
    required _FakeMessagingRepository repo,
    required int userId,
    UserRole role = UserRole.traveler,
    int? initialGroupId,
  }) {
    return MaterialApp(
      home: BlocProvider<MessengerCubit>(
        create: (_) =>
            MessengerCubit(MessagingUseCases(repo), _IdleRealtime(), userId)
              ..initialize(initialGroupId: initialGroupId),
        child: MessengerPage(
          userId: userId,
          userRole: role,
          displayName: userId == 41 ? 'Trưởng nhóm QA' : 'Thành viên QA',
          initialGroupId: initialGroupId,
        ),
      ),
    );
  }

  group('MessengerPage Widget Tests (Real Messaging Contract)', () {
    testWidgets(
      'displays empty state instead of hardcoded seed data when no conversations exist',
      (tester) async {
        final repo = _FakeMessagingRepository(
          groups: const [],
          directs: const [],
        );
        await tester.pumpWidget(buildPage(repo: repo, userId: 42));
        await tester.pumpAndSettle();

        expect(find.textContaining('Chưa có cuộc trò chuyện'), findsOneWidget);
        expect(find.textContaining('Nguyễn Tuấn'), findsNothing);
        expect(find.textContaining('0987654321'), findsNothing);
      },
    );

    testWidgets(
      'hides broadcast and roll call tools for regular Traveler member (TG-E2E-002)',
      (tester) async {
        final repo = _FakeMessagingRepository.withDefaultData();
        await tester.pumpWidget(
          buildPage(repo: repo, userId: 42, initialGroupId: 10),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('chat_tools_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tool_create_poll')), findsOneWidget);
        expect(find.byKey(const Key('tool_create_expense')), findsOneWidget);
        expect(find.byKey(const Key('tool_create_broadcast')), findsNothing);
        expect(find.byKey(const Key('tool_create_roll_call')), findsNothing);
      },
    );

    testWidgets(
      'shows broadcast and roll call tools to group Host and TourOperator',
      (tester) async {
        final repo = _FakeMessagingRepository.withDefaultData();
        await tester.pumpWidget(
          buildPage(repo: repo, userId: 41, initialGroupId: 10),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('chat_tools_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tool_create_broadcast')), findsOneWidget);
        expect(find.byKey(const Key('tool_create_roll_call')), findsOneWidget);
      },
    );

    testWidgets('closed group renders read-only banner and disables composer', (
      tester,
    ) async {
      final repo = _FakeMessagingRepository(
        groups: [
          const ChatThread(
            ref: ChatThreadRef(kind: ChatKind.group, id: 15),
            title: 'Nhóm đã đóng QA',
            unreadCount: 0,
            hostUserId: 41,
            memberCount: 2,
            status: ChatThreadStatus.closed,
          ),
        ],
        directs: const [],
      );
      await tester.pumpWidget(
        buildPage(repo: repo, userId: 42, initialGroupId: 15),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Nhóm đã đóng. Bạn chỉ có thể xem lịch sử.'),
        findsOneWidget,
      );
      final input = tester.widget<TextField>(
        find.byKey(const Key('chat_draft_input')),
      );
      expect(input.enabled, isFalse);
      expect(repo.membersCalls, 0);
    });
  });
}

class _IdleRealtime implements ChatRealtime {
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

class _FakeMessagingRepository implements MessagingRepository {
  _FakeMessagingRepository({
    required this.groups,
    required this.directs,
    List<ChatMessage>? initialMessages,
  }) : messages = List.of(initialMessages ?? const []);

  factory _FakeMessagingRepository.withDefaultData() {
    const ref = ChatThreadRef(kind: ChatKind.group, id: 10);
    return _FakeMessagingRepository(
      groups: const [
        ChatThread(
          ref: ref,
          title: 'Đoàn QA Đà Nẵng',
          unreadCount: 0,
          hostUserId: 41,
          memberCount: 2,
        ),
      ],
      directs: const [],
      initialMessages: [
        ChatMessage(
          id: 1,
          thread: ref,
          senderUserId: 41,
          senderName: 'Trưởng nhóm QA',
          type: ChatMessageType.text,
          content: 'Chào cả đoàn!',
          createdAtUtc: DateTime.utc(2026, 11, 24, 8),
        ),
      ],
    );
  }

  final List<ChatThread> groups;
  final List<ChatThread> directs;
  final List<ChatMessage> messages;
  int membersCalls = 0;

  @override
  Future<ChatPage<ChatThread>> listThreads(
    ChatKind kind, {
    int? beforeId,
  }) async => ChatPage(
    items: kind == ChatKind.group ? groups : directs,
    nextBeforeId: null,
  );

  @override
  Future<ChatPage<ChatMessage>> history(
    ChatThreadRef thread, {
    int? beforeMessageId,
  }) async => ChatPage(
    items: messages.where((m) => m.thread == thread).toList(),
    nextBeforeId: null,
  );

  @override
  Future<List<ChatMember>> members(ChatThreadRef thread) async {
    membersCalls++;
    return [
      ChatMember(
        userId: 41,
        displayName: 'Trưởng nhóm QA',
        isHost: true,
        joinedAtUtc: DateTime.utc(2026, 11, 24),
        locationSharingEnabled: false,
      ),
      ChatMember(
        userId: 42,
        displayName: 'Thành viên QA',
        isHost: false,
        joinedAtUtc: DateTime.utc(2026, 11, 24),
        locationSharingEnabled: false,
      ),
    ];
  }

  @override
  Future<void> markRead(ChatThreadRef thread, int throughMessageId) async {}

  @override
  Future<List<ChatUser>> searchUsers(String query) async => const [];

  @override
  Future<ChatThread> startDirect(int otherUserId) => throw UnimplementedError();

  @override
  Future<ChatMessage> send({
    required ChatThreadRef thread,
    required String content,
    required String clientMessageId,
    required ChatMessageType type,
    ChatMetadata? metadata,
  }) async {
    final nextId = messages.length + 1;
    final created = ChatMessage(
      id: nextId,
      thread: thread,
      senderUserId: 41,
      senderName: 'Trưởng nhóm QA',
      type: type,
      content: content,
      createdAtUtc: DateTime.utc(2026, 11, 24, 9),
      clientMessageId: clientMessageId,
      metadata: metadata,
      groupState: ChatGroupState(
        readByCount: 0,
        isReadByMe: false,
        presentCount: 0,
        isPresentByMe: false,
        paidUserIds: const [],
        pollVoteCounts: const {},
      ),
    );
    messages.add(created);
    return created;
  }

  @override
  Future<ChatMessage> interact({
    required ChatMessage message,
    required ChatInteraction action,
    int? optionIndex,
    bool? isPaid,
  }) async => message;
}
