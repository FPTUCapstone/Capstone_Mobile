import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/notifications/domain/repositories/in_app_notification_realtime.dart';

/// SignalR hint client for `/hubs/notifications`.
/// No logger is attached: the hub URL carries the access token during setup.
final class SignalRInAppNotificationRealtime
    implements InAppNotificationRealtime {
  SignalRInAppNotificationRealtime({
    required Uri apiBaseUrl,
    required SecureStorageService storage,
  }) : _apiBaseUrl = apiBaseUrl,
       _storage = storage;

  static const clientEvent = 'NotificationsChanged';
  static const _reconnectDelaysMs = [0, 2000, 10000, 30000];

  final Uri _apiBaseUrl;
  final SecureStorageService _storage;
  final _changes = StreamController<void>.broadcast();
  HubConnection? _hub;
  bool _disposed = false;

  @visibleForTesting
  static String hubUrl(Uri apiBaseUrl) =>
      apiBaseUrl.replace(path: '/hubs/notifications', query: null).toString();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> start() async {
    if (_disposed || _hub != null) return;
    final hub = HubConnectionBuilder()
        .withUrl(
          hubUrl(_apiBaseUrl),
          options: HttpConnectionOptions(accessTokenFactory: _accessToken),
        )
        .withAutomaticReconnect(retryDelays: _reconnectDelaysMs)
        .build();
    _hub = hub;
    hub
      ..on(clientEvent, (_) {
        if (!_disposed && identical(_hub, hub)) {
          _changes.add(null);
        }
      })
      ..onreconnected(({connectionId}) {
        if (!_disposed && identical(_hub, hub)) {
          _changes.add(null);
        }
      })
      ..onclose(({error}) {
        if (identical(_hub, hub)) {
          _hub = null;
        }
      });

    try {
      await hub.start();
    } on Object {
      // Initial handshake failure stays quiet; foreground/resume refresh remains active.
      if (identical(_hub, hub)) {
        _hub = null;
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
    final hub = _hub;
    _hub = null;
    if (hub != null) {
      await hub.stop().catchError((_) {});
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _changes.close();
  }
}
