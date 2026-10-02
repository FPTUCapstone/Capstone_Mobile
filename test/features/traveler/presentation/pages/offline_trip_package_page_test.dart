import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_trip_package_page.dart';

void main() {
  Widget buildTestWidget({OfflineTripPackageCubit? cubit}) {
    return MaterialApp(
      home: OfflineTripPackagePage(
        itineraryId: 101,
        title: 'Đà Nẵng City Explorer',
        cubit: cubit,
      ),
    );
  }

  group('OfflineTripPackagePage', () {
    testWidgets(
      'renders package details and download button for fresh package',
      (tester) async {
        final notDownloadedPackage =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              title: 'Đà Nẵng City Explorer',
              status: OfflinePackageStatus.notDownloaded,
              totalSizeMb: 118.5,
            );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: notDownloadedPackage,
        );

        await tester.pumpWidget(buildTestWidget(cubit: cubit));
        await tester.pumpAndSettle();

        expect(find.text('Offline Access'), findsOneWidget);
        expect(find.text('Đà Nẵng City Explorer'), findsOneWidget);
        expect(find.textContaining('118.5 MB'), findsWidgets);
        expect(find.text('Download for Offline Use'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets('displays error when package exceeds 150 MB ceiling rule', (
      tester,
    ) async {
      final oversizedPackage =
          ActiveTripDemoFixtures.createSampleOfflinePackage(
            itineraryId: 101,
            totalSizeMb: 165.0,
            status: OfflinePackageStatus.insufficientStorage,
          ).copyWith(
            errorMessage:
                'Package size (165.0 MB) exceeds configured limit of 150 MB.',
          );
      final cubit = OfflineTripPackageCubit(
        itineraryId: 101,
        initialPackage: oversizedPackage,
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.textContaining('150 MB'), findsWidgets);
      expect(
        find.textContaining(
          'Package size (165.0 MB) exceeds configured limit of 150 MB.',
        ),
        findsOneWidget,
      );

      await cubit.close();
    });

    testWidgets('renders ready state with remove button when downloaded', (
      tester,
    ) async {
      final availablePackage =
          ActiveTripDemoFixtures.createSampleOfflinePackage(
            itineraryId: 101,
            status: OfflinePackageStatus.available,
            lastDownloadedAt: DateTime(2026, 10, 12, 10, 30),
          );
      final cubit = OfflineTripPackageCubit(
        itineraryId: 101,
        initialPackage: availablePackage,
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      expect(find.text('AVAILABLE OFFLINE'), findsOneWidget);
      expect(find.text('Remove Offline Data'), findsOneWidget);

      await cubit.close();
    });

    testWidgets('renders update notice and refresh button when superseded', (
      tester,
    ) async {
      final supersededPackage =
          ActiveTripDemoFixtures.createSampleOfflinePackage(
            itineraryId: 101,
            status: OfflinePackageStatus.superseded,
          );
      final cubit = OfflineTripPackageCubit(
        itineraryId: 101,
        initialPackage: supersededPackage,
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Refresh Offline Data'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('UPDATE AVAILABLE'), findsOneWidget);
      expect(find.text('Refresh Offline Data'), findsOneWidget);

      await cubit.close();
    });
  });
}
