import 'dart:async';

import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/push/push_device_repository.dart';
import 'package:trip_mate_mobile/core/push/trip_push_messaging.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:uuid/uuid.dart';

abstract interface class PushDeviceLifecycle {
  Future<void> onAuthenticated();
  Future<void> onBeforeLogout();
}

final class PushDeviceCoordinator implements PushDeviceLifecycle {
  PushDeviceCoordinator({
    required PushDeviceRepository repository,
    required SecureStorageService storage,
    required TripPushMessaging messaging,
  }) : _repository = repository,
       _storage = storage,
       _messaging = messaging;

  final PushDeviceRepository _repository;
  final SecureStorageService _storage;
  final TripPushMessaging _messaging;
  final _hints = StreamController<TripPushHint>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _authenticated = false;
  bool _listening = false;
  Future<String>? _installationIdFuture;
  final Set<String> _handledHintKeys = {};

  Stream<TripPushHint> get hints => _hints.stream;

  @override
  Future<void> onAuthenticated() async {
    _authenticated = true;
    _listenOnce();
    try {
      if (!await _messaging.requestPermission()) return;
      final token = await _messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _register(token);
      }
      final initial = await _messaging.getInitialHint();
      if (initial != null) _forwardHint(initial);
    } catch (_) {
      // Push is optional. Alert history remains the recovery path.
    }
  }

  @override
  Future<void> onBeforeLogout() async {
    _authenticated = false;
    try {
      final installationId = await _storage.read(
        AppConstants.pushInstallationIdKey,
      );
      if (installationId != null && installationId.isNotEmpty) {
        await _repository.remove(installationId);
      }
    } catch (_) {
      // Device removal is best effort and must not block logout.
    }
  }

  void _listenOnce() {
    if (_listening) return;
    _listening = true;
    _subscriptions
      ..add(
        _messaging.tokenRefreshes.listen((token) {
          if (_authenticated && token.trim().isNotEmpty) {
            unawaited(_register(token));
          }
        }),
      )
      ..add(
        _messaging.foregroundHints.listen((hint) {
          if (_authenticated) _forwardHint(hint);
        }),
      )
      ..add(
        _messaging.openedHints.listen((hint) {
          if (_authenticated) _forwardHint(hint);
        }),
      );
  }

  void _forwardHint(TripPushHint hint) {
    final key = '${hint.opened}:${hint.sessionId}:${hint.incidentId}';
    if (_handledHintKeys.add(key)) _hints.add(hint);
  }

  Future<void> _register(String token) async {
    try {
      final installationId = await _installationId();
      await _repository.register(installationId: installationId, token: token);
    } catch (_) {
      // Token registration is recovered by a future login or token rotation.
    }
  }

  Future<String> _installationId() =>
      _installationIdFuture ??= _readOrCreateInstallationId();

  Future<String> _readOrCreateInstallationId() async {
    final current = await _storage.read(AppConstants.pushInstallationIdKey);
    if (current != null && current.isNotEmpty) return current;
    final created = const Uuid().v4();
    await _storage.write(AppConstants.pushInstallationIdKey, created);
    return created;
  }

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _hints.close();
  }
}
