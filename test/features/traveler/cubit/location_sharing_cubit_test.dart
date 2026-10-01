import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_location.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/group_location_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/group_location_publisher.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/location_sharing_cubit.dart';

void main() {
  test(
    'denied permission with offline clear keeps paused setting visible',
    () async {
      final repository = _Repository()
        ..enabled = true
        ..clearFails = true;
      final publisher = _Publisher()..permissionGranted = false;
      final cubit = LocationSharingCubit(
        repository: repository,
        publisher: publisher,
      );
      await cubit.load(42);
      expect(cubit.state.status, LocationSharingStatus.ready);
      expect(cubit.state.enabled, true);
      expect(cubit.state.permissionGranted, false);
      await cubit.close();
    },
  );
  test('denied GPS permission does not enable server opt-in', () async {
    final repository = _Repository();
    final publisher = _Publisher()..permissionGranted = false;
    final cubit = LocationSharingCubit(
      repository: repository,
      publisher: publisher,
    );
    await cubit.load(42);

    await cubit.setEnabled(true);

    expect(repository.updateCount, 0);
    expect(cubit.state.enabled, false);
    expect(cubit.state.permissionGranted, false);
    await cubit.close();
  });

  test('granted GPS permission enables opt-in and starts publishing', () async {
    final repository = _Repository();
    final publisher = _Publisher()..permissionGranted = true;
    final cubit = LocationSharingCubit(
      repository: repository,
      publisher: publisher,
    );
    await cubit.load(42);

    await cubit.setEnabled(true);

    expect(repository.enabled, true);
    expect(cubit.state.enabled, true);
    expect(publisher.activeGroups, contains(42));
    await cubit.close();
  });

  test('disabling stops publisher and persists opt-out', () async {
    final repository = _Repository()..enabled = true;
    final publisher = _Publisher()..permissionGranted = true;
    final cubit = LocationSharingCubit(
      repository: repository,
      publisher: publisher,
    );
    await cubit.load(42);

    await cubit.setEnabled(false);

    expect(repository.enabled, false);
    expect(cubit.state.enabled, false);
    expect(cubit.state.permissionGranted, true);
    expect(publisher.activeGroups, isNot(contains(42)));
    await cubit.close();
  });

  test(
    'revoked permission pauses active sharing without revoking opt-in',
    () async {
      final repository = _Repository()..enabled = true;
      final publisher = _Publisher()..permissionGranted = true;
      final cubit = LocationSharingCubit(
        repository: repository,
        publisher: publisher,
      );
      await cubit.load(42);
      publisher.permissionGranted = false;

      await cubit.refreshLocations();

      expect(cubit.state.enabled, true);
      expect(cubit.state.permissionGranted, false);
      expect(publisher.permissionPauseCount, 1);
      await cubit.close();
    },
  );

  test(
    'permission revoked still allows viewing other shared locations',
    () async {
      final repository = _Repository()
        ..enabled = true
        ..locations = [
          GroupLocation(
            userId: 9,
            latitude: 16,
            longitude: 108,
            recordedAtUtc: DateTime.utc(2026, 9, 30),
          ),
        ];
      final publisher = _Publisher()..permissionGranted = true;
      final cubit = LocationSharingCubit(
        repository: repository,
        publisher: publisher,
      );
      await cubit.load(42);
      publisher.permissionGranted = false;
      await cubit.refreshLocations();
      expect(cubit.state.locations.single.userId, 9);
      expect(cubit.state.permissionGranted, false);
      await cubit.close();
    },
  );

  test(
    'late opt-in response cannot start publishing for a stale group',
    () async {
      final repository = _Repository()
        ..updateCompleter = Completer<LocationSharingSetting>();
      final publisher = _Publisher()..permissionGranted = true;
      final cubit = LocationSharingCubit(
        repository: repository,
        publisher: publisher,
      );
      await cubit.load(42);

      final enable = cubit.setEnabled(true);
      await cubit.load(43);
      repository.updateCompleter!.complete(
        const LocationSharingSetting(groupId: 42, enabled: true),
      );
      await enable;

      expect(publisher.activeGroups, isNot(contains(42)));
      expect(cubit.state.enabled, false);
      await cubit.close();
    },
  );
}

final class _Repository implements GroupLocationRepository {
  bool enabled = false;
  int updateCount = 0;
  bool clearFails = false;
  List<GroupLocation> locations = [];
  Completer<LocationSharingSetting>? updateCompleter;

  @override
  Future<List<int>> getEnabledGroupIds() async => enabled ? [42] : [];

  @override
  Future<LocationSharingSetting> getSetting(int groupId) async =>
      LocationSharingSetting(groupId: groupId, enabled: enabled);

  @override
  Future<LocationSharingSetting> updateSetting(int groupId, bool value) async {
    updateCount++;
    final pending = updateCompleter;
    if (pending != null) return pending.future;
    enabled = value;
    return LocationSharingSetting(groupId: groupId, enabled: enabled);
  }

  @override
  Future<List<GroupLocation>> getLocations(int groupId) async => locations;

  @override
  Future<void> publish(
    int groupId,
    DeviceGroupLocation location,
    String sessionVersion,
  ) async {}

  @override
  Future<void> clear(int groupId) async {
    if (clearFails) throw const NetworkFailure();
  }
}

final class _Publisher implements GroupLocationPublisher {
  bool permissionGranted = true;
  int suspendCount = 0;
  int permissionPauseCount = 0;
  final activeGroups = <int>{};

  @override
  Future<void> restoreActiveGroups() async {}

  @override
  Future<bool> ensurePermission({bool request = false}) async =>
      permissionGranted;

  @override
  Future<void> start(int groupId) async => activeGroups.add(groupId);

  @override
  Future<void> stop(int groupId) async => activeGroups.remove(groupId);

  @override
  Future<void> suspend() async {
    suspendCount++;
  }

  @override
  Future<void> pauseForPermission() async {
    permissionPauseCount++;
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> stopAll() async => activeGroups.clear();

  @override
  Future<bool> openSettings() async => true;
}
