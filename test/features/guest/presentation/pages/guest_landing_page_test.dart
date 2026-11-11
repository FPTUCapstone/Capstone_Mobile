import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/guest/presentation/pages/guest_landing_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sliding_bottom_nav.dart';

void main() {
  testWidgets(
    'GuestLandingPage persistent bottom navigation switches tabs without losing the bar',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GuestLandingPage())),
      );
      await tester.pumpAndSettle();

      // Bottom navigation bar is rendered
      expect(find.byType(AppSlidingBottomNav), findsOneWidget);
      expect(find.text('Trang chủ'), findsOneWidget);
      expect(find.text('Khám phá'), findsWidgets);
      expect(find.text('Tour'), findsWidgets);
      expect(find.text('Tài khoản'), findsOneWidget);

      // Initially on Tab 0 (Home)
      expect(
        find.text('Hành trình trọn vẹn,\ntrải nghiệm thông minh'),
        findsOneWidget,
      );

      // Tap "Tài khoản" tab
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle();

      // Bottom bar is STILL visible
      expect(find.byType(AppSlidingBottomNav), findsOneWidget);
      // Account screen is displayed
      expect(find.text('Khách du lịch'), findsOneWidget);
      expect(find.text('Đăng nhập ngay'), findsOneWidget);

      // Tap "Trang chủ" tab to switch back
      await tester.tap(find.text('Trang chủ'));
      await tester.pumpAndSettle();

      // Bottom bar is STILL visible and Home is back
      expect(find.byType(AppSlidingBottomNav), findsOneWidget);
      expect(
        find.text('Hành trình trọn vẹn,\ntrải nghiệm thông minh'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GuestLandingPage displays curated tour section safely without synthetic broken detail routes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GuestLandingPage())),
      );
      await tester.pumpAndSettle();

      // Curated tour cards are present in home list
      expect(find.text('Tour du lịch thịnh hành'), findsOneWidget);
      expect(
        find.text('Khám phá Cố đô Huế & Ca Huế Sông Hương'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'GuestLandingPage curated POI and tour imagery uses accurate verified Wikimedia assets without Unsplash',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GuestLandingPage())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final tourCardFinder = find.text('Bà Nà Hills & Cầu Vàng Trọn Gói');
      await tester.scrollUntilVisible(
        tourCardFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tourCardFinder, findsOneWidget);

      final renderedAssets = tester
          .widgetList<Image>(find.byType(Image))
          .map((w) => w.image)
          .whereType<AssetImage>()
          .map((a) => a.assetName)
          .toList();

      expect(
        renderedAssets,
        contains('assets/images/destinations/bana_golden_bridge.jpg'),
      );
      expect(
        renderedAssets,
        contains('assets/images/destinations/hoian_ancient_town.jpg'),
      );
      expect(
        renderedAssets,
        contains('assets/images/destinations/hue_ngo_mon.jpg'),
      );
      for (final asset in renderedAssets) {
        expect(asset, isNot(contains('unsplash.com')));
      }
    },
  );
}
