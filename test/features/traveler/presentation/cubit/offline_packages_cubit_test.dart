import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/live_offline_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_packages_cubit.dart';
import '../../support/offline_fixture.dart';

void main() {
  test(
    'losing account identity clears private list data and diagnostics',
    () async {
      final repo = FakeOfflineRepository()..unreadable = ['private-cache'];
      final cubit = OfflinePackagesCubit(repo);
      await cubit.load();
      repo.failure = const AuthenticationFailure();
      await cubit.load();
      expect(cubit.state.packages, isEmpty);
      expect(cubit.state.unreadable, isEmpty);
      await cubit.close();
    },
  );
  test(
    'losing account identity clears an already open cached package',
    () async {
      final repo = FakeOfflineRepository();
      final cubit = LiveOfflinePackageCubit(repo, itineraryId: 10);
      await cubit.load();
      repo.failure = const AuthenticationFailure();
      await cubit.load();
      expect(cubit.state.manifest, isNull);
      await cubit.close();
    },
  );
  test(
    'list exposes retained local packages and corruption diagnostics',
    () async {
      final repo = FakeOfflineRepository()..unreadable = ['broken'];
      final cubit = OfflinePackagesCubit(repo);
      await cubit.load();
      expect(cubit.state.packages.single.title, 'Local trip');
      expect(cubit.state.unreadable, ['broken']);
      expect(repo.calls, ['list']);
      await cubit.close();
    },
  );
  test('failed refresh retains local list and hides raw errors', () async {
    final repo = FakeOfflineRepository();
    final cubit = OfflinePackagesCubit(repo);
    await cubit.load();
    repo.failure = StateError('secret internal path');
    await cubit.load();
    expect(cubit.state.packages, hasLength(1));
    expect(cubit.state.error, isNot(contains('secret')));
    await cubit.close();
  });
  test('opening cached package is not a download success', () async {
    final repo = FakeOfflineRepository();
    final cubit = LiveOfflinePackageCubit(repo, itineraryId: 10);
    await cubit.load();
    expect(cubit.state.manifest?.title, 'Local trip');
    expect(cubit.state.completionSequence, 0);
    expect(repo.calls.first, 'read');
    await cubit.close();
  });
  test('failed replacement preserves installed manifest', () async {
    final repo = FakeOfflineRepository();
    final cubit = LiveOfflinePackageCubit(repo, itineraryId: 10);
    await cubit.load();
    repo.failure = const NetworkFailure();
    await cubit.download();
    expect(cubit.state.manifest?.title, 'Local trip');
    expect(cubit.state.completionSequence, 0);
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });
  test('cancellation ignores a late successful transfer result', () async {
    final repo = FakeOfflineRepository();
    final result = Completer<OfflineTripManifest>();
    repo.transfer = () => result.future;
    final cubit = LiveOfflinePackageCubit(repo, itineraryId: 10);
    await cubit.load();
    final pending = cubit.download();
    await cubit.cancel();
    result.complete(offlineFixture());
    await pending;
    expect(cubit.state.isDownloading, isFalse);
    expect(cubit.state.completionSequence, 0);
    expect(repo.calls, contains('cancel'));
    await cubit.close();
  });
  test(
    'reconnection checks version once without downloading or hiding local data',
    () async {
      final network = _Network();
      final repo = FakeOfflineRepository();
      final cubit = LiveOfflinePackageCubit(
        repo,
        itineraryId: 10,
        networkInfo: network,
      );
      await cubit.load();
      expect(repo.calls, ['read']);
      network.events.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      network.events.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(repo.calls.where((call) => call == 'check'), hasLength(1));
      expect(repo.calls, isNot(contains('download')));
      expect(cubit.state.manifest?.title, 'Local trip');
      await cubit.close();
      await network.events.close();
    },
  );
  test(
    'rejected cancel during publication preserves accepted transfer success',
    () async {
      final repo = FakeOfflineRepository();
      final result = Completer<OfflineTripManifest>();
      repo.transfer = () => result.future;
      repo.cancellation = () async =>
          throw const ConflictFailure('Finishing save; wait');
      final cubit = LiveOfflinePackageCubit(repo, itineraryId: 10);
      await cubit.load();
      final pending = cubit.download();
      await cubit.cancel();
      expect(cubit.state.isDownloading, isTrue);
      result.complete(offlineFixture());
      await pending;
      expect(cubit.state.completionSequence, 1);
      expect(cubit.state.isDownloading, isFalse);
      await cubit.close();
    },
  );
  test(
    'authoritative access denial reloads persisted lock before rendering',
    () async {
      final repo = FakeOfflineRepository();
      final cubit = LiveOfflinePackageCubit(repo, itineraryId: 10);
      await cubit.load();
      repo.manifest = offlineFixture(locked: true);
      repo.updateFailure = const PermissionFailure();
      await cubit.checkForUpdate();
      expect(cubit.state.manifest?.locked, isTrue);
      expect(cubit.state.error, isNotNull);
      await cubit.close();
    },
  );
}

class _Network implements NetworkInfo {
  final events = StreamController<bool>.broadcast();
  @override
  Future<bool> get isConnected async => false;
  @override
  Stream<bool> get onConnectivityChanged => events.stream;
}
