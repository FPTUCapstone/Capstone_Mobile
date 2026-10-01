import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/app.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/session_coordinator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/group_location_publisher.dart';

void main() {
  testWidgets(
    'the running app connects authenticated 401 invalidation to its session',
    (tester) async {
      await serviceLocator.reset();
      final coordinator = SessionCoordinator();
      final session = AuthSessionCubit(
        null,
        _MemoryStorage({
          AppConstants.accessTokenKey: 'access',
          AppConstants.refreshTokenKey: 'refresh',
          AppConstants.sessionRoleKey: 'traveler',
          AppConstants.keepSignedInKey: 'true',
        }),
      );
      serviceLocator
        ..registerSingleton<SessionCoordinator>(coordinator)
        ..registerSingleton<AuthSessionCubit>(session);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await serviceLocator.reset();
      });

      await tester.pumpWidget(const TripMateApp());
      await session.restoreSession();
      expect(session.state.isAuthenticated, isTrue);
      await coordinator.invalidate();

      expect(session.state, const AuthSessionState.unauthenticated());
    },
  );

  testWidgets(
    'does not resume location sharing after an unauthenticated app resume',
    (tester) async {
      await serviceLocator.reset();
      final coordinator = SessionCoordinator();
      final session = AuthSessionCubit(
        null,
        _MemoryStorage({
          AppConstants.accessTokenKey: 'access',
          AppConstants.refreshTokenKey: 'refresh',
          AppConstants.sessionRoleKey: 'traveler',
          AppConstants.keepSignedInKey: 'true',
        }),
      );
      final publisher = _LocationPublisher();
      serviceLocator
        ..registerSingleton<SessionCoordinator>(coordinator)
        ..registerSingleton<AuthSessionCubit>(session)
        ..registerSingleton<GroupLocationPublisher>(publisher);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await serviceLocator.reset();
      });

      await tester.pumpWidget(const TripMateApp());
      await session.restoreSession();
      await coordinator.invalidate();
      final resumesBeforeLifecycleChange = publisher.resumeCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(publisher.resumeCalls, resumesBeforeLifecycleChange);
      expect(publisher.stopAllCalls, greaterThan(0));
    },
  );

  testWidgets('detached app stops foreground location publishing', (
    tester,
  ) async {
    await serviceLocator.reset();
    final coordinator = SessionCoordinator();
    final session = AuthSessionCubit(
      null,
      _MemoryStorage({
        AppConstants.accessTokenKey: 'access',
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'traveler',
        AppConstants.keepSignedInKey: 'true',
      }),
    );
    final publisher = _LocationPublisher();
    serviceLocator
      ..registerSingleton<SessionCoordinator>(coordinator)
      ..registerSingleton<AuthSessionCubit>(session)
      ..registerSingleton<GroupLocationPublisher>(publisher);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await serviceLocator.reset();
    });

    await tester.pumpWidget(const TripMateApp());
    await session.restoreSession();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);

    expect(publisher.stopAllCalls, greaterThan(0));
  });
}

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this.values);

  final Map<String, String> values;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final class _LocationPublisher implements GroupLocationPublisher {
  int resumeCalls = 0;
  int stopAllCalls = 0;

  @override
  Future<bool> ensurePermission({bool request = false}) async => true;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<void> pauseForPermission() async {}

  @override
  Future<void> restoreActiveGroups() async {}

  @override
  Future<void> resume() async => resumeCalls++;

  @override
  Future<void> start(int groupId) async {}

  @override
  Future<void> stop(int groupId) async {}

  @override
  Future<void> stopAll() async => stopAllCalls++;

  @override
  Future<void> suspend() async {}
}
