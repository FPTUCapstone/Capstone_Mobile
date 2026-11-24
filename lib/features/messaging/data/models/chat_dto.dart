import 'dart:convert';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';

Never _invalid() => throw const FormatException('Invalid messaging contract.');
Map<String, dynamic> chatObject(Object? value) {
  if (value is! Map<String, dynamic>) _invalid();
  return value;
}

List<dynamic> chatArray(Object? value) {
  if (value is! List) _invalid();
  return value;
}

int chatInt(Object? value, {int min = 0}) {
  if (value is! int || value < min || value > 9007199254740991) _invalid();
  return value;
}

String _string(Object? value) {
  if (value is! String) _invalid();
  return value;
}

String? _optionalString(Object? value) => value == null ? null : _string(value);
bool _bool(Object? value) {
  if (value is! bool) _invalid();
  return value;
}

DateTime _date(Object? value) {
  final text = _string(value);
  if (!RegExp(
    r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)$',
  ).hasMatch(text)) {
    _invalid();
  }
  final date = DateTime.tryParse(text);
  if (date == null) _invalid();
  return date.toUtc();
}

int? chatCursor(Object? value) => value == null ? null : chatInt(value, min: 1);
List<int> chatIds(Object? value) {
  final ids = chatArray(value).map((e) => chatInt(e, min: 1)).toList();
  if (ids.toSet().length != ids.length) _invalid();
  return ids;
}

Map<int, int> chatVotes(Object? value, {int optionCount = 6}) {
  final data = chatObject(value);
  final counts = <int, int>{};
  for (final e in data.entries) {
    final index = int.tryParse(e.key);
    if (index == null ||
        index < 0 ||
        index >= optionCount ||
        '$index' != e.key) {
      _invalid();
    }
    counts[index] = chatInt(e.value);
  }
  return counts;
}

String chatTypeName(ChatMessageType type) => switch (type) {
  ChatMessageType.rollCall => 'roll_call',
  ChatMessageType.splitBill => 'split_bill',
  _ => type.name,
};
ChatMessageType _type(Object? value) => switch (value) {
  'text' => ChatMessageType.text,
  'broadcast' => ChatMessageType.broadcast,
  'roll_call' => ChatMessageType.rollCall,
  'split_bill' => ChatMessageType.splitBill,
  'poll' => ChatMessageType.poll,
  _ => _invalid(),
};

final class ChatMetadataDto {
  factory ChatMetadataDto.fromJson(Object? value) =>
      ChatMetadataDto._(chatObject(value));
  ChatMetadataDto._(this._data);
  final Map<String, dynamic> _data;
  ChatMetadata toDomain(ChatMessageType type) {
    final d = _data;
    final options = d['options'] == null
        ? <String>[]
        : chatArray(
            d['options'],
          ).map((o) => _string(chatObject(o)['text'])).toList();
    if (type == ChatMessageType.poll &&
        (options.length < 2 ||
            options.length > 6 ||
            options.any((s) => s.trim().isEmpty))) {
      _invalid();
    }

    var shares = <ChatExpenseShare>[];
    int? total;
    if (type == ChatMessageType.splitBill) {
      try {
        final rawShares = d['participants'] == null
            ? <ChatExpenseShare>[]
            : chatArray(d['participants']).map((p) {
                final row = chatObject(p);
                return ChatExpenseShare(
                  userId: chatInt(row['userId'], min: 1),
                  displayName: _string(row['displayName']),
                  amountVnd: chatInt(row['amount']),
                );
              }).toList();
        final parsedTotal = d['totalAmount'] == null
            ? null
            : chatInt(d['totalAmount'], min: 1);
        final validShares =
            rawShares.map((s) => s.userId).toSet().length == rawShares.length &&
            (rawShares.isEmpty ||
                (parsedTotal != null &&
                    rawShares.fold<int>(0, (sum, s) => sum + s.amountVnd) ==
                        parsedTotal));
        if (validShares) {
          shares = rawShares;
          total = parsedTotal;
        }
      } on FormatException {
        // Malformed historical split_bill metadata degrades safely in UI rather than crashing thread history.
      }
    }
    return ChatMetadata(
      pollOptions: options,
      shares: shares,
      totalAmountVnd: total,
      bankCode: _optionalString(d['payerBankName']),
      accountNumber: _optionalString(d['payerBankAccount']),
      accountName: _optionalString(d['payerName']),
      title: _optionalString(d['title'] ?? d['question']),
      content: _optionalString(d['content']),
      deadline: _optionalString(d['deadlineTime']),
    );
  }

  static String encode(ChatMetadata metadata) {
    final value = jsonEncode({
      if (metadata.title != null) 'title': metadata.title,
      if (metadata.content != null) 'content': metadata.content,
      if (metadata.deadline != null) 'deadlineTime': metadata.deadline,
      if (metadata.pollOptions.isNotEmpty)
        'options': [
          for (var i = 0; i < metadata.pollOptions.length; i++)
            {'id': '$i', 'text': metadata.pollOptions[i]},
        ],
      if (metadata.totalAmountVnd != null)
        'totalAmount': metadata.totalAmountVnd,
      if (metadata.shares.isNotEmpty)
        'participants': [
          for (final s in metadata.shares)
            {
              'userId': s.userId,
              'displayName': s.displayName,
              'amount': s.amountVnd,
            },
        ],
      if (metadata.bankCode != null) 'payerBankName': metadata.bankCode,
      if (metadata.accountNumber != null)
        'payerBankAccount': metadata.accountNumber,
      if (metadata.accountName != null) 'payerName': metadata.accountName,
    });
    if (value.length > 16000) _invalid();
    return value;
  }
}

final class ChatThreadDto {
  factory ChatThreadDto.fromJson(Object? value, ChatKind kind) {
    final dto = ChatThreadDto._(chatObject(value), kind);
    dto.toDomain();
    return dto;
  }
  ChatThreadDto._(this._data, this.kind);
  final Map<String, dynamic> _data;
  final ChatKind kind;
  ChatThread toDomain() {
    final d = _data;
    final group = kind == ChatKind.group;
    final status = group
        ? switch (d['status']) {
            'Active' => ChatThreadStatus.active,
            'Closed' => ChatThreadStatus.closed,
            _ => _invalid(),
          }
        : ChatThreadStatus.active;
    final source = group ? _string(d['itinerarySourceType']) : null;
    return ChatThread(
      ref: ChatThreadRef(
        kind: kind,
        id: chatInt(d[group ? 'groupId' : 'conversationId'], min: 1),
      ),
      title: _string(d[group ? 'groupName' : 'displayName']),
      unreadCount: chatInt(d['unreadCount']),
      status: status,
      hostUserId: group ? chatInt(d['hostUserId'], min: 1) : null,
      memberCount: group ? chatInt(d['memberCount'], min: 1) : null,
      otherUserId: group ? null : chatInt(d['otherUserId'], min: 1),
      avatarUrl: group ? null : _optionalString(d['avatarUrl']),
      lastMessage: _optionalString(d['lastMessage']),
      lastMessageAtUtc: d['lastMessageAtUtc'] == null
          ? null
          : _date(d['lastMessageAtUtc']),
      itineraryId: group ? chatInt(d['itineraryId'], min: 1) : null,
      itineraryTitle: group ? _optionalString(d['itineraryTitle']) : null,
      itinerarySourceType: source,
    );
  }
}

final class ChatMessageDto {
  factory ChatMessageDto.fromJson(Object? value, ChatThreadRef thread) {
    final dto = ChatMessageDto._(chatObject(value), thread);
    dto.toDomain();
    return dto;
  }
  ChatMessageDto._(this._data, this.thread);
  final Map<String, dynamic> _data;
  final ChatThreadRef thread;
  ChatMessage toDomain() {
    final d = _data;
    final group = thread.kind == ChatKind.group;
    if (chatInt(d[group ? 'groupId' : 'conversationId'], min: 1) != thread.id) {
      _invalid();
    }
    final type = group ? _type(d['messageType']) : ChatMessageType.text;
    ChatMetadata? metadata;
    if (group && d['metadataJson'] != null) {
      final raw = _string(d['metadataJson']);
      if (raw.length > 16000) _invalid();
      final decoded = jsonDecode(raw);
      _depth(decoded, 0);
      metadata = ChatMetadataDto.fromJson(decoded).toDomain(type);
    }
    if (type == ChatMessageType.poll && metadata == null) _invalid();
    final nonce = _optionalString(d['clientMessageId']);
    if ((!group && nonce == null) || (nonce != null && !isChatNonce(nonce))) {
      _invalid();
    }
    final myVote = chatCursorVote(d['myPollVoteOption']);
    final optionCount = metadata?.pollOptions.length ?? 0;
    if (group &&
        myVote != null &&
        (type != ChatMessageType.poll || myVote >= optionCount)) {
      _invalid();
    }
    return ChatMessage(
      id: chatInt(d['messageId'], min: 1),
      thread: thread,
      senderUserId: chatInt(d['senderUserId'], min: 1),
      senderName: _string(d['senderName']),
      senderAvatarUrl: group ? _optionalString(d['senderAvatarUrl']) : null,
      type: type,
      content: _string(d['content']),
      createdAtUtc: _date(d['createdAtUtc']),
      clientMessageId: nonce,
      metadata: metadata,
      isReadByOther: group ? null : _bool(d['isReadByOther']),
      groupState: group
          ? ChatGroupState(
              readByCount: chatInt(d['readByCount']),
              isReadByMe: _bool(d['isReadByMe']),
              presentCount: chatInt(d['presentCount']),
              isPresentByMe: _bool(d['isPresentByMe']),
              paidUserIds: chatIds(d['paidUserIds']),
              pollVoteCounts: chatVotes(
                d['pollVoteCounts'],
                optionCount: type == ChatMessageType.poll ? optionCount : 0,
              ),
              myPollVoteOption: myVote,
            )
          : null,
    );
  }
}

int? chatCursorVote(Object? value) => value == null ? null : chatInt(value);
void _depth(Object? value, int depth) {
  if (value is Map || value is List) {
    if (depth >= 16) _invalid();
    for (final child in value is Map ? value.values : value as List) {
      _depth(child, depth + 1);
    }
  }
}

final class ChatUserDto {
  factory ChatUserDto.fromJson(Object? value) {
    final dto = ChatUserDto._(chatObject(value));
    dto.toDomain();
    return dto;
  }
  ChatUserDto._(this._data);
  final Map<String, dynamic> _data;
  ChatUser toDomain() => ChatUser(
    userId: chatInt(_data['userId'], min: 1),
    displayName: _string(_data['displayName']),
    avatarUrl: _optionalString(_data['avatarUrl']),
  );
}

final class ChatMemberDto {
  factory ChatMemberDto.fromJson(Object? value) {
    final dto = ChatMemberDto._(chatObject(value));
    dto.toDomain();
    return dto;
  }
  ChatMemberDto._(this._data);
  final Map<String, dynamic> _data;
  ChatMember toDomain() => ChatMember(
    userId: chatInt(_data['memberId'], min: 1),
    displayName: _string(_data['displayName']),
    avatarUrl: _optionalString(_data['avatarUrl']),
    isHost: _bool(_data['isHost']),
    joinedAtUtc: _date(_data['joinedAtUtc']),
    locationSharingEnabled: _bool(_data['locationSharingEnabled']),
  );
}
