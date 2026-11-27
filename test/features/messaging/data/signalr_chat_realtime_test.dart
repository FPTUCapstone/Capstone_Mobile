import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/messaging/data/realtime/signalr_chat_realtime.dart';
import 'package:trip_mate_mobile/features/messaging/domain/entities/chat.dart';

void main() {
  test('builds group and direct SignalR hub URLs from API base origin', () {
    final base = Uri.parse('http://10.0.2.2:5000');
    expect(
      SignalRChatRealtime.groupHubUrl(base),
      'http://10.0.2.2:5000/hubs/group-chat',
    );
    expect(
      SignalRChatRealtime.directHubUrl(base),
      'http://10.0.2.2:5000/hubs/direct-chat',
    );
  });

  test(
    'parses group and direct invalidations without trusting payload body',
    () {
      final groupEvt = SignalRChatRealtime.parseGroupInvalidation([
        {'groupId': 42, 'content': 'ignored'},
      ]);
      expect(groupEvt?.kind, ChatKind.group);
      expect(
        groupEvt?.thread,
        const ChatThreadRef(kind: ChatKind.group, id: 42),
      );

      final directEvt = SignalRChatRealtime.parseDirectInvalidation([
        {'conversationId': 9},
      ]);
      expect(directEvt?.kind, ChatKind.direct);
      expect(
        directEvt?.thread,
        const ChatThreadRef(kind: ChatKind.direct, id: 9),
      );
    },
  );
}
