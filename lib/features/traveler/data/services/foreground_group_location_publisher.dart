import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_location.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/group_location_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/group_location_publisher.dart';

abstract interface class GroupLocationDevice {
  Future<bool> ensurePermission({bool request = false});
  Stream<DeviceGroupLocation> positionStream();
  Future<bool> openSettings();
}

final class GeolocatorGroupLocationDevice implements GroupLocationDevice {
  const GeolocatorGroupLocationDevice();

  @override
  Future<bool> ensurePermission({bool request = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (request && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Stream<DeviceGroupLocation> positionStream() =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).map(
        (position) => DeviceGroupLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );

  @override
  Future<bool> openSettings() async => Geolocator.openAppSettings();
}

/// Keeps foreground GPS publishing alive across route changes. Never starts
/// without device permission and clears the last position when suspended.
final class ForegroundGroupLocationPublisher implements GroupLocationPublisher {
  ForegroundGroupLocationPublisher({
    required GroupLocationRepository repository,
    required GroupLocationDevice device,
    this.retryDelay = const Duration(seconds: 5),
  }) : _repository = repository,
       _device = device;

  final GroupLocationRepository _repository;
  final GroupLocationDevice _device;
  final Duration retryDelay;
  final Set<int> _activeGroups = {};
  final Map<int, String> _sessionVersions = {};
  StreamSubscription<DeviceGroupLocation>? _subscription;
  Timer? _reconnectTimer;
  Future<void> _pending = Future<void>.value();
  bool _suspended = false;
  bool _foreground = true;
  int _lifecycleEpoch = 0;

  @override
  Future<bool> ensurePermission({bool request = false}) =>
      _device.ensurePermission(request: request);

  @override
  Future<void> restoreActiveGroups() async {
    final epoch = _lifecycleEpoch;
    final groupIds = await _repository.getEnabledGroupIds();
    if (epoch != _lifecycleEpoch) return;
    final permission = await _device.ensurePermission();
    if (epoch != _lifecycleEpoch) return;
    final settings = permission
        ? await Future.wait(groupIds.map(_repository.getSetting))
        : <LocationSharingSetting>[];
    if (epoch != _lifecycleEpoch) return;
    _activeGroups
      ..clear()
      ..addAll(groupIds);
    _sessionVersions.clear();
    for (final setting in settings) {
      if (setting.enabled && setting.sessionVersion != null) {
        _sessionVersions[setting.groupId] = setting.sessionVersion!;
      }
    }
    if (_activeGroups.isEmpty) return;
    if (!permission) {
      await pauseForPermission();
      return;
    }
    if (!_foreground) return;
    _suspended = false;
    _listen();
  }

  @override
  Future<void> start(int groupId) async {
    final epoch = _lifecycleEpoch;
    if (!await _device.ensurePermission()) {
      throw const LocationPermissionFailure();
    }
    final setting = await _repository.getSetting(groupId);
    if (epoch != _lifecycleEpoch) return;
    if (!setting.enabled || setting.sessionVersion == null) {
      throw StateError('Location sharing is not enabled for this group.');
    }
    _activeGroups.add(groupId);
    _sessionVersions[groupId] = setting.sessionVersion!;
    if (!_foreground) return;
    _suspended = false;
    _listen();
  }

  void _listen() {
    if (_subscription != null || _suspended || _activeGroups.isEmpty) return;
    _subscription = _device.positionStream().listen(
      (position) {
        _pending = _pending
            .catchError((Object _) {})
            .then((_) => _publish(position));
        unawaited(_pending.catchError((Object _) {}));
      },
      onError: (Object _) => unawaited(_recoverFromStreamInterruption()),
      onDone: () => unawaited(_recoverFromStreamInterruption()),
    );
  }

  Future<void> _recoverFromStreamInterruption() async {
    await pauseForPermission();
    final epoch = _lifecycleEpoch;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(retryDelay, () {
      if (epoch == _lifecycleEpoch && _foreground) {
        unawaited(resume());
      }
    });
  }

  Future<void> _publish(DeviceGroupLocation position) async {
    if (_suspended || !_foreground || _activeGroups.isEmpty) return;
    if (!await _device.ensurePermission()) {
      await pauseForPermission();
      return;
    }
    for (final groupId in _activeGroups.toList()) {
      if (_suspended || !_foreground || !_activeGroups.contains(groupId)) break;
      final sessionVersion = _sessionVersions[groupId];
      if (sessionVersion == null) continue;
      try {
        await _repository.publish(groupId, position, sessionVersion);
      } on PermissionFailure {
        await stop(groupId);
      } on AuthenticationFailure {
        await stopAll();
      } on Failure {
        // Network failure leaves the last fix to expire on the server.
      }
    }
  }

  @override
  Future<void> stop(int groupId) async {
    ++_lifecycleEpoch;
    _activeGroups.remove(groupId);
    _sessionVersions.remove(groupId);
    if (_activeGroups.isEmpty) {
      await _subscription?.cancel();
      _subscription = null;
    }
    await _clearBestEffort(groupId);
  }

  @override
  Future<void> suspend() async {
    await _pause(background: true);
  }

  @override
  Future<void> pauseForPermission() async {
    await _pause(background: false);
  }

  Future<void> _pause({required bool background}) async {
    ++_lifecycleEpoch;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (background) _foreground = false;
    _suspended = true;
    await _subscription?.cancel();
    _subscription = null;
    for (final groupId in _activeGroups.toList()) {
      await _clearBestEffort(groupId);
    }
  }

  @override
  Future<void> resume() async {
    _foreground = true;
    await restoreActiveGroups();
  }

  @override
  Future<void> stopAll() async {
    ++_lifecycleEpoch;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final groups = _activeGroups.toList();
    _activeGroups.clear();
    _sessionVersions.clear();
    _foreground = false;
    _suspended = true;
    await _subscription?.cancel();
    _subscription = null;
    for (final groupId in groups) {
      await _clearBestEffort(groupId);
    }
  }

  Future<void> _clearBestEffort(int groupId) async {
    try {
      await _repository.clear(groupId);
    } catch (_) {
      // Server TTL also prevents an indefinitely visible stale position.
    }
  }

  @override
  Future<bool> openSettings() => _device.openSettings();
}
