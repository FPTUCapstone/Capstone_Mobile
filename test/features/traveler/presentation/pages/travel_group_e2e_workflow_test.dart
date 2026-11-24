import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/cubit/messenger_cubit.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/pages/messenger_page.dart';

void main() {
  Widget buildWorkflowPage({
    required _WorkflowRepository repo,
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
          displayName: userId == 41 ? 'Host QA' : 'Member QA',
          initialGroupId: initialGroupId,
        ),
      ),
    );
  }

  group('Real Messenger Workflows (No Seed Data)', () {
    testWidgets(
      'Broadcast ack, Roll call checkin, Poll vote/cancel, and Split bill payment persist through repository',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _WorkflowRepository();
        await tester.pumpWidget(
          buildWorkflowPage(repo: repo, userId: 42, initialGroupId: 10),
        );
        await tester.pumpAndSettle();

        // Broadcast ack
        await tester.tap(find.byKey(const Key('ack_101')));
        await tester.pumpAndSettle();
        expect(find.text('Đã xác nhận đã đọc'), findsOneWidget);
        expect(find.text('1 người đã xác nhận'), findsOneWidget);

        // Roll call checkin
        await tester.tap(find.byKey(const Key('checkin_102')));
        await tester.pumpAndSettle();
        expect(find.text('Đã có mặt'), findsOneWidget);
        expect(find.text('1 người đã có mặt'), findsOneWidget);

        // Poll vote option 0 and cancel
        await tester.tap(find.byKey(const Key('vote_103_0')));
        await tester.pumpAndSettle();
        expect(find.text('1 phiếu'), findsOneWidget);
        await tester.tap(find.byKey(const Key('vote_103_0')));
        await tester.pumpAndSettle();
        expect(find.text('0 phiếu'), findsNWidgets(2));

        // Split bill payment confirmation
        await tester.tap(find.byKey(const Key('mark_paid_104')));
        await tester.pumpAndSettle();
        expect(find.text('Đã chuyển tiền'), findsOneWidget);
      },
    );

    testWidgets('Direct message user search and send persists to repository', (
      tester,
    ) async {
      final repo = _WorkflowRepository();
      await tester.pumpWidget(buildWorkflowPage(repo: repo, userId: 42));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('new_dm_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('dm_user_search_input')),
        'Host QA',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dm_user_41')));
      await tester.pumpAndSettle();

      expect(find.text('Tin nhắn riêng 1–1'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('chat_draft_input')),
        'Chào Host qua DM!',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('Chào Host qua DM!'), findsWidgets);
      expect(repo._directMessages.last.content, 'Chào Host qua DM!');
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

class _WorkflowRepository implements MessagingRepository {
  static const _groupRef = ChatThreadRef(kind: ChatKind.group, id: 10);
  static const _directRef = ChatThreadRef(kind: ChatKind.direct, id: 77);

  final List<ChatMessage> _groupMessages = [
    ChatMessage(
      id: 101,
      thread: _groupRef,
      senderUserId: 41,
      senderName: 'Host QA',
      type: ChatMessageType.broadcast,
      content: 'Tập trung 07:00',
      createdAtUtc: DateTime.utc(2026, 11, 24, 7),
      metadata: ChatMetadata(title: 'Thông báo sáng', content: 'Sảnh chính'),
      groupState: ChatGroupState(
        readByCount: 0,
        isReadByMe: false,
        presentCount: 0,
        isPresentByMe: false,
        paidUserIds: const [],
        pollVoteCounts: const {},
      ),
    ),
    ChatMessage(
      id: 102,
      thread: _groupRef,
      senderUserId: 41,
      senderName: 'Host QA',
      type: ChatMessageType.rollCall,
      content: 'Điểm danh xe 1',
      createdAtUtc: DateTime.utc(2026, 11, 24, 7, 5),
      metadata: ChatMetadata(title: 'Điểm danh xe 1'),
      groupState: ChatGroupState(
        readByCount: 0,
        isReadByMe: false,
        presentCount: 0,
        isPresentByMe: false,
        paidUserIds: const [],
        pollVoteCounts: const {},
      ),
    ),
    ChatMessage(
      id: 103,
      thread: _groupRef,
      senderUserId: 41,
      senderName: 'Host QA',
      type: ChatMessageType.poll,
      content: 'Ăn trưa ở đâu?',
      createdAtUtc: DateTime.utc(2026, 11, 24, 7, 10),
      metadata: ChatMetadata(pollOptions: const ['Bún chả', 'Mì Quảng']),
      groupState: ChatGroupState(
        readByCount: 0,
        isReadByMe: false,
        presentCount: 0,
        isPresentByMe: false,
        paidUserIds: const [],
        pollVoteCounts: const {},
      ),
    ),
    ChatMessage(
      id: 104,
      thread: _groupRef,
      senderUserId: 41,
      senderName: 'Host QA',
      type: ChatMessageType.splitBill,
      content: 'Vé tham quan',
      createdAtUtc: DateTime.utc(2026, 11, 24, 7, 15),
      metadata: ChatMetadata(
        title: 'Vé tham quan',
        totalAmountVnd: 200000,
        bankCode: 'MBBank',
        accountNumber: '1122334455',
        accountName: 'HOST QA',
        shares: const [
          ChatExpenseShare(
            userId: 41,
            displayName: 'Host QA',
            amountVnd: 100000,
          ),
          ChatExpenseShare(
            userId: 42,
            displayName: 'Member QA',
            amountVnd: 100000,
          ),
        ],
      ),
      groupState: ChatGroupState(
        readByCount: 0,
        isReadByMe: false,
        presentCount: 0,
        isPresentByMe: false,
        paidUserIds: const [41],
        pollVoteCounts: const {},
      ),
    ),
  ];

  final List<ChatMessage> _directMessages = [];
  int _nextId = 200;

  @override
  Future<ChatPage<ChatThread>> listThreads(
    ChatKind kind, {
    int? beforeId,
  }) async {
    if (kind == ChatKind.group) {
      return ChatPage(
        items: const [
          ChatThread(
            ref: _groupRef,
            title: 'Nhóm QA Test',
            unreadCount: 0,
            hostUserId: 41,
            memberCount: 2,
          ),
        ],
        nextBeforeId: null,
      );
    }
    return ChatPage(items: const [], nextBeforeId: null);
  }

  @override
  Future<ChatPage<ChatMessage>> history(
    ChatThreadRef thread, {
    int? beforeMessageId,
  }) async => ChatPage(
    items: thread == _groupRef ? _groupMessages : _directMessages,
    nextBeforeId: null,
  );

  @override
  Future<List<ChatMember>> members(ChatThreadRef thread) async => [
    ChatMember(
      userId: 41,
      displayName: 'Host QA',
      isHost: true,
      joinedAtUtc: DateTime.utc(2026, 11, 24),
      locationSharingEnabled: false,
    ),
    ChatMember(
      userId: 42,
      displayName: 'Member QA',
      isHost: false,
      joinedAtUtc: DateTime.utc(2026, 11, 24),
      locationSharingEnabled: false,
    ),
  ];

  @override
  Future<void> markRead(ChatThreadRef thread, int throughMessageId) async {}

  @override
  Future<List<ChatUser>> searchUsers(String query) async => const [
    ChatUser(userId: 41, displayName: 'Host QA'),
  ];

  @override
  Future<ChatThread> startDirect(int otherUserId) async => const ChatThread(
    ref: _directRef,
    title: 'Host QA',
    unreadCount: 0,
    otherUserId: 41,
  );

  @override
  Future<ChatMessage> send({
    required ChatThreadRef thread,
    required String content,
    required String clientMessageId,
    required ChatMessageType type,
    ChatMetadata? metadata,
  }) async {
    final msg = ChatMessage(
      id: ++_nextId,
      thread: thread,
      senderUserId: 42,
      senderName: 'Member QA',
      type: type,
      content: content,
      createdAtUtc: DateTime.utc(2026, 11, 24, 9),
      clientMessageId: clientMessageId,
      metadata: metadata,
    );
    if (thread == _directRef) {
      _directMessages.add(msg);
    } else {
      _groupMessages.add(msg);
    }
    return msg;
  }

  @override
  Future<ChatMessage> interact({
    required ChatMessage message,
    required ChatInteraction action,
    int? optionIndex,
    bool? isPaid,
  }) async {
    final old = message.groupState!;
    final nextState = switch (action) {
      ChatInteraction.acknowledge => ChatGroupState(
        readByCount: 1,
        isReadByMe: true,
        presentCount: old.presentCount,
        isPresentByMe: old.isPresentByMe,
        paidUserIds: old.paidUserIds,
        pollVoteCounts: old.pollVoteCounts,
        myPollVoteOption: old.myPollVoteOption,
      ),
      ChatInteraction.checkin => ChatGroupState(
        readByCount: old.readByCount,
        isReadByMe: old.isReadByMe,
        presentCount: 1,
        isPresentByMe: true,
        paidUserIds: old.paidUserIds,
        pollVoteCounts: old.pollVoteCounts,
        myPollVoteOption: old.myPollVoteOption,
      ),
      ChatInteraction.togglePayment => ChatGroupState(
        readByCount: old.readByCount,
        isReadByMe: old.isReadByMe,
        presentCount: old.presentCount,
        isPresentByMe: old.isPresentByMe,
        paidUserIds: const [41, 42],
        pollVoteCounts: old.pollVoteCounts,
        myPollVoteOption: old.myPollVoteOption,
      ),
      ChatInteraction.vote => ChatGroupState(
        readByCount: old.readByCount,
        isReadByMe: old.isReadByMe,
        presentCount: old.presentCount,
        isPresentByMe: old.isPresentByMe,
        paidUserIds: old.paidUserIds,
        pollVoteCounts: optionIndex == -1 ? const {} : {optionIndex!: 1},
        myPollVoteOption: optionIndex == -1 ? null : optionIndex,
      ),
    };
    return ChatMessage(
      id: message.id,
      thread: message.thread,
      senderUserId: message.senderUserId,
      senderName: message.senderName,
      type: message.type,
      content: message.content,
      createdAtUtc: message.createdAtUtc,
      metadata: message.metadata,
      groupState: nextState,
    );
  }
}
