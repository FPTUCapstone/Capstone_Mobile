import 'package:trip_mate_mobile/features/messaging/domain/entities/chat.dart';

/// All operations throw application Failure objects, never transport exceptions.
abstract interface class MessagingRepository {
  Future<ChatPage<ChatThread>> listThreads(ChatKind kind, {int? beforeId});
  Future<ChatPage<ChatMessage>> history(
    ChatThreadRef thread, {
    int? beforeMessageId,
  });
  Future<List<ChatUser>> searchUsers(String query);
  Future<ChatThread> startDirect(int otherUserId);
  Future<ChatMessage> send({
    required ChatThreadRef thread,
    required String content,
    required String clientMessageId,
    required ChatMessageType type,
    ChatMetadata? metadata,
  });
  Future<void> markRead(ChatThreadRef thread, int throughMessageId);
  Future<List<ChatMember>> members(ChatThreadRef thread);
  Future<ChatMessage> interact({
    required ChatMessage message,
    required ChatInteraction action,
    int? optionIndex,
    bool? isPaid,
  });
}
