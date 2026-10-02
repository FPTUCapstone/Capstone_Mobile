import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_cubit.dart';
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
          OfflinePackageStatus.notDownloaded,
        );
        expect(prodCubit.state.package.lastDownloadedAt, isNull);

        prodCubit.close();
      },
    );

    test(
      'production cubit download does not fake success and reports truthful unavailability',
      () async {
        final prodCubit = OfflineTripPackageCubit(itineraryId: 202);

        await prodCubit.startDownload();

        expect(prodCubit.state.package.status, OfflinePackageStatus.error);
        expect(
          prodCubit.state.package.errorMessage,
          'Offline download service is currently unavailable.',
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
}
