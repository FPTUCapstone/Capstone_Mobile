import 'package:trip_mate_mobile/features/messaging/domain/entities/chat.dart';

final class ChatInvalidation {
  const ChatInvalidation({required this.kind, this.thread});
  final ChatKind kind;
  final ChatThreadRef? thread;
}

/// Events are hints to refetch authorized HTTP resources, never message data.
abstract interface class ChatRealtime {
  Stream<ChatInvalidation> get invalidations;
  Future<void> start();
  Future<void> watchThread(ChatThreadRef? thread);
  Future<void> stop();
  Future<void> dispose();
}
