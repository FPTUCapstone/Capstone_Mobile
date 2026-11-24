import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/features/auth/data/datasources/offline_trip_identity_source.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

import 'offline_trip_identity_source_test.dart'
    show MemoryOfflineStorage, offlineJwt;

void main() {
  test(
    'expired authenticated restart becomes a local read session only',
    () async {
      final storage = MemoryOfflineStorage();
      final token = offlineJwt(7, expired: true);
      await OfflineTripIdentitySource(
        storage,
      ).enableForSession(userId: 7, accessToken: token, isTraveler: true);
      storage.values.addAll({
        AppConstants.accessTokenKey: token,
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'traveler',
        AppConstants.keepSignedInKey: 'true',
      });
      final cubit = AuthSessionCubit(
        null,
        storage,
        null,
        null,
        OfflineTripIdentitySource(storage),
      );
      addTearDown(cubit.close);
      await cubit.restoreSession();
      expect(cubit.state, const AuthSessionState.offlineReadOnly(7));
      expect(cubit.state.isAuthenticated, isFalse);
      expect(storage.values[AppConstants.refreshTokenKey], 'refresh');
    },
  );

  test(
    '401 invalidates online credentials while retaining read-only owner',
    () async {
      final storage = MemoryOfflineStorage();
      final cubit = AuthSessionCubit(
        _Repository(7),
        storage,
        null,
        null,
        OfflineTripIdentitySource(storage),
      );
      addTearDown(cubit.close);
      await cubit.signIn(email: 'traveler@example.com', password: 'password');
      await cubit.handleSessionExpired();
      expect(cubit.state, const AuthSessionState.offlineReadOnly(7));
      expect(storage.values[AppConstants.accessTokenKey], isNull);
      expect(
        await OfflineTripIdentitySource(storage).currentOnlineOwnerId(),
        isNull,
      );
    },
  );

  test('explicit logout locks retained downloads across restart', () async {
    final storage = MemoryOfflineStorage();
    final source = OfflineTripIdentitySource(storage);
    await source.enableForSession(
      userId: 7,
      accessToken: offlineJwt(7),
      isTraveler: true,
    );
    final cubit = AuthSessionCubit(null, storage, null, null, source);
    addTearDown(cubit.close);
    await cubit.restoreSession();
    expect(cubit.state.isOfflineReadOnly, isTrue);
    await cubit.signOut();
    expect(cubit.state.isOfflineReadOnly, isFalse);
    expect(await source.currentOwnerId(), isNull);
    final restarted = AuthSessionCubit(null, storage, null, null, source);
    addTearDown(restarted.close);
    await restarted.restoreSession();
    expect(restarted.state.isOfflineReadOnly, isFalse);
  });

  test(
    'switching account replaces retained owner and invalidates old operation key',
    () async {
      final storage = MemoryOfflineStorage();
      final old = AuthSessionCubit(
        _Repository(7),
        storage,
        null,
        null,
        OfflineTripIdentitySource(storage),
      );
      addTearDown(old.close);
      await old.signIn(email: 'a@example.com', password: 'password');
      final source = OfflineTripIdentitySource(storage);
      final key = await source.currentSessionKey();
      final next = AuthSessionCubit(
        _Repository(8),
        storage,
        null,
        null,
        source,
      );
      addTearDown(next.close);
      await next.signIn(email: 'b@example.com', password: 'password');
      expect(await source.currentOwnerId(), 8);
      expect(await source.currentSessionKey(), isNot(key));
    },
  );

  test('unproven offline gate cleanup never claims logout success', () async {
    final storage = MemoryOfflineStorage();
    final source = OfflineTripIdentitySource(storage);
    await source.enableForSession(
      userId: 7,
      accessToken: offlineJwt(7),
      isTraveler: true,
    );
    final cubit = AuthSessionCubit(null, storage, null, null, source);
    addTearDown(cubit.close);
    await cubit.restoreSession();
    storage.failOfflineReads = true;
    await cubit.signOut();
    expect(cubit.state.isOfflineReadOnly, isTrue);
    expect(
      cubit.state.errorMessage,
      AuthSessionCubit.signOutLocalCleanupFailureMessage,
    );
  });

  test(
    'online expired restart retains credentials for the established refresh interceptor',
    () async {
      final storage = await _renewableStorage();
      final network = _Network(true);
      addTearDown(network.close);
      final cubit = AuthSessionCubit(
        null,
        storage,
        null,
        null,
        OfflineTripIdentitySource(storage),
        network,
      );
      addTearDown(cubit.close);
      await cubit.restoreSession();
      expect(cubit.state.isAuthenticated, isTrue);
      expect(storage.values[AppConstants.refreshTokenKey], 'refresh');
    },
  );

  test(
    'offline renewable session resumes provisional online restore on reconnection',
    () async {
      final storage = await _renewableStorage();
      final network = _Network(false);
      addTearDown(network.close);
      final cubit = AuthSessionCubit(
        null,
        storage,
        null,
        null,
        OfflineTripIdentitySource(storage),
        network,
      );
      addTearDown(cubit.close);
      await cubit.restoreSession();
      expect(cubit.state.isOfflineReadOnly, isTrue);
      network.setConnected(true);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.isAuthenticated, isTrue);
      expect(storage.values[AppConstants.refreshTokenKey], 'refresh');
    },
  );

  test(
    'closing during awaited connectivity cannot emit or restore a stale session',
    () async {
      final storage = await _renewableStorage();
      final network = _Network(true)..pending = Completer<bool>();
      addTearDown(network.close);
      final cubit = AuthSessionCubit(
        null,
        storage,
        null,
        null,
        OfflineTripIdentitySource(storage),
        network,
      );
      final restoring = cubit.restoreSession();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      network.pending!.complete(true);
      await restoring;
      expect(cubit.isClosed, isTrue);
    },
  );

  test(
    'unsupported account refusal does not falsely claim previous identity was cleared',
    () async {
      final storage = MemoryOfflineStorage();
      final source = OfflineTripIdentitySource(storage);
      await source.enableForSession(
        userId: 7,
        accessToken: offlineJwt(7),
        isTraveler: true,
      );
      storage.failOfflineReads = true;
      final cubit = AuthSessionCubit(
        _Repository(8, role: 'Administrator'),
        storage,
        null,
        null,
        source,
      );
      addTearDown(cubit.close);
      await cubit.signIn(email: 'admin@example.com', password: 'password');
      expect(
        cubit.state.errorMessage,
        AuthSessionCubit.previousSessionCleanupFailureMessage,
      );
    },
  );

  test(
    'connectivity stream errors preserve read-only access without an unhandled error',
    () async {
      final storage = await _renewableStorage();
      final network = _Network(false);
      addTearDown(network.close);
      final cubit = AuthSessionCubit(
        null,
        storage,
        null,
        null,
        OfflineTripIdentitySource(storage),
        network,
      );
      addTearDown(cubit.close);
      await cubit.restoreSession();
      network.changes.addError(StateError('Connectivity unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.isOfflineReadOnly, isTrue);
    },
  );

  test(
    'reconnect and explicit restore cannot reset an in-flight offline logout guard',
    () async {
      final storage = await _renewableStorage();
      final network = _Network(false);
      final lifecycle = _DelayedLifecycle();
      addTearDown(network.close);
      final cubit = AuthSessionCubit(
        null,
        storage,
        null,
        lifecycle,
        OfflineTripIdentitySource(storage),
        network,
      );
      addTearDown(cubit.close);
      await cubit.restoreSession();
      final logout = cubit.signOut();
      await Future<void>.delayed(Duration.zero);
      network.setConnected(true);
      await cubit.restoreSession();
      await Future<void>.delayed(Duration.zero);
      final duplicate = cubit.signOut();
      await Future<void>.delayed(Duration.zero);
      try {
        expect(cubit.state.operation, AuthSessionOperation.signOut);
        expect(lifecycle.beforeLogoutCalls, 1);
        expect(lifecycle.authenticatedCalls, 0);
      } finally {
        lifecycle.pending.complete();
        await logout;
        await duplicate;
      }
      expect(cubit.state.isOfflineReadOnly, isFalse);
    },
  );
}

class _DelayedLifecycle implements PushDeviceLifecycle {
  final pending = Completer<void>();
  int beforeLogoutCalls = 0;
  int authenticatedCalls = 0;
  @override
  Future<void> onBeforeLogout() async {
    beforeLogoutCalls++;
    await pending.future;
  }

  @override
  Future<void> onAuthenticated() async {
    authenticatedCalls++;
  }
}

Future<MemoryOfflineStorage> _renewableStorage() async {
  final storage = MemoryOfflineStorage();
  final token = offlineJwt(7, expired: true);
  await OfflineTripIdentitySource(
    storage,
  ).enableForSession(userId: 7, accessToken: token, isTraveler: true);
  storage.values.addAll({
    AppConstants.accessTokenKey: token,
    AppConstants.refreshTokenKey: 'refresh',
    AppConstants.sessionRoleKey: 'traveler',
    AppConstants.keepSignedInKey: 'true',
  });
  return storage;
}

class _Network implements NetworkInfo {
  _Network(this.connected);
  bool connected;
  Completer<bool>? pending;
  final changes = StreamController<bool>.broadcast(sync: true);
  @override
  Future<bool> get isConnected async =>
      pending == null ? connected : await pending!.future;
  @override
  Stream<bool> get onConnectivityChanged => changes.stream;
  void setConnected(bool value) {
    connected = value;
    changes.add(value);
  }

  Future<void> close() => changes.close();
}

class _Repository implements AuthRepository {
  _Repository(this.id, {this.role = 'Traveler'});
  final int id;
  final String role;
  @override
  Future<AuthSession> login(
    AuthCredentials credentials, [
    String? token,
  ]) async => AuthSession(
    userId: id,
    status: 'Active',
    role: role,
    accessToken: offlineJwt(id),
    refreshToken: 'refresh',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
