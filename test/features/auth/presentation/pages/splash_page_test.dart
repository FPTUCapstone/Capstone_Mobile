import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/auth/presentation/pages/splash_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/tripmate_logo.dart';

void main() {
  group('SplashPage Animated Startup Tests', () {
    testWidgets('renders branded Voyager elements and logo emblem', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SplashPage()));

      // Verify emblem and brand text elements
      expect(find.byType(TripMateEmblem), findsOneWidget);
      expect(find.text('TripMate'), findsOneWidget);
      expect(find.text('Plan smarter. Travel better.'), findsOneWidget);
      expect(
        find.text('Hành trình trọn vẹn · Trải nghiệm thông minh'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Get started'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('animates entrance sequence smoothly over time', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SplashPage()));

      // On first frame, initial animation has started
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(TripMateEmblem), findsOneWidget);

      // Halfway through animation (800ms)
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('TripMate'), findsOneWidget);

      // Settle animation to completion
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('invokes onFinished callback upon animation completion', (
      tester,
    ) async {
      var finished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashPage(
            displayDuration: const Duration(milliseconds: 500),
            onFinished: () {
              finished = true;
            },
          ),
        ),
      );

      expect(finished, isFalse);

      await tester.pump(const Duration(milliseconds: 600));
      expect(finished, isTrue);
    });

    testWidgets('autoNavigate routes to guestHome when autoNavigate is true', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AppRoutes.splash,
        routes: [
          GoRoute(
            path: AppRoutes.splash,
            builder: (_, _) => const SplashPage(
              autoNavigate: true,
              displayDuration: Duration(milliseconds: 400),
            ),
          ),
          GoRoute(
            path: AppRoutes.guestHome,
            builder: (_, _) =>
                const Scaffold(body: Text('Guest Home Destination')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Guest Home Destination'), findsOneWidget);
    });

    testWidgets('manual Get started tap triggers immediate navigation', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: AppRoutes.splash,
        routes: [
          GoRoute(
            path: AppRoutes.splash,
            builder: (_, _) => const SplashPage(autoNavigate: false),
          ),
          GoRoute(
            path: AppRoutes.guestHome,
            builder: (_, _) =>
                const Scaffold(body: Text('Guest Home Destination')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.text('Guest Home Destination'), findsOneWidget);
    });

    testWidgets('respects disableAnimations accessibility setting', (
      tester,
    ) async {
      var finished = false;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: SplashPage(
              displayDuration: const Duration(milliseconds: 1600),
              onFinished: () {
                finished = true;
              },
            ),
          ),
        ),
      );

      // With disableAnimations, animation finishes immediately
      await tester.pump();
      expect(finished, isTrue);
    });
  });
}
