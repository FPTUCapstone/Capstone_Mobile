import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

void main() {
  group('OfflineTripPackageCubit Demo Mode', () {
    late OfflineTripPackageCubit cubit;

    setUp(() {
      cubit = OfflineTripPackageCubit(
        itineraryId: 101,
        title: 'Đà Nẵng City Explorer',
        initialPackage: ActiveTripDemoFixtures.createSampleOfflinePackage(
          itineraryId: 101,
          totalSizeMb: 118.5,
        ),
        isDemoMode: true,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state loads package with notDownloaded metadata', () {
      expect(cubit.state.package.status, OfflinePackageStatus.notDownloaded);
      expect(cubit.state.package.itineraryId, 101);
      expect(cubit.state.package.totalSizeMb, 118.5);
      expect(cubit.state.package.isAvailableOffline, isFalse);
    });

    test('enforces BR-37 150 MB ceiling rule', () async {
      final oversizedPackage =
          ActiveTripDemoFixtures.createSampleOfflinePackage(
            itineraryId: 101,
            totalSizeMb: 165.0,
          );
      final oversizedCubit = OfflineTripPackageCubit(
        itineraryId: 101,
        initialPackage: oversizedPackage,
        isDemoMode: true,
      );

      await oversizedCubit.startDownload();

      expect(
        oversizedCubit.state.package.status,
        OfflinePackageStatus.insufficientStorage,
      );
      expect(oversizedCubit.state.package.errorMessage, contains('150 MB'));

      await oversizedCubit.close();
    });

    test('detects insufficient device storage space', () async {
      final lowStorageCubit = OfflineTripPackageCubit(
        itineraryId: 101,
        initialPackage: ActiveTripDemoFixtures.createSampleOfflinePackage(
          itineraryId: 101,
        ),
        initialFreeStorageMb: 50.0, // Less than 150 MB required
        isDemoMode: true,
      );

      await lowStorageCubit.startDownload();

      expect(
        lowStorageCubit.state.package.status,
        OfflinePackageStatus.insufficientStorage,
      );
      expect(
        lowStorageCubit.state.package.errorMessage,
        contains('Insufficient storage space'),
      );

      await lowStorageCubit.close();
    });

    test(
      'download simulation completes and marks package as available',
      () async {
        expect(cubit.state.package.isAvailableOffline, isFalse);

        await cubit.startDownload();

        expect(cubit.state.package.status, OfflinePackageStatus.available);
        expect(cubit.state.package.isAvailableOffline, isTrue);
        expect(cubit.state.package.progressPercent, 100.0);
        expect(cubit.state.package.lastDownloadedAt, isNotNull);
      },
    );

    test(
      'BR-38 partial download safety: interrupted download never marked available',
      () {
        cubit.demoSimulateNetworkInterruption();

        expect(
          cubit.state.package.status,
          OfflinePackageStatus.networkInterrupted,
        );
        expect(cubit.state.package.isAvailableOffline, isFalse);
        expect(cubit.state.package.errorMessage, contains('interrupted'));
      },
    );

    test(
      'superseded refresh retains old copy until replacement download',
      () async {
        final availablePackage =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              status: OfflinePackageStatus.available,
            );
        final testCubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: availablePackage,
          isDemoMode: true,
        );
        expect(testCubit.state.package.isAvailableOffline, isTrue);

        testCubit.demoSimulateSuperseded();
        expect(testCubit.state.package.status, OfflinePackageStatus.superseded);
        // Still available offline to prevent stranded Traveler
        expect(testCubit.state.package.isAvailableOffline, isTrue);

        await testCubit.close();
      },
    );

    test(
      'removeOfflineData resets package to notDownloaded and clears lastDownloadedAt',
      () {
        final downloadedPackage =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              status: OfflinePackageStatus.available,
              lastDownloadedAt: DateTime(2026, 10, 1, 12),
            );
        final activeCubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: downloadedPackage,
          isDemoMode: true,
        );

        expect(activeCubit.state.package.lastDownloadedAt, isNotNull);

        activeCubit.removeOfflineData();

        expect(
          activeCubit.state.package.status,
          OfflinePackageStatus.notDownloaded,
        );
        expect(activeCubit.state.package.progressPercent, 0.0);
        expect(activeCubit.state.package.lastDownloadedAt, isNull);
        expect(activeCubit.state.package.isAvailableOffline, isFalse);

        activeCubit.close();
      },
    );
  });

  group('Production / Demo Boundary in OfflineTripPackageCubit', () {
    test('OfflineTripPackageCubit defaults isDemoMode to false', () {
      final prodCubit = OfflineTripPackageCubit(itineraryId: 202);
      expect(prodCubit.state.isDemoMode, isFalse);
      prodCubit.close();
    });

    test(
      'production cubit does NOT automatically populate demo package fixtures',
      () {
        final prodCubit = OfflineTripPackageCubit(
          itineraryId: 202,
          title: 'Da Nang Real Trip',
        );

        expect(prodCubit.state.package.title, 'Da Nang Real Trip');
        expect(prodCubit.state.package.totalSizeMb, 0.0);
        expect(
          prodCubit.state.package.status,
          OfflinePackageStatus.unavailable,
        );
        expect(prodCubit.state.package.lastDownloadedAt, isNull);

        prodCubit.close();
      },
    );

    test(
      'production cubit download does not fake success and reports truthful unavailability',
      () async {
        final prodCubit = OfflineTripPackageCubit(itineraryId: 202);

        expect(
          prodCubit.state.package.status,
          OfflinePackageStatus.unavailable,
        );

        await prodCubit.startDownload();

        expect(
          prodCubit.state.package.status,
          OfflinePackageStatus.unavailable,
        );
        expect(
          prodCubit.state.package.errorMessage,
          contains('not currently available'),
        );

        await prodCubit.close();
      },
    );

    test('offline demo simulation methods cannot alter non-demo state', () {
      final prodCubit = OfflineTripPackageCubit(itineraryId: 202);
      final initialStatus = prodCubit.state.package.status;

      prodCubit.demoSimulateNetworkInterruption();
      expect(prodCubit.state.package.status, initialStatus);

      prodCubit.demoSimulateOversizePackage();
      expect(prodCubit.state.package.status, initialStatus);

      prodCubit.demoSimulateSuperseded();
      expect(prodCubit.state.package.status, initialStatus);

      prodCubit.close();
    });
  });

  group('FIX 4: OfflineTripPackage Nullable Clear Semantics', () {
    test('copyWith(clearLastDownloadedAt: true) clears lastDownloadedAt', () {
      final pkg = OfflineTripPackage(
        itineraryId: 101,
        title: 'Test',
        version: 1,
        totalSizeMb: 50.0,
        lastDownloadedAt: DateTime(2026, 10, 1, 15, 30),
      );

      expect(pkg.lastDownloadedAt, isNotNull);

      final cleared = pkg.copyWith(clearLastDownloadedAt: true);
      expect(cleared.lastDownloadedAt, isNull);
      expect(cleared.itineraryId, 101);
      expect(cleared.title, 'Test');
    });

    test('copyWith() preserves existing lastDownloadedAt when not cleared', () {
      final downloadedTime = DateTime(2026, 10, 1, 15, 30);
      final pkg = OfflineTripPackage(
        itineraryId: 101,
        title: 'Test',
        version: 1,
        totalSizeMb: 50.0,
        lastDownloadedAt: downloadedTime,
      );

      final updated = pkg.copyWith(progressPercent: 50.0);
      expect(updated.lastDownloadedAt, downloadedTime);
      expect(updated.progressPercent, 50.0);
    });

    test('copyWith(clearErrorMessage: true) clears errorMessage', () {
      final pkg = const OfflineTripPackage(
        itineraryId: 101,
        title: 'Test',
        version: 1,
        totalSizeMb: 50.0,
        errorMessage: 'Network failed',
      );

      expect(pkg.errorMessage, 'Network failed');

      final cleared = pkg.copyWith(clearErrorMessage: true);
      expect(cleared.errorMessage, isNull);
    });

    test('copyWith(clearDateRange: true) clears dateRange', () {
      final pkg = const OfflineTripPackage(
        itineraryId: 101,
        title: 'Test',
        version: 1,
        totalSizeMb: 50.0,
        dateRange: 'Oct 20 - Oct 22',
      );

      expect(pkg.dateRange, 'Oct 20 - Oct 22');

      final cleared = pkg.copyWith(clearDateRange: true);
      expect(cleared.dateRange, isNull);
    });
  });

  group('Review Round 4 Finding P2: Offline refresh preserves installed package', () {
    test(
      'refreshSupersededPackage preserves installed package availability in all emitted states and promotes atomically at 100%',
      () async {
        final supersededPkg = ActiveTripDemoFixtures.createSampleOfflinePackage(
          itineraryId: 101,
          version: 1,
          status: OfflinePackageStatus.superseded,
          lastDownloadedAt: DateTime(2026, 10, 1, 10),
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPkg,
          isDemoMode: true,
        );

        expect(cubit.state.package.isAvailableOffline, isTrue);
        expect(cubit.state.isAvailableOffline, isTrue);
        expect(cubit.state.isRefreshing, isFalse);

        final emittedStates = <OfflineTripPackageState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        await cubit.refreshSupersededPackage();
        await pumpEventQueue();
        await subscription.cancel();

        // 4 intermediate states (checkingStorage, 15%, 55%, 88%) + 1 final promoted state (100%)
        expect(emittedStates.length, 5);

        // Verify intermediate states: installed package stays superseded and available offline
        for (int i = 0; i < 4; i++) {
          final s = emittedStates[i];
          expect(
            s.package.status,
            OfflinePackageStatus.superseded,
            reason: 'State $i package status must be superseded',
          );
          expect(
            s.package.version,
            1,
            reason: 'State $i package version must remain 1',
          );
          expect(
            s.package.isAvailableOffline,
            isTrue,
            reason: 'State $i package must remain available offline',
          );
          expect(
            s.isAvailableOffline,
            isTrue,
            reason: 'State $i cubit state must report available offline',
          );
          expect(
            s.isRefreshing,
            isTrue,
            reason: 'State $i must indicate active refresh',
          );
          expect(
            s.replacementPackage,
            isNotNull,
            reason: 'State $i must hold replacement package',
          );
          expect(
            s.replacementPackage!.version,
            2,
            reason: 'State $i replacement package must have target version',
          );
        }

        // Verify final promoted state: replacement atomically becomes the package
        final finalState = emittedStates.last;
        expect(finalState.package.status, OfflinePackageStatus.available);
        expect(finalState.package.version, 2);
        expect(finalState.package.progressPercent, 100.0);
        expect(finalState.package.isAvailableOffline, isTrue);
        expect(finalState.isAvailableOffline, isTrue);
        expect(finalState.isRefreshing, isFalse);
        expect(finalState.replacementPackage, isNull);

        await cubit.close();
      },
    );

    test(
      'startDownload on superseded package delegates to refresh to preserve usable copy',
      () async {
        final supersededPkg = ActiveTripDemoFixtures.createSampleOfflinePackage(
          itineraryId: 101,
          version: 1,
          status: OfflinePackageStatus.superseded,
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPkg,
          isDemoMode: true,
        );

        final emittedStates = <OfflineTripPackageState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        await cubit.startDownload();
        await pumpEventQueue();
        await subscription.cancel();

        // Must never set installed package status to checkingStorage or downloading
        for (final s in emittedStates) {
          expect(s.isAvailableOffline, isTrue);
          expect(s.package.isAvailableOffline, isTrue);
          expect(s.package.status == OfflinePackageStatus.downloading, isFalse);
          expect(
            s.package.status == OfflinePackageStatus.checkingStorage,
            isFalse,
          );
        }

        expect(cubit.state.package.status, OfflinePackageStatus.available);
        expect(cubit.state.package.version, 2);

        await cubit.close();
      },
    );

    test(
      'refresh failure due to low storage leaves installed package superseded and usable',
      () async {
        final supersededPkg = ActiveTripDemoFixtures.createSampleOfflinePackage(
          itineraryId: 101,
          version: 1,
          status: OfflinePackageStatus.superseded,
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPkg,
          initialFreeStorageMb: 50.0, // Insufficient for 150 MB requirement
          isDemoMode: true,
        );

        await cubit.refreshSupersededPackage();

        expect(
          cubit.state.replacementPackage?.status,
          OfflinePackageStatus.insufficientStorage,
        );
        expect(cubit.state.package.status, OfflinePackageStatus.superseded);
        expect(cubit.state.package.isAvailableOffline, isTrue);
        expect(cubit.state.isAvailableOffline, isTrue);

        await cubit.close();
      },
    );

    test(
      'refresh failure due to oversized package leaves installed package superseded and usable',
      () async {
        final oversizedSupersededPkg =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              version: 1,
              totalSizeMb: 165.0, // Exceeds 150 MB ceiling
              status: OfflinePackageStatus.superseded,
            );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: oversizedSupersededPkg,
          isDemoMode: true,
        );

        await cubit.refreshSupersededPackage();

        expect(
          cubit.state.replacementPackage?.status,
          OfflinePackageStatus.insufficientStorage,
        );
        expect(cubit.state.package.status, OfflinePackageStatus.superseded);
        expect(cubit.state.package.isAvailableOffline, isTrue);
        expect(cubit.state.isAvailableOffline, isTrue);

        await cubit.close();
      },
    );

    test(
      'demoSimulateNetworkInterruption during refresh marks replacement interrupted while installed package remains usable',
      () async {
        final supersededPkg = ActiveTripDemoFixtures.createSampleOfflinePackage(
          itineraryId: 101,
          version: 1,
          status: OfflinePackageStatus.superseded,
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPkg,
          initialFreeStorageMb:
              50.0, // Enters refresh failure state so replacementPackage != null
          isDemoMode: true,
        );

        await cubit.refreshSupersededPackage();
        expect(cubit.state.replacementPackage, isNotNull);

        cubit.demoSimulateNetworkInterruption();

        expect(
          cubit.state.replacementPackage?.status,
          OfflinePackageStatus.networkInterrupted,
        );
        expect(cubit.state.package.status, OfflinePackageStatus.superseded);
        expect(cubit.state.package.isAvailableOffline, isTrue);
        expect(cubit.state.isAvailableOffline, isTrue);

        await cubit.close();
      },
    );

    test(
      'cancelDownload during refresh clears replacementPackage and retains installed package',
      () async {
        final supersededPkg = ActiveTripDemoFixtures.createSampleOfflinePackage(
          itineraryId: 101,
          version: 1,
          status: OfflinePackageStatus.superseded,
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPkg,
          initialFreeStorageMb: 50.0,
          isDemoMode: true,
        );

        await cubit.refreshSupersededPackage();
        expect(cubit.state.replacementPackage, isNotNull);

        cubit.cancelDownload();

        expect(cubit.state.replacementPackage, isNull);
        expect(cubit.state.isRefreshing, isFalse);
        expect(cubit.state.package.status, OfflinePackageStatus.superseded);
        expect(cubit.state.package.isAvailableOffline, isTrue);
        expect(cubit.state.isAvailableOffline, isTrue);

        await cubit.close();
      },
    );

    test(
      'removeOfflineData resets package to notDownloaded and clears active replacement download',
      () async {
        final supersededPkg = ActiveTripDemoFixtures.createSampleOfflinePackage(
          itineraryId: 101,
          version: 1,
          status: OfflinePackageStatus.superseded,
          lastDownloadedAt: DateTime(2026, 10, 1, 10),
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPkg,
          initialFreeStorageMb: 50.0,
          isDemoMode: true,
        );

        await cubit.refreshSupersededPackage();
        expect(cubit.state.replacementPackage, isNotNull);

        cubit.removeOfflineData();

        expect(cubit.state.package.status, OfflinePackageStatus.notDownloaded);
        expect(cubit.state.package.progressPercent, 0.0);
        expect(cubit.state.package.lastDownloadedAt, isNull);
        expect(cubit.state.package.isAvailableOffline, isFalse);
        expect(cubit.state.replacementPackage, isNull);
        expect(cubit.state.isRefreshing, isFalse);

        await cubit.close();
      },
    );

    test(
      'initial first-time download is NOT available offline during checkingStorage or downloading',
      () async {
        final notDownloadedPkg =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              status: OfflinePackageStatus.notDownloaded,
            );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: notDownloadedPkg,
          isDemoMode: true,
        );

        final emittedStates = <OfflineTripPackageState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        await cubit.startDownload();
        await pumpEventQueue();
        await subscription.cancel();

        // Intermediate states (checkingStorage, 15%, 55%, 88%) must all be false for isAvailableOffline
        for (int i = 0; i < emittedStates.length - 1; i++) {
          final s = emittedStates[i];
          expect(
            s.package.isAvailableOffline,
            isFalse,
            reason: 'Intermediate state $i must NOT be available offline',
          );
          expect(
            s.isAvailableOffline,
            isFalse,
            reason:
                'Intermediate state $i state.isAvailableOffline must be false',
          );
        }

        // Final state is available
        expect(emittedStates.last.package.isAvailableOffline, isTrue);
        expect(emittedStates.last.isAvailableOffline, isTrue);

        await cubit.close();
      },
    );
  });
}
