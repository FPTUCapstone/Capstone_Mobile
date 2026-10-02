import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_trip_package_page.dart';

void main() {
  Widget buildTestWidget({
    OfflineTripPackageCubit? cubit,
    bool isDemoMode = false,
  }) {
    return MaterialApp(
      home: OfflineTripPackagePage(
        itineraryId: 101,
        title: 'Đà Nẵng City Explorer',
        cubit: cubit,
        isDemoMode: isDemoMode,
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
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        expect(find.text('Offline Access'), findsOneWidget);
        expect(find.text('Đà Nẵng City Explorer'), findsOneWidget);
        expect(find.textContaining('118.5 MB'), findsWidgets);
        expect(find.text('Download for Offline Use'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets('DEMO controls are absent when isDemoMode is false', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(isDemoMode: false));
      await tester.pumpAndSettle();

      expect(find.byTooltip('DEMO_ONLY Controls'), findsNothing);
      expect(find.byIcon(Icons.build_circle_outlined), findsNothing);
    });

    testWidgets('DEMO controls appear when isDemoMode is true', (tester) async {
      await tester.pumpWidget(buildTestWidget(isDemoMode: true));
      await tester.pumpAndSettle();

      expect(find.byTooltip('DEMO_ONLY Controls'), findsOneWidget);
      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
    });

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
        isDemoMode: true,
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit, isDemoMode: true));
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
        isDemoMode: true,
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      expect(find.text('AVAILABLE OFFLINE'), findsOneWidget);
      expect(find.text('Remove Offline Data'), findsOneWidget);
      expect(find.textContaining('Last downloaded:'), findsOneWidget);

      await cubit.close();
    });

    testWidgets(
      'FIX 4: removing offline data clears lastDownloadedAt and UI removes Last downloaded text',
      (tester) async {
        final availablePackage =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              status: OfflinePackageStatus.available,
              lastDownloadedAt: DateTime(2026, 10, 12, 10, 30),
            );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: availablePackage,
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Last downloaded:'), findsOneWidget);

        // Tap Remove Offline Data
        await tester.tap(find.text('Remove Offline Data'));
        await tester.pumpAndSettle();

        // Confirm in dialog
        await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
        await tester.pumpAndSettle();

        // Package is removed and lastDownloadedAt is cleared
        expect(cubit.state.package.status, OfflinePackageStatus.notDownloaded);
        expect(cubit.state.package.lastDownloadedAt, isNull);
        expect(find.textContaining('Last downloaded:'), findsNothing);

        await cubit.close();
      },
    );

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
        isDemoMode: true,
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit, isDemoMode: true));
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
