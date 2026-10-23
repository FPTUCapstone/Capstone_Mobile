import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/guest/presentation/widgets/guest_hero_banner.dart';

void main() {
  const customSlides = [
    HeroSlideData(
      tag: '✦ SLIDE 1',
      title: 'Title Slide 1',
      subtitle: 'Subtitle Slide 1',
      imageUrl: 'https://example.com/img1.jpg',
    ),
    HeroSlideData(
      tag: '✦ SLIDE 2',
      title: 'Title Slide 2',
      subtitle: 'Subtitle Slide 2',
      imageUrl: 'https://example.com/img2.jpg',
    ),
  ];

  testWidgets('renders first slide title, tag, subtitle, and indicators', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GuestHeroBanner(autoRotate: false, customSlides: customSlides),
        ),
      ),
    );

    expect(find.text('✦ SLIDE 1'), findsOneWidget);
    expect(find.text('Title Slide 1'), findsOneWidget);
    expect(find.text('Subtitle Slide 1'), findsOneWidget);
    // Two indicators for 2 slides
    expect(find.byType(AnimatedContainer), findsNWidgets(2));
  });

  testWidgets('manual swipe transitions to next slide', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GuestHeroBanner(autoRotate: false, customSlides: customSlides),
        ),
      ),
    );

    expect(find.text('Title Slide 1'), findsOneWidget);

    // Fling left to transition to slide 2
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Title Slide 2'), findsOneWidget);
    expect(find.text('✦ SLIDE 2'), findsOneWidget);
  });

  testWidgets('tapping slide navigates to explore by default', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(
            body: GuestHeroBanner(
              autoRotate: false,
              customSlides: customSlides,
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.explore,
          builder: (_, _) => const Scaffold(body: Text('Explore Destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Title Slide 1'));
    await tester.pumpAndSettle();

    expect(find.text('Explore Destination'), findsOneWidget);
  });

  testWidgets('auto-rotation advances slides over time', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GuestHeroBanner(
            autoRotate: true,
            rotationInterval: Duration(milliseconds: 1000),
            customSlides: customSlides,
          ),
        ),
      ),
    );

    expect(find.text('Title Slide 1'), findsOneWidget);

    // Advance time past the rotation interval and animation duration
    await tester.pump(const Duration(milliseconds: 1050));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Title Slide 2'), findsOneWidget);
  });
}
