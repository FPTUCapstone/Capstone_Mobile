import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/push/emergency_push_hint.dart';
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
    EmergencyPushMessaging? emergencyMessaging,
    Future<void> Function()? clearDisplayed,
  }) : _repository = repository,
       _storage = storage,
       _messaging = messaging,
       _emergencyMessaging = emergencyMessaging,
       _clearDisplayed = clearDisplayed;

  final PushDeviceRepository _repository;
  final SecureStorageService _storage;
  final TripPushMessaging _messaging;
  final EmergencyPushMessaging? _emergencyMessaging;
  final Future<void> Function()? _clearDisplayed;
  final _hints = StreamController<TripPushHint>.broadcast();
  final _emergencyHints = StreamController<EmergencyPushHint>.broadcast();
  final _handledEmergencyKeys = <String>{};
  final _permissionDenied = ValueNotifier<bool>(false);

  /// A tap made while signed out: only route identifiers, held in memory until
  /// sign-in, where the route guards and REST decide what may be shown.
  EmergencyPushHint? _pendingEmergencyTap;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _authenticated = false;
  bool _listening = false;
  Future<String>? _installationIdFuture;
  final Set<String> _handledHintKeys = {};

  Stream<TripPushHint> get hints => _hints.stream;

  /// UC-70 hints, once per logical notice. A hint only asks for a REST refresh.
  Stream<EmergencyPushHint> get emergencyHints => _emergencyHints.stream;

  /// True when notifications are off; the app keeps working through REST.
  ValueListenable<bool> get permissionDenied => _permissionDenied;

  @override
  Future<void> onAuthenticated() async {
    _authenticated = true;
    _listenOnce();
    if (_pendingEmergencyTap case final tap?) {
      _pendingEmergencyTap = null;
      _forwardEmergency(tap);
    }
    await _forwardInitialHints();
    try {
      if (await _messaging.hasPermission() == false &&
          await _alreadyAskedForPermission()) {
        _permissionDenied.value = true;
        return;
      }
      await _storage.write(AppConstants.pushPermissionAskedKey, 'true');
      final granted = await _messaging.hasPermission()
          ? true
          : await _messaging.requestPermission();
      _permissionDenied.value = !granted;
      if (!granted) return;
      final token = await _messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _register(token);
      }
    } catch (_) {
      // Push is optional. Alert history remains the recovery path.
    }
  }

  /// Apart from registration: a token failure must not lose a cold-start tap.
  Future<void> _forwardInitialHints() async {
    try {
      final initial = await _messaging.getInitialHint();
      if (initial != null) _forwardHint(initial);
      final initialEmergency = await _emergencyMessaging
          ?.getInitialEmergencyHint();
      if (initialEmergency != null) _forwardEmergency(initialEmergency);
    } catch (_) {
      // The tap is lost, and alert history remains the recovery path.
    }
  }

  @override
  Future<void> onBeforeLogout() async {
    _authenticated = false;
    _handledEmergencyKeys.clear();
    // Nothing shown to this account may stay behind for the next one.
    await _clearDisplayed?.call();
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

  /// Starts listening before any sign-in, so a tap on a notification is not lost.
  void listen() => _listenOnce();

  /// The app came back, possibly from Settings: never prompts, only re-reads.
  Future<void> onResumed() async {
    if (!_authenticated || !_permissionDenied.value) return;
    try {
      if (!await _messaging.hasPermission()) return;
      _permissionDenied.value = false;
      final token = await _messaging.getToken();
      if (token != null && token.trim().isNotEmpty) await _register(token);
    } catch (_) {
      // Push is optional. The next resume or sign-in tries again.
    }
  }

  Future<bool> _alreadyAskedForPermission() async =>
      await _storage.read(AppConstants.pushPermissionAskedKey) != null;

  void _forwardEmergency(EmergencyPushHint hint) {
    if (_handledEmergencyKeys.add(hint.dedupeKey)) _emergencyHints.add(hint);
  }

  void _listenOnce() {
    if (_listening) return;
    _listening = true;
    if (_emergencyMessaging case final emergency?) {
      _subscriptions
        ..add(
          emergency.foregroundEmergencyHints.listen((hint) {
            if (_authenticated) _forwardEmergency(hint);
          }),
        )
        ..add(
          emergency.openedEmergencyHints.listen((hint) {
            if (_authenticated) {
              _forwardEmergency(hint);
            } else {
              _pendingEmergencyTap = hint;
            }
          }),
        );
    }
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
    await _emergencyHints.close();
    _permissionDenied.dispose();
  }
}
