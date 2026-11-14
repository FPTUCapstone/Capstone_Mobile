import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/usecases/send_support_message.dart';
import 'package:trip_mate_mobile/features/support_chat/presentation/cubit/support_chat_cubit.dart';

import 'support_chat_test.dart' show FakeChatRepository;

void main() {
  late FakeChatRepository repository;
  late SupportChatCubit cubit;
  const selection = SupportChatAction(
    type: SupportChatActionType.selectContext,
    label: 'Choose beach tour',
    context: SupportChatContext(kind: 'tour', id: '12'),
    prompt: 'Show available departures for this tour',
  );
  setUp(() {
    repository = FakeChatRepository();
    cubit = SupportChatCubit(SendSupportMessage(repository));
  });
  tearDown(() async => cubit.close());

  Future<void> showSelection() async {
    final pending = cubit.send('Find a beach tour');
    repository.pending.complete(
      const SupportChatReply(
        answer: 'Choose a matching tour',
        sources: [],
        actions: [selection],
      ),
    );
    await pending;
  }

  test(
    'selecting a result sends its prompt and retains conversation history',
    () async {
      await showSelection();
      expect(cubit.state.messages.last.actions.single, same(selection));
      final pending = cubit.performAction(selection);
      expect(repository.requests.last.context, selection.context);
      expect(repository.requests.last.message, selection.prompt);
      expect(repository.requests.last.history.map((entry) => entry.content), [
        'Find a beach tour',
        'Choose a matching tour',
      ]);
      expect(cubit.state.messages, hasLength(3));
      repository.complete();
      await pending;
      expect(cubit.state.messages, hasLength(4));

      final repeated = cubit.performAction(selection);
      expect(repository.requests.last.history, hasLength(4));
      repository.complete();
      await repeated;
      expect(cubit.state.context, selection.context);
    },
  );

  test(
    'selection cancels an older turn and ignores its late failure',
    () async {
      await showSelection();
      final old = cubit.send('Old question');
      final oldReply = repository.pending;
      final cancelled = repository.cancellation!;
      final current = cubit.performAction(selection);
      await expectLater(cancelled, completes);
      repository.complete(answer: 'Selected tour departures');
      await current;
      oldReply.completeError(const AuthenticationFailure());
      await old;
      expect(cubit.state.failure, isNull);
      expect(cubit.state.messages.last.content, 'Selected tour departures');
    },
  );

  for (final transition in ['clear', 'session', 'close']) {
    test(
      '$transition invalidates old actions and cancels selected prompt',
      () async {
        final sessions = StreamController<Object?>.broadcast(sync: true);
        await cubit.close();
        cubit = SupportChatCubit(
          SendSupportMessage(repository),
          sessionChanges: sessions.stream,
        );
        await showSelection();
        final pending = cubit.performAction(selection);
        final cancelled = repository.cancellation!;
        switch (transition) {
          case 'clear':
            cubit.reset();
          case 'session':
            sessions.add('different account');
          case 'close':
            await cubit.close();
        }
        await expectLater(cancelled, completes);
        repository.complete(answer: 'Private late result');
        await pending;
        expect(
          cubit.state.messages.any(
            (entry) => entry.content == 'Private late result',
          ),
          isFalse,
        );
        final count = repository.requests.length;
        await cubit.performAction(selection);
        expect(repository.requests, hasLength(count));
        await sessions.close();
      },
    );
  }

  test(
    'fabricated selection cannot bypass displayed result validation',
    () async {
      await cubit.performAction(selection);
      expect(repository.requests, isEmpty);
      expect(cubit.state.context, isNull);
    },
  );

  test(
    'retrying a selected result keeps its context and earlier turns',
    () async {
      await showSelection();
      final selected = cubit.performAction(selection);
      repository.pending.completeError(const ServerFailure());
      await selected;
      expect(cubit.state.messages, hasLength(2));
      expect(cubit.state.context, selection.context);
      final retried = cubit.retry();
      expect(repository.requests.last.message, selection.prompt);
      expect(repository.requests.last.history, hasLength(2));
      repository.complete();
      await retried;
      expect(cubit.state.messages, hasLength(4));
    },
  );

  for (final kind in ['refund', 'itinerary']) {
    test('selects a matching $kind record from the conversation', () async {
      final action = SupportChatAction(
        type: SupportChatActionType.selectContext,
        label: 'Select record',
        context: SupportChatContext(kind: kind, id: '7'),
        prompt: 'Show this record',
      );
      final search = cubit.send('Find my records');
      repository.pending.complete(
        SupportChatReply(
          answer: 'Matching record',
          sources: const [],
          actions: [action],
        ),
      );
      await search;
      final selected = cubit.performAction(action);
      expect(repository.requests.last.context, action.context);
      expect(repository.requests.last.history, hasLength(2));
      repository.complete();
      await selected;
    });
  }
}
