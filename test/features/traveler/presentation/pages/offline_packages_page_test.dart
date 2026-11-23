import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_itinerary_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_packages_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/offline_trip_package_page.dart';
import '../../support/offline_fixture.dart';

void main() {
  testWidgets('local package list opens without requesting online metadata', (
    tester,
  ) async {
    final repo = FakeOfflineRepository()..unreadable = ['bad-cache'];
    await tester.pumpWidget(
      MaterialApp(home: OfflinePackagesPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Local trip'), findsOneWidget);
    expect(find.textContaining('Một số gói dữ liệu bị hỏng'), findsOneWidget);
    expect(repo.calls, ['list']);
  });
  testWidgets('empty list explains how to download a real itinerary', (
    tester,
  ) async {
    final repo = FakeOfflineRepository()..manifest = null;
    await tester.pumpWidget(
      MaterialApp(home: OfflinePackagesPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch trình đã tải'), findsOneWidget);
  });
  testWidgets(
    'package page loads local-first and opening it is not download success',
    (tester) async {
      final repo = FakeOfflineRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineTripPackagePage(
            itineraryId: 10,
            offlineRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.calls.first, 'read');
      expect(find.text('Local trip'), findsOneWidget);
      expect(find.textContaining('Trip package downloaded!'), findsNothing);
      expect(find.text('Giới hạn gói: 150 MB'), findsOneWidget);
    },
  );
  testWidgets(
    'locked cached reader never exposes itinerary contents or map action',
    (tester) async {
      final repo = FakeOfflineRepository()
        ..manifest = offlineFixture(locked: true);
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineItineraryPage(itineraryId: 10, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Không còn quyền truy cập'), findsOneWidget);
      expect(find.text('Local trip'), findsNothing);
      expect(find.text('Xem bản đồ'), findsNothing);
    },
  );
  testWidgets('small screen and large text keep package controls scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: OfflineTripPackagePage(
          itineraryId: 10,
          offlineRepository: FakeOfflineRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
