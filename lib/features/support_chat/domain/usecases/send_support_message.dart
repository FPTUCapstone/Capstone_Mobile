import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/repositories/support_chat_repository.dart';

final class SendSupportMessage {
  const SendSupportMessage(this._repository);

  final SupportChatRepository _repository;

  Future<SupportChatReply> call({
    required String message,
    List<SupportChatMessage> history = const [],
    SupportChatContext? context,
    Future<void>? cancellation,
  }) async {
    if (!_validContent(message)) {
      throw const ValidationFailure('Enter a message of 1–2000 characters.');
    }
    if (history.length > 10 ||
        history.any(
          (entry) =>
              (entry.role != 'user' && entry.role != 'assistant') ||
              !_validContent(entry.content),
        )) {
      throw const ValidationFailure('Please start a new support conversation.');
    }
    if (context != null && !context.isValid) {
      throw const ValidationFailure('Choose a valid support context.');
    }
    return _repository.send(
      message: message,
      history: List.unmodifiable(history),
      context: context,
      cancellation: cancellation,
    );
  }

  bool _validContent(String value) =>
      value.trim().isNotEmpty && value.length <= 2000;
}
