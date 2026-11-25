import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/messaging/data/datasources/messaging_remote_data_source.dart';
import 'package:trip_mate_mobile/features/messaging/data/models/chat_dto.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';

final class MessagingRepositoryImpl implements MessagingRepository {
  const MessagingRepositoryImpl(this._remote);
  final MessagingRemoteDataSource _remote;
  static const _groups = '/api/v1/travel-groups';
  static const _direct = '/api/v1/direct-conversations';
  static String _base(ChatThreadRef ref) =>
      '${ref.kind == ChatKind.group ? _groups : _direct}/${ref.id}';
  static String _messages(ChatThreadRef ref) => '${_base(ref)}/messages';

  Future<T> _safe<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (error is Failure) rethrow;
      if (error is FormatException || error is TypeError) {
        throw const ServerFailure(
          'Chat data could not be loaded. Please try again.',
        );
      }
      // Never expose ProblemDetails titles or validation fields containing private data.
      if (error is DioException) {
        switch (error.response?.statusCode) {
          case 400:
            throw const ValidationFailure(
              'Please check your message or selected action.',
            );
          case 401:
            throw const AuthenticationFailure();
          case 403:
            throw const PermissionFailure(
              'You no longer have access to this conversation.',
            );
          case 404:
            throw const NotFoundFailure(
              'This conversation or message is unavailable.',
            );
          case 409:
            throw const ConflictFailure(
              'This group is closed or the action conflicts with an earlier request. Reload the conversation.',
            );
          case 429:
            throw const RateLimitFailure();
        }
      }
      throw ErrorMapper.toFailure(error);
    }
  }

  @override
  Future<ChatPage<ChatThread>> listThreads(ChatKind kind, {int? beforeId}) =>
      _safe(() async {
        final group = kind == ChatKind.group;
        final key = group ? 'nextBeforeGroupId' : 'nextBeforeConversationId';
        final data = chatObject(
          await _remote.get(
            group ? '$_groups/conversations' : _direct,
            query: {
              'limit': 50,
              (group ? 'beforeGroupId' : 'beforeConversationId'): ?beforeId,
            },
          ),
        );
        if (!data.containsKey(key)) {
          throw const FormatException('Missing cursor.');
        }
        final items = chatArray(
          data['items'],
        ).map((v) => ChatThreadDto.fromJson(v, kind).toDomain()).toList();
        final next = chatCursor(data[key]);
        _descending(items.map((e) => e.id).toList(), beforeId);
        if (items.length > 50 ||
            (next != null && (items.isEmpty || next != items.last.id))) {
          throw const FormatException('Invalid conversation page.');
        }
        return ChatPage(items: items, nextBeforeId: next);
      });

  @override
  Future<ChatPage<ChatMessage>> history(
    ChatThreadRef thread, {
    int? beforeMessageId,
  }) => _safe(() async {
    final raw = await _remote.get(
      _messages(thread),
      query: {'limit': 50, 'beforeMessageId': ?beforeMessageId},
    );
    final messages = chatArray(
      raw,
    ).map((m) => ChatMessageDto.fromJson(m, thread).toDomain()).toList();
    if (messages.length > 50) {
      throw const FormatException('History is not bounded.');
    }
    var previous = 0;
    for (final message in messages) {
      if (message.id <= previous ||
          (beforeMessageId != null && message.id >= beforeMessageId)) {
        throw const FormatException('Invalid history ordering.');
      }
      previous = message.id;
    }
    // Array history has no hasMore field; a full page permits one further request.
    return ChatPage(
      items: messages,
      nextBeforeId: messages.length == 50 ? messages.first.id : null,
    );
  });

  @override
  Future<List<ChatUser>> searchUsers(String query) => _safe(() async {
    final users = chatArray(
      await _remote.get(
        '$_direct/users',
        query: {'search': query, 'limit': 20},
      ),
    ).map((v) => ChatUserDto.fromJson(v).toDomain()).toList();
    if (users.length > 20 ||
        users.map((u) => u.userId).toSet().length != users.length) {
      throw const FormatException('Invalid search results.');
    }
    return List.unmodifiable(users);
  });

  @override
  Future<ChatThread> startDirect(int otherUserId) => _safe(() async {
    final thread = ChatThreadDto.fromJson(
      await _remote.post(_direct, body: {'otherUserId': otherUserId}),
      ChatKind.direct,
    ).toDomain();
    if (thread.otherUserId != otherUserId) {
      throw const FormatException('Unexpected recipient.');
    }
    return thread;
  });

  @override
  Future<ChatMessage> send({
    required ChatThreadRef thread,
    required String content,
    required String clientMessageId,
    required ChatMessageType type,
    ChatMetadata? metadata,
  }) => _safe(() async {
    final raw = await _remote.post(
      _messages(thread),
      status: thread.kind == ChatKind.group ? 201 : 200,
      body: {
        'content': content,
        'clientMessageId': clientMessageId,
        if (thread.kind == ChatKind.group) 'messageType': chatTypeName(type),
        if (metadata != null) 'metadataJson': ChatMetadataDto.encode(metadata),
      },
    );
    final message = ChatMessageDto.fromJson(raw, thread).toDomain();
    if (message.clientMessageId?.toLowerCase() !=
            clientMessageId.toLowerCase() ||
        message.type != type ||
        message.content != content) {
      throw const FormatException('Unexpected saved message.');
    }
    return message;
  });

  @override
  Future<void> markRead(ChatThreadRef thread, int throughMessageId) =>
      _safe(() async {
        final group = thread.kind == ChatKind.group;
        final result = await _remote.post(
          group ? '${_messages(thread)}/read' : '${_base(thread)}/read',
          body: {'throughMessageId': throughMessageId},
          status: group ? 200 : 204,
        );
        if (group &&
            chatInt(chatObject(result)['lastReadChatMessageId'], min: 1) <
                throughMessageId) {
          throw const FormatException('Read cursor did not advance.');
        }
      });

  @override
  Future<List<ChatMember>> members(ChatThreadRef thread) => _safe(() async {
    if (thread.kind != ChatKind.group) {
      throw const ValidationFailure(
        'Member lists are available for groups only.',
      );
    }
    final data = chatObject(await _remote.get('${_base(thread)}/members'));
    if (chatInt(data['groupId'], min: 1) != thread.id ||
        data['groupName'] is! String) {
      throw const FormatException('Unexpected group.');
    }
    chatInt(data['itineraryId'], min: 1);
    final members = chatArray(
      data['members'],
    ).map((m) => ChatMemberDto.fromJson(m).toDomain()).toList();
    if (chatInt(data['memberCount']) != members.length ||
        members.where((m) => m.isHost).length != 1 ||
        members.map((m) => m.userId).toSet().length != members.length) {
      throw const FormatException('Invalid membership.');
    }
    return List.unmodifiable(members);
  });

  @override
  Future<ChatMessage> interact({
    required ChatMessage message,
    required ChatInteraction action,
    int? optionIndex,
    bool? isPaid,
  }) => _safe(() async {
    final old = message.groupState;
    if (old == null || message.thread.kind != ChatKind.group) {
      throw const ValidationFailure('Choose a group message.');
    }
    final suffix = switch (action) {
      ChatInteraction.acknowledge => 'acknowledge',
      ChatInteraction.checkin => 'checkin',
      ChatInteraction.togglePayment => 'toggle-payment',
      ChatInteraction.vote => 'vote',
    };
    final raw = await _remote.post(
      '${_messages(message.thread)}/${message.id}/$suffix',
      body: switch (action) {
        ChatInteraction.vote => {'optionIndex': optionIndex},
        ChatInteraction.togglePayment => {'isPaid': isPaid},
        _ => null,
      },
    );
    final state = ChatGroupState(
      readByCount: action == ChatInteraction.acknowledge
          ? chatInt(raw, min: 1)
          : old.readByCount,
      isReadByMe: action == ChatInteraction.acknowledge ? true : old.isReadByMe,
      presentCount: action == ChatInteraction.checkin
          ? chatInt(raw, min: 1)
          : old.presentCount,
      isPresentByMe: action == ChatInteraction.checkin
          ? true
          : old.isPresentByMe,
      paidUserIds: action == ChatInteraction.togglePayment
          ? chatIds(raw)
          : old.paidUserIds,
      pollVoteCounts: action == ChatInteraction.vote
          ? chatVotes(
              raw,
              optionCount: message.metadata?.pollOptions.length ?? 0,
            )
          : old.pollVoteCounts,
      myPollVoteOption: action == ChatInteraction.vote
          ? (optionIndex == -1 ? null : optionIndex)
          : old.myPollVoteOption,
    );
    return ChatMessage(
      id: message.id,
      thread: message.thread,
      senderUserId: message.senderUserId,
      senderName: message.senderName,
      type: message.type,
      content: message.content,
      createdAtUtc: message.createdAtUtc,
      senderAvatarUrl: message.senderAvatarUrl,
      clientMessageId: message.clientMessageId,
      metadata: message.metadata,
      groupState: state,
      isReadByOther: message.isReadByOther,
    );
  });

  static void _descending(List<int> ids, int? before) {
    int? previous = before;
    for (final id in ids) {
      if (previous != null && id >= previous) {
        throw const FormatException('Invalid conversation ordering.');
      }
      previous = id;
    }
  }
}
