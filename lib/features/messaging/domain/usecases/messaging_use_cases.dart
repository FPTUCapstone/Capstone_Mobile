import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/messaging/domain/entities/chat.dart';
import 'package:trip_mate_mobile/features/messaging/domain/repositories/messaging_repository.dart';

/// Validates user intent before transport; never automatically repeats mutations.
class MessagingUseCases {
  const MessagingUseCases(this.repository);
  final MessagingRepository repository;

  Future<ChatPage<ChatThread>> listThreads(
    ChatKind kind, {
    int? beforeId,
  }) async {
    _cursor(beforeId);
    return repository.listThreads(kind, beforeId: beforeId);
  }

  Future<ChatPage<ChatMessage>> history(
    ChatThreadRef thread, {
    int? beforeMessageId,
  }) async {
    _thread(thread);
    _cursor(beforeMessageId);
    return repository.history(thread, beforeMessageId: beforeMessageId);
  }

  Future<List<ChatUser>> searchUsers(String query) async {
    final name = query.trim();
    if (name.length < 2) return const [];
    if (name.length > 100 ||
        name.contains('@') ||
        RegExp(r'^\+?[\d\s().-]{7,}$').hasMatch(name)) {
      throw const ValidationFailure(
        'Tìm kiếm theo tên hiển thị từ 2 đến 100 ký tự.',
      );
    }
    return repository.searchUsers(name);
  }

  Future<ChatThread> startDirect({
    required int otherUserId,
    required int currentUserId,
  }) async {
    if (currentUserId <= 0) throw const AuthenticationFailure();
    if (otherUserId <= 0 || otherUserId == currentUserId) {
      throw const ValidationFailure(
        'Vui lòng chọn người dùng khác để bắt đầu cuộc trò chuyện.',
      );
    }
    return repository.startDirect(otherUserId);
  }

  Future<ChatMessage> send({
    required ChatThread thread,
    required String content,
    required String clientMessageId,
    ChatMessageType type = ChatMessageType.text,
    ChatMetadata? metadata,
  }) async {
    _writable(thread);
    final text = content.trim();
    if (text.isEmpty || text.length > 4000) {
      throw const ValidationFailure(
        'Vui lòng nhập tin nhắn từ 1 đến 4.000 ký tự.',
      );
    }
    if (!isChatNonce(clientMessageId)) {
      throw const ValidationFailure('Mã tin nhắn hợp lệ là bắt buộc.');
    }
    if (thread.kind == ChatKind.direct &&
        (type != ChatMessageType.text || metadata != null)) {
      throw const ValidationFailure(
        'Trò chuyện riêng tư chỉ hỗ trợ tin nhắn văn bản.',
      );
    }
    if (type == ChatMessageType.poll &&
        (metadata == null ||
            metadata.pollOptions.length < 2 ||
            metadata.pollOptions.length > 6 ||
            metadata.pollOptions.any((o) => o.trim().isEmpty))) {
      throw const ValidationFailure(
        'Bình chọn cần từ 2 đến 6 lựa chọn hợp lệ.',
      );
    }
    if (type == ChatMessageType.splitBill) {
      final shares = metadata?.shares ?? const <ChatExpenseShare>[];
      final total = metadata?.totalAmountVnd;
      if (total == null ||
          total <= 0 ||
          total > 9007199254740991 ||
          shares.isEmpty ||
          shares.any(
            (s) =>
                s.userId <= 0 ||
                s.displayName.trim().isEmpty ||
                s.amountVnd < 0,
          ) ||
          shares.map((s) => s.userId).toSet().length != shares.length ||
          shares.fold<int>(0, (sum, s) => sum + s.amountVnd) != total ||
          [
            metadata?.bankCode,
            metadata?.accountNumber,
            metadata?.accountName,
          ].any((s) => s == null || s.trim().isEmpty)) {
        throw const ValidationFailure(
          'Vui lòng nhập thông tin người nhận và số tiền chia hợp lệ khớp với tổng chi phí.',
        );
      }
      // Membership comes from the authorized endpoint, never display names or a fallback count.
      final active = await repository.members(thread.ref);
      final ids = active.map((m) => m.userId).toSet();
      if (shares.any((s) => !ids.contains(s.userId))) {
        throw const ValidationFailure(
          'Khoản chia tiền chỉ áp dụng cho thành viên hiện tại của nhóm.',
        );
      }
    }
    return repository.send(
      thread: thread.ref,
      content: text,
      clientMessageId: clientMessageId,
      type: type,
      metadata: metadata,
    );
  }

  Future<void> markRead(ChatThreadRef thread, int throughMessageId) async {
    _thread(thread);
    _id(throughMessageId);
    await repository.markRead(thread, throughMessageId);
  }

  Future<List<ChatMember>> members(ChatThreadRef thread) async {
    _thread(thread);
    if (thread.kind != ChatKind.group) {
      throw const ValidationFailure(
        'Danh sách thành viên chỉ khả dụng cho trò chuyện nhóm.',
      );
    }
    return repository.members(thread);
  }

  Future<ChatMessage> interact({
    required ChatThread thread,
    required ChatMessage message,
    required ChatInteraction action,
    int? optionIndex,
    bool? isPaid,
  }) async {
    _writable(thread);
    _id(message.id);
    if (thread.kind != ChatKind.group || message.thread != thread.ref) {
      throw const ValidationFailure(
        'Vui lòng chọn một tin nhắn trong nhóm này.',
      );
    }
    final expected = switch (action) {
      ChatInteraction.acknowledge => ChatMessageType.broadcast,
      ChatInteraction.checkin => ChatMessageType.rollCall,
      ChatInteraction.togglePayment => ChatMessageType.splitBill,
      ChatInteraction.vote => ChatMessageType.poll,
    };
    if (message.type != expected || message.groupState == null) {
      throw const ValidationFailure(
        'Thao tác này không khả dụng cho tin nhắn đã chọn.',
      );
    }
    if (action == ChatInteraction.togglePayment && isPaid == null) {
      throw const ValidationFailure('Vui lòng xác nhận trạng thái thanh toán.');
    }
    if (action == ChatInteraction.vote &&
        (optionIndex == null ||
            optionIndex < -1 ||
            optionIndex >= (message.metadata?.pollOptions.length ?? 0))) {
      throw const ValidationFailure(
        'Vui lòng chọn một phương án bình chọn hợp lệ hoặc hủy bình chọn.',
      );
    }
    return repository.interact(
      message: message,
      action: action,
      optionIndex: optionIndex,
      isPaid: isPaid,
    );
  }

  static void _id(int id) {
    if (id <= 0) throw const ValidationFailure('Mã định danh không hợp lệ.');
  }

  static void _cursor(int? id) {
    if (id != null) _id(id);
  }

  static void _thread(ChatThreadRef thread) => _id(thread.id);
  static void _writable(ChatThread thread) {
    _thread(thread.ref);
    if (thread.isReadOnly) {
      throw const ConflictFailure('Nhóm đã đóng. Bạn chỉ có thể xem lịch sử.');
    }
  }
}

bool isChatNonce(String value) =>
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value) &&
    value != '00000000-0000-0000-0000-000000000000';
