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
}
