import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
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
        expect(find.textContaining('Mức thu phóng 12–16'), findsNothing);
        expect(find.text('Nội dung gói dữ liệu'), findsNothing);
        expect(find.textContaining('Dung lượng trống'), findsNothing);
      },
    );

    testWidgets(
      'production UC-16 immediately shows the truthful unavailable/integration-pending state',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(title: 'Real Trip', isDemoMode: false),
        );
        await tester.pumpAndSettle();

        expect(find.text('Truy cập ngoại tuyến'), findsOneWidget);
        expect(find.text('Real Trip'), findsOneWidget);
        expect(find.text('Gói ngoại tuyến hiện chưa khả dụng'), findsOneWidget);
        expect(
          find.textContaining(
            'Tính năng tải bản đồ và lịch trình ngoại tuyến hiện chưa khả dụng do dịch vụ gói chuyến đi và lưu trữ cục bộ chưa được kết nối.',
          ),
          findsOneWidget,
        );
        expect(find.text('Quay lại lịch trình'), findsOneWidget);
      },
    );

    testWidgets('production UC-16 has no actionable fake Download button', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(title: 'Real Trip', isDemoMode: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tải về xem ngoại tuyến'), findsNothing);
      expect(find.byIcon(Icons.download_rounded), findsNothing);
    });

    testWidgets(
      'direct Offline route without state.extra does NOT fabricate "Khám phá Đà Nẵng"',
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

        expect(find.text('Khám phá Đà Nẵng'), findsNothing);
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

      expect(find.text('Truy cập ngoại tuyến'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Đang tải thông tin chuyến đi...'), findsOneWidget);

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

      expect(find.text('Không thể tải thông tin chuyến đi.'), findsOneWidget);
      expect(find.text('Không thể tải lịch trình #101.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);
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

        expect(find.text('Truy cập ngoại tuyến'), findsOneWidget);
        expect(find.text('Đà Nẵng City Explorer'), findsOneWidget);
        expect(find.text('Nội dung gói dữ liệu'), findsOneWidget);
        expect(find.textContaining('85.0 MB'), findsWidgets);
        expect(find.textContaining('2.5 MB'), findsWidgets);
        expect(find.textContaining('31.0 MB'), findsWidgets);
        expect(find.text('Tải về xem ngoại tuyến'), findsOneWidget);

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

      expect(find.byTooltip('Điều khiển demo'), findsNothing);
      expect(find.byIcon(Icons.build_circle_outlined), findsNothing);
    });

    testWidgets('DEMO controls appear when isDemoMode is true', (tester) async {
      await tester.pumpWidget(buildTestWidget(isDemoMode: true));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Điều khiển demo'), findsOneWidget);
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

      expect(find.text('SẴN SÀNG NGOẠI TUYẾN'), findsOneWidget);
      expect(find.text('Xóa dữ liệu ngoại tuyến'), findsOneWidget);
      expect(find.textContaining('Tải lần cuối:'), findsOneWidget);

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

        expect(find.textContaining('Tải lần cuối:'), findsOneWidget);

        // Tap Remove Offline Data
        await tester.tap(find.text('Xóa dữ liệu ngoại tuyến'));
        await tester.pumpAndSettle();

        // Confirm in dialog
        await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
        await tester.pumpAndSettle();

        // Package is removed and lastDownloadedAt is cleared
        expect(cubit.state.package.status, OfflinePackageStatus.notDownloaded);
        expect(cubit.state.package.lastDownloadedAt, isNull);
        expect(find.textContaining('Tải lần cuối:'), findsNothing);

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
        find.text('Cập nhật dữ liệu ngoại tuyến'),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('CÓ BẢN CẬP NHẬT'), findsOneWidget);
      expect(find.text('Cập nhật dữ liệu ngoại tuyến'), findsOneWidget);

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

        expect(find.text('ĐANG CẬP NHẬT...'), findsOneWidget);
        expect(find.text('Đà Nẵng City Explorer'), findsOneWidget);
        expect(find.textContaining('Tải lần cuối:'), findsOneWidget);
        expect(
          find.text(
            'Đang tải phiên bản mới (v2). Gói ngoại tuyến hiện tại (v1) vẫn có thể sử dụng.',
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
          find.text('Hủy cập nhật'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Hủy cập nhật'), findsOneWidget);

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
          find.text('Hủy cập nhật'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Hủy cập nhật'), findsOneWidget);
        await tester.tap(find.text('Hủy cập nhật'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('CÓ BẢN CẬP NHẬT'),
          -100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('CÓ BẢN CẬP NHẬT'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Cập nhật dữ liệu ngoại tuyến'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Cập nhật dữ liệu ngoại tuyến'), findsOneWidget);
        expect(
          find.text(
            'Có phiên bản lịch trình mới hơn trên máy chủ. Bản sao ngoại tuyến hiện tại vẫn dùng được.',
          ),
          findsOneWidget,
        );
        expect(find.text('Hủy cập nhật'), findsNothing);

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
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
    Map<int, StopRemovalReason> removalReasons = const {},
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
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
    Map<int, StopRemovalReason> removalReasons = const {},
  }) => throw UnimplementedError();
}
