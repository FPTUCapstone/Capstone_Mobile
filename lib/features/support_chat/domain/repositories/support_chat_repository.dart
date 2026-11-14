import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';

abstract interface class SupportChatRepository {
  Future<SupportChatReply> send({
    required String message,
    required List<SupportChatMessage> history,
    SupportChatContext? context,
    Future<void>? cancellation,
  });
}
