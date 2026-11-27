import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';

void main() {
  late _Repository repository;
  late MessagingUseCases cases;
  const thread = ChatThread(
    ref: ChatThreadRef(kind: ChatKind.direct, id: 7),
    title: 'Recipient',
    unreadCount: 0,
  );
  setUp(() {
    repository = _Repository();
    cases = MessagingUseCases(repository);
  });
  test(
    'invalid nonce and group tools in a direct chat never reach transport',
    () async {
      await expectLater(
        cases.send(thread: thread, content: 'Hello', clientMessageId: 'bad'),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        cases.send(
          thread: thread,
          content: 'Hello',
          clientMessageId: 'b759f92c-8f9f-4ca8-9bea-b1a2edb4c2ed',
          type: ChatMessageType.poll,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(repository.sends, 0);
    },
  );
  test(
    'short searches do not enumerate users and self DM is rejected',
    () async {
      expect(await cases.searchUsers(' A '), isEmpty);
      await expectLater(
        cases.startDirect(otherUserId: 42, currentUserId: 42),
        throwsA(isA<ValidationFailure>()),
      );
    },
  );
  test(
    'successful send trims content and preserves caller nonce without retry',
    () async {
      await cases.send(
        thread: thread,
        content: ' Hello ',
        clientMessageId: 'b759f92c-8f9f-4ca8-9bea-b1a2edb4c2ed',
      );
      expect(repository.sends, 1);
      expect(repository.content, 'Hello');
      expect(repository.nonce, 'b759f92c-8f9f-4ca8-9bea-b1a2edb4c2ed');
    },
  );
}

class _Repository implements MessagingRepository {
  int sends = 0;
  String? content, nonce;
  @override
  Future<ChatMessage> send({
    required ChatThreadRef thread,
    required String content,
    required String clientMessageId,
    required ChatMessageType type,
    ChatMetadata? metadata,
  }) async {
    sends++;
    this.content = content;
    nonce = clientMessageId;
    return ChatMessage(
      id: 10,
      thread: thread,
      senderUserId: 42,
      senderName: 'Sender',
      type: type,
      content: content,
      createdAtUtc: DateTime.utc(2026),
      clientMessageId: clientMessageId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
