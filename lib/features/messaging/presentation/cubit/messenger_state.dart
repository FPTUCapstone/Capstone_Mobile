import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';

const _unchanged = Object();

/// A route owns this state for exactly one authenticated account.
final class MessengerState {
  MessengerState({
    List<ChatThread> threads = const [],
    this.selected,
    List<ChatMessage> messages = const [],
    List<ChatMember> members = const [],
    this.draft = '',
    this.error,
    this.listError,
    this.searchError,
    this.loading = false,
    this.loadingMessages = false,
    this.loadingOlder = false,
    this.hasOlder = false,
    this.loadingMoreThreads = false,
    this.hasMoreThreads = false,
    List<ChatUser> searchResults = const [],
    this.searching = false,
    this.busy = false,
    this.blocked = false,
    this.needsSignIn = false,
    this.appActive = true,
  }) : threads = List.unmodifiable(threads),
       messages = List.unmodifiable(messages),
       members = List.unmodifiable(members),
       searchResults = List.unmodifiable(searchResults);

  final List<ChatThread> threads;
  final ChatThread? selected;
  final List<ChatMessage> messages;
  final List<ChatMember> members;
  final String draft;
  final String? error, listError, searchError;
  final bool loading, loadingMessages, loadingOlder, hasOlder;
  final bool loadingMoreThreads, hasMoreThreads;
  final List<ChatUser> searchResults;
  final bool searching, busy, blocked, needsSignIn, appActive;

  MessengerState copyWith({
    List<ChatThread>? threads,
    Object? selected = _unchanged,
    List<ChatMessage>? messages,
    List<ChatMember>? members,
    String? draft,
    Object? error = _unchanged,
    Object? listError = _unchanged,
    Object? searchError = _unchanged,
    bool? loading,
    bool? loadingMessages,
    bool? loadingOlder,
    bool? hasOlder,
    bool? loadingMoreThreads,
    bool? hasMoreThreads,
    List<ChatUser>? searchResults,
    bool? searching,
    bool? busy,
    bool? blocked,
    bool? needsSignIn,
    bool? appActive,
  }) => MessengerState(
    threads: threads ?? this.threads,
    selected: identical(selected, _unchanged)
        ? this.selected
        : selected as ChatThread?,
    messages: messages ?? this.messages,
    members: members ?? this.members,
    draft: draft ?? this.draft,
    error: identical(error, _unchanged) ? this.error : error as String?,
    listError: identical(listError, _unchanged)
        ? this.listError
        : listError as String?,
    searchError: identical(searchError, _unchanged)
        ? this.searchError
        : searchError as String?,
    loading: loading ?? this.loading,
    loadingMessages: loadingMessages ?? this.loadingMessages,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    hasOlder: hasOlder ?? this.hasOlder,
    loadingMoreThreads: loadingMoreThreads ?? this.loadingMoreThreads,
    hasMoreThreads: hasMoreThreads ?? this.hasMoreThreads,
    searchResults: searchResults ?? this.searchResults,
    searching: searching ?? this.searching,
    busy: busy ?? this.busy,
    blocked: blocked ?? this.blocked,
    needsSignIn: needsSignIn ?? this.needsSignIn,
    appActive: appActive ?? this.appActive,
  );
}
