import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/messaging/domain/messaging.dart';
import 'package:trip_mate_mobile/features/messaging/presentation/cubit/messenger_state.dart';
import 'package:uuid/uuid.dart';

export 'messenger_state.dart';

/// Route scoped: close and recreate when the authenticated account changes.
final class MessengerCubit extends Cubit<MessengerState> {
  MessengerCubit(this._useCases, this._realtime, this.userId)
    : super(MessengerState()) {
    if (userId <= 0) {
      throw ArgumentError.value(
        userId,
        'userId',
        'An authenticated ID is required',
      );
    }
  }

  final MessagingUseCases _useCases;
  final ChatRealtime _realtime;
  final int userId;
  final _drafts = <String, String>{};
  final _draftRevisions = <String, int>{};
  final _outbox = <_SendOperation>[];
  final _pending = <String>{};
  final _errors = <String, String>{};
  final _blocked = <String>{};
  final _readCursors = <String, int>{};
  final _cursors = <ChatKind, int?>{};
  final _interactionChanges = <int, ({int revision, ChatMessage message})>{};
  int _selectionEpoch = 0;
  int _activityEpoch = 0;
  int _searchEpoch = 0;
  int _interactionRevision = 0;
  int _historyAnchor = 0;
  int? _olderCursor;
  bool _historyInitialized = false;
  bool _disposed = false;
  bool _initialized = false;
  _HistoryGap? _gap;
  _Flight? _listFlight;
  _Flight? _historyFlight;
  Future<void>? _refreshFlight;
  Future<void> _realtimeQueue = Future.value();
  StreamSubscription<ChatInvalidation>? _subscription;
  Timer? _poll;
  Timer? _hintTimer;
  Timer? _continuation;

  bool get _alive => !_disposed && !isClosed;
  bool get _authorized => _alive && !state.needsSignIn;
  bool get _active => _authorized && state.appActive;
  bool _current(ChatThread thread, int selection, int activity) =>
      _active &&
      _selectionEpoch == selection &&
      _activityEpoch == activity &&
      state.selected?.ref == thread.ref;

  Future<void> initialize({int? initialGroupId}) async {
    if (!_authorized || _initialized) return;
    _initialized = true;
    _subscription = _realtime.invalidations.listen(
      (_) => _scheduleRefresh(),
      onError: (Object error, StackTrace stack) {
        if (_active) _setListFailure(error);
      },
    );
    await _list(false);
    if (!_active) return;
    if (initialGroupId != null && initialGroupId > 0) {
      final matches = state.threads.where(
        (thread) =>
            thread.kind == ChatKind.group && thread.id == initialGroupId,
      );
      // A deep link still performs an authorized history/membership read. No
      // membership, title, host, or user identity is fabricated here.
      await select(
        matches.isNotEmpty
            ? matches.first
            : ChatThread(
                ref: ChatThreadRef(kind: ChatKind.group, id: initialGroupId),
                title: 'Trò chuyện nhóm',
                unreadCount: 0,
              ),
      );
    }
    if (_active) {
      _startPolling();
      await _syncRealtime();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _scheduleRefresh(),
    );
  }

  void _scheduleRefresh() {
    if (!_active || _hintTimer != null) return;
    _hintTimer = Timer(const Duration(milliseconds: 200), () {
      _hintTimer = null;
      if (_active) unawaited(refresh());
    });
  }

  Future<void> refresh() {
    if (!_active) return Future.value();
    final existing = _refreshFlight;
    if (existing != null) return existing;
    final work = _refresh();
    _refreshFlight = work;
    return work.whenComplete(() {
      if (identical(_refreshFlight, work)) _refreshFlight = null;
    });
  }

  Future<void> _refresh() async {
    final activity = _activityEpoch;
    await _list(false);
    final selected = state.selected;
    if (!_active || activity != _activityEpoch || selected == null) return;
    await _history(
      selected,
      _historyInitialized ? _HistoryMode.refresh : _HistoryMode.initial,
    );
  }

  Future<void> loadMoreThreads() => _list(true);

  Future<void> _list(bool more) async {
    if (!_active) return;
    final existing = _listFlight;
    if (existing != null) {
      await existing.future;
      if (!_active || existing.more == more) return;
      return _list(more);
    }
    if (more && !state.hasMoreThreads) return;
    final activity = _activityEpoch;
    final flight = _Flight(more: more);
    _listFlight = flight;
    emit(
      state.copyWith(loading: !more, loadingMoreThreads: more, listError: null),
    );
    try {
      final rows = <ChatThread>[];
      final next = <ChatKind, int?>{};
      for (final kind in ChatKind.values) {
        if (more && _cursors[kind] == null) continue;
        final page = await _useCases.listThreads(
          kind,
          beforeId: more ? _cursors[kind] : null,
        );
        if (!_active || activity != _activityEpoch) return;
        rows.addAll(page.items);
        next[kind] = page.nextBeforeId;
      }
      if (!_active || activity != _activityEpoch) return;
      // Refreshing the head must not throw away pages already loaded or rewind
      // their cursors. Only initial load and pagination advance list cursors.
      if (more || _cursors.isEmpty) _cursors.addAll(next);
      final merged = <String, ChatThread>{
        for (final t in state.threads) t.key: t,
      };
      for (final row in rows) {
        merged[row.key] = row;
      }
      final threads = merged.values.toList()
        ..sort((a, b) {
          final time =
              (b.lastMessageAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.lastMessageAtUtc ??
                        DateTime.fromMillisecondsSinceEpoch(0),
                  );
          return time != 0 ? time : a.key.compareTo(b.key);
        });
      final selected = state.selected;
      final updated = selected == null
          ? null
          : merged[selected.key] ?? selected;
      emit(
        state.copyWith(
          threads: threads,
          selected: updated,
          blocked:
              updated != null &&
              (updated.isReadOnly || _blocked.contains(updated.key)),
          hasMoreThreads: _cursors.values.any((cursor) => cursor != null),
          listError: null,
        ),
      );
    } catch (error) {
      if (_active && activity == _activityEpoch) _setListFailure(error);
    } finally {
      if (identical(_listFlight, flight)) {
        _listFlight = null;
        if (_alive) {
          emit(state.copyWith(loading: false, loadingMoreThreads: false));
        }
      }
      flight.complete();
    }
  }

  Future<void> select(ChatThread thread) async {
    if (!_active) return;
    final selection = ++_selectionEpoch;
    final activity = _activityEpoch;
    _continuation?.cancel();
    _gap = null;
    _historyAnchor = 0;
    _historyInitialized = false;
    _olderCursor = null;
    _historyFlight = null;
    _interactionChanges.clear();
    emit(
      state.copyWith(
        selected: thread,
        messages: [],
        members: [],
        draft: _drafts[thread.key] ?? '',
        error: _errors[thread.key],
        busy: _pending.contains(thread.key),
        blocked: thread.isReadOnly || _blocked.contains(thread.key),
        loadingMessages: true,
        loadingOlder: false,
        hasOlder: false,
      ),
    );
    final history = _history(thread, _HistoryMode.initial);
    final members = thread.kind == ChatKind.group && !thread.isReadOnly
        ? _loadMembers(thread, selection, activity)
        : Future<void>.value();
    await Future.wait([history, members, _syncRealtime()]);
  }

  Future<void> _loadMembers(
    ChatThread thread,
    int selection,
    int activity,
  ) async {
    try {
      final members = await _useCases.members(thread.ref);
      if (_current(thread, selection, activity)) {
        emit(state.copyWith(members: members));
      }
    } catch (error) {
      // Missing member data only disables expense creation; never clear or block authorized chat history.
      if (error is AuthenticationFailure &&
          _current(thread, selection, activity)) {
        _authenticationFailure(error);
      }
    }
  }

  Future<void> loadOlder() async {
    final selected = state.selected;
    if (!_active ||
        selected == null ||
        !state.hasOlder ||
        _olderCursor == null) {
      return;
    }
    await _history(
      selected,
      _gap == null ? _HistoryMode.older : _HistoryMode.refresh,
    );
  }

  Future<void> _history(ChatThread thread, _HistoryMode mode) async {
    if (!_active || state.selected?.ref != thread.ref) return;
    final existing = _historyFlight;
    if (existing != null) {
      await existing.future;
      // A head refresh queued behind older-page loading still needs to run.
      if (mode == _HistoryMode.refresh &&
          existing.more &&
          _active &&
          state.selected?.ref == thread.ref) {
        await _history(thread, mode);
      }
      return;
    }
    final selection = _selectionEpoch;
    final activity = _activityEpoch;
    final flight = _Flight(more: mode == _HistoryMode.older);
    _historyFlight = flight;
    emit(
      state.copyWith(
        loadingMessages: mode == _HistoryMode.initial,
        loadingOlder: mode == _HistoryMode.older,
      ),
    );
    var incoming = _gap?.incoming ?? 0;
    try {
      for (var pages = 0; pages < 10; pages++) {
        final cursor = mode == _HistoryMode.older
            ? _olderCursor
            : mode == _HistoryMode.refresh
            ? _gap?.before
            : null;
        final revision = _interactionRevision;
        final page = await _useCases.history(
          thread.ref,
          beforeMessageId: cursor,
        );
        if (!_current(thread, selection, activity)) return;
        final rows = page.items.where((m) => m.thread == thread.ref).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        if (page.items.length > 50 || rows.length != page.items.length) {
          throw const ServerFailure();
        }
        final oldest = rows.isEmpty ? null : rows.first.id;
        final newest = rows.isEmpty ? 0 : rows.last.id;
        if (cursor != null && rows.any((m) => m.id >= cursor)) {
          throw const ServerFailure();
        }
        for (final message in rows) {
          if (message.senderUserId != userId && message.id > incoming) {
            incoming = message.id;
          }
          _reconcileSend(message);
        }
        final patched = rows.map((message) {
          final patch = _interactionChanges[message.id];
          return patch != null && patch.revision > revision
              ? _withGroupState(message, patch.message.groupState)
              : message;
        });
        emit(state.copyWith(messages: _merge(state.messages, patched)));
        if (mode != _HistoryMode.refresh) {
          _olderCursor = page.nextBeforeId;
          if (mode == _HistoryMode.initial) {
            _historyAnchor = newest;
            _historyInitialized = true;
          }
          emit(state.copyWith(hasOlder: _olderCursor != null));
          break;
        }
        final gap = _gap;
        if (oldest == null ||
            oldest <= _historyAnchor ||
            page.nextBeforeId == null) {
          _historyAnchor = gap?.newest ?? newest;
          _gap = null;
          break;
        }
        final next = page.nextBeforeId;
        if (next == null ||
            (cursor != null && next >= cursor) ||
            next > oldest) {
          throw const ServerFailure();
        }
        _gap = _HistoryGap(
          before: next,
          newest: gap?.newest ?? newest,
          incoming: incoming,
        );
      }
      if (!_current(thread, selection, activity)) return;
      if (_gap != null) {
        // Yield after at most 500 rows, retaining the descending cursor. Read
        // receipts remain behind the unsynchronized gap during continuation.
        _continuation?.cancel();
        _continuation = Timer(const Duration(milliseconds: 200), () {
          if (_current(thread, selection, activity)) {
            unawaited(_history(thread, _HistoryMode.refresh));
          }
        });
        return;
      }
      _blocked.remove(thread.key);
      _errors.remove(thread.key);
      emit(
        state.copyWith(
          error: null,
          blocked: state.selected?.isReadOnly ?? false,
        ),
      );
      if (mode != _HistoryMode.older) {
        await _markRead(thread, incoming, selection, activity);
      }
    } catch (error) {
      if (_current(thread, selection, activity)) {
        _setThreadFailure(thread, error);
      }
    } finally {
      if (identical(_historyFlight, flight)) {
        _historyFlight = null;
        if (_alive) {
          emit(state.copyWith(loadingMessages: false, loadingOlder: false));
        }
      }
      flight.complete();
    }
  }

  Future<void> _markRead(
    ChatThread thread,
    int incoming,
    int selection,
    int activity,
  ) async {
    if (!_current(thread, selection, activity) ||
        _gap != null ||
        incoming <= (_readCursors[thread.key] ?? 0)) {
      return;
    }
    await _useCases.markRead(thread.ref, incoming);
    if (!_current(thread, selection, activity)) return;
    _readCursors[thread.key] = incoming;
    final updated = _withThreadSummary(
      state.selected ?? thread,
      unreadCount: 0,
    );
    emit(
      state.copyWith(
        selected: updated,
        threads: state.threads
            .map(
              (t) => t.ref == thread.ref
                  ? _withThreadSummary(t, unreadCount: 0)
                  : t,
            )
            .toList(),
      ),
    );
  }

  void setDraft(String value) {
    final thread = state.selected;
    if (!_authorized || thread == null) return;
    _drafts[thread.key] = value;
    _draftRevisions[thread.key] = (_draftRevisions[thread.key] ?? 0) + 1;
    emit(state.copyWith(draft: value));
  }

  Future<bool> send(
    ChatMessageType type,
    String content, [
    ChatMetadata? metadata,
  ]) async {
    final thread = state.selected;
    if (!_active ||
        thread == null ||
        state.blocked ||
        _pending.contains(thread.key)) {
      return false;
    }
    final text = content.trim();
    if (text.isEmpty || text.length > 4000) {
      _setThreadFailure(
        thread,
        const ValidationFailure('Vui lòng nhập tin nhắn từ 1 đến 4.000 ký tự.'),
      );
      return false;
    }
    final selection = _selectionEpoch;
    final matches = _outbox.where(
      (operation) =>
          operation.thread.ref == thread.ref &&
          operation.type == type &&
          operation.content == text &&
          operation.metadata == metadata,
    );
    final operation = matches.isEmpty
        ? _SendOperation(
            thread: thread,
            type: type,
            content: text,
            metadata: metadata,
            nonce: const Uuid().v4(),
            draftRevision: _draftRevisions[thread.key] ?? 0,
          )
        : matches.first;
    operation.draftRevision = _draftRevisions[thread.key] ?? 0;
    if (matches.isEmpty) _outbox.add(operation);
    _beginOperation(thread);
    try {
      final result = await _useCases.send(
        thread: thread,
        type: type,
        content: text,
        clientMessageId: operation.nonce,
        metadata: metadata,
      );
      if (!_authorized) return false;
      if (result.thread != thread.ref ||
          result.senderUserId != userId ||
          result.clientMessageId != operation.nonce) {
        throw const ServerFailure();
      }
      _completeSend(operation);
      if (_selectionEpoch == selection && state.selected?.ref == thread.ref) {
        emit(state.copyWith(messages: _merge(state.messages, [result])));
      }
      emit(
        state.copyWith(
          threads: state.threads
              .map(
                (t) => t.ref == thread.ref
                    ? _withThreadSummary(
                        t,
                        lastMessage: result.content,
                        lastMessageAtUtc: result.createdAtUtc,
                      )
                    : t,
              )
              .toList(),
        ),
      );
      return true;
    } catch (error) {
      if (!_authorized) return false;
      if (operation.confirmed) return true;
      _setThreadFailure(thread, error);
      return false;
    } finally {
      _endOperation(thread);
    }
  }

  void _reconcileSend(ChatMessage message) {
    if (message.senderUserId != userId || message.clientMessageId == null) {
      return;
    }
    for (final operation in List<_SendOperation>.of(_outbox)) {
      if (operation.thread.ref == message.thread &&
          operation.nonce == message.clientMessageId &&
          operation.content == message.content &&
          operation.type == message.type) {
        _completeSend(operation);
      }
    }
  }

  void _completeSend(_SendOperation operation) {
    operation.confirmed = true;
    _outbox.remove(operation);
    final key = operation.thread.key;
    if (operation.type == ChatMessageType.text &&
        (_draftRevisions[key] ?? 0) == operation.draftRevision &&
        (_drafts[key] ?? '').trim() == operation.content) {
      _drafts[key] = '';
      if (state.selected?.key == key) emit(state.copyWith(draft: ''));
    }
  }

  Future<bool> interact(
    ChatMessage message,
    ChatInteraction action, {
    int? optionIndex,
    bool? isPaid,
  }) async {
    final thread = state.selected;
    if (!_active ||
        thread == null ||
        thread.kind != ChatKind.group ||
        thread.ref != message.thread ||
        state.blocked ||
        _pending.contains(thread.key)) {
      return false;
    }
    final selection = _selectionEpoch;
    _beginOperation(thread);
    try {
      final result = await _useCases.interact(
        thread: thread,
        message: message,
        action: action,
        optionIndex: optionIndex,
        isPaid: isPaid,
      );
      if (!_authorized) return false;
      if (result.thread != thread.ref || result.id != message.id) {
        throw const ServerFailure();
      }
      if (selection == _selectionEpoch && state.selected?.ref == thread.ref) {
        _interactionChanges[result.id] = (
          revision: ++_interactionRevision,
          message: result,
        );
        emit(state.copyWith(messages: _merge(state.messages, [result])));
      }
      return true;
    } catch (error) {
      if (_authorized) _setThreadFailure(thread, error);
      return false;
    } finally {
      _endOperation(thread);
    }
  }

  void _beginOperation(ChatThread thread) {
    _pending.add(thread.key);
    _errors.remove(thread.key);
    if (_alive && state.selected?.ref == thread.ref) {
      emit(state.copyWith(busy: true, error: null));
    }
  }

  void _endOperation(ChatThread thread) {
    _pending.remove(thread.key);
    if (_alive && state.selected?.ref == thread.ref) {
      emit(state.copyWith(busy: false));
    }
  }

  Future<void> searchUsers(String query) async {
    final generation = ++_searchEpoch;
    if (!_active) return;
    final text = query.trim();
    emit(
      state.copyWith(
        searchResults: [],
        searching: text.length >= 2,
        searchError: null,
      ),
    );
    if (text.length < 2) return;
    try {
      final users = await _useCases.searchUsers(text);
      if (_active && generation == _searchEpoch) {
        emit(
          state.copyWith(
            searchResults: users
                .where((user) => user.userId != userId)
                .toList(),
            searching: false,
          ),
        );
      }
    } catch (error) {
      if (_active && generation == _searchEpoch) {
        _authenticationFailure(error);
        if (_alive) {
          emit(
            state.copyWith(searching: false, searchError: _safeMessage(error)),
          );
        }
      }
    }
  }

  void cancelContactSearch() {
    _searchEpoch++;
    if (_alive) {
      emit(
        state.copyWith(searchResults: [], searching: false, searchError: null),
      );
    }
  }

  /// Returns a confirmed thread without navigation. The dialog must check its
  /// own mounted/user-intent guard before explicitly awaiting [select].
  Future<ChatThread?> openDirect(int otherUserId) async {
    if (!_active) return null;
    final generation = _searchEpoch;
    final activity = _activityEpoch;
    try {
      final thread = await _useCases.startDirect(
        otherUserId: otherUserId,
        currentUserId: userId,
      );
      if (!_active ||
          activity != _activityEpoch ||
          generation != _searchEpoch) {
        return null;
      }
      emit(
        state.copyWith(
          threads: [thread, ...state.threads.where((t) => t.ref != thread.ref)],
        ),
      );
      return thread;
    } catch (error) {
      if (_active && activity == _activityEpoch && generation == _searchEpoch) {
        _authenticationFailure(error);
        if (_alive) emit(state.copyWith(searchError: _safeMessage(error)));
      }
      return null;
    }
  }

  Future<void> setAppActive(bool active) async {
    if (!_alive || state.appActive == active) return;
    _activityEpoch++;
    _searchEpoch++;
    _cancelTimers();
    _listFlight = null;
    _historyFlight = null;
    _refreshFlight = null;
    emit(
      state.copyWith(
        appActive: active,
        loading: false,
        loadingMessages: false,
        loadingOlder: false,
        loadingMoreThreads: false,
        searching: false,
      ),
    );
    if (!active) {
      await _syncRealtime();
      return;
    }
    if (!_authorized) return;
    // Authorize reads before reconnecting a previously watched room.
    await refresh();
    if (_active) {
      _startPolling();
      await _syncRealtime();
    }
  }

  Future<void> _syncRealtime() {
    final next = _realtimeQueue
        .then((_) async {
          if (!_active) {
            await _realtime.stop();
            return;
          }
          await _realtime.start();
          if (!_active) {
            await _realtime.stop();
            return;
          }
          await _realtime.watchThread(
            state.blocked ? null : state.selected?.ref,
          );
        })
        .catchError((Object error) {
          if (_active) _setListFailure(error);
        });
    _realtimeQueue = next;
    return next;
  }

  void _setListFailure(Object error) {
    _authenticationFailure(error);
    if (_alive) emit(state.copyWith(listError: _safeMessage(error)));
  }

  void _setThreadFailure(ChatThread thread, Object error) {
    _authenticationFailure(error);
    if (!_authorized) return;
    _errors[thread.key] = _safeMessage(error);
    final denied = error is PermissionFailure || error is NotFoundFailure;
    if (denied) _blocked.add(thread.key);
    if (state.selected?.ref == thread.ref) {
      emit(
        state.copyWith(
          error: _safeMessage(error),
          blocked: denied || thread.isReadOnly || _blocked.contains(thread.key),
          messages: denied ? [] : null,
          members: denied ? [] : null,
        ),
      );
    }
    if (denied) unawaited(_syncRealtime());
  }

  void _authenticationFailure(Object error) {
    if (error is! AuthenticationFailure || !_alive || state.needsSignIn) return;
    _activityEpoch++;
    _selectionEpoch++;
    _searchEpoch++;
    _cancelTimers();
    _drafts.clear();
    _outbox.clear();
    emit(
      MessengerState(
        needsSignIn: true,
        appActive: state.appActive,
        error: _safeMessage(error),
        listError: _safeMessage(error),
      ),
    );
    unawaited(_syncRealtime());
  }

  String _safeMessage(Object error) {
    if (error is AuthenticationFailure) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (error is PermissionFailure) {
      return 'Bạn không còn quyền truy cập cuộc trò chuyện này.';
    }
    if (error is NotFoundFailure) {
      return 'Cuộc trò chuyện hoặc tin nhắn này không còn khả dụng.';
    }
    if (error is ConflictFailure) {
      return 'Cuộc trò chuyện đã thay đổi. Vui lòng tải lại trước khi thử lại.';
    }
    if (error is RateLimitFailure) {
      return 'Bạn thao tác quá nhiều lần. Vui lòng đợi một chút rồi thử lại.';
    }
    if (error is NetworkFailure) {
      return 'Mất kết nối mạng. Tin nhắn nháp đã được lưu, vui lòng thử lại.';
    }
    if (error is ServerFailure) {
      return 'Tính năng nhắn tin tạm thời gián đoạn. Vui lòng thử lại sau.';
    }
    // Domain validation is deliberately bounded below; arbitrary exception or
    // server messages are never displayed by this presentation boundary.
    if (error is ValidationFailure) {
      return 'Vui lòng kiểm tra tin nhắn và các lựa chọn rồi thử lại.';
    }
    return 'Không thể hoàn tất thao tác này. Vui lòng thử lại.';
  }

  void _cancelTimers() {
    _poll?.cancel();
    _hintTimer?.cancel();
    _hintTimer = null;
    _continuation?.cancel();
  }

  @override
  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    _selectionEpoch++;
    _activityEpoch++;
    _searchEpoch++;
    _cancelTimers();
    await _subscription?.cancel();
    await _realtimeQueue;
    try {
      await _realtime.stop();
    } catch (_) {
      /* The route is already closed. */
    }
    try {
      await _realtime.dispose();
    } catch (_) {
      /* No UI remains for this session. */
    }
    _drafts.clear();
    _outbox.clear();
    await super.close();
  }
}

enum _HistoryMode { initial, refresh, older }

final class _Flight {
  _Flight({required this.more});
  final bool more;
  final _completer = Completer<void>();
  Future<void> get future => _completer.future;
  void complete() => _completer.complete();
}

final class _HistoryGap {
  const _HistoryGap({
    required this.before,
    required this.newest,
    required this.incoming,
  });
  final int before, newest, incoming;
}

final class _SendOperation {
  _SendOperation({
    required this.thread,
    required this.type,
    required this.content,
    required this.nonce,
    required this.draftRevision,
    this.metadata,
  });
  final ChatThread thread;
  final ChatMessageType type;
  final String content, nonce;
  final ChatMetadata? metadata;
  int draftRevision;
  bool confirmed = false;
}

List<ChatMessage> _merge(
  Iterable<ChatMessage> old,
  Iterable<ChatMessage> incoming,
) => (<int, ChatMessage>{
  for (final m in old) m.id: m,
  for (final m in incoming) m.id: m,
}.values.toList()..sort((a, b) => a.id.compareTo(b.id)));

ChatMessage _withGroupState(ChatMessage message, ChatGroupState? groupState) =>
    ChatMessage(
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
      groupState: groupState,
      isReadByOther: message.isReadByOther,
    );

ChatThread _withThreadSummary(
  ChatThread thread, {
  int? unreadCount,
  String? lastMessage,
  DateTime? lastMessageAtUtc,
}) => ChatThread(
  ref: thread.ref,
  title: thread.title,
  unreadCount: unreadCount ?? thread.unreadCount,
  hostUserId: thread.hostUserId,
  memberCount: thread.memberCount,
  status: thread.status,
  otherUserId: thread.otherUserId,
  avatarUrl: thread.avatarUrl,
  lastMessage: lastMessage ?? thread.lastMessage,
  lastMessageAtUtc: lastMessageAtUtc ?? thread.lastMessageAtUtc,
  itineraryId: thread.itineraryId,
  itineraryTitle: thread.itineraryTitle,
  itinerarySourceType: thread.itinerarySourceType,
);
