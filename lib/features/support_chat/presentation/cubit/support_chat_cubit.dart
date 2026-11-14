import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/usecases/send_support_message.dart';

final class SupportChatState {
  const SupportChatState({
    this.messages = const [],
    this.context,
    this.loading = false,
    this.failure,
    this.canRetry = false,
  });

  final List<SupportChatMessage> messages;
  final SupportChatContext? context;
  final bool loading;
  final Failure? failure;
  final bool canRetry;
}

final class SupportChatCubit extends Cubit<SupportChatState> {
  SupportChatCubit(this._send, {Stream<Object?>? sessionChanges})
    : super(const SupportChatState()) {
    _sessionSubscription = sessionChanges?.listen((_) => reset());
  }

  final SendSupportMessage _send;
  StreamSubscription<Object?>? _sessionSubscription;
  int _generation = 0;
  String? _retryMessage;
  Completer<void>? _cancellation;

  void _cancelPending() {
    _cancellation?.complete();
    _cancellation = null;
  }

  void reset() {
    if (isClosed) return;
    _cancelPending();
    _generation++;
    _retryMessage = null;
    emit(const SupportChatState());
  }

  void selectContext(SupportChatContext? context) {
    if (isClosed || context == state.context) return;
    _cancelPending();
    _generation++;
    _retryMessage = null;
    emit(SupportChatState(context: context));
  }

  bool hasAction(SupportChatAction action) =>
      !isClosed &&
      state.failure is! AuthenticationFailure &&
      state.messages.any((message) => message.actions.contains(action));

  Future<void> performAction(SupportChatAction action) async {
    if (!hasAction(action) ||
        action.type != SupportChatActionType.selectContext) {
      return;
    }
    final context = action.context;
    final prompt = action.prompt;
    if (context == null ||
        !context.isValid ||
        prompt == null ||
        prompt.trim().isEmpty ||
        prompt.length > 2000) {
      return;
    }
    _cancelPending();
    _generation++;
    _retryMessage = null;
    emit(SupportChatState(messages: state.messages, context: context));
    await send(prompt);
  }

  Future<void> retry() async {
    final message = _retryMessage;
    if (message != null) await send(message);
  }

  Future<void> send(String message) async {
    if (isClosed || state.loading || state.failure is AuthenticationFailure) {
      return;
    }
    if (message.trim().isEmpty || message.length > 2000) {
      emit(
        SupportChatState(
          messages: state.messages,
          context: state.context,
          failure: const ValidationFailure(
            'Enter a message of 1–2000 characters.',
          ),
        ),
      );
      return;
    }
    final generation = ++_generation;
    final cancellation = Completer<void>();
    _cancellation = cancellation;
    final previous = state.messages;
    final context = state.context;
    final history = previous
        .skip(previous.length > 10 ? previous.length - 10 : 0)
        .map((entry) {
          var content = entry.content;
          if (content.length > 2000) {
            // Avoid splitting a UTF-16 surrogate pair at the contract boundary.
            var end = 2000;
            final code = content.codeUnitAt(end - 1);
            if (code >= 0xD800 && code <= 0xDBFF) end--;
            content = content.substring(0, end);
          }
          return SupportChatMessage(role: entry.role, content: content);
        })
        .toList();
    _retryMessage = null;
    emit(
      SupportChatState(
        messages: List.unmodifiable([
          ...previous,
          SupportChatMessage(role: 'user', content: message),
        ]),
        context: context,
        loading: true,
      ),
    );
    try {
      final reply = await _send(
        message: message,
        history: history,
        context: context,
        cancellation: cancellation.future,
      );
      if (isClosed || generation != _generation) return;
      // Response context never changes the user's explicit selection.
      emit(
        SupportChatState(
          messages: List.unmodifiable([
            ...state.messages,
            SupportChatMessage(
              role: 'assistant',
              content: reply.answer,
              sources: reply.sources,
              actions: reply.actions,
            ),
          ]),
          context: context,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      final failure = error is Failure ? error : const UnknownFailure();
      if (failure is AuthenticationFailure) {
        _retryMessage = null;
        emit(SupportChatState(failure: failure));
        return;
      }
      _retryMessage = message;
      emit(
        SupportChatState(
          messages: previous,
          context: context,
          failure: failure,
          canRetry: true,
        ),
      );
    } finally {
      if (identical(_cancellation, cancellation)) _cancelPending();
    }
  }

  @override
  Future<void> close() async {
    _cancelPending();
    _generation++;
    _retryMessage = null;
    await _sessionSubscription?.cancel();
    return super.close();
  }
}
