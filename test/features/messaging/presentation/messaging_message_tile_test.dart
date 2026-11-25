import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/widgets/messaging_message_tile.dart';

void main() {
  final thread = ChatThread(
    ref: const ChatThreadRef(kind: ChatKind.group, id: 9),
    title: 'Group',
    unreadCount: 0,
    memberCount: 2,
    hostUserId: 41,
  );
  final message = ChatMessage(
    id: 100,
    thread: thread.ref,
    senderUserId: 41,
    senderName: 'Host',
    type: ChatMessageType.poll,
    content: 'Lunch?',
    createdAtUtc: DateTime.utc(2026, 11, 24),
    metadata: ChatMetadata(pollOptions: ['A', 'B']),
    groupState: ChatGroupState(
      readByCount: 0,
      isReadByMe: false,
      presentCount: 0,
      isPresentByMe: false,
      paidUserIds: [],
      pollVoteCounts: {0: 1},
      myPollVoteOption: 0,
    ),
  );
  testWidgets(
    'poll cancels the selected zero-based option without faking updated counts',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagingMessageTile(
              message: message,
              thread: thread,
              userId: 57,
              busy: false,
              onInteract: (action, index) async {
                selected = index;
                return 'Offline';
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('vote_100_0')));
      await tester.pump();
      expect(selected, -1);
      expect(find.textContaining('1 phiếu'), findsOneWidget);
    },
  );
  testWidgets('long text wraps at small widths without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final long = ChatMessage(
      id: 101,
      thread: thread.ref,
      senderUserId: 41,
      senderName: 'Long name ' * 10,
      type: ChatMessageType.text,
      content: 'a' * 4000,
      createdAtUtc: DateTime.utc(2026, 11, 24),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MessagingMessageTile(
              message: long,
              thread: thread,
              userId: 57,
              busy: false,
              onInteract: (_, _) async => null,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
