import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/core/push/push_device_repository.dart';
import 'package:trip_mate_mobile/core/push/trip_push_messaging.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';

void main() {
  test(
    'registers a stable installation after authenticated permission',
    () async {
      final repository = _FakeRepository();
      final storage = _MemoryStorage();
      final messaging = _FakeMessaging(token: 'fcm-token');
      final coordinator = PushDeviceCoordinator(
        repository: repository,
        storage: storage,
        messaging: messaging,
      );

      await coordinator.onAuthenticated();
      await coordinator.onAuthenticated();

      expect(repository.registrations, hasLength(2));
      expect(repository.registrations[0].installationId, isNotEmpty);
      expect(
        repository.registrations[1].installationId,
        repository.registrations[0].installationId,
      );
      expect(repository.registrations[0].token, 'fcm-token');
      await coordinator.close();
    },
  );

  test('permission denial does not register a token', () async {
    final repository = _FakeRepository();
    final coordinator = PushDeviceCoordinator(
      repository: repository,
      storage: _MemoryStorage(),
      messaging: _FakeMessaging(permissionGranted: false, token: 'ignored'),
    );

    await coordinator.onAuthenticated();

    expect(repository.registrations, isEmpty);
    await coordinator.close();
  });

  test(
    'token rotation registers and logout removes the same installation',
    () async {
      final repository = _FakeRepository();
      final messaging = _FakeMessaging(token: 'first-token');
      final coordinator = PushDeviceCoordinator(
        repository: repository,
        storage: _MemoryStorage(),
        messaging: messaging,
      );
      await coordinator.onAuthenticated();

      messaging.tokenController.add('rotated-token');
      await Future<void>.delayed(Duration.zero);
      await coordinator.onBeforeLogout();

      expect(repository.registrations.last.token, 'rotated-token');
      expect(
        repository.removals.single,
        repository.registrations.first.installationId,
      );
      await coordinator.close();
    },
  );

  test(
    'forwards valid foreground and opened push hints while signed in',
    () async {
      final messaging = _FakeMessaging(token: 'token');
      final coordinator = PushDeviceCoordinator(
        repository: _FakeRepository(),
        storage: _MemoryStorage(),
        messaging: messaging,
      );
      final received = <TripPushHint>[];
      final subscription = coordinator.hints.listen(received.add);
      await coordinator.onAuthenticated();

      messaging.foregroundController.add(
        const TripPushHint(sessionId: 7, incidentId: 9, opened: false),
      );
      messaging.openedController.add(
        const TripPushHint(sessionId: 7, incidentId: 9, opened: true),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.map((hint) => hint.opened), [false, true]);
      await subscription.cancel();
      await coordinator.close();
    },
  );

  test('deduplicates repeated hints without swallowing a later open', () async {
    final messaging = _FakeMessaging(token: 'token');
    final coordinator = PushDeviceCoordinator(
      repository: _FakeRepository(),
      storage: _MemoryStorage(),
      messaging: messaging,
    );
    final received = <TripPushHint>[];
    final subscription = coordinator.hints.listen(received.add);
    await coordinator.onAuthenticated();

    const foreground = TripPushHint(sessionId: 7, incidentId: 9, opened: false);
    const opened = TripPushHint(sessionId: 7, incidentId: 9, opened: true);
    messaging.foregroundController
      ..add(foreground)
      ..add(foreground);
    messaging.openedController
      ..add(opened)
      ..add(opened);
    await Future<void>.delayed(Duration.zero);

    expect(received.map((hint) => hint.opened), [false, true]);
    await subscription.cancel();
    await coordinator.close();
  });
}

final class _Registration {
  const _Registration(this.installationId, this.token);
  final String installationId;
  final String token;
}

final class _FakeRepository implements PushDeviceRepository {
  final registrations = <_Registration>[];
  final removals = <String>[];

  @override
  Future<void> register({
    required String installationId,
    required String token,
  }) async {
    registrations.add(_Registration(installationId, token));
  }

  @override
  Future<void> remove(String installationId) async {
    removals.add(installationId);
  }
}

final class _FakeMessaging implements TripPushMessaging {
  _FakeMessaging({this.permissionGranted = true, this.token});

  final bool permissionGranted;
  final String? token;
  final tokenController = StreamController<String>.broadcast();
  final foregroundController = StreamController<TripPushHint>.broadcast();
  final openedController = StreamController<TripPushHint>.broadcast();

  @override
  Stream<String> get tokenRefreshes => tokenController.stream;
  @override
  Stream<TripPushHint> get foregroundHints => foregroundController.stream;
  @override
  Stream<TripPushHint> get openedHints => openedController.stream;
  @override
  Future<String?> getToken() async => token;
  @override
  Future<TripPushHint?> getInitialHint() async => null;
  @override
  Future<bool> requestPermission() async => permissionGranted;
}

final class _MemoryStorage implements SecureStorageService {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> deleteAll() async => values.clear();
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
