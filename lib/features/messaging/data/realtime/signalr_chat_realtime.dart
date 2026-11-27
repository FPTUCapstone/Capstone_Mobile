import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/messaging/domain/entities/chat.dart';
import 'package:trip_mate_mobile/features/messaging/domain/repositories/chat_realtime.dart';

/// SignalR hint client for `/hubs/group-chat` and `/hubs/direct-chat`.
/// Events only trigger authorized HTTP refetches; message payloads are never trusted directly.
final class SignalRChatRealtime implements ChatRealtime {
  SignalRChatRealtime({
    required Uri apiBaseUrl,
    required SecureStorageService storage,
  }) : _apiBaseUrl = apiBaseUrl,
       _storage = storage;

  static const _reconnectDelaysMs = [0, 2000, 10000, 30000];
  static const _groupEvents = [
    'MessageReceived',
    'BroadcastAcknowledged',
    'RollCallCheckedIn',
    'ExpensePaymentUpdated',
    'PollVoteRecorded',
  ];
  static const _directEvents = ['MessageReceived', 'ConversationChanged'];

  final Uri _apiBaseUrl;
  final SecureStorageService _storage;
  final _invalidations = StreamController<ChatInvalidation>.broadcast();

  HubConnection? _groupHub;
  HubConnection? _directHub;
  ChatThreadRef? _watchedThread;
  int? _joinedGroupId;
  bool _disposed = false;

  @visibleForTesting
  static String groupHubUrl(Uri apiBaseUrl) =>
      apiBaseUrl.replace(path: '/hubs/group-chat', query: null).toString();

  @visibleForTesting
  static String directHubUrl(Uri apiBaseUrl) =>
      apiBaseUrl.replace(path: '/hubs/direct-chat', query: null).toString();

  @visibleForTesting
  static ChatInvalidation? parseGroupInvalidation(List<Object?>? arguments) {
    final first = arguments == null || arguments.isEmpty
        ? null
        : arguments.first;
    final groupId = first is Map ? first['groupId'] : null;
    return ChatInvalidation(
      kind: ChatKind.group,
      thread: groupId is int && groupId > 0
          ? ChatThreadRef(kind: ChatKind.group, id: groupId)
          : null,
    );
  }

  @visibleForTesting
  static ChatInvalidation? parseDirectInvalidation(List<Object?>? arguments) {
    final first = arguments == null || arguments.isEmpty
        ? null
        : arguments.first;
    final conversationId = first is Map ? first['conversationId'] : null;
    return ChatInvalidation(
      kind: ChatKind.direct,
      thread: conversationId is int && conversationId > 0
          ? ChatThreadRef(kind: ChatKind.direct, id: conversationId)
          : null,
    );
  }

  @override
  Stream<ChatInvalidation> get invalidations => _invalidations.stream;

  @override
  Future<void> start() async {
    if (_disposed) return;
    await Future.wait([_ensureGroupHub(), _ensureDirectHub()]);
  }

  Future<void> _ensureGroupHub() async {
    if (_groupHub != null) return;
    final hub = HubConnectionBuilder()
        .withUrl(
          groupHubUrl(_apiBaseUrl),
          options: HttpConnectionOptions(accessTokenFactory: _accessToken),
        )
        .withAutomaticReconnect(retryDelays: _reconnectDelaysMs)
        .build();
    _groupHub = hub;
    for (final eventName in _groupEvents) {
      hub.on(eventName, (args) {
        if (_disposed || !identical(_groupHub, hub)) return;
        final item = parseGroupInvalidation(args);
        if (item != null) _invalidations.add(item);
      });
    }
    hub
      ..onreconnected(({connectionId}) {
        if (!_disposed && identical(_groupHub, hub)) {
          unawaited(_rejoinWatched());
        }
      })
      ..onclose(({error}) {
        if (identical(_groupHub, hub)) {
          _groupHub = null;
          _joinedGroupId = null;
        }
      });

    try {
      await hub.start();
      if (!_disposed && identical(_groupHub, hub)) {
        await _rejoinWatched();
      }
    } on Object {
      // Initial realtime handshake failure falls back to Cubit polling without crashing chat.
      if (identical(_groupHub, hub)) {
        _groupHub = null;
        _joinedGroupId = null;
      }
    }
  }

  Future<void> _ensureDirectHub() async {
    if (_directHub != null) return;
    final hub = HubConnectionBuilder()
        .withUrl(
          directHubUrl(_apiBaseUrl),
          options: HttpConnectionOptions(accessTokenFactory: _accessToken),
        )
        .withAutomaticReconnect(retryDelays: _reconnectDelaysMs)
        .build();
    _directHub = hub;
    for (final eventName in _directEvents) {
      hub.on(eventName, (args) {
        if (_disposed || !identical(_directHub, hub)) return;
        final item = parseDirectInvalidation(args);
        if (item != null) _invalidations.add(item);
      });
    }
    hub.onclose(({error}) {
      if (identical(_directHub, hub)) _directHub = null;
    });

    try {
      await hub.start();
      if (!_disposed && identical(_directHub, hub)) {
        await _rejoinWatched();
      }
    } on Object {
      if (identical(_directHub, hub)) {
        _directHub = null;
      }
    }
  }

  @override
  Future<void> watchThread(ChatThreadRef? thread) async {
    if (_disposed) return;
    _watchedThread = thread;
    await _rejoinWatched();
  }

  Future<void> _rejoinWatched() async {
    final target = _watchedThread;
    final previousGroup = _joinedGroupId;
    final groupHub = _groupHub;
    if (previousGroup != null &&
        (target == null ||
            target.kind != ChatKind.group ||
            target.id != previousGroup)) {
      _joinedGroupId = null;
      if (groupHub?.state == HubConnectionState.Connected) {
        try {
          await groupHub!.invoke('LeaveGroupChat', args: [previousGroup]);
        } on Object {
          // Ignore stale room leave failures.
        }
      }
    }

    if (target == null) return;
    if (target.kind == ChatKind.group) {
      if (groupHub?.state != HubConnectionState.Connected) return;
      try {
        await groupHub!.invoke('JoinGroupChat', args: [target.id]);
        _joinedGroupId = target.id;
      } on Object {
        // Group may be closed or denied; polling/HTTP authority handles UI state.
      }
    } else {
      final directHub = _directHub;
      if (directHub?.state != HubConnectionState.Connected) return;
      try {
        await directHub!.invoke('JoinDirectChat', args: [target.id]);
      } on Object {
        // Ignore transient direct room validation failures.
      }
    }
  }

  Future<String> _accessToken() async {
    final token = await _storage.read(AppConstants.accessTokenKey);
    if (token == null || token.isEmpty) {
      throw StateError('No signed-in session.');
    }
    return token;
  }

  @override
  Future<void> stop() async {
    _watchedThread = null;
    _joinedGroupId = null;
    final g = _groupHub;
    final d = _directHub;
    _groupHub = null;
    _directHub = null;
    await Future.wait([
      if (g != null) g.stop().catchError((_) {}),
      if (d != null) d.stop().catchError((_) {}),
    ]);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _invalidations.close();
  }
}
