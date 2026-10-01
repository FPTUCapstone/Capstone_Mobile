import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/services/foreground_group_location_publisher.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_location.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/group_location_repository.dart';

void main() {
  test('late opt-in cannot open GPS until foreground resumes', () async {
    final device = _Device();
    final repository = _Repository()..enabledGroups = [42];
    final publisher = ForegroundGroupLocationPublisher(
      repository: repository,
      device: device,
    );
    await publisher.suspend();
    await publisher.start(42);
    device.positions.add(
      const DeviceGroupLocation(latitude: 16, longitude: 108),
    );
    await _settle();
    expect(repository.published, isEmpty);
    await publisher.resume();
    device.positions.add(
      const DeviceGroupLocation(latitude: 17, longitude: 109),
    );
    await _settle();
    expect(repository.published, [42]);
    await publisher.stopAll();
    await device.positions.close();
  });
  test(
    'permission pause can resume without an app lifecycle transition',
    () async {
      final device = _Device();
      final repository = _Repository();
      final publisher = ForegroundGroupLocationPublisher(
        repository: repository,
        device: device,
      );
      await publisher.start(42);
      device.permission = false;
      await publisher.pauseForPermission();
      device.permission = true;
      await publisher.start(42);
      device.positions.add(
        const DeviceGroupLocation(latitude: 16, longitude: 108),
      );
      await _settle();
      expect(repository.published, [42]);
      await publisher.stopAll();
      await device.positions.close();
    },
  );
  test('restores server opt-ins after restart without prompting', () async {
    final device = _Device();
    final repository = _Repository()..enabledGroups = [42, 43];
    final publisher = ForegroundGroupLocationPublisher(
      repository: repository,
      device: device,
    );
    await publisher.restoreActiveGroups();
    device.positions.add(
      const DeviceGroupLocation(latitude: 16, longitude: 108),
    );
    await _settle();
    expect(repository.published, [42, 43]);
    expect(repository.publishedVersions, ['v42', 'v43']);
    await publisher.stopAll();
    await device.positions.close();
  });

  test('restored opt-ins do not publish without device permission', () async {
    final device = _Device()..permission = false;
    final repository = _Repository()..enabledGroups = [42];
    final publisher = ForegroundGroupLocationPublisher(
      repository: repository,
      device: device,
    );
    await publisher.restoreActiveGroups();
    expect(repository.published, isEmpty);
    expect(repository.cleared, [42]);
    await device.positions.close();
  });

  test('late restore cannot restart GPS after sign out', () async {
    final device = _Device();
    final repository = _Repository()
      ..enabledGroupsCompleter = Completer<List<int>>();
    final publisher = ForegroundGroupLocationPublisher(
      repository: repository,
      device: device,
    );
    final restore = publisher.restoreActiveGroups();
    await publisher.stopAll();
    repository.enabledGroupsCompleter!.complete([42]);
    await restore;
    device.positions.add(
      const DeviceGroupLocation(latitude: 16, longitude: 108),
    );
    await _settle();
    expect(repository.published, isEmpty);
    await device.positions.close();
  });

  test('late restore cannot reenable a group after opt out', () async {
    final device = _Device();
    final repository = _Repository()
      ..enabledGroupsCompleter = Completer<List<int>>();
    final publisher = ForegroundGroupLocationPublisher(
      repository: repository,
      device: device,
    );
    final restore = publisher.restoreActiveGroups();
    await publisher.stop(42);
    repository.enabledGroupsCompleter!.complete([42]);
    await restore;
    device.positions.add(
      const DeviceGroupLocation(latitude: 16, longitude: 108),
    );
    await _settle();
    expect(repository.published, isEmpty);
    await device.positions.close();
  });
  test('publishes only for opted-in active foreground group', () async {
    final device = _Device();
    final repository = _Repository();
    final publisher = ForegroundGroupLocationPublisher(
      repository: repository,
      device: device,
    );
    await publisher.start(42);

    device.positions.add(
      const DeviceGroupLocation(latitude: 16, longitude: 108),
    );
    await _settle();
    expect(repository.published, [42]);
    expect(repository.publishedVersions, ['v42']);

    await publisher.stop(42);
    device.positions.add(
      const DeviceGroupLocation(latitude: 17, longitude: 109),
    );
    await _settle();
    expect(repository.published, [42]);
    expect(repository.cleared, [42]);
    await device.positions.close();
  });

  test(
    'revoked permission stops publishing and clears last position',
    () async {
      final device = _Device();
      final repository = _Repository();
      final publisher = ForegroundGroupLocationPublisher(
        repository: repository,
        device: device,
      );
      await publisher.start(42);
      device.permission = false;

      device.positions.add(
        const DeviceGroupLocation(latitude: 16, longitude: 108),
      );
      await _settle();

      expect(repository.published, isEmpty);
      expect(repository.cleared, [42]);
      await device.positions.close();
    },
  );

  test(
    'background clears position and foreground resumes only with permission',
    () async {
      final device = _Device();
      final repository = _Repository()..enabledGroups = [42];
      final publisher = ForegroundGroupLocationPublisher(
        repository: repository,
        device: device,
      );
      await publisher.start(42);

      await publisher.suspend();
      device.positions.add(
        const DeviceGroupLocation(latitude: 16, longitude: 108),
      );
      await _settle();
      expect(repository.published, isEmpty);
      expect(repository.cleared, [42]);

      await publisher.resume();
      device.positions.add(
        const DeviceGroupLocation(latitude: 17, longitude: 109),
      );
      await _settle();
      expect(repository.published, [42]);
      await publisher.stopAll();
      await device.positions.close();
    },
  );

  test('a failed fix does not permanently stop later GPS updates', () async {
    final device = _Device();
    final repository = _Repository()..failNextPublish = true;
    final publisher = ForegroundGroupLocationPublisher(
      repository: repository,
      device: device,
    );
    await publisher.start(42);
    device.positions.add(
      const DeviceGroupLocation(latitude: 16, longitude: 108),
    );
    await _settle();
    device.positions.add(
      const DeviceGroupLocation(latitude: 17, longitude: 109),
    );
    await _settle();

    expect(repository.published, [42]);
    await publisher.stopAll();
    await device.positions.close();
  });

  test(
    'GPS stream interruption reconnects and publishes a later fix',
    () async {
      final device = _Device();
      final repository = _Repository()..enabledGroups = [42];
      final publisher = ForegroundGroupLocationPublisher(
        repository: repository,
        device: device,
        retryDelay: Duration.zero,
      );
      await publisher.start(42);

      device.positions.addError(StateError('GPS temporarily unavailable'));
      await _settle();
      device.positions.add(
        const DeviceGroupLocation(latitude: 16, longitude: 108),
      );
      await _settle();

      expect(repository.cleared, [42]);
      expect(repository.published, [42]);
      await publisher.stopAll();
      await device.positions.close();
    },
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

final class _Device implements GroupLocationDevice {
  bool permission = true;
  final positions = StreamController<DeviceGroupLocation>.broadcast();

  @override
  Future<bool> ensurePermission({bool request = false}) async => permission;

  @override
  Stream<DeviceGroupLocation> positionStream() => positions.stream;

  @override
  Future<bool> openSettings() async => true;
}

final class _Repository implements GroupLocationRepository {
  final published = <int>[];
  final publishedVersions = <String>[];
  final cleared = <int>[];
  List<int> enabledGroups = [];
  Completer<List<int>>? enabledGroupsCompleter;
  bool failNextPublish = false;

  @override
  Future<List<int>> getEnabledGroupIds() async =>
      enabledGroupsCompleter?.future ?? enabledGroups;

  @override
  Future<void> publish(
    int groupId,
    DeviceGroupLocation location,
    String sessionVersion,
  ) async {
    if (failNextPublish) {
      failNextPublish = false;
      throw StateError('Unexpected transport error');
    }
    published.add(groupId);
    publishedVersions.add(sessionVersion);
  }

  @override
  Future<void> clear(int groupId) async => cleared.add(groupId);

  @override
  Future<LocationSharingSetting> getSetting(int groupId) async =>
      LocationSharingSetting(
        groupId: groupId,
        enabled: true,
        sessionVersion: 'v$groupId',
      );

  @override
  Future<LocationSharingSetting> updateSetting(
    int groupId,
    bool enabled,
  ) async => LocationSharingSetting(groupId: groupId, enabled: enabled);

  @override
  Future<List<GroupLocation>> getLocations(int groupId) async => [];
}
