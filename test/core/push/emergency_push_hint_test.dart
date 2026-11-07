import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/emergency_push_handler.dart';
import 'package:trip_mate_mobile/core/push/emergency_push_hint.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/core/push/push_device_repository.dart';
import 'package:trip_mate_mobile/core/push/trip_push_messaging.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';

const _reviewData = {
  'type': 'uc70_weather_safety_review',
  'reviewId': '7',
  'tourId': '12',
  'scheduleId': '31',
  'changeType': 'Created',
  'issuedAtUtc': '2026-11-03T08:00:00.0000000Z',
};

const _bookingData = {
  'type': 'uc70_booking_emergency',
  'bookingId': '42',
  'scheduleId': '31',
  'operationId': '90',
  'action': 'EmergencyStop',
  'committedAtUtc': '2026-11-03T08:00:00.0000000Z',
};

void main() {
  group('contract', () {
    test('reads the frozen review payload', () {
      final hint = EmergencyPushHint.tryParse(_reviewData, opened: true);

      expect(hint, isA<OperatorReviewHint>());
      expect((hint! as OperatorReviewHint).reviewId, 7);
      expect(hint.opened, isTrue);
    });

    test('reads the frozen booking payload', () {
      final hint = EmergencyPushHint.tryParse(_bookingData, opened: false);

      expect(hint, isA<TravelerBookingHint>());
      expect((hint! as TravelerBookingHint).bookingId, 42);
    });

    test('unknown or malformed data is ignored', () {
      for (final data in <Map<String, dynamic>>[
        {},
        {'type': 'TripAlert', 'sessionId': '1'},
        {'type': 'uc70_weather_safety_review'},
        {'type': 'uc70_weather_safety_review', 'reviewId': 'x'},
        {'type': 'uc70_weather_safety_review', 'reviewId': '7'},
        {'type': 'uc70_booking_emergency', 'bookingId': '-1'},
      ]) {
        expect(EmergencyPushHint.tryParse(data, opened: true), isNull);
      }
    });
  });

  group('coordinator', () {
    late _Messaging messaging;
    late PushDeviceCoordinator coordinator;
    late _Storage storage;

    setUp(() {
      messaging = _Messaging();
      storage = _Storage();
      coordinator = PushDeviceCoordinator(
        repository: _Repository(),
        storage: storage,
        messaging: messaging,
        emergencyMessaging: messaging,
      );
    });

    tearDown(() => coordinator.close());

    test('a token failure does not lose a cold-start tap', () async {
      messaging
        ..failToken = true
        ..initial = EmergencyPushHint.tryParse(_reviewData, opened: true);
      final hints = <EmergencyPushHint>[];
      coordinator.emergencyHints.listen(hints.add);

      await coordinator.onAuthenticated();
      await pumpEventQueue();

      expect(hints, hasLength(1));
    });

    test('logout clears what is still in the tray', () async {
      var cleared = 0;
      final clearing = PushDeviceCoordinator(
        repository: _Repository(),
        storage: storage,
        messaging: messaging,
        emergencyMessaging: messaging,
        clearDisplayed: () async => cleared++,
      );
      addTearDown(clearing.close);

      await clearing.onBeforeLogout();

      expect(cleared, 1);
    });

    test('a duplicate payload is delivered once', () async {
      final hints = <EmergencyPushHint>[];
      coordinator.emergencyHints.listen(hints.add);
      await coordinator.onAuthenticated();

      final hint = EmergencyPushHint.tryParse(_reviewData, opened: false)!;
      messaging.foreground.add(hint);
      messaging.foreground.add(hint);
      await pumpEventQueue();

      expect(hints, hasLength(1));
    });

    test('created then escalated are both delivered', () async {
      final hints = <EmergencyPushHint>[];
      coordinator.emergencyHints.listen(hints.add);
      await coordinator.onAuthenticated();

      messaging.foreground.add(
        EmergencyPushHint.tryParse(_reviewData, opened: false)!,
      );
      messaging.foreground.add(
        EmergencyPushHint.tryParse({
          ..._reviewData,
          'changeType': 'Escalated',
        }, opened: false)!,
      );
      await pumpEventQueue();

      expect(hints, hasLength(2));
    });

    test(
      'a tap on a notice already seen in the foreground still opens',
      () async {
        final hints = <EmergencyPushHint>[];
        coordinator.emergencyHints.listen(hints.add);
        await coordinator.onAuthenticated();

        messaging.foreground.add(
          EmergencyPushHint.tryParse(_reviewData, opened: false)!,
        );
        messaging.opened.add(
          EmergencyPushHint.tryParse(_reviewData, opened: true)!,
        );
        await pumpEventQueue();

        expect(hints.map((hint) => hint.opened), [false, true]);
      },
    );

    test('hints stop after sign-out', () async {
      final hints = <EmergencyPushHint>[];
      coordinator.emergencyHints.listen(hints.add);
      await coordinator.onAuthenticated();
      await coordinator.onBeforeLogout();

      messaging.foreground.add(
        EmergencyPushHint.tryParse(_bookingData, opened: false)!,
      );
      await pumpEventQueue();

      expect(hints, isEmpty);
    });

    test(
      'a tap while signed out waits for sign-in and is delivered once',
      () async {
        final hints = <EmergencyPushHint>[];
        coordinator.emergencyHints.listen(hints.add);
        coordinator.listen();

        messaging.opened.add(
          EmergencyPushHint.tryParse(_bookingData, opened: true)!,
        );
        await pumpEventQueue();
        expect(hints, isEmpty);

        await coordinator.onAuthenticated();
        await coordinator.onAuthenticated();
        await pumpEventQueue();

        expect(hints, hasLength(1));
      },
    );

    test('a foreground hint while signed out is dropped', () async {
      final hints = <EmergencyPushHint>[];
      coordinator.emergencyHints.listen(hints.add);
      coordinator.listen();

      messaging.foreground.add(
        EmergencyPushHint.tryParse(_bookingData, opened: false)!,
      );
      await pumpEventQueue();
      await coordinator.onAuthenticated();
      await pumpEventQueue();

      expect(hints, isEmpty);
    });

    test('a killed-app tap is delivered after sign-in', () async {
      messaging.initial = EmergencyPushHint.tryParse(
        _bookingData,
        opened: true,
      );
      final hints = <EmergencyPushHint>[];
      coordinator.emergencyHints.listen(hints.add);

      await coordinator.onAuthenticated();
      await pumpEventQueue();

      expect(hints.single, isA<TravelerBookingHint>());
    });
  });

  group('permission', () {
    late _Messaging messaging;
    late _Storage storage;
    PushDeviceCoordinator create() => PushDeviceCoordinator(
      repository: _Repository(),
      storage: storage,
      messaging: messaging,
    );

    setUp(() {
      messaging = _Messaging();
      storage = _Storage();
    });

    test('asks once and never prompts again', () async {
      messaging.granted = false;
      final coordinator = create();
      addTearDown(coordinator.close);

      await coordinator.onAuthenticated();
      await coordinator.onAuthenticated();
      await coordinator.onAuthenticated();

      expect(messaging.prompts, 1);
      expect(coordinator.permissionDenied.value, isTrue);
    });

    test('granted reports no denial', () async {
      final coordinator = create();
      addTearDown(coordinator.close);

      await coordinator.onAuthenticated();

      expect(coordinator.permissionDenied.value, isFalse);
    });

    test(
      'returning from settings clears the denial and registers the device',
      () async {
        messaging.granted = false;
        final repository = _Repository();
        final coordinator = PushDeviceCoordinator(
          repository: repository,
          storage: storage,
          messaging: messaging,
        );
        addTearDown(coordinator.close);
        await coordinator.onAuthenticated();
        expect(repository.registrations, 0);

        messaging.granted = true;
        await coordinator.onResumed();

        expect(coordinator.permissionDenied.value, isFalse);
        expect(repository.registrations, 1);
        expect(messaging.prompts, 1);
      },
    );

    test('resuming while signed out does nothing', () async {
      final repository = _Repository();
      final coordinator = PushDeviceCoordinator(
        repository: repository,
        storage: storage,
        messaging: messaging,
      );
      addTearDown(coordinator.close);

      await coordinator.onResumed();

      expect(repository.registrations, 0);
    });

    test('granting later in settings clears the denial', () async {
      messaging.granted = false;
      final coordinator = create();
      addTearDown(coordinator.close);
      await coordinator.onAuthenticated();

      messaging.granted = true;
      await coordinator.onAuthenticated();

      expect(coordinator.permissionDenied.value, isFalse);
      expect(messaging.prompts, 1);
    });
  });

  group('handler', () {
    late List<String> opened;
    late int refreshes;
    late List<String> surfaced;
    late EmergencyPushHandler handler;

    setUp(() {
      opened = [];
      refreshes = 0;
      surfaced = [];
      handler = EmergencyPushHandler(
        open: opened.add,
        refresh: (_) async => refreshes++,
        surface: surfaced.add,
      );
    });

    testWidgets('the in-app surface dismisses itself', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .showSnackBar(emergencyUpdateSnackBar(onOpen: () {}));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    test('opening a notice dismisses the in-app surface first', () async {
      final calls = <String>[];
      final dismissing = EmergencyPushHandler(
        open: (_) => calls.add('open'),
        refresh: (_) async {},
        surface: (_) {},
        dismissSurface: () => calls.add('dismiss'),
      );

      await dismissing.handle(
        EmergencyPushHint.tryParse(_reviewData, opened: true)!,
      );

      expect(calls, ['dismiss', 'open']);
    });

    test(
      'a tapped review refreshes and opens through the guarded route',
      () async {
        await handler.handle(
          EmergencyPushHint.tryParse(_reviewData, opened: true)!,
        );

        expect(refreshes, 1);
        expect(opened, ['/operator/weather-safety-reviews/7']);
        expect(surfaced, isEmpty);
      },
    );

    test(
      'a tapped booking opens only the owner-checked notice route',
      () async {
        await handler.handle(
          EmergencyPushHint.tryParse(_bookingData, opened: true)!,
        );

        expect(opened, ['/traveler/bookings/42/emergency']);
      },
    );

    test('a failed refresh still opens the guarded route', () async {
      final failing = EmergencyPushHandler(
        open: opened.add,
        refresh: (_) async => throw StateError('offline'),
        surface: surfaced.add,
      );

      await failing.handle(
        EmergencyPushHint.tryParse(_bookingData, opened: true)!,
      );

      expect(opened, ['/traveler/bookings/42/emergency']);
    });

    test('a foreground hint refreshes and shows one in-app surface', () async {
      await handler.handle(
        EmergencyPushHint.tryParse(_bookingData, opened: false)!,
      );

      expect(refreshes, 1);
      expect(opened, isEmpty);
      expect(surfaced, ['/traveler/bookings/42/emergency']);
    });
  });
}

final class _Messaging implements TripPushMessaging, EmergencyPushMessaging {
  bool granted = true;
  bool failToken = false;
  int prompts = 0;
  EmergencyPushHint? initial;
  final foreground = StreamController<EmergencyPushHint>.broadcast();
  final opened = StreamController<EmergencyPushHint>.broadcast();

  @override
  Stream<EmergencyPushHint> get foregroundEmergencyHints => foreground.stream;
  @override
  Stream<EmergencyPushHint> get openedEmergencyHints => opened.stream;
  @override
  Future<EmergencyPushHint?> getInitialEmergencyHint() async {
    final hint = initial;
    initial = null;
    return hint;
  }

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
  @override
  Stream<TripPushHint> get foregroundHints => const Stream.empty();
  @override
  Stream<TripPushHint> get openedHints => const Stream.empty();
  @override
  Future<String?> getToken() async =>
      failToken ? throw StateError('offline') : 'token';
  @override
  Future<TripPushHint?> getInitialHint() async => null;
  @override
  Future<bool> requestPermission() async {
    prompts++;
    return granted;
  }

  @override
  Future<bool> hasPermission() async => granted;
}

final class _Repository implements PushDeviceRepository {
  int registrations = 0;

  @override
  Future<void> register({
    required String installationId,
    required String token,
  }) async => registrations++;

  @override
  Future<void> remove(String installationId) async {}
}

final class _Storage implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);
  @override
  Future<void> deleteAll() async => _values.clear();
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
