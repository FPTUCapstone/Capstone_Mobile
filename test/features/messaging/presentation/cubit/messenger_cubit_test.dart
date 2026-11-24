import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/cubit/messenger_cubit.dart';

void main() {
  test(
    'a lost response retries the nonce and preserves a newer draft',
    () async {
      final repository = TestRepository();
      final cubit = MessengerCubit(
        MessagingUseCases(repository),
        TestRealtime(),
        7,
      );
      addTearDown(cubit.close);
      await cubit.select(directThread);
      cubit.setDraft('hello');
      expect(await cubit.send(ChatMessageType.text, 'hello'), isFalse);
      expect(cubit.state.messages, isEmpty);
      final response = Completer<ChatMessage>();
      repository.sendResponse = response.future;
      final retry = cubit.send(ChatMessageType.text, 'hello');
      cubit.setDraft('newer draft');
      response.complete(
        message(1, content: 'hello', nonce: repository.nonces.first),
      );
      expect(await retry, isTrue);
      expect(repository.nonces.toSet(), hasLength(1));
      expect(cubit.state.draft, 'newer draft');
      expect(cubit.state.messages.map((m) => m.id), [1]);
    },
  );
}

final directThread = ChatThread(
  ref: const ChatThreadRef(kind: ChatKind.direct, id: 3),
  title: 'Recipient',
  unreadCount: 0,
  otherUserId: 8,
);

ChatMessage message(int id, {String content = 'hello', String? nonce}) =>
    ChatMessage(
      id: id,
      thread: directThread.ref,
      senderUserId: 7,
      senderName: 'Me',
      type: ChatMessageType.text,
      content: content,
      createdAtUtc: DateTime.utc(2026),
      clientMessageId: nonce,
    );

class TestRepository implements MessagingRepository {
  final nonces = <String>[];
  Future<ChatMessage>? sendResponse;

  @override
  Future<ChatPage<ChatMessage>> history(
    ChatThreadRef thread, {
    int? beforeMessageId,
  }) async => ChatPage(items: const [], nextBeforeId: null);

  @override
  Future<ChatMessage> send({
    required ChatThreadRef thread,
    required String content,
    required String clientMessageId,
    required ChatMessageType type,
    ChatMetadata? metadata,
  }) async {
    nonces.add(clientMessageId);
    return sendResponse ?? Future.error(const NetworkFailure());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestRealtime implements ChatRealtime {
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
