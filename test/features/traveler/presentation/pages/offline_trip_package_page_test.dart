import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/offline_trip_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_trip_package_page.dart';

void main() {
  Widget buildTestWidget({
    OfflineTripPackageCubit? cubit,
    String? title,
    ItineraryRepository? repository,
    bool isDemoMode = false,
  }) {
    return MaterialApp(
      home: OfflineTripPackagePage(
        itineraryId: 101,
        title: title,
        cubit: cubit,
        repository: repository,
        isDemoMode: isDemoMode,
      ),
    );
  }

  group('OfflineTripPackagePage Production Mode (UC-16 Truthful)', () {
    testWidgets(
      'production mode does NOT show fake package values (85.0 MB, 2.5 MB, 31.0 MB, 18 km, Zoom 12-16)',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Real Trip', isDemoMode: false),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('85.0 MB'), findsNothing);
        expect(find.textContaining('2.5 MB'), findsNothing);
        expect(find.textContaining('31.0 MB'), findsNothing);
        expect(find.textContaining('18 km'), findsNothing);
        expect(find.textContaining('Zoom 12-16'), findsNothing);
        expect(find.text('Package Contents'), findsNothing);
        expect(find.textContaining('GB available'), findsNothing);
      },
    );

    testWidgets(
      'production UC-16 immediately shows the truthful unavailable/integration-pending state',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Real Trip', isDemoMode: false),
        );
        await tester.pumpAndSettle();

        expect(find.text('Offline Access'), findsOneWidget);
        expect(find.text('Real Trip'), findsOneWidget);
        expect(
          find.text('Offline package is not available yet'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Offline map and itinerary download is not currently available because the required trip-package service and local persistence integration are not yet connected.',
          ),
          findsOneWidget,
        );
        expect(find.text('Back to itinerary'), findsOneWidget);
      },
    );

    testWidgets('production UC-16 has no actionable fake Download button', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(title: 'Real Trip', isDemoMode: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Download for Offline Use'), findsNothing);
      expect(find.byIcon(Icons.download_rounded), findsNothing);
    });

    testWidgets(
      'direct Offline route without state.extra does NOT fabricate "Đà Nẵng City Explorer"',
      (tester) async {
        final repo = _FakeItineraryRepository(
          detail: _createSampleDetail(
            itineraryId: 101,
            title: 'Hue Cultural Journey',
          ),
        );

        await tester.pumpWidget(
          buildTestWidget(title: null, repository: repo, isDemoMode: false),
        );
        await tester.pumpAndSettle();

        expect(find.text('Đà Nẵng City Explorer'), findsNothing);
        expect(find.text('Hue Cultural Journey'), findsOneWidget);
      },
    );

    testWidgets('shows loading state while metadata is being retrieved', (
      tester,
    ) async {
      final completer = Completer<ItineraryDetail>();
      final repo = _CompleterItineraryRepository(completer);

      await tester.pumpWidget(
        buildTestWidget(title: null, repository: repo, isDemoMode: false),
      );
      await tester.pump();

      expect(find.text('Offline Access'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading trip information...'), findsOneWidget);

      completer.complete(
        _createSampleDetail(itineraryId: 101, title: 'Loaded Trip'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loaded Trip'), findsOneWidget);
    });

    testWidgets('shows error state when metadata retrieval fails', (
      tester,
    ) async {
      final repo = _FakeItineraryRepository(shouldThrow: true);

      await tester.pumpWidget(
        buildTestWidget(title: null, repository: repo, isDemoMode: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trip information unavailable.'), findsOneWidget);
      expect(find.text('Could not load itinerary #101.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Go back'), findsOneWidget);
    });
  });

  group('OfflineTripPackagePage Demo Mode (UC-16 Preview)', () {
    testWidgets(
      'explicit demo mode DOES show the intended package-preview experience and fixtures',
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
        expect(find.text('Package Contents'), findsOneWidget);
        expect(find.textContaining('85.0 MB'), findsWidgets);
        expect(find.textContaining('2.5 MB'), findsWidgets);
        expect(find.textContaining('31.0 MB'), findsWidgets);
        expect(find.text('Download for Offline Use'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets('DEMO controls are absent when isDemoMode is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(title: 'Real Trip', isDemoMode: false),
      );
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

    testWidgets(
      'Review Round 4 P2: renders UPDATING badge, progress, and usable notice during refresh without hiding installed metadata',
      (tester) async {
        final supersededPackage =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              status: OfflinePackageStatus.superseded,
              version: 1,
              title: 'Đà Nẵng City Explorer',
              lastDownloadedAt: DateTime(2026, 10, 1, 9),
            );
        final replacementPackage = OfflineTripPackage(
          itineraryId: 101,
          title: 'Đà Nẵng City Explorer',
          version: 2,
          status: OfflinePackageStatus.downloading,
          totalSizeMb: 118.5,
          progressPercent: 55.0,
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPackage,
          initialReplacementPackage: replacementPackage,
          initialDownloadStepDescription:
              'Downloading updated POI photos & information...',
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        expect(find.text('UPDATING...'), findsOneWidget);
        expect(find.text('Đà Nẵng City Explorer'), findsOneWidget);
        expect(find.textContaining('Last downloaded:'), findsOneWidget);
        expect(
          find.text(
            'Downloading updated version (v2). Your current offline package (v1) remains usable.',
          ),
          findsOneWidget,
        );

        await tester.scrollUntilVisible(
          find.text('55%'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('55%'), findsOneWidget);
        expect(
          find.text('Downloading updated POI photos & information...'),
          findsOneWidget,
        );

        await tester.scrollUntilVisible(
          find.text('Cancel Update'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Cancel Update'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets(
      'Review Round 4 P2: cancelling active update restores superseded view with current copy usable',
      (tester) async {
        final supersededPackage =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              status: OfflinePackageStatus.superseded,
              version: 1,
              title: 'Đà Nẵng City Explorer',
            );
        final replacementPackage = OfflineTripPackage(
          itineraryId: 101,
          title: 'Đà Nẵng City Explorer',
          version: 2,
          status: OfflinePackageStatus.downloading,
          totalSizeMb: 118.5,
          progressPercent: 55.0,
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPackage,
          initialReplacementPackage: replacementPackage,
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Cancel Update'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Cancel Update'), findsOneWidget);
        await tester.tap(find.text('Cancel Update'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('UPDATE AVAILABLE'),
          -100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('UPDATE AVAILABLE'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Refresh Offline Data'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Refresh Offline Data'), findsOneWidget);
        expect(
          find.text(
            'A newer itinerary version exists on the server. Your existing offline copy remains usable.',
          ),
          findsOneWidget,
        );
        expect(find.text('Cancel Update'), findsNothing);

        await cubit.close();
      },
    );

    testWidgets(
      'Review Round 4 P2: update failure due to insufficient storage alerts user while keeping installed copy',
      (tester) async {
        final supersededPackage =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              status: OfflinePackageStatus.superseded,
              version: 1,
              title: 'Đà Nẵng City Explorer',
            );
        final replacementPackage = OfflineTripPackage(
          itineraryId: 101,
          title: 'Đà Nẵng City Explorer',
          version: 2,
          status: OfflinePackageStatus.insufficientStorage,
          errorMessage:
              'Insufficient storage space. At least 150MB free space required for offline data.',
          totalSizeMb: 118.5,
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPackage,
          initialReplacementPackage: replacementPackage,
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Insufficient storage space. At least 150MB free space required for offline data.',
          ),
          findsOneWidget,
        );
        expect(find.text('Đà Nẵng City Explorer'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets(
      'Review Round 4 P2: update failure due to network interruption alerts user that existing offline data remains usable',
      (tester) async {
        final supersededPackage =
            ActiveTripDemoFixtures.createSampleOfflinePackage(
              itineraryId: 101,
              status: OfflinePackageStatus.superseded,
              version: 1,
              title: 'Đà Nẵng City Explorer',
            );
        final replacementPackage = OfflineTripPackage(
          itineraryId: 101,
          title: 'Đà Nẵng City Explorer',
          version: 2,
          status: OfflinePackageStatus.networkInterrupted,
          errorMessage:
              'Download interrupted due to connection loss. Existing offline data remains usable.',
          totalSizeMb: 118.5,
        );
        final cubit = OfflineTripPackageCubit(
          itineraryId: 101,
          initialPackage: supersededPackage,
          initialReplacementPackage: replacementPackage,
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Download interrupted due to connection loss. Existing offline data remains usable.',
          ),
          findsOneWidget,
        );
        expect(find.text('Đà Nẵng City Explorer'), findsOneWidget);

        await cubit.close();
      },
    );
  });
}

ItineraryDetail _createSampleDetail({
  required int itineraryId,
  required String title,
}) {
  return ItineraryDetail(
    itineraryId: itineraryId,
    schedulingRequestId: 1,
    title: title,
    version: 1,
    status: 'Active',
    validFrom: null,
    validTo: null,
    canManage: true,
    totalEstimatedCost: 150000,
    totalDurationMinutes: 180,
    items: const [],
  );
}

final class _FakeItineraryRepository implements ItineraryRepository {
  _FakeItineraryRepository({this.detail, this.shouldThrow = false});

  final ItineraryDetail? detail;
  final bool shouldThrow;

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    if (shouldThrow) {
      throw Exception('Server unreachable');
    }
    return detail ??
        _createSampleDetail(itineraryId: itineraryId, title: 'Sample Trip');
  }

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> adjustItems({
    required int itineraryId,
    required List<int> orderedVisitPoiIds,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

final class _CompleterItineraryRepository implements ItineraryRepository {
  _CompleterItineraryRepository(this.completer);

  final Completer<ItineraryDetail> completer;

  @override
  Future<ItineraryDetail> getById(int itineraryId) => completer.future;

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> adjustItems({
    required int itineraryId,
    required List<int> orderedVisitPoiIds,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}
