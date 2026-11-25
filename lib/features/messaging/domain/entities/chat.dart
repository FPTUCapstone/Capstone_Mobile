import 'package:equatable/equatable.dart';

enum ChatKind { group, direct }

enum ChatThreadStatus { active, closed }

enum ChatMessageType { text, broadcast, rollCall, splitBill, poll }

enum ChatInteraction { acknowledge, checkin, togglePayment, vote }

final class ChatThreadRef extends Equatable {
  const ChatThreadRef({required this.kind, required this.id});
  final ChatKind kind;
  final int id;
  String get key => '${kind.name}:$id';
  @override
  List<Object?> get props => [kind, id];
}

final class ChatThread extends Equatable {
  const ChatThread({
    required this.ref,
    required this.title,
    required this.unreadCount,
    this.hostUserId,
    this.memberCount,
    this.status = ChatThreadStatus.active,
    this.otherUserId,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAtUtc,
    this.itineraryId,
    this.itineraryTitle,
    this.itinerarySourceType,
  });
  final ChatThreadRef ref;
  final String title;
  final int unreadCount;
  final int? hostUserId, memberCount, otherUserId, itineraryId;
  final ChatThreadStatus status;
  final String? avatarUrl, lastMessage, itineraryTitle, itinerarySourceType;
  final DateTime? lastMessageAtUtc;
  ChatKind get kind => ref.kind;
  int get id => ref.id;
  String get key => ref.key;
  bool get isReadOnly => status == ChatThreadStatus.closed;
  @override
  List<Object?> get props => [
    ref,
    title,
    unreadCount,
    hostUserId,
    memberCount,
    status,
    otherUserId,
    avatarUrl,
    lastMessage,
    lastMessageAtUtc,
    itineraryId,
    itineraryTitle,
    itinerarySourceType,
  ];
}

final class ChatUser extends Equatable {
  const ChatUser({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });
  final int userId;
  final String displayName;
  final String? avatarUrl;
  @override
  List<Object?> get props => [userId, displayName, avatarUrl];
}

final class ChatMember extends Equatable {
  const ChatMember({
    required this.userId,
    required this.displayName,
    required this.isHost,
    required this.joinedAtUtc,
    required this.locationSharingEnabled,
    this.avatarUrl,
  });
  final int userId;
  final String displayName;
  final bool isHost, locationSharingEnabled;
  final DateTime joinedAtUtc;
  final String? avatarUrl;
  @override
  List<Object?> get props => [
    userId,
    displayName,
    isHost,
    joinedAtUtc,
    locationSharingEnabled,
    avatarUrl,
  ];
}

final class ChatExpenseShare extends Equatable {
  const ChatExpenseShare({
    required this.userId,
    required this.displayName,
    required this.amountVnd,
  });
  final int userId, amountVnd;
  final String displayName;
  @override
  List<Object?> get props => [userId, displayName, amountVnd];
}

final class ChatMetadata extends Equatable {
  ChatMetadata({
    List<String> pollOptions = const [],
    this.totalAmountVnd,
    List<ChatExpenseShare> shares = const [],
    this.bankCode,
    this.accountNumber,
    this.accountName,
    this.title,
    this.content,
    this.deadline,
  }) : pollOptions = List.unmodifiable(pollOptions),
       shares = List.unmodifiable(shares);
  final List<String> pollOptions;
  final int? totalAmountVnd;
  final List<ChatExpenseShare> shares;
  final String? bankCode, accountNumber, accountName;
  final String? title, content, deadline;
  @override
  List<Object?> get props => [
    pollOptions,
    totalAmountVnd,
    shares,
    bankCode,
    accountNumber,
    accountName,
    title,
    content,
    deadline,
  ];
}

final class ChatGroupState extends Equatable {
  ChatGroupState({
    required this.readByCount,
    required this.isReadByMe,
    required this.presentCount,
    required this.isPresentByMe,
    required List<int> paidUserIds,
    required Map<int, int> pollVoteCounts,
    this.myPollVoteOption,
  }) : paidUserIds = List.unmodifiable(paidUserIds),
       pollVoteCounts = Map.unmodifiable(pollVoteCounts);
  final int readByCount, presentCount;
  final bool isReadByMe, isPresentByMe;
  final List<int> paidUserIds;
  final Map<int, int> pollVoteCounts;
  final int? myPollVoteOption;
  @override
  List<Object?> get props => [
    readByCount,
    isReadByMe,
    presentCount,
    isPresentByMe,
    paidUserIds,
    pollVoteCounts,
    myPollVoteOption,
  ];
}

final class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.thread,
    required this.senderUserId,
    required this.senderName,
    required this.type,
    required this.content,
    required this.createdAtUtc,
    this.senderAvatarUrl,
    this.clientMessageId,
    this.metadata,
    this.groupState,
    this.isReadByOther,
  });
  final int id, senderUserId;
  final ChatThreadRef thread;
  final String senderName, content;
  final ChatMessageType type;
  final DateTime createdAtUtc;
  final String? senderAvatarUrl, clientMessageId;
  final ChatMetadata? metadata;
  final ChatGroupState? groupState;
  final bool? isReadByOther;
  @override
  List<Object?> get props => [
    id,
    thread,
    senderUserId,
    senderName,
    type,
    content,
    createdAtUtc,
    senderAvatarUrl,
    clientMessageId,
    metadata,
    groupState,
    isReadByOther,
  ];
}

final class ChatPage<T> {
  ChatPage({required List<T> items, required this.nextBeforeId})
    : items = List.unmodifiable(items);
  final List<T> items;
  final int? nextBeforeId;
  bool get hasMore => nextBeforeId != null;
}
