import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

void main() {
  group('OfflineTripPackageCubit', () {
    late OfflineTripPackageCubit cubit;

    setUp(() {
      cubit = OfflineTripPackageCubit(
        itineraryId: 101,
        title: 'Đà Nẵng City Explorer',
        initialPackage: ActiveTripDemoFixtures.createSampleOfflinePackage(
          itineraryId: 101,
          totalSizeMb: 118.5,
        ),
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
        );
        expect(testCubit.state.package.isAvailableOffline, isTrue);

        testCubit.demoSimulateSuperseded();
        expect(testCubit.state.package.status, OfflinePackageStatus.superseded);
        // Still available offline to prevent stranded Traveler
        expect(testCubit.state.package.isAvailableOffline, isTrue);

        await testCubit.close();
      },
    );

    test('removeOfflineData resets package to notDownloaded', () {
      cubit.removeOfflineData();
      expect(cubit.state.package.status, OfflinePackageStatus.notDownloaded);
      expect(cubit.state.package.isAvailableOffline, isFalse);
    });
  });
}
