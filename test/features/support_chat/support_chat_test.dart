import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/support_chat/data/models/support_chat_response_model.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/repositories/support_chat_repository.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/usecases/send_support_message.dart';
import 'package:trip_mate_mobile/features/support_chat/presentation/cubit/support_chat_cubit.dart';

void main() {
  late FakeChatRepository repository;
  late SupportChatCubit cubit;
  setUp(() {
    repository = FakeChatRepository();
    cubit = SupportChatCubit(SendSupportMessage(repository));
  });
  tearDown(() async {
    await cubit.close();
  });

  for (final action in ['reset', 'context', 'close']) {
    test('$action cancels the outstanding transport', () async {
      final pending = cubit.send('private question');
      final cancelled = repository.cancellation;
      expect(cancelled, isNotNull);
      switch (action) {
        case 'reset':
          cubit.reset();
        case 'context':
          cubit.selectContext(
            const SupportChatContext(kind: 'refund', id: '1'),
          );
        case 'close':
          await cubit.close();
      }
      await expectLater(cancelled!, completes);
      repository.complete();
      await pending;
      expect(
        cubit.state.messages.where((message) => message.role == 'assistant'),
        isEmpty,
      );
    });
  }

  test(
    'validates message, history and explicit context before transport',
    () async {
      final send = SendSupportMessage(repository);
      for (final message in ['', '   ', 'a' * 2001]) {
        await expectLater(
          send(message: message),
          throwsA(isA<ValidationFailure>()),
        );
      }
      for (final id in [
        '0',
        '000',
        '-1',
        '1.0',
        'abc',
        ' 12',
        '9223372036854775808',
        '999999999999999999999',
      ]) {
        await expectLater(
          send(
            message: 'help',
            context: SupportChatContext(kind: 'refund', id: id),
          ),
          throwsA(isA<ValidationFailure>()),
        );
      }
      await expectLater(
        send(
          message: 'help',
          context: const SupportChatContext(kind: 'booking', id: '1'),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        send(
          message: 'help',
          history: List.filled(
            11,
            const SupportChatMessage(role: 'user', content: 'hi'),
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      for (final entry in [
        const SupportChatMessage(role: 'system', content: 'hi'),
        const SupportChatMessage(role: 'user', content: ''),
        SupportChatMessage(role: 'assistant', content: 'a' * 2001),
      ]) {
        await expectLater(
          send(message: 'help', history: [entry]),
          throwsA(isA<ValidationFailure>()),
        );
      }
      expect(repository.requests, isEmpty);
      final pending = send(
        message: 'a' * 2000,
        context: const SupportChatContext(
          kind: 'itinerary',
          id: '9223372036854775807',
        ),
      );
      repository.complete();
      await pending;
      expect(repository.requests.single.context?.id, '9223372036854775807');
      expect(
        const SupportChatContext(kind: 'refund', id: '0001').isValid,
        isTrue,
      );
    },
  );

  test('strictly parses answer, sources and optional context', () {
    final result = SupportChatResponseModel.fromJson({
      'answer': '<b>Plain text</b>',
      'sources': [
        {'id': 'policy', 'title': 'Refund policy', 'url': '/help/refunds'},
      ],
      'context': {'kind': 'refund', 'id': '12'},
    }).toDomain();
    expect(result.answer, '<b>Plain text</b>');
    expect(result.sources.single.title, 'Refund policy');
    expect(result.context?.id, '12');
    for (final invalid in <Object?>[
      null,
      [],
      {},
      {'answer': '', 'sources': []},
      {'answer': 42, 'sources': []},
      {'answer': 'ok'},
      {
        'answer': 'ok',
        'sources': [null],
      },
      {
        'answer': 'ok',
        'sources': [
          {'id': 1, 'title': 't', 'url': '/help'},
        ],
      },
      {
        'answer': 'ok',
        'sources': [],
        'context': {'kind': 'refund', 'id': 1},
      },
      {
        'answer': 'ok',
        'sources': [],
        'context': {'kind': 'other', 'id': '1'},
      },
    ]) {
      expect(
        () => SupportChatResponseModel.fromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test(
    'sends bounded history and prevents duplicate in-flight sends',
    () async {
      for (var i = 0; i < 7; i++) {
        final pending = cubit.send('question $i');
        await cubit.send('duplicate');
        repository.complete();
        await pending;
      }
      expect(repository.requests, hasLength(7));
      expect(repository.requests.last.history, hasLength(10));
      expect(repository.requests.last.history.first.content, 'question 1');
      expect(cubit.state.messages, hasLength(14));
    },
  );

  test(
    'long answers remain visible and are bounded in outbound history',
    () async {
      var pending = cubit.send('question');
      repository.complete(answer: 'a' * 3000);
      await pending;
      expect(cubit.state.messages.last.content.length, 3000);
      pending = cubit.send('next');
      expect(repository.requests.last.history.last.content.length, 2000);
      repository.complete();
      await pending;
    },
  );

  test('retry resends the same turn without duplicating history', () async {
    var pending = cubit.send('help');
    repository.pending.completeError(const ServerFailure());
    await pending;
    expect(cubit.state.failure, isA<ServerFailure>());
    pending = cubit.retry();
    expect(repository.requests.last.message, 'help');
    expect(repository.requests.last.history, isEmpty);
    repository.complete();
    await pending;
    expect(cubit.state.messages, hasLength(2));
    expect(cubit.state.failure, isNull);
  });

  test('context change ignores stale success and stale failure', () async {
    var pending = cubit.send('help');
    cubit.selectContext(const SupportChatContext(kind: 'refund', id: '7'));
    repository.complete();
    await pending;
    expect(cubit.state.messages, isEmpty);
    pending = cubit.send('refund help');
    expect(repository.requests.last.context?.id, '7');
    cubit.reset();
    repository.pending.completeError(const AuthenticationFailure());
    await pending;
    expect(cubit.state.failure, isNull);
    expect(cubit.state.context, isNull);
  });

  test('dispose during request ignores completion', () async {
    final pending = cubit.send('help');
    await cubit.close();
    repository.complete();
    await expectLater(pending, completes);
  });

  test('stale request cannot replace a newer context response', () async {
    final oldRequest = cubit.send('old question');
    final oldReply = repository.pending;
    cubit.selectContext(const SupportChatContext(kind: 'refund', id: '12'));
    final currentRequest = cubit.send('current question');
    repository.complete(answer: 'current answer');
    await currentRequest;
    oldReply.completeError(const ServerFailure());
    await oldRequest;
    expect(cubit.state.messages.last.content, 'current answer');
    expect(cubit.state.context?.id, '12');
    expect(cubit.state.failure, isNull);
  });

  test('dispose during request ignores late failure', () async {
    final pending = cubit.send('help');
    await cubit.close();
    repository.pending.completeError(const ServerFailure());
    await expectLater(pending, completes);
  });

  test(
    'logout and user switch clear history and ignore outstanding replies',
    () async {
      final sessionChanges = StreamController<Object?>.broadcast(sync: true);
      await cubit.close();
      cubit = SupportChatCubit(
        SendSupportMessage(repository),
        sessionChanges: sessionChanges.stream,
      );
      cubit.selectContext(const SupportChatContext(kind: 'itinerary', id: '5'));
      var request = cubit.send('private account question');
      repository.complete();
      await request;
      request = cubit.send('pending question');
      sessionChanges.add('logout');
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.context, isNull);
      repository.complete();
      await request;
      sessionChanges.add('new user');
      request = cubit.send('new account question');
      expect(repository.requests.last.history, isEmpty);
      expect(repository.requests.last.context, isNull);
      repository.complete();
      await request;
      await cubit.close();
      await sessionChanges.close();
    },
  );

  test(
    'authentication failure clears private conversation and retry',
    () async {
      var pending = cubit.send('private');
      repository.complete();
      await pending;
      pending = cubit.send('next');
      repository.pending.completeError(const AuthenticationFailure());
      await pending;
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.context, isNull);
      expect(cubit.state.failure, isA<AuthenticationFailure>());
      await cubit.retry();
      expect(repository.requests, hasLength(2));
    },
  );
}

class ChatRequest {
  ChatRequest(this.message, this.history, this.context);
  final String message;
  final List<SupportChatMessage> history;
  final SupportChatContext? context;
}

class FakeChatRepository implements SupportChatRepository {
  final requests = <ChatRequest>[];
  var pending = Completer<SupportChatReply>();
  Future<void>? cancellation;
  @override
  Future<SupportChatReply> send({
    required String message,
    required List<SupportChatMessage> history,
    SupportChatContext? context,
    Future<void>? cancellation,
  }) {
    this.cancellation = cancellation;
    requests.add(ChatRequest(message, history, context));
    pending = Completer<SupportChatReply>();
    return pending.future;
  }

  void complete({
    String answer = 'Helpful answer',
    List<SupportChatSource> sources = const [],
  }) => pending.complete(SupportChatReply(answer: answer, sources: sources));
}
